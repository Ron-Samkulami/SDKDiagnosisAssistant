/* vv_mz_zip_rw.c -- Zip reader/writer
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/

#include "vv_mz.h"
#include "vv_mz_crypt.h"
#include "vv_mz_os.h"
#include "vv_mz_strm.h"
#include "vv_mz_strm_buf.h"
#include "vv_mz_strm_mem.h"
#include "vv_mz_strm_os.h"
#include "vv_mz_strm_split.h"
#include "vv_mz_strm_wzaes.h"
#include "vv_mz_zip.h"

#include "vv_mz_zip_rw.h"

/***************************************************************************/

#define VV_MZ_DEFAULT_PROGRESS_INTERVAL    (1000u)

#define VV_MZ_ZIP_CD_FILENAME              ("__cdcd__")

/***************************************************************************/

typedef struct vv_mz_zip_reader_s {
    void        *zip_handle;
    void        *file_stream;
    void        *buffered_stream;
    void        *split_stream;
    void        *mem_stream;
    void        *hash;
    uint16_t    hash_algorithm;
    uint16_t    hash_digest_size;
    vv_mz_zip_file *file_info;
    const char  *pattern;
    uint8_t     pattern_ignore_case;
    const char  *password;
    void        *overwrite_userdata;
    vv_mz_zip_reader_overwrite_cb
                overwrite_cb;
    void        *password_userdata;
    vv_mz_zip_reader_password_cb
                password_cb;
    void        *progress_userdata;
    vv_mz_zip_reader_progress_cb
                progress_cb;
    uint32_t    progress_cb_interval_ms;
    void        *entry_userdata;
    vv_mz_zip_reader_entry_cb
                entry_cb;
    uint8_t     raw;
    uint8_t     buffer[UINT16_MAX];
    int32_t     encoding;
    uint8_t     sign_required;
    uint8_t     cd_verified;
    uint8_t     cd_zipped;
    uint8_t     entry_verified;
} vv_mz_zip_reader;

/***************************************************************************/

int32_t vv_mz_zip_reader_is_open(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    if (reader == NULL)
        return VV_MZ_PARAM_ERROR;
    if (reader->zip_handle == NULL)
        return VV_MZ_PARAM_ERROR;
    return VV_MZ_OK;
}

int32_t vv_mz_zip_reader_open(void *handle, void *stream)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;

    reader->cd_verified = 0;
    reader->cd_zipped = 0;

    vv_mz_zip_create(&reader->zip_handle);
    vv_mz_zip_set_recover(reader->zip_handle, 1);

    err = vv_mz_zip_open(reader->zip_handle, stream, VV_MZ_OPEN_MODE_READ);

    if (err != VV_MZ_OK)
    {
        vv_mz_zip_reader_close(handle);
        return err;
    }

    vv_mz_zip_reader_unzip_cd(reader);
    return VV_MZ_OK;
}

int32_t vv_mz_zip_reader_open_file(void *handle, const char *path)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;


    vv_mz_zip_reader_close(handle);

    vv_mz_stream_os_create(&reader->file_stream);
    vv_mz_stream_buffered_create(&reader->buffered_stream);
    vv_mz_stream_split_create(&reader->split_stream);

    vv_mz_stream_set_base(reader->buffered_stream, reader->file_stream);
    vv_mz_stream_set_base(reader->split_stream, reader->buffered_stream);

    err = vv_mz_stream_open(reader->split_stream, path, VV_MZ_OPEN_MODE_READ);
    if (err == VV_MZ_OK)
        err = vv_mz_zip_reader_open(handle, reader->split_stream);
    return err;
}

int32_t vv_mz_zip_reader_open_file_in_memory(void *handle, const char *path)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    void *file_stream = NULL;
    int64_t file_size = 0;
    int32_t err = 0;


    vv_mz_zip_reader_close(handle);

    vv_mz_stream_os_create(&file_stream);

    err = vv_mz_stream_os_open(file_stream, path, VV_MZ_OPEN_MODE_READ);

    if (err != VV_MZ_OK)
    {
        vv_mz_stream_os_delete(&file_stream);
        vv_mz_zip_reader_close(handle);
        return err;
    }

    vv_mz_stream_os_seek(file_stream, 0, VV_MZ_SEEK_END);
    file_size = vv_mz_stream_os_tell(file_stream);
    vv_mz_stream_os_seek(file_stream, 0, VV_MZ_SEEK_SET);

    if ((file_size <= 0) || (file_size > UINT32_MAX))
    {
        /* Memory size is too large or too small */

        vv_mz_stream_os_close(file_stream);
        vv_mz_stream_os_delete(&file_stream);
        vv_mz_zip_reader_close(handle);
        return VV_MZ_MEM_ERROR;
    }

    vv_mz_stream_mem_create(&reader->mem_stream);
    vv_mz_stream_mem_set_grow_size(reader->mem_stream, (int32_t)file_size);
    vv_mz_stream_mem_open(reader->mem_stream, NULL, VV_MZ_OPEN_MODE_CREATE);

    err = vv_mz_stream_copy(reader->mem_stream, file_stream, (int32_t)file_size);

    vv_mz_stream_os_close(file_stream);
    vv_mz_stream_os_delete(&file_stream);

    if (err == VV_MZ_OK)
        err = vv_mz_zip_reader_open(handle, reader->mem_stream);
    if (err != VV_MZ_OK)
        vv_mz_zip_reader_close(handle);

    return err;
}

int32_t vv_mz_zip_reader_open_buffer(void *handle, uint8_t *buf, int32_t len, uint8_t copy)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;

    vv_mz_zip_reader_close(handle);

    vv_mz_stream_mem_create(&reader->mem_stream);

    if (copy)
    {
        vv_mz_stream_mem_set_grow_size(reader->mem_stream, len);
        vv_mz_stream_mem_open(reader->mem_stream, NULL, VV_MZ_OPEN_MODE_CREATE);
        vv_mz_stream_mem_write(reader->mem_stream, buf, len);
        vv_mz_stream_mem_seek(reader->mem_stream, 0, VV_MZ_SEEK_SET);
    }
    else
    {
        vv_mz_stream_mem_open(reader->mem_stream, NULL, VV_MZ_OPEN_MODE_READ);
        vv_mz_stream_mem_set_buffer(reader->mem_stream, buf, len);
    }

    if (err == VV_MZ_OK)
        err = vv_mz_zip_reader_open(handle, reader->mem_stream);

    return err;
}

int32_t vv_mz_zip_reader_close(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;

    if (reader->zip_handle != NULL)
    {
        err = vv_mz_zip_close(reader->zip_handle);
        vv_mz_zip_delete(&reader->zip_handle);
    }

    if (reader->split_stream != NULL)
    {
        vv_mz_stream_split_close(reader->split_stream);
        vv_mz_stream_split_delete(&reader->split_stream);
    }

    if (reader->buffered_stream != NULL)
        vv_mz_stream_buffered_delete(&reader->buffered_stream);

    if (reader->file_stream != NULL)
        vv_mz_stream_os_delete(&reader->file_stream);

    if (reader->mem_stream != NULL)
    {
        vv_mz_stream_mem_close(reader->mem_stream);
        vv_mz_stream_mem_delete(&reader->mem_stream);
    }

    return err;
}

/***************************************************************************/

int32_t vv_mz_zip_reader_unzip_cd(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    vv_mz_zip_file *cd_info = NULL;
    void *cd_mem_stream = NULL;
    void *new_cd_stream = NULL;
    void *file_extra_stream = NULL;
    uint64_t number_entry = 0;
    int32_t err = VV_MZ_OK;


    err = vv_mz_zip_reader_goto_first_entry(handle);
    if (err != VV_MZ_OK)
        return err;
    err = vv_mz_zip_reader_entry_get_info(handle, &cd_info);
    if (err != VV_MZ_OK)
        return err;

    if (strcmp(cd_info->filename, VV_MZ_ZIP_CD_FILENAME) != 0)
        return vv_mz_zip_reader_goto_first_entry(handle);

    err = vv_mz_zip_reader_entry_open(handle);
    if (err != VV_MZ_OK)
        return err;

    vv_mz_stream_mem_create(&file_extra_stream);
    vv_mz_stream_mem_set_buffer(file_extra_stream, (void *)cd_info->extrafield, cd_info->extrafield_size);

    err = vv_mz_zip_extrafield_find(file_extra_stream, VV_MZ_ZIP_EXTENSION_CDCD, NULL);
    if (err == VV_MZ_OK)
        err = vv_mz_stream_read_uint64(file_extra_stream, &number_entry);

    vv_mz_stream_mem_delete(&file_extra_stream);

    if (err != VV_MZ_OK)
        return err;

    vv_mz_zip_get_cd_mem_stream(reader->zip_handle, &cd_mem_stream);
    if (vv_mz_stream_mem_is_open(cd_mem_stream) != VV_MZ_OK)
        vv_mz_stream_mem_open(cd_mem_stream, NULL, VV_MZ_OPEN_MODE_CREATE);

    err = vv_mz_stream_seek(cd_mem_stream, 0, VV_MZ_SEEK_SET);
    if (err == VV_MZ_OK)
        err = vv_mz_stream_copy_stream(cd_mem_stream, NULL, handle, vv_mz_zip_reader_entry_read,
            (int32_t)cd_info->uncompressed_size);

    if (err == VV_MZ_OK)
    {
        reader->cd_zipped = 1;

        vv_mz_zip_set_cd_stream(reader->zip_handle, 0, cd_mem_stream);
        vv_mz_zip_set_number_entry(reader->zip_handle, number_entry);

        err = vv_mz_zip_reader_goto_first_entry(handle);
    }

    reader->cd_verified = reader->entry_verified;

    vv_mz_stream_mem_delete(&new_cd_stream);
    return err;
}

/***************************************************************************/

static int32_t vv_mz_zip_reader_locate_entry_cb(void *handle, void *userdata, vv_mz_zip_file *file_info)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)userdata;
    int32_t result = 0;
    VV_MZ_UNUSED(handle);
    result = vv_mz_path_compare_wc(file_info->filename, reader->pattern, reader->pattern_ignore_case);
    return result;
}

int32_t vv_mz_zip_reader_goto_first_entry(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;

    if (vv_mz_zip_reader_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;

    if (vv_mz_zip_entry_is_open(reader->zip_handle) == VV_MZ_OK)
        vv_mz_zip_reader_entry_close(handle);

    if (reader->pattern == NULL)
        err = vv_mz_zip_goto_first_entry(reader->zip_handle);
    else
        err = vv_mz_zip_locate_first_entry(reader->zip_handle, reader, vv_mz_zip_reader_locate_entry_cb);

    reader->file_info = NULL;
    if (err == VV_MZ_OK)
        err = vv_mz_zip_entry_get_info(reader->zip_handle, &reader->file_info);

    return err;
}

int32_t vv_mz_zip_reader_goto_next_entry(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;

    if (vv_mz_zip_reader_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;

    if (vv_mz_zip_entry_is_open(reader->zip_handle) == VV_MZ_OK)
        vv_mz_zip_reader_entry_close(handle);

    if (reader->pattern == NULL)
        err = vv_mz_zip_goto_next_entry(reader->zip_handle);
    else
        err = vv_mz_zip_locate_next_entry(reader->zip_handle, reader, vv_mz_zip_reader_locate_entry_cb);

    reader->file_info = NULL;
    if (err == VV_MZ_OK)
        err = vv_mz_zip_entry_get_info(reader->zip_handle, &reader->file_info);

    return err;
}

int32_t vv_mz_zip_reader_locate_entry(void *handle, const char *filename, uint8_t ignore_case)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;

    if (vv_mz_zip_entry_is_open(reader->zip_handle) == VV_MZ_OK)
        vv_mz_zip_reader_entry_close(handle);

    err = vv_mz_zip_locate_entry(reader->zip_handle, filename, ignore_case);

    reader->file_info = NULL;
    if (err == VV_MZ_OK)
        err = vv_mz_zip_entry_get_info(reader->zip_handle, &reader->file_info);

    return err;
}

/***************************************************************************/

int32_t vv_mz_zip_reader_entry_open(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;
    const char *password = NULL;
    char password_buf[120];


    reader->entry_verified = 0;

    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info == NULL)
        return VV_MZ_PARAM_ERROR;

    /* If the entry isn't open for reading, open it */
    if (vv_mz_zip_entry_is_open(reader->zip_handle) == VV_MZ_OK)
        return VV_MZ_OK;

    password = reader->password;

    /* Check if we need a password and ask for it if we need to */
    if ((reader->file_info->flag & VV_MZ_ZIP_FLAG_ENCRYPTED) && (password == NULL) &&
        (reader->password_cb != NULL))
    {
        reader->password_cb(handle, reader->password_userdata, reader->file_info,
            password_buf, sizeof(password_buf));

        password = password_buf;
    }

    err = vv_mz_zip_entry_read_open(reader->zip_handle, reader->raw, password);
#ifndef VV_MZ_ZIP_NO_ENCRYPTION
    if (err != VV_MZ_OK)
        return err;

    if (vv_mz_zip_reader_entry_get_first_hash(handle, &reader->hash_algorithm, &reader->hash_digest_size) == VV_MZ_OK)
    {
        vv_mz_crypt_sha_create(&reader->hash);
        if (reader->hash_algorithm == VV_MZ_HASH_SHA1)
            vv_mz_crypt_sha_set_algorithm(reader->hash, VV_MZ_HASH_SHA1);
        else if (reader->hash_algorithm == VV_MZ_HASH_SHA256)
            vv_mz_crypt_sha_set_algorithm(reader->hash, VV_MZ_HASH_SHA256);
        else
            err = VV_MZ_SUPPORT_ERROR;

        if (err == VV_MZ_OK)
            vv_mz_crypt_sha_begin(reader->hash);
#ifdef VV_MZ_ZIP_SIGNING
        if (err == VV_MZ_OK)
        {
            if (vv_mz_zip_reader_entry_has_sign(handle) == VV_MZ_OK)
            {
                err = vv_mz_zip_reader_entry_sign_verify(handle);
                if (err == VV_MZ_OK)
                    reader->entry_verified = 1;
            }
            else if (reader->sign_required && !reader->cd_verified)
                err = VV_MZ_SIGN_ERROR;
        }
#endif
    }
    else if (reader->sign_required && !reader->cd_verified)
        err = VV_MZ_SIGN_ERROR;
#endif

    return err;
}

int32_t vv_mz_zip_reader_entry_close(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;
    int32_t err_close = VV_MZ_OK;
#ifndef VV_MZ_ZIP_NO_ENCRYPTION
    int32_t err_hash = VV_MZ_OK;
    uint8_t computed_hash[VV_MZ_HASH_MAX_SIZE];
    uint8_t expected_hash[VV_MZ_HASH_MAX_SIZE];

    if (reader->hash != NULL)
    {
        vv_mz_crypt_sha_end(reader->hash, computed_hash, sizeof(computed_hash));
        vv_mz_crypt_sha_delete(&reader->hash);

        err_hash = vv_mz_zip_reader_entry_get_hash(handle, reader->hash_algorithm, expected_hash,
            reader->hash_digest_size);

        if (err_hash == VV_MZ_OK)
        {
            /* Verify expected hash against computed hash */
            if (memcmp(computed_hash, expected_hash, reader->hash_digest_size) != 0)
                err = VV_MZ_CRC_ERROR;
        }
    }
#endif

    err_close = vv_mz_zip_entry_close(reader->zip_handle);
    if (err == VV_MZ_OK)
        err = err_close;
    return err;
}

int32_t vv_mz_zip_reader_entry_read(void *handle, void *buf, int32_t len)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t read = 0;
    read = vv_mz_zip_entry_read(reader->zip_handle, buf, len);
#ifndef VV_MZ_ZIP_NO_ENCRYPTION
    if ((read > 0) && (reader->hash != NULL))
        vv_mz_crypt_sha_update(reader->hash, buf, read);
#endif
    return read;
}

int32_t vv_mz_zip_reader_entry_has_sign(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;

    if (reader == NULL || vv_mz_zip_entry_is_open(reader->zip_handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;

    return vv_mz_zip_extrafield_contains(reader->file_info->extrafield,
        reader->file_info->extrafield_size, VV_MZ_ZIP_EXTENSION_SIGN, NULL);
}

#if !defined(VV_MZ_ZIP_NO_ENCRYPTION) && defined(VV_MZ_ZIP_SIGNING)
int32_t vv_mz_zip_reader_entry_sign_verify(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    void *file_extra_stream = NULL;
    int32_t err = VV_MZ_OK;
    uint8_t *signature = NULL;
    uint16_t signature_size = 0;
    uint8_t hash[VV_MZ_HASH_MAX_SIZE];

    if (reader == NULL || vv_mz_zip_entry_is_open(reader->zip_handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;

    vv_mz_stream_mem_create(&file_extra_stream);
    vv_mz_stream_mem_set_buffer(file_extra_stream, (void *)reader->file_info->extrafield,
        reader->file_info->extrafield_size);

    err = vv_mz_zip_extrafield_find(file_extra_stream, VV_MZ_ZIP_EXTENSION_SIGN, &signature_size);
    if ((err == VV_MZ_OK) && (signature_size > 0))
    {
        signature = (uint8_t *)VV_MZ_ALLOC(signature_size);
        if (vv_mz_stream_read(file_extra_stream, signature, signature_size) != signature_size)
            err = VV_MZ_READ_ERROR;
    }

    vv_mz_stream_mem_delete(&file_extra_stream);

    if (err == VV_MZ_OK)
    {
        /* Get most secure hash to verify signature against */
        err = vv_mz_zip_reader_entry_get_hash(handle, reader->hash_algorithm, hash, reader->hash_digest_size);
    }

    if (err == VV_MZ_OK)
    {
        /* Verify the pkcs signature */
        err = vv_mz_crypt_sign_verify(hash, reader->hash_digest_size, signature, signature_size);
    }

    if (signature != NULL)
        VV_MZ_FREE(signature);

    return err;
}
#endif

int32_t vv_mz_zip_reader_entry_get_hash(void *handle, uint16_t algorithm, uint8_t *digest, int32_t digest_size)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    void *file_extra_stream = NULL;
    int32_t err = VV_MZ_OK;
    int32_t return_err = VV_MZ_EXIST_ERROR;
    uint16_t cur_algorithm = 0;
    uint16_t cur_digest_size = 0;

    vv_mz_stream_mem_create(&file_extra_stream);
    vv_mz_stream_mem_set_buffer(file_extra_stream, (void *)reader->file_info->extrafield,
        reader->file_info->extrafield_size);

    do
    {
        err = vv_mz_zip_extrafield_find(file_extra_stream, VV_MZ_ZIP_EXTENSION_HASH, NULL);
        if (err != VV_MZ_OK)
            break;

        err = vv_mz_stream_read_uint16(file_extra_stream, &cur_algorithm);
        if (err == VV_MZ_OK)
            err = vv_mz_stream_read_uint16(file_extra_stream, &cur_digest_size);
        if ((err == VV_MZ_OK) && (cur_algorithm == algorithm) && (cur_digest_size <= digest_size) &&
            (cur_digest_size <= VV_MZ_HASH_MAX_SIZE))
        {
            /* Read hash digest */
            if (vv_mz_stream_read(file_extra_stream, digest, digest_size) == cur_digest_size)
                return_err = VV_MZ_OK;
            break;
        }
        else
        {
            err = vv_mz_stream_seek(file_extra_stream, cur_digest_size, VV_MZ_SEEK_CUR);
        }
    }
    while (err == VV_MZ_OK);

    vv_mz_stream_mem_delete(&file_extra_stream);

    return return_err;
}

int32_t vv_mz_zip_reader_entry_get_first_hash(void *handle, uint16_t *algorithm, uint16_t *digest_size)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    void *file_extra_stream = NULL;
    int32_t err = VV_MZ_OK;
    uint16_t cur_algorithm = 0;
    uint16_t cur_digest_size = 0;

    if (reader == NULL || algorithm == NULL)
        return VV_MZ_PARAM_ERROR;

    vv_mz_stream_mem_create(&file_extra_stream);
    vv_mz_stream_mem_set_buffer(file_extra_stream, (void *)reader->file_info->extrafield,
        reader->file_info->extrafield_size);

    err = vv_mz_zip_extrafield_find(file_extra_stream, VV_MZ_ZIP_EXTENSION_HASH, NULL);
    if (err == VV_MZ_OK)
        err = vv_mz_stream_read_uint16(file_extra_stream, &cur_algorithm);
    if (err == VV_MZ_OK)
        err = vv_mz_stream_read_uint16(file_extra_stream, &cur_digest_size);

    if (algorithm != NULL)
        *algorithm = cur_algorithm;
    if (digest_size != NULL)
        *digest_size = cur_digest_size;

    vv_mz_stream_mem_delete(&file_extra_stream);

    return err;
}

int32_t vv_mz_zip_reader_entry_get_info(void *handle, vv_mz_zip_file **file_info)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;
    if (file_info == NULL || vv_mz_zip_reader_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    *file_info = reader->file_info;
    if (*file_info == NULL)
        return VV_MZ_EXIST_ERROR;
    return err;
}

int32_t vv_mz_zip_reader_entry_is_dir(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    if (vv_mz_zip_reader_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    return vv_mz_zip_entry_is_dir(reader->zip_handle);
}

int32_t vv_mz_zip_reader_entry_save_process(void *handle, void *stream, vv_mz_stream_write_cb write_cb)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;
    int32_t read = 0;
    int32_t written = 0;


    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info == NULL)
        return VV_MZ_PARAM_ERROR;
    if (write_cb == NULL)
        return VV_MZ_PARAM_ERROR;

    /* If the entry isn't open for reading, open it */
    if (vv_mz_zip_entry_is_open(reader->zip_handle) != VV_MZ_OK)
        err = vv_mz_zip_reader_entry_open(handle);

    if (err != VV_MZ_OK)
        return err;

    /* Unzip entry in zip file */
    read = vv_mz_zip_reader_entry_read(handle, reader->buffer, sizeof(reader->buffer));

    if (read == 0)
    {
        /* If we are done close the entry */
        err = vv_mz_zip_reader_entry_close(handle);
        if (err != VV_MZ_OK)
            return err;

        return VV_MZ_END_OF_STREAM;
    }

    if (read > 0)
    {
        /* Write the data to the specified stream */
        written = write_cb(stream, reader->buffer, read);
        if (written != read)
            return VV_MZ_WRITE_ERROR;
    }

    return read;
}

int32_t vv_mz_zip_reader_entry_save(void *handle, void *stream, vv_mz_stream_write_cb write_cb)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    uint64_t current_time = 0;
    uint64_t update_time = 0;
    int64_t current_pos = 0;
    int64_t update_pos = 0;
    int32_t err = VV_MZ_OK;
    int32_t written = 0;

    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info == NULL)
        return VV_MZ_PARAM_ERROR;

    /* Update the progress at the beginning */
    if (reader->progress_cb != NULL)
        reader->progress_cb(handle, reader->progress_userdata, reader->file_info, current_pos);

    /* Write data to stream until done */
    while (err == VV_MZ_OK)
    {
        written = vv_mz_zip_reader_entry_save_process(handle, stream, write_cb);
        if (written == VV_MZ_END_OF_STREAM)
            break;
        if (written > 0)
            current_pos += written;
        if (written < 0)
            err = written;

        /* Update progress if enough time have passed */
        current_time = vv_mz_os_ms_time();
        if ((current_time - update_time) > reader->progress_cb_interval_ms)
        {
            if (reader->progress_cb != NULL)
                reader->progress_cb(handle, reader->progress_userdata, reader->file_info, current_pos);

            update_pos = current_pos;
            update_time = current_time;
        }
    }

    /* Update the progress at the end */
    if (reader->progress_cb != NULL && update_pos != current_pos)
        reader->progress_cb(handle, reader->progress_userdata, reader->file_info, current_pos);

    return err;
}

int32_t vv_mz_zip_reader_entry_save_file(void *handle, const char *path)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    void *stream = NULL;
    uint32_t target_attrib = 0;
    int32_t err_attrib = 0;
    int32_t err = VV_MZ_OK;
    int32_t err_cb = VV_MZ_OK;
    char pathwfs[512];
    char directory[512];

    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info == NULL || path == NULL)
        return VV_MZ_PARAM_ERROR;

    /* Convert to forward slashes for unix which doesn't like backslashes */
    strncpy(pathwfs, path, sizeof(pathwfs) - 1);
    pathwfs[sizeof(pathwfs) - 1] = 0;
    vv_mz_path_convert_slashes(pathwfs, VV_MZ_PATH_SLASH_UNIX);

    if (reader->entry_cb != NULL)
        reader->entry_cb(handle, reader->entry_userdata, reader->file_info, pathwfs);

    strncpy(directory, pathwfs, sizeof(directory) - 1);
    directory[sizeof(directory) - 1] = 0;
    vv_mz_path_remove_filename(directory);

    /* If it is a directory entry then create a directory instead of writing file */
    if ((vv_mz_zip_entry_is_dir(reader->zip_handle) == VV_MZ_OK) &&
        (vv_mz_zip_entry_is_symlink(reader->zip_handle) != VV_MZ_OK))
    {
        err = vv_mz_dir_make(directory);
        return err;
    }

    /* Check if file exists and ask if we want to overwrite */
    if ((vv_mz_os_file_exists(pathwfs) == VV_MZ_OK) && (reader->overwrite_cb != NULL))
    {
        err_cb = reader->overwrite_cb(handle, reader->overwrite_userdata, reader->file_info, pathwfs);
        if (err_cb != VV_MZ_OK)
            return err;
        /* We want to overwrite the file so we delete the existing one */
        vv_mz_os_unlink(pathwfs);
    }

    /* If symbolic link then properly construct destination path and link path */
    if (vv_mz_zip_entry_is_symlink(reader->zip_handle) == VV_MZ_OK)
    {
        vv_mz_path_remove_slash(pathwfs);
        vv_mz_path_remove_filename(directory);
    }

    /* Create the output directory if it doesn't already exist */
    if (vv_mz_os_is_dir(directory) != VV_MZ_OK)
    {
        err = vv_mz_dir_make(directory);
        if (err != VV_MZ_OK)
            return err;
    }

    /* If it is a symbolic link then create symbolic link instead of writing file */
    if (vv_mz_zip_entry_is_symlink(reader->zip_handle) == VV_MZ_OK)
    {
        vv_mz_os_make_symlink(pathwfs, reader->file_info->linkname);
        /* Don't check return value because we aren't validating symbolic link target */
        return err;
    }

    /* Create the file on disk so we can save to it */
    vv_mz_stream_os_create(&stream);
    err = vv_mz_stream_os_open(stream, pathwfs, VV_MZ_OPEN_MODE_CREATE);

    if (err == VV_MZ_OK)
        err = vv_mz_zip_reader_entry_save(handle, stream, vv_mz_stream_write);

    vv_mz_stream_close(stream);
    vv_mz_stream_delete(&stream);

    if (err == VV_MZ_OK)
    {
        /* Set the time of the file that has been created */
        vv_mz_os_set_file_date(pathwfs, reader->file_info->modified_date,
            reader->file_info->accessed_date, reader->file_info->creation_date);
    }

    if (err == VV_MZ_OK)
    {
        /* Set file attributes for the correct system */
        err_attrib = vv_mz_zip_attrib_convert(VV_MZ_HOST_SYSTEM(reader->file_info->version_madeby),
            reader->file_info->external_fa, VV_MZ_VERSION_MADEBY_HOST_SYSTEM, &target_attrib);

        if (err_attrib == VV_MZ_OK)
            vv_mz_os_set_file_attribs(pathwfs, target_attrib);
    }

    return err;
}

int32_t vv_mz_zip_reader_entry_save_buffer(void *handle, void *buf, int32_t len)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    void *mem_stream = NULL;
    int32_t err = VV_MZ_OK;

    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info == NULL)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info->uncompressed_size > INT32_MAX)
        return VV_MZ_PARAM_ERROR;
    if (len != (int32_t)reader->file_info->uncompressed_size)
        return VV_MZ_BUF_ERROR;

    /* Create a memory stream backed by our buffer and save to it */
    vv_mz_stream_mem_create(&mem_stream);
    vv_mz_stream_mem_set_buffer(mem_stream, buf, len);

    err = vv_mz_stream_mem_open(mem_stream, NULL, VV_MZ_OPEN_MODE_READ);
    if (err == VV_MZ_OK)
        err = vv_mz_zip_reader_entry_save(handle, mem_stream, vv_mz_stream_mem_write);

    vv_mz_stream_mem_delete(&mem_stream);
    return err;
}

int32_t vv_mz_zip_reader_entry_save_buffer_length(void *handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;

    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info == NULL)
        return VV_MZ_PARAM_ERROR;
    if (reader->file_info->uncompressed_size > INT32_MAX)
        return VV_MZ_PARAM_ERROR;

    /* Get the maximum size required for the save buffer */
    return (int32_t)reader->file_info->uncompressed_size;
}

/***************************************************************************/

int32_t vv_mz_zip_reader_save_all(void *handle, const char *destination_dir)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    int32_t err = VV_MZ_OK;
    uint8_t *utf8_string = NULL;
    char path[512];
    char utf8_name[256];
    char resolved_name[256];

    err = vv_mz_zip_reader_goto_first_entry(handle);

    if (err == VV_MZ_END_OF_LIST)
        return err;

    while (err == VV_MZ_OK)
    {
        /* Construct output path */
        path[0] = 0;

        strncpy(utf8_name, reader->file_info->filename, sizeof(utf8_name) - 1);
        utf8_name[sizeof(utf8_name) - 1] = 0;

        if ((reader->encoding > 0) && (reader->file_info->flag & VV_MZ_ZIP_FLAG_UTF8) == 0)
        {
            utf8_string = vv_mz_os_utf8_string_create(reader->file_info->filename, reader->encoding);
            if (utf8_string)
            {
                strncpy(utf8_name, (char *)utf8_string, sizeof(utf8_name) - 1);
                utf8_name[sizeof(utf8_name) - 1] = 0;
                vv_mz_os_utf8_string_delete(&utf8_string);
            }
        }

        err = vv_mz_path_resolve(utf8_name, resolved_name, sizeof(resolved_name));
        if (err != VV_MZ_OK)
            break;

        if (destination_dir != NULL)
            vv_mz_path_combine(path, destination_dir, sizeof(path));

        vv_mz_path_combine(path, resolved_name, sizeof(path));

        /* Save file to disk */
        err = vv_mz_zip_reader_entry_save_file(handle, path);

        if (err == VV_MZ_OK)
            err = vv_mz_zip_reader_goto_next_entry(handle);
    }

    if (err == VV_MZ_END_OF_LIST)
        return VV_MZ_OK;

    return err;
}

/***************************************************************************/

void vv_mz_zip_reader_set_pattern(void *handle, const char *pattern, uint8_t ignore_case)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->pattern = pattern;
    reader->pattern_ignore_case = ignore_case;
}

void vv_mz_zip_reader_set_password(void *handle, const char *password)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->password = password;
}

void vv_mz_zip_reader_set_raw(void *handle, uint8_t raw)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->raw = raw;
}

int32_t vv_mz_zip_reader_get_raw(void *handle, uint8_t *raw)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    if (raw == NULL)
        return VV_MZ_PARAM_ERROR;
    *raw = reader->raw;
    return VV_MZ_OK;
}

int32_t vv_mz_zip_reader_get_zip_cd(void *handle, uint8_t *zip_cd)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    if (zip_cd == NULL)
        return VV_MZ_PARAM_ERROR;
    *zip_cd = reader->cd_zipped;
    return VV_MZ_OK;
}

int32_t vv_mz_zip_reader_get_comment(void *handle, const char **comment)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (comment == NULL)
        return VV_MZ_PARAM_ERROR;
    return vv_mz_zip_get_comment(reader->zip_handle, comment);
}

void vv_mz_zip_reader_set_encoding(void *handle, int32_t encoding)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->encoding = encoding;
}

void vv_mz_zip_reader_set_sign_required(void *handle, uint8_t sign_required)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->sign_required = sign_required;
}

void vv_mz_zip_reader_set_overwrite_cb(void *handle, void *userdata, vv_mz_zip_reader_overwrite_cb cb)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->overwrite_cb = cb;
    reader->overwrite_userdata = userdata;
}

void vv_mz_zip_reader_set_password_cb(void *handle, void *userdata, vv_mz_zip_reader_password_cb cb)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->password_cb = cb;
    reader->password_userdata = userdata;
}

void vv_mz_zip_reader_set_progress_cb(void *handle, void *userdata, vv_mz_zip_reader_progress_cb cb)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->progress_cb = cb;
    reader->progress_userdata = userdata;
}

void vv_mz_zip_reader_set_progress_interval(void *handle, uint32_t milliseconds)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->progress_cb_interval_ms = milliseconds;
}

void vv_mz_zip_reader_set_entry_cb(void *handle, void *userdata, vv_mz_zip_reader_entry_cb cb)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    reader->entry_cb = cb;
    reader->entry_userdata = userdata;
}

int32_t vv_mz_zip_reader_get_zip_handle(void *handle, void **zip_handle)
{
    vv_mz_zip_reader *reader = (vv_mz_zip_reader *)handle;
    if (zip_handle == NULL)
        return VV_MZ_PARAM_ERROR;
    *zip_handle = reader->zip_handle;
    if (*zip_handle == NULL)
        return VV_MZ_EXIST_ERROR;
    return VV_MZ_OK;
}

/***************************************************************************/

void *vv_mz_zip_reader_create(void **handle)
{
    vv_mz_zip_reader *reader = NULL;

    reader = (vv_mz_zip_reader *)VV_MZ_ALLOC(sizeof(vv_mz_zip_reader));
    if (reader != NULL)
    {
        memset(reader, 0, sizeof(vv_mz_zip_reader));
        reader->progress_cb_interval_ms = VV_MZ_DEFAULT_PROGRESS_INTERVAL;
        *handle = reader;
    }

    return reader;
}

void vv_mz_zip_reader_delete(void **handle)
{
    vv_mz_zip_reader *reader = NULL;
    if (handle == NULL)
        return;
    reader = (vv_mz_zip_reader *)*handle;
    if (reader != NULL)
    {
        vv_mz_zip_reader_close(reader);
        VV_MZ_FREE(reader);
    }
    *handle = NULL;
}

/***************************************************************************/

typedef struct vv_mz_zip_writer_s {
    void        *zip_handle;
    void        *file_stream;
    void        *buffered_stream;
    void        *split_stream;
    void        *sha256;
    void        *mem_stream;
    void        *file_extra_stream;
    vv_mz_zip_file file_info;
    void        *overwrite_userdata;
    vv_mz_zip_writer_overwrite_cb
                overwrite_cb;
    void        *password_userdata;
    vv_mz_zip_writer_password_cb
                password_cb;
    void        *progress_userdata;
    vv_mz_zip_writer_progress_cb
                progress_cb;
    uint32_t    progress_cb_interval_ms;
    void        *entry_userdata;
    vv_mz_zip_writer_entry_cb
                entry_cb;
    const char  *password;
    const char  *comment;
    uint8_t     *cert_data;
    int32_t     cert_data_size;
    const char  *cert_pwd;
    uint16_t    compress_method;
    int16_t     compress_level;
    uint8_t     follow_links;
    uint8_t     store_links;
    uint8_t     zip_cd;
    uint8_t     aes;
    uint8_t     raw;
    uint8_t     buffer[UINT16_MAX];
} vv_mz_zip_writer;

/***************************************************************************/

int32_t vv_mz_zip_writer_zip_cd(void *handle)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    vv_mz_zip_file cd_file;
    uint64_t number_entry = 0;
    int64_t cd_mem_length = 0;
    int32_t err = VV_MZ_OK;
    int32_t extrafield_size = 0;
    void *file_extra_stream = NULL;
    void *cd_mem_stream = NULL;


    memset(&cd_file, 0, sizeof(cd_file));

    vv_mz_zip_get_number_entry(writer->zip_handle, &number_entry);
    vv_mz_zip_get_cd_mem_stream(writer->zip_handle, &cd_mem_stream);
    vv_mz_stream_seek(cd_mem_stream, 0, VV_MZ_SEEK_END);
    cd_mem_length = (uint32_t)vv_mz_stream_tell(cd_mem_stream);
    vv_mz_stream_seek(cd_mem_stream, 0, VV_MZ_SEEK_SET);

    cd_file.filename = VV_MZ_ZIP_CD_FILENAME;
    cd_file.modified_date = time(NULL);
    cd_file.version_madeby = VV_MZ_VERSION_MADEBY;
    cd_file.compression_method = writer->compress_method;
    cd_file.uncompressed_size = (int32_t)cd_mem_length;
    cd_file.flag = VV_MZ_ZIP_FLAG_UTF8;

    if (writer->password != NULL)
        cd_file.flag |= VV_MZ_ZIP_FLAG_ENCRYPTED;

    vv_mz_stream_mem_create(&file_extra_stream);
    vv_mz_stream_mem_open(file_extra_stream, NULL, VV_MZ_OPEN_MODE_CREATE);

    vv_mz_zip_extrafield_write(file_extra_stream, VV_MZ_ZIP_EXTENSION_CDCD, 8);

    vv_mz_stream_write_uint64(file_extra_stream, number_entry);

    vv_mz_stream_mem_get_buffer(file_extra_stream, (const void **)&cd_file.extrafield);
    vv_mz_stream_mem_get_buffer_length(file_extra_stream, &extrafield_size);
    cd_file.extrafield_size = (uint16_t)extrafield_size;

    err = vv_mz_zip_writer_entry_open(handle, &cd_file);
    if (err == VV_MZ_OK)
    {
        vv_mz_stream_copy_stream(handle, vv_mz_zip_writer_entry_write, cd_mem_stream,
            NULL, (int32_t)cd_mem_length);

        vv_mz_stream_seek(cd_mem_stream, 0, VV_MZ_SEEK_SET);
        vv_mz_stream_mem_set_buffer_limit(cd_mem_stream, 0);

        err = vv_mz_zip_writer_entry_close(writer);
    }

    vv_mz_stream_mem_delete(&file_extra_stream);

    return err;
}

/***************************************************************************/

int32_t vv_mz_zip_writer_is_open(void *handle)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    if (writer == NULL)
        return VV_MZ_PARAM_ERROR;
    if (writer->zip_handle == NULL)
        return VV_MZ_PARAM_ERROR;
    return VV_MZ_OK;
}

static int32_t vv_mz_zip_writer_open_int(void *handle, void *stream, int32_t mode)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t err = VV_MZ_OK;

    vv_mz_zip_create(&writer->zip_handle);
    err = vv_mz_zip_open(writer->zip_handle, stream, mode);

    if (err != VV_MZ_OK)
    {
        vv_mz_zip_writer_close(handle);
        return err;
    }

    return VV_MZ_OK;
}

int32_t vv_mz_zip_writer_open(void *handle, void *stream)
{
    return vv_mz_zip_writer_open_int(handle, stream, VV_MZ_OPEN_MODE_WRITE);
}

int32_t vv_mz_zip_writer_open_file(void *handle, const char *path, int64_t disk_size, uint8_t append)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t mode = VV_MZ_OPEN_MODE_READWRITE;
    int32_t err = VV_MZ_OK;
    int32_t err_cb = 0;
    char directory[320];

    vv_mz_zip_writer_close(handle);

    if (vv_mz_os_file_exists(path) != VV_MZ_OK)
    {
        /* If the file doesn't exist, we don't append file */
        mode |= VV_MZ_OPEN_MODE_CREATE;

        /* Create destination directory if it doesn't already exist */
        if (strchr(path, '/') != NULL || strrchr(path, '\\') != NULL)
        {
            strncpy(directory, path, sizeof(directory));
            vv_mz_path_remove_filename(directory);
            if (vv_mz_os_file_exists(directory) != VV_MZ_OK)
                vv_mz_dir_make(directory);
        }
    }
    else if (append)
    {
        mode |= VV_MZ_OPEN_MODE_APPEND;
    }
    else
    {
        if (writer->overwrite_cb != NULL)
            err_cb = writer->overwrite_cb(handle, writer->overwrite_userdata, path);

        if (err_cb == VV_MZ_INTERNAL_ERROR)
            return err;

        if (err_cb == VV_MZ_OK)
            mode |= VV_MZ_OPEN_MODE_CREATE;
        else
            mode |= VV_MZ_OPEN_MODE_APPEND;
    }

    vv_mz_stream_os_create(&writer->file_stream);
    vv_mz_stream_buffered_create(&writer->buffered_stream);
    vv_mz_stream_split_create(&writer->split_stream);

    vv_mz_stream_set_base(writer->buffered_stream, writer->file_stream);
    vv_mz_stream_set_base(writer->split_stream, writer->buffered_stream);

    vv_mz_stream_split_set_prop_int64(writer->split_stream, VV_MZ_STREAM_PROP_DISK_SIZE, disk_size);

    err = vv_mz_stream_open(writer->split_stream, path, mode);
    if (err == VV_MZ_OK)
        err = vv_mz_zip_writer_open_int(handle, writer->split_stream, mode);

    return err;
}

int32_t vv_mz_zip_writer_open_file_in_memory(void *handle, const char *path)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    void *file_stream = NULL;
    int64_t file_size = 0;
    int32_t err = 0;


    vv_mz_zip_writer_close(handle);

    vv_mz_stream_os_create(&file_stream);

    err = vv_mz_stream_os_open(file_stream, path, VV_MZ_OPEN_MODE_READ);

    if (err != VV_MZ_OK)
    {
        vv_mz_stream_os_delete(&file_stream);
        vv_mz_zip_writer_close(handle);
        return err;
    }

    vv_mz_stream_os_seek(file_stream, 0, VV_MZ_SEEK_END);
    file_size = vv_mz_stream_os_tell(file_stream);
    vv_mz_stream_os_seek(file_stream, 0, VV_MZ_SEEK_SET);

    if ((file_size <= 0) || (file_size > UINT32_MAX))
    {
        /* Memory size is too large or too small */

        vv_mz_stream_os_close(file_stream);
        vv_mz_stream_os_delete(&file_stream);
        vv_mz_zip_writer_close(handle);
        return VV_MZ_MEM_ERROR;
    }

    vv_mz_stream_mem_create(&writer->mem_stream);
    vv_mz_stream_mem_set_grow_size(writer->mem_stream, (int32_t)file_size);
    vv_mz_stream_mem_open(writer->mem_stream, NULL, VV_MZ_OPEN_MODE_CREATE);

    err = vv_mz_stream_copy(writer->mem_stream, file_stream, (int32_t)file_size);

    vv_mz_stream_os_close(file_stream);
    vv_mz_stream_os_delete(&file_stream);

    if (err == VV_MZ_OK)
        err = vv_mz_zip_writer_open(handle, writer->mem_stream);
    if (err != VV_MZ_OK)
        vv_mz_zip_writer_close(handle);

    return err;
}

int32_t vv_mz_zip_writer_close(void *handle)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t err = VV_MZ_OK;


    if (writer->zip_handle != NULL)
    {
        vv_mz_zip_set_version_madeby(writer->zip_handle, VV_MZ_VERSION_MADEBY);
        if (writer->comment)
            vv_mz_zip_set_comment(writer->zip_handle, writer->comment);
        if (writer->zip_cd)
            vv_mz_zip_writer_zip_cd(writer);

        err = vv_mz_zip_close(writer->zip_handle);
        vv_mz_zip_delete(&writer->zip_handle);
    }

    if (writer->split_stream != NULL)
    {
        vv_mz_stream_split_close(writer->split_stream);
        vv_mz_stream_split_delete(&writer->split_stream);
    }

    if (writer->buffered_stream != NULL)
        vv_mz_stream_buffered_delete(&writer->buffered_stream);

    if (writer->file_stream != NULL)
        vv_mz_stream_os_delete(&writer->file_stream);

    if (writer->mem_stream != NULL)
    {
        vv_mz_stream_mem_close(writer->mem_stream);
        vv_mz_stream_mem_delete(&writer->mem_stream);
    }

    return err;
}

/***************************************************************************/

int32_t vv_mz_zip_writer_entry_open(void *handle, vv_mz_zip_file *file_info)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t err = VV_MZ_OK;
    const char *password = NULL;
    char password_buf[120];

    /* Copy file info to access data upon close */
    memcpy(&writer->file_info, file_info, sizeof(vv_mz_zip_file));

    if (writer->entry_cb != NULL)
        writer->entry_cb(handle, writer->entry_userdata, &writer->file_info);

    password = writer->password;

    /* Check if we need a password and ask for it if we need to */
    if ((writer->file_info.flag & VV_MZ_ZIP_FLAG_ENCRYPTED) && (password == NULL) &&
        (writer->password_cb != NULL))
    {
        writer->password_cb(handle, writer->password_userdata, &writer->file_info,
            password_buf, sizeof(password_buf));
        password = password_buf;
    }

#ifndef VV_MZ_ZIP_NO_ENCRYPTION
    if (vv_mz_zip_attrib_is_dir(writer->file_info.external_fa, writer->file_info.version_madeby) != VV_MZ_OK)
    {
        /* Start calculating sha256 */
        vv_mz_crypt_sha_create(&writer->sha256);
        vv_mz_crypt_sha_set_algorithm(writer->sha256, VV_MZ_HASH_SHA256);
        vv_mz_crypt_sha_begin(writer->sha256);
    }
#endif

    /* Open entry in zip */
    err = vv_mz_zip_entry_write_open(writer->zip_handle, &writer->file_info, writer->compress_level,
        writer->raw, password);

    return err;
}


#if !defined(VV_MZ_ZIP_NO_ENCRYPTION) && defined(VV_MZ_ZIP_SIGNING)
int32_t vv_mz_zip_writer_entry_sign(void *handle, uint8_t *message, int32_t message_size,
    uint8_t *cert_data, int32_t cert_data_size, const char *cert_pwd)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t err = VV_MZ_OK;
    int32_t signature_size = 0;
    uint8_t *signature = NULL;


    if (writer == NULL || cert_data == NULL || cert_data_size <= 0)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_zip_entry_is_open(writer->zip_handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;

    /* Sign message with certificate */
    err = vv_mz_crypt_sign(message, message_size, cert_data, cert_data_size, cert_pwd,
        &signature, &signature_size);

    if ((err == VV_MZ_OK) && (signature != NULL))
    {
        /* Write signature zip extra field */
        err = vv_mz_zip_extrafield_write(writer->file_extra_stream, VV_MZ_ZIP_EXTENSION_SIGN,
            (uint16_t)signature_size);

        if (err == VV_MZ_OK)
        {
            if (vv_mz_stream_write(writer->file_extra_stream, signature, signature_size) != signature_size)
                err = VV_MZ_WRITE_ERROR;
        }

        VV_MZ_FREE(signature);
    }

    return err;
}
#endif

int32_t vv_mz_zip_writer_entry_close(void *handle)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t err = VV_MZ_OK;
#ifndef VV_MZ_ZIP_NO_ENCRYPTION
    const uint8_t *extrafield = NULL;
    int32_t extrafield_size = 0;
    int16_t field_length_hash = 0;
    uint8_t sha256[VV_MZ_HASH_SHA256_SIZE];


    if (writer->sha256 != NULL)
    {
        vv_mz_crypt_sha_end(writer->sha256, sha256, sizeof(sha256));
        vv_mz_crypt_sha_delete(&writer->sha256);

        /* Copy extrafield so we can append our own fields before close */
        vv_mz_stream_mem_create(&writer->file_extra_stream);
        vv_mz_stream_mem_open(writer->file_extra_stream, NULL, VV_MZ_OPEN_MODE_CREATE);

        /* Write sha256 hash to extrafield */
        field_length_hash = 4 + VV_MZ_HASH_SHA256_SIZE;
        err = vv_mz_zip_extrafield_write(writer->file_extra_stream, VV_MZ_ZIP_EXTENSION_HASH, field_length_hash);
        if (err == VV_MZ_OK)
            err = vv_mz_stream_write_uint16(writer->file_extra_stream, VV_MZ_HASH_SHA256);
        if (err == VV_MZ_OK)
            err = vv_mz_stream_write_uint16(writer->file_extra_stream, VV_MZ_HASH_SHA256_SIZE);
        if (err == VV_MZ_OK)
        {
            if (vv_mz_stream_write(writer->file_extra_stream, sha256, sizeof(sha256)) != VV_MZ_HASH_SHA256_SIZE)
                err = VV_MZ_WRITE_ERROR;
        }

#ifdef VV_MZ_ZIP_SIGNING
        if ((err == VV_MZ_OK) && (writer->cert_data != NULL) && (writer->cert_data_size > 0))
        {
            /* Sign entry if not zipping cd or if it is cd being zipped */
            if (!writer->zip_cd || strcmp(writer->file_info.filename, VV_MZ_ZIP_CD_FILENAME) == 0)
            {
                err = vv_mz_zip_writer_entry_sign(handle, sha256, sizeof(sha256),
                    writer->cert_data, writer->cert_data_size, writer->cert_pwd);
            }
        }
#endif

        if ((writer->file_info.extrafield != NULL) && (writer->file_info.extrafield_size > 0))
            vv_mz_stream_mem_write(writer->file_extra_stream, writer->file_info.extrafield,
                writer->file_info.extrafield_size);

        /* Update extra field for central directory after adding extra fields */
        vv_mz_stream_mem_get_buffer(writer->file_extra_stream, (const void **)&extrafield);
        vv_mz_stream_mem_get_buffer_length(writer->file_extra_stream, &extrafield_size);

        vv_mz_zip_entry_set_extrafield(writer->zip_handle, extrafield, (uint16_t)extrafield_size);
    }
#endif

    if (err == VV_MZ_OK)
    {
        if (writer->raw)
            err = vv_mz_zip_entry_close_raw(writer->zip_handle, writer->file_info.uncompressed_size,
                writer->file_info.crc);
        else
            err = vv_mz_zip_entry_close(writer->zip_handle);
    }

    if (writer->file_extra_stream != NULL)
        vv_mz_stream_mem_delete(&writer->file_extra_stream);

    return err;
}

int32_t vv_mz_zip_writer_entry_write(void *handle, const void *buf, int32_t len)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t written = 0;
    written = vv_mz_zip_entry_write(writer->zip_handle, buf, len);
#ifndef VV_MZ_ZIP_NO_ENCRYPTION
    if ((written > 0) && (writer->sha256 != NULL))
        vv_mz_crypt_sha_update(writer->sha256, buf, written);
#endif
    return written;
}
/***************************************************************************/

int32_t vv_mz_zip_writer_add_process(void *handle, void *stream, vv_mz_stream_read_cb read_cb)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t read = 0;
    int32_t written = 0;
    int32_t err = VV_MZ_OK;

    if (vv_mz_zip_writer_is_open(writer) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    /* If the entry isn't open for writing, open it */
    if (vv_mz_zip_entry_is_open(writer->zip_handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (read_cb == NULL)
        return VV_MZ_PARAM_ERROR;

    read = read_cb(stream, writer->buffer, sizeof(writer->buffer));
    if (read == 0)
        return VV_MZ_END_OF_STREAM;
    if (read < 0)
    {
        err = read;
        return err;
    }

    written = vv_mz_zip_writer_entry_write(handle, writer->buffer, read);
    if (written != read)
        return VV_MZ_WRITE_ERROR;

    return written;
}

int32_t vv_mz_zip_writer_add(void *handle, void *stream, vv_mz_stream_read_cb read_cb)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    uint64_t current_time = 0;
    uint64_t update_time = 0;
    int64_t current_pos = 0;
    int64_t update_pos = 0;
    int32_t err = VV_MZ_OK;
    int32_t written = 0;

    /* Update the progress at the beginning */
    if (writer->progress_cb != NULL)
        writer->progress_cb(handle, writer->progress_userdata, &writer->file_info, current_pos);

    /* Write data to stream until done */
    while (err == VV_MZ_OK)
    {
        written = vv_mz_zip_writer_add_process(handle, stream, read_cb);
        if (written == VV_MZ_END_OF_STREAM)
            break;
        if (written > 0)
            current_pos += written;
        if (written < 0)
            err = written;

        /* Update progress if enough time have passed */
        current_time = vv_mz_os_ms_time();
        if ((current_time - update_time) > writer->progress_cb_interval_ms)
        {
            if (writer->progress_cb != NULL)
                writer->progress_cb(handle, writer->progress_userdata, &writer->file_info, current_pos);

            update_pos = current_pos;
            update_time = current_time;
        }
    }

    /* Update the progress at the end */
    if (writer->progress_cb != NULL && update_pos != current_pos)
        writer->progress_cb(handle, writer->progress_userdata, &writer->file_info, current_pos);

    return err;
}

int32_t vv_mz_zip_writer_add_info(void *handle, void *stream, vv_mz_stream_read_cb read_cb, vv_mz_zip_file *file_info)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    int32_t err = VV_MZ_OK;


    if (vv_mz_zip_writer_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (file_info == NULL)
        return VV_MZ_PARAM_ERROR;

    /* Add to zip */
    err = vv_mz_zip_writer_entry_open(handle, file_info);
    if (err != VV_MZ_OK)
        return err;

    if (stream != NULL)
    {
        if (vv_mz_zip_attrib_is_dir(writer->file_info.external_fa, writer->file_info.version_madeby) != VV_MZ_OK)
        {
            err = vv_mz_zip_writer_add(handle, stream, read_cb);
            if (err != VV_MZ_OK)
                return err;
        }
    }

    err = vv_mz_zip_writer_entry_close(handle);

    return err;
}

int32_t vv_mz_zip_writer_add_buffer(void *handle, void *buf, int32_t len, vv_mz_zip_file *file_info)
{
    void *mem_stream = NULL;
    int32_t err = VV_MZ_OK;

    if (vv_mz_zip_writer_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (buf == NULL)
        return VV_MZ_PARAM_ERROR;

    /* Create a memory stream backed by our buffer and add from it */
    vv_mz_stream_mem_create(&mem_stream);
    vv_mz_stream_mem_set_buffer(mem_stream, buf, len);

    err = vv_mz_stream_mem_open(mem_stream, NULL, VV_MZ_OPEN_MODE_READ);
    if (err == VV_MZ_OK)
        err = vv_mz_zip_writer_add_info(handle, mem_stream, vv_mz_stream_mem_read, file_info);

    vv_mz_stream_mem_delete(&mem_stream);
    return err;
}

int32_t vv_mz_zip_writer_add_file(void *handle, const char *path, const char *filename_in_zip)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    vv_mz_zip_file file_info;
    uint32_t target_attrib = 0;
    uint32_t src_attrib = 0;
    int32_t err = VV_MZ_OK;
    uint8_t src_sys = 0;
    void *stream = NULL;
    char link_path[1024];
    const char *filename = filename_in_zip;


    if (vv_mz_zip_writer_is_open(handle) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (path == NULL)
        return VV_MZ_PARAM_ERROR;

    if (filename == NULL)
    {
        err = vv_mz_path_get_filename(path, &filename);
        if (err != VV_MZ_OK)
            return err;
    }

    memset(&file_info, 0, sizeof(file_info));

    /* The path name saved, should not include a leading slash. */
    /* If it did, windows/xp and dynazip couldn't read the zip file. */

    while (filename[0] == '\\' || filename[0] == '/')
        filename += 1;

    /* Get information about the file on disk so we can store it in zip */

    file_info.version_madeby = VV_MZ_VERSION_MADEBY;
    file_info.compression_method = writer->compress_method;
    file_info.filename = filename;
    file_info.uncompressed_size = vv_mz_os_get_file_size(path);
    file_info.flag = VV_MZ_ZIP_FLAG_UTF8;

    if (writer->zip_cd)
        file_info.flag |= VV_MZ_ZIP_FLAG_MASK_LOCAL_INFO;
    if (writer->aes)
        file_info.aes_version = VV_MZ_AES_VERSION;

    vv_mz_os_get_file_date(path, &file_info.modified_date, &file_info.accessed_date,
        &file_info.creation_date);
    vv_mz_os_get_file_attribs(path, &src_attrib);

    src_sys = VV_MZ_HOST_SYSTEM(file_info.version_madeby);

    if ((src_sys != VV_MZ_HOST_SYSTEM_MSDOS) && (src_sys != VV_MZ_HOST_SYSTEM_WINDOWS_NTFS))
    {
        /* High bytes are OS specific attributes, low byte is always DOS attributes */
        if (vv_mz_zip_attrib_convert(src_sys, src_attrib, VV_MZ_HOST_SYSTEM_MSDOS, &target_attrib) == VV_MZ_OK)
            file_info.external_fa = target_attrib;
        file_info.external_fa |= (src_attrib << 16);
    }
    else
    {
        file_info.external_fa = src_attrib;
    }

    if (writer->store_links && vv_mz_os_is_symlink(path) == VV_MZ_OK)
    {
        err = vv_mz_os_read_symlink(path, link_path, sizeof(link_path));
        if (err == VV_MZ_OK)
            file_info.linkname = link_path;
    }

    if (vv_mz_os_is_dir(path) != VV_MZ_OK)
    {
        vv_mz_stream_os_create(&stream);
        err = vv_mz_stream_os_open(stream, path, VV_MZ_OPEN_MODE_READ);
    }

    if (err == VV_MZ_OK)
        err = vv_mz_zip_writer_add_info(handle, stream, vv_mz_stream_read, &file_info);

    if (stream != NULL)
    {
        vv_mz_stream_close(stream);
        vv_mz_stream_delete(&stream);
    }

    return err;
}

int32_t vv_mz_zip_writer_add_path(void *handle, const char *path, const char *root_path,
    uint8_t include_path, uint8_t recursive)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    DIR *dir = NULL;
    struct dirent *entry = NULL;
    int32_t err = VV_MZ_OK;
    int16_t is_dir = 0;
    const char *filename = NULL;
    const char *filenameinzip = path;
    char *wildcard_ptr = NULL;
    char full_path[1024];
    char path_dir[1024];


    if (strrchr(path, '*') != NULL)
    {
        strncpy(path_dir, path, sizeof(path_dir) - 1);
        path_dir[sizeof(path_dir) - 1] = 0;
        vv_mz_path_remove_filename(path_dir);
        wildcard_ptr = path_dir + strlen(path_dir) + 1;
        root_path = path = path_dir;
    }
    else
    {
        if (vv_mz_os_is_dir(path) == VV_MZ_OK)
            is_dir = 1;

        /* Construct the filename that our file will be stored in the zip as */
        if (root_path == NULL)
            root_path = path;

        /* Should the file be stored with any path info at all? */
        if (!include_path)
        {
            if (!is_dir && root_path == path)
            {
                if (vv_mz_path_get_filename(filenameinzip, &filename) == VV_MZ_OK)
                    filenameinzip = filename;
            }
            else
            {
                filenameinzip += strlen(root_path);
            }
        }

        if (!writer->store_links && !writer->follow_links)
        {
            if (vv_mz_os_is_symlink(path) == VV_MZ_OK)
                return err;
        }

        if (*filenameinzip != 0)
            err = vv_mz_zip_writer_add_file(handle, path, filenameinzip);

        if (!is_dir)
            return err;

        if (writer->store_links)
        {
            if (vv_mz_os_is_symlink(path) == VV_MZ_OK)
                return err;
        }
    }

    dir = vv_mz_os_open_dir(path);

    if (dir == NULL)
        return VV_MZ_EXIST_ERROR;

    while ((entry = vv_mz_os_read_dir(dir)) != NULL)
    {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        full_path[0] = 0;
        vv_mz_path_combine(full_path, path, sizeof(full_path));
        vv_mz_path_combine(full_path, entry->d_name, sizeof(full_path));

        if (!recursive && vv_mz_os_is_dir(full_path) == VV_MZ_OK)
            continue;

        if ((wildcard_ptr != NULL) && (vv_mz_path_compare_wc(entry->d_name, wildcard_ptr, 1) != VV_MZ_OK))
            continue;

        err = vv_mz_zip_writer_add_path(handle, full_path, root_path, include_path, recursive);
        if (err != VV_MZ_OK)
            return err;
    }

    vv_mz_os_close_dir(dir);
    return VV_MZ_OK;
}

int32_t vv_mz_zip_writer_copy_from_reader(void *handle, void *reader)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    vv_mz_zip_file *file_info = NULL;
    int64_t compressed_size = 0;
    int64_t uncompressed_size = 0;
    uint32_t crc32 = 0;
    int32_t err = VV_MZ_OK;
    uint8_t original_raw = 0;
    void *reader_zip_handle = NULL;
    void *writer_zip_handle = NULL;


    if (vv_mz_zip_reader_is_open(reader) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_zip_writer_is_open(writer) != VV_MZ_OK)
        return VV_MZ_PARAM_ERROR;

    err = vv_mz_zip_reader_entry_get_info(reader, &file_info);

    if (err != VV_MZ_OK)
        return err;

    vv_mz_zip_reader_get_zip_handle(reader, &reader_zip_handle);
    vv_mz_zip_writer_get_zip_handle(writer, &writer_zip_handle);

    /* Open entry for raw reading */
    err = vv_mz_zip_entry_read_open(reader_zip_handle, 1, NULL);

    if (err == VV_MZ_OK)
    {
        /* Write entry raw, save original raw value */
        original_raw = writer->raw;
        writer->raw = 1;

        err = vv_mz_zip_writer_entry_open(writer, file_info);

        if ((err == VV_MZ_OK) &&
            (vv_mz_zip_attrib_is_dir(writer->file_info.external_fa, writer->file_info.version_madeby) != VV_MZ_OK))
        {
            err = vv_mz_zip_writer_add(writer, reader_zip_handle, vv_mz_zip_entry_read);
        }

        if (err == VV_MZ_OK)
        {
            err = vv_mz_zip_entry_read_close(reader_zip_handle, &crc32, &compressed_size, &uncompressed_size);
            if (err == VV_MZ_OK)
                err = vv_mz_zip_entry_write_close(writer_zip_handle, crc32, compressed_size, uncompressed_size);
        }

        if (vv_mz_zip_entry_is_open(reader_zip_handle) == VV_MZ_OK)
            vv_mz_zip_entry_close(reader_zip_handle);

        if (vv_mz_zip_entry_is_open(writer_zip_handle) == VV_MZ_OK)
            vv_mz_zip_entry_close(writer_zip_handle);

        writer->raw = original_raw;
    }

    return err;
}

/***************************************************************************/

void vv_mz_zip_writer_set_password(void *handle, const char *password)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->password = password;
}

void vv_mz_zip_writer_set_comment(void *handle, const char *comment)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->comment = comment;
}

void vv_mz_zip_writer_set_raw(void *handle, uint8_t raw)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->raw = raw;
}

int32_t vv_mz_zip_writer_get_raw(void *handle, uint8_t *raw)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    if (raw == NULL)
        return VV_MZ_PARAM_ERROR;
    *raw = writer->raw;
    return VV_MZ_OK;
}

void vv_mz_zip_writer_set_aes(void *handle, uint8_t aes)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->aes = aes;
}

void vv_mz_zip_writer_set_compress_method(void *handle, uint16_t compress_method)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->compress_method = compress_method;
}

void vv_mz_zip_writer_set_compress_level(void *handle, int16_t compress_level)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->compress_level = compress_level;
}

void vv_mz_zip_writer_set_follow_links(void *handle, uint8_t follow_links)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->follow_links = follow_links;
}

void vv_mz_zip_writer_set_store_links(void *handle, uint8_t store_links)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->store_links = store_links;
}

void vv_mz_zip_writer_set_zip_cd(void *handle, uint8_t zip_cd)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->zip_cd = zip_cd;
}

int32_t vv_mz_zip_writer_set_certificate(void *handle, const char *cert_path, const char *cert_pwd)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    void *cert_stream = NULL;
    uint8_t *cert_data = NULL;
    int32_t cert_data_size = 0;
    int32_t err = VV_MZ_OK;

    if (cert_path == NULL)
        return VV_MZ_PARAM_ERROR;

    cert_data_size = (int32_t)vv_mz_os_get_file_size(cert_path);

    if (cert_data_size == 0)
        return VV_MZ_PARAM_ERROR;

    if (writer->cert_data != NULL)
    {
        VV_MZ_FREE(writer->cert_data);
        writer->cert_data = NULL;
    }

    cert_data = (uint8_t *)VV_MZ_ALLOC(cert_data_size);

    /* Read pkcs12 certificate from disk */
    vv_mz_stream_os_create(&cert_stream);
    err = vv_mz_stream_os_open(cert_stream, cert_path, VV_MZ_OPEN_MODE_READ);
    if (err == VV_MZ_OK)
    {
        if (vv_mz_stream_os_read(cert_stream, cert_data, cert_data_size) != cert_data_size)
            err = VV_MZ_READ_ERROR;
        vv_mz_stream_os_close(cert_stream);
    }
    vv_mz_stream_os_delete(&cert_stream);

    if (err == VV_MZ_OK)
    {
        writer->cert_data = cert_data;
        writer->cert_data_size = cert_data_size;
        writer->cert_pwd = cert_pwd;
    }
    else
    {
        VV_MZ_FREE(cert_data);
    }

    return err;
}

void vv_mz_zip_writer_set_overwrite_cb(void *handle, void *userdata, vv_mz_zip_writer_overwrite_cb cb)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->overwrite_cb = cb;
    writer->overwrite_userdata = userdata;
}

void vv_mz_zip_writer_set_password_cb(void *handle, void *userdata, vv_mz_zip_writer_password_cb cb)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->password_cb = cb;
    writer->password_userdata = userdata;
}

void vv_mz_zip_writer_set_progress_cb(void *handle, void *userdata, vv_mz_zip_writer_progress_cb cb)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->progress_cb = cb;
    writer->progress_userdata = userdata;
}

void vv_mz_zip_writer_set_progress_interval(void *handle, uint32_t milliseconds)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->progress_cb_interval_ms = milliseconds;
}

void vv_mz_zip_writer_set_entry_cb(void *handle, void *userdata, vv_mz_zip_writer_entry_cb cb)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    writer->entry_cb = cb;
    writer->entry_userdata = userdata;
}

int32_t vv_mz_zip_writer_get_zip_handle(void *handle, void **zip_handle)
{
    vv_mz_zip_writer *writer = (vv_mz_zip_writer *)handle;
    if (zip_handle == NULL)
        return VV_MZ_PARAM_ERROR;
    *zip_handle = writer->zip_handle;
    if (*zip_handle == NULL)
        return VV_MZ_EXIST_ERROR;
    return VV_MZ_OK;
}

/***************************************************************************/

void *vv_mz_zip_writer_create(void **handle)
{
    vv_mz_zip_writer *writer = NULL;

    writer = (vv_mz_zip_writer *)VV_MZ_ALLOC(sizeof(vv_mz_zip_writer));
    if (writer != NULL)
    {
        memset(writer, 0, sizeof(vv_mz_zip_writer));

        writer->aes = 1;


        writer->compress_method = VV_MZ_COMPRESS_METHOD_DEFLATE;

        writer->compress_level = VV_MZ_COMPRESS_LEVEL_BEST;
        writer->progress_cb_interval_ms = VV_MZ_DEFAULT_PROGRESS_INTERVAL;

        *handle = writer;
    }

    return writer;
}

void vv_mz_zip_writer_delete(void **handle)
{
    vv_mz_zip_writer *writer = NULL;
    if (handle == NULL)
        return;
    writer = (vv_mz_zip_writer *)*handle;
    if (writer != NULL)
    {
        vv_mz_zip_writer_close(writer);

        if (writer->cert_data != NULL)
            VV_MZ_FREE(writer->cert_data);

        writer->cert_data = NULL;
        writer->cert_data_size = 0;

        VV_MZ_FREE(writer);
    }
    *handle = NULL;
}

/***************************************************************************/
