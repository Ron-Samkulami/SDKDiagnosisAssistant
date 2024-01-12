/* vv_mz_compat.c -- Backwards compatible interface for older versions
   Version 2.8.9, July 4, 2019
   part of the MiniZip project

   Copyright (C) 2010-2019 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip
   Copyright (C) 1998-2010 Gilles Vollant
     https://www.winimage.com/zLibDll/minizip.html

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include "vv_mz.h"
#include "vv_mz_os.h"
#include "vv_mz_strm.h"
#include "vv_mz_strm_mem.h"
#include "vv_mz_strm_os.h"
#include "vv_mz_strm_zlib.h"
#include "vv_mz_zip.h"

#include <stdio.h> /* SEEK */

#include "vv_mz_compat.h"

/***************************************************************************/

typedef struct vv_mz_compat_s {
    void     *stream;
    void     *handle;
    uint64_t entry_index;
    int64_t  entry_pos;
    int64_t  total_out;
} vv_mz_compat;

/***************************************************************************/

static int32_t zipConvertAppendToStreamMode(int append)
{
    int32_t mode = VV_MZ_OPEN_MODE_WRITE;
    switch (append)
    {
    case APPEND_STATUS_CREATE:
        mode |= VV_MZ_OPEN_MODE_CREATE;
        break;
    case APPEND_STATUS_CREATEAFTER:
        mode |= VV_MZ_OPEN_MODE_CREATE | VV_MZ_OPEN_MODE_APPEND;
        break;
    case APPEND_STATUS_ADDINZIP:
        mode |= VV_MZ_OPEN_MODE_READ | VV_MZ_OPEN_MODE_APPEND;
        break;
    }
    return mode;
}

zipFile vv_zipOpen(const char *path, int append)
{
    zlib_filefunc64_def pzlib = vv_mz_stream_os_get_interface();
    return vv_zipOpen2(path, append, NULL, &pzlib);
}

zipFile vv_zipOpen64(const void *path, int append)
{
    zlib_filefunc64_def pzlib = vv_mz_stream_os_get_interface();
    return vv_zipOpen2(path, append, NULL, &pzlib);
}

zipFile vv_zipOpen2(const char *path, int append, const char **globalcomment,
    zlib_filefunc_def *pzlib_filefunc_def)
{
    return vv_zipOpen2_64(path, append, globalcomment, pzlib_filefunc_def);
}

zipFile vv_zipOpen2_64(const void *path, int append, const char **globalcomment,
    zlib_filefunc64_def *pzlib_filefunc_def)
{
    zipFile zip = NULL;
    int32_t mode = zipConvertAppendToStreamMode(append);
    void *stream = NULL;

    if (pzlib_filefunc_def)
    {
        if (vv_mz_stream_create(&stream, (vv_mz_stream_vtbl *)*pzlib_filefunc_def) == NULL)
            return NULL;
    }
    else
    {
        if (vv_mz_stream_os_create(&stream) == NULL)
            return NULL;
    }

    if (vv_mz_stream_open(stream, path, mode) != VV_MZ_OK)
    {
        vv_mz_stream_delete(&stream);
        return NULL;
    }

    zip = vv_zipOpen_MZ(stream, append, globalcomment);

    if (zip == NULL)
    {
        vv_mz_stream_delete(&stream);
        return NULL;
    }

    return zip;
}

zipFile vv_zipOpen_MZ(void *stream, int append, const char **globalcomment)
{
    vv_mz_compat *compat = NULL;
    int32_t err = VV_MZ_OK;
    int32_t mode = zipConvertAppendToStreamMode(append);
    void *handle = NULL;

    vv_mz_zip_create(&handle);
    err = vv_mz_zip_open(handle, stream, mode);

    if (err != VV_MZ_OK)
    {
        vv_mz_zip_delete(&handle);
        return NULL;
    }

    if (globalcomment != NULL)
        vv_mz_zip_get_comment(handle, globalcomment);

    compat = (vv_mz_compat *)VV_MZ_ALLOC(sizeof(vv_mz_compat));
    if (compat != NULL)
    {
        compat->handle = handle;
        compat->stream = stream;
    }
    else
    {
        vv_mz_zip_delete(&handle);
    }

    return (zipFile)compat;
}

int vv_zipOpenNewFileInZip5(zipFile file, const char *filename, const zip_fileinfo *zipfi,
    const void *extrafield_local, uint16_t size_extrafield_local, const void *extrafield_global,
    uint16_t size_extrafield_global, const char *comment, uint16_t compression_method, int level,
    int raw, int windowBits, int memLevel, int strategy, const char *password,
    signed char aes, uint16_t version_madeby, uint16_t flag_base, int zip64)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file file_info;
    uint64_t dos_date = 0;

    VV_MZ_UNUSED(strategy);
    VV_MZ_UNUSED(memLevel);
    VV_MZ_UNUSED(windowBits);
    VV_MZ_UNUSED(size_extrafield_local);
    VV_MZ_UNUSED(extrafield_local);

    if (compat == NULL)
        return ZIP_PARAMERROR;

    memset(&file_info, 0, sizeof(file_info));

    if (zipfi != NULL)
    {
        if (zipfi->vv_mz_dos_date != 0)
            dos_date = zipfi->vv_mz_dos_date;
        else
            dos_date = vv_mz_zip_tm_to_dosdate(&zipfi->tvv_mz_date);

        file_info.modified_date = vv_mz_zip_dosdate_to_time_t(dos_date);
        file_info.external_fa = zipfi->external_fa;
        file_info.internal_fa = zipfi->internal_fa;
    }

    if (filename == NULL)
        filename = "-";

    file_info.compression_method = compression_method;
    file_info.filename = filename;
    /* file_info.extrafield_local = extrafield_local; */
    /* file_info.extrafield_local_size = size_extrafield_local; */
    file_info.extrafield = extrafield_global;
    file_info.extrafield_size = size_extrafield_global;
    file_info.version_madeby = version_madeby;
    file_info.comment = comment;
    file_info.flag = flag_base;
    if (zip64)
        file_info.zip64 = VV_MZ_ZIP64_FORCE;
    else
        file_info.zip64 = VV_MZ_ZIP64_DISABLE;

    if ((aes && password != NULL) || (raw && (file_info.flag & VV_MZ_ZIP_FLAG_ENCRYPTED)))
        file_info.aes_version = VV_MZ_AES_VERSION;


    return vv_mz_zip_entry_write_open(compat->handle, &file_info, (int16_t)level, (uint8_t)raw, password);
}

int vv_zipWriteInFileInZip(zipFile file, const void *buf, uint32_t len)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t written = 0;
    if (compat == NULL || len >= INT32_MAX)
        return ZIP_PARAMERROR;
    written = vv_mz_zip_entry_write(compat->handle, buf, (int32_t)len);
    if ((written < 0) || ((uint32_t)written != len))
        return ZIP_ERRNO;
    return ZIP_OK;
}

int vv_zipCloseFileInZipRaw(zipFile file, uint32_t uncompressed_size, uint32_t crc32)
{
    return vv_zipCloseFileInZipRaw64(file, uncompressed_size, crc32);
}

int vv_zipCloseFileInZipRaw64(zipFile file, int64_t uncompressed_size, uint32_t crc32)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return ZIP_PARAMERROR;
    return vv_mz_zip_entry_close_raw(compat->handle, uncompressed_size, crc32);
}

int vv_zipCloseFileInZip(zipFile file)
{
    return vv_zipCloseFileInZip64(file);
}

int vv_zipCloseFileInZip64(zipFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return ZIP_PARAMERROR;
    return vv_mz_zip_entry_close(compat->handle);
}

int vv_zipClose(zipFile file, const char *global_comment)
{
    return vv_zipClose_64(file, global_comment);
}

int vv_zipClose_64(zipFile file, const char *global_comment)
{
    return vv_zipClose2_64(file, global_comment, VV_MZ_VERSION_MADEBY);
}

int vv_zipClose2_64(zipFile file, const char *global_comment, uint16_t version_madeby)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;

    if (compat->handle != NULL)
        err = vv_zipClose2_MZ(file, global_comment, version_madeby);

    if (compat->stream != NULL)
    {
        vv_mz_stream_close(compat->stream);
        vv_mz_stream_delete(&compat->stream);
    }

    VV_MZ_FREE(compat);

    return err;
}

/* Only closes the zip handle, does not close the stream */
int vv_zipClose_MZ(zipFile file, const char *global_comment)
{
    return vv_zipClose2_MZ(file, global_comment, VV_MZ_VERSION_MADEBY);
}

/* Only closes the zip handle, does not close the stream */
int vv_zipClose2_MZ(zipFile file, const char *global_comment, uint16_t version_madeby)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;

    if (compat == NULL)
        return ZIP_PARAMERROR;
    if (compat->handle == NULL)
        return err;

    if (global_comment != NULL)
        vv_mz_zip_set_comment(compat->handle, global_comment);

    vv_mz_zip_set_version_madeby(compat->handle, version_madeby);
    err = vv_mz_zip_close(compat->handle);
    vv_mz_zip_delete(&compat->handle);

    return err;
}

void* vv_zipGetStream(zipFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return NULL;
    return (void *)compat->stream;
}

/***************************************************************************/

vv_unzFile vv_unzOpen(const char *path)
{
    return vv_unzOpen64(path);
}

vv_unzFile vv_unzOpen64(const void *path)
{
    zlib_filefunc64_def pzlib = vv_mz_stream_os_get_interface();
    return vv_unzOpen2(path, &pzlib);
}

vv_unzFile vv_unzOpen2(const char *path, zlib_filefunc_def *pzlib_filefunc_def)
{
    return vv_unzOpen2_64(path, pzlib_filefunc_def);
}

vv_unzFile vv_unzOpen2_64(const void *path, zlib_filefunc64_def *pzlib_filefunc_def)
{
    vv_unzFile vv_unz = NULL;
    void *stream = NULL;

    if (pzlib_filefunc_def)
    {
        if (vv_mz_stream_create(&stream, (vv_mz_stream_vtbl *)*pzlib_filefunc_def) == NULL)
            return NULL;
    }
    else
    {
        if (vv_mz_stream_os_create(&stream) == NULL)
            return NULL;
    }

    if (vv_mz_stream_open(stream, path, VV_MZ_OPEN_MODE_READ) != VV_MZ_OK)
    {
        vv_mz_stream_delete(&stream);
        return NULL;
    }

    vv_unz = vv_unzOpen_MZ(stream);
    if (vv_unz == NULL)
    {
        vv_mz_stream_delete(&stream);
        return NULL;
    }
    return vv_unz;
}

vv_unzFile vv_unzOpen_MZ(void *stream)
{
    vv_mz_compat *compat = NULL;
    int32_t err = VV_MZ_OK;
    void *handle = NULL;

    vv_mz_zip_create(&handle);
    err = vv_mz_zip_open(handle, stream, VV_MZ_OPEN_MODE_READ);

    if (err != VV_MZ_OK)
    {
        vv_mz_zip_delete(&handle);
        return NULL;
    }

    compat = (vv_mz_compat *)VV_MZ_ALLOC(sizeof(vv_mz_compat));
    if (compat != NULL)
    {
        compat->handle = handle;
        compat->stream = stream;

        vv_mz_zip_goto_first_entry(compat->handle);
    }
    else
    {
        vv_mz_zip_delete(&handle);
    }

    return (vv_unzFile)compat;
}

int vv_unzClose(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;

    if (compat->handle != NULL)
        err = vv_unzClose_MZ(file);

    if (compat->stream != NULL)
    {
        vv_mz_stream_close(compat->stream);
        vv_mz_stream_delete(&compat->stream);
    }

    VV_MZ_FREE(compat);

    return err;
}

/* Only closes the zip handle, does not close the stream */
int vv_unzClose_MZ(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;

    err = vv_mz_zip_close(compat->handle);
    vv_mz_zip_delete(&compat->handle);

    return err;
}

int vv_unzGetGlobalInfo(vv_unzFile file, vv_unz_global_info* pglobal_info32)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_unz_global_info64 global_info64;
    int32_t err = VV_MZ_OK;

    memset(pglobal_info32, 0, sizeof(vv_unz_global_info));
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;

    err = vv_unzGetGlobalInfo64(file, &global_info64);
    if (err == VV_MZ_OK)
    {
        pglobal_info32->number_entry = (uint32_t)global_info64.number_entry;
        pglobal_info32->size_comment = global_info64.size_comment;
        pglobal_info32->number_disk_with_CD = global_info64.number_disk_with_CD;
    }
    return err;
}

int vv_unzGetGlobalInfo64(vv_unzFile file, vv_unz_global_info64 *pglobal_info)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    const char *comment_ptr = NULL;
    int32_t err = VV_MZ_OK;

    memset(pglobal_info, 0, sizeof(vv_unz_global_info64));
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_get_comment(compat->handle, &comment_ptr);
    if (err == VV_MZ_OK)
        pglobal_info->size_comment = (uint16_t)strlen(comment_ptr);
    if ((err == VV_MZ_OK) || (err == VV_MZ_EXIST_ERROR))
        err = vv_mz_zip_get_number_entry(compat->handle, &pglobal_info->number_entry);
    if (err == VV_MZ_OK)
        err = vv_mz_zip_get_disk_number_with_cd(compat->handle, &pglobal_info->number_disk_with_CD);
    return err;
}

int vv_unzGetGlobalComment(vv_unzFile file, char *comment, uint16_t comment_size)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    const char *comment_ptr = NULL;
    int32_t err = VV_MZ_OK;

    if (comment == NULL || comment_size == 0)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_get_comment(compat->handle, &comment_ptr);
    if (err == VV_MZ_OK)
    {
        strncpy(comment, comment_ptr, comment_size - 1);
        comment[comment_size - 1] = 0;
    }
    return err;
}

int vv_unzOpenCurrentFile3(vv_unzFile file, int *method, int *level, int raw, const char *password)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    int32_t err = VV_MZ_OK;
    void *stream = NULL;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    if (method != NULL)
        *method = 0;
    if (level != NULL)
        *level = 0;

    compat->total_out = 0;
    err = vv_mz_zip_entry_read_open(compat->handle, (uint8_t)raw, password);
    if (err == VV_MZ_OK)
        err = vv_mz_zip_entry_get_info(compat->handle, &file_info);
    if (err == VV_MZ_OK)
    {
        if (method != NULL)
        {
            *method = file_info->compression_method;
        }

        if (level != NULL)
        {
            *level = 6;
            switch (file_info->flag & 0x06)
            {
            case VV_MZ_ZIP_FLAG_DEFLATE_SUPER_FAST:
                *level = 1;
                break;
            case VV_MZ_ZIP_FLAG_DEFLATE_FAST:
                *level = 2;
                break;
            case VV_MZ_ZIP_FLAG_DEFLATE_MAX:
                *level = 9;
                break;
            }
        }
    }
    if (err == VV_MZ_OK)
        err = vv_mz_zip_get_stream(compat->handle, &stream);
    if (err == VV_MZ_OK)
        compat->entry_pos = vv_mz_stream_tell(stream);
    return err;
}

int vv_unzOpenCurrentFile(vv_unzFile file)
{
    return vv_unzOpenCurrentFile3(file, NULL, NULL, 0, NULL);
}

int vv_unzOpenCurrentFilePassword(vv_unzFile file, const char *password)
{
    return vv_unzOpenCurrentFile3(file, NULL, NULL, 0, password);
}

int vv_unzOpenCurrentFile2(vv_unzFile file, int *method, int *level, int raw)
{
    return vv_unzOpenCurrentFile3(file, method, level, raw, NULL);
}

int vv_unzReadCurrentFile(vv_unzFile file, void *buf, uint32_t len)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;
    if (compat == NULL || len >= INT32_MAX)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_entry_read(compat->handle, buf, (int32_t)len);
    if (err > 0)
        compat->total_out += (uint32_t)err;
    return err;
}

int vv_unzCloseCurrentFile(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_entry_close(compat->handle);
    return err;
}

int vv_unzGetCurrentFileInfo(vv_unzFile file, vv_unz_file_info *pfile_info, char *filename,
    uint16_t filename_size, void *extrafield, uint16_t extrafield_size, char *comment, uint16_t comment_size)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    uint16_t bytes_to_copy = 0;
    int32_t err = VV_MZ_OK;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;

    err = vv_mz_zip_entry_get_info(compat->handle, &file_info);

    if ((err == VV_MZ_OK) && (pfile_info != NULL))
    {
        pfile_info->version = file_info->version_madeby;
        pfile_info->version_needed = file_info->version_needed;
        pfile_info->flag = file_info->flag;
        pfile_info->compression_method = file_info->compression_method;
        pfile_info->vv_mz_dos_date = vv_mz_zip_time_t_to_dos_date(file_info->modified_date);
        //vv_mz_zip_time_t_to_tm(file_info->modified_date, &pfile_info->tmu_date);
        //pfile_info->tmu_date.tm_year += 1900;
        pfile_info->crc = file_info->crc;

        pfile_info->size_filename = file_info->filename_size;
        pfile_info->size_file_extra = file_info->extrafield_size;
        pfile_info->size_file_comment = file_info->comment_size;

        pfile_info->disk_num_start = (uint16_t)file_info->disk_number;
        pfile_info->internal_fa = file_info->internal_fa;
        pfile_info->external_fa = file_info->external_fa;

        pfile_info->compressed_size = (uint32_t)file_info->compressed_size;
        pfile_info->uncompressed_size = (uint32_t)file_info->uncompressed_size;

        if (filename_size > 0 && filename != NULL && file_info->filename != NULL)
        {
            bytes_to_copy = filename_size;
            if (bytes_to_copy > file_info->filename_size)
                bytes_to_copy = file_info->filename_size;
            memcpy(filename, file_info->filename, bytes_to_copy);
            if (bytes_to_copy < filename_size)
                filename[bytes_to_copy] = 0;
        }
        if (extrafield_size > 0 && extrafield != NULL)
        {
            bytes_to_copy = extrafield_size;
            if (bytes_to_copy > file_info->extrafield_size)
                bytes_to_copy = file_info->extrafield_size;
            memcpy(extrafield, file_info->extrafield, bytes_to_copy);
        }
        if (comment_size > 0 && comment != NULL && file_info->comment != NULL)
        {
            bytes_to_copy = comment_size;
            if (bytes_to_copy > file_info->comment_size)
                bytes_to_copy = file_info->comment_size;
            memcpy(comment, file_info->comment, bytes_to_copy);
            if (bytes_to_copy < comment_size)
                comment[bytes_to_copy] = 0;
        }
    }
    return err;
}

int vv_unzGetCurrentFileInfo64(vv_unzFile file, vv_unz_file_info64 * pfile_info, char *filename,
    uint16_t filename_size, void *extrafield, uint16_t extrafield_size, char *comment, uint16_t comment_size)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    uint16_t bytes_to_copy = 0;
    int32_t err = VV_MZ_OK;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;

    err = vv_mz_zip_entry_get_info(compat->handle, &file_info);

    if ((err == VV_MZ_OK) && (pfile_info != NULL))
    {
        pfile_info->version = file_info->version_madeby;
        pfile_info->version_needed = file_info->version_needed;
        pfile_info->flag = file_info->flag;
        pfile_info->compression_method = file_info->compression_method;
        pfile_info->vv_mz_dos_date = vv_mz_zip_time_t_to_dos_date(file_info->modified_date);
        //vv_mz_zip_time_t_to_tm(file_info->modified_date, &pfile_info->tmu_date);
        //pfile_info->tmu_date.tm_year += 1900;
        pfile_info->crc = file_info->crc;

        pfile_info->size_filename = file_info->filename_size;
        pfile_info->size_file_extra = file_info->extrafield_size;
        pfile_info->size_file_comment = file_info->comment_size;

        pfile_info->disk_num_start = file_info->disk_number;
        pfile_info->internal_fa = file_info->internal_fa;
        pfile_info->external_fa = file_info->external_fa;

        pfile_info->compressed_size = (uint64_t)file_info->compressed_size;
        pfile_info->uncompressed_size = (uint64_t)file_info->uncompressed_size;

        if (filename_size > 0 && filename != NULL && file_info->filename != NULL)
        {
            bytes_to_copy = filename_size;
            if (bytes_to_copy > file_info->filename_size)
                bytes_to_copy = file_info->filename_size;
            memcpy(filename, file_info->filename, bytes_to_copy);
            if (bytes_to_copy < filename_size)
                filename[bytes_to_copy] = 0;
        }

        if (extrafield_size > 0 && extrafield != NULL)
        {
            bytes_to_copy = extrafield_size;
            if (bytes_to_copy > file_info->extrafield_size)
                bytes_to_copy = file_info->extrafield_size;
            memcpy(extrafield, file_info->extrafield, bytes_to_copy);
        }

        if (comment_size > 0 && comment != NULL && file_info->comment != NULL)
        {
            bytes_to_copy = comment_size;
            if (bytes_to_copy > file_info->comment_size)
                bytes_to_copy = file_info->comment_size;
            memcpy(comment, file_info->comment, bytes_to_copy);
            if (bytes_to_copy < comment_size)
                comment[bytes_to_copy] = 0;
        }
    }
    return err;
}

int vv_unzGoToFirstFile(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    compat->entry_index = 0;
    return vv_mz_zip_goto_first_entry(compat->handle);
}

int vv_unzGoToNextFile(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_goto_next_entry(compat->handle);
    if (err != VV_MZ_END_OF_LIST)
        compat->entry_index += 1;
    return err;
}

int vv_unzLocateFile(vv_unzFile file, const char *filename, vv_unzFileNameComparer filename_compare_func)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    uint64_t preserve_index = 0;
    int32_t err = VV_MZ_OK;
    int32_t result = 0;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;

    preserve_index = compat->entry_index;

    err = vv_mz_zip_goto_first_entry(compat->handle);
    while (err == VV_MZ_OK)
    {
        err = vv_mz_zip_entry_get_info(compat->handle, &file_info);
        if (err != VV_MZ_OK)
            break;

        if (filename_compare_func != NULL)
            result = filename_compare_func(file, filename, file_info->filename);
        else
            result = strcmp(filename, file_info->filename);

        if (result == 0)
            return VV_MZ_OK;

        err = vv_mz_zip_goto_next_entry(compat->handle);
    }

    compat->entry_index = preserve_index;
    return err;
}

/***************************************************************************/

int vv_unzGetFilePos(vv_unzFile file, vv_unz_file_pos *file_pos)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t offset = 0;

    if (compat == NULL || file_pos == NULL)
        return VV_UNZ_PARAMERROR;

    offset = vv_unzGetOffset(file);
    if (offset < 0)
        return offset;

    file_pos->pos_in_zip_directory = (uint32_t)offset;
    file_pos->num_of_file = (uint32_t)compat->entry_index;
    return VV_MZ_OK;
}

int vv_unzGoToFilePos(vv_unzFile file, vv_unz_file_pos *file_pos)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_unz64_file_pos file_pos64;

    if (compat == NULL || file_pos == NULL)
        return VV_UNZ_PARAMERROR;

    file_pos64.pos_in_zip_directory = file_pos->pos_in_zip_directory;
    file_pos64.num_of_file = file_pos->num_of_file;

    return vv_unzGoToFilePos64(file, &file_pos64);
}

int vv_unzGetFilePos64(vv_unzFile file, vv_unz64_file_pos *file_pos)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int64_t offset = 0;

    if (compat == NULL || file_pos == NULL)
        return VV_UNZ_PARAMERROR;

    offset = vv_unzGetOffset64(file);
    if (offset < 0)
        return (int)offset;

    file_pos->pos_in_zip_directory = offset;
    file_pos->num_of_file = compat->entry_index;
    return VV_UNZ_OK;
}

int vv_unzGoToFilePos64(vv_unzFile file, const vv_unz64_file_pos *file_pos)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    int32_t err = VV_MZ_OK;

    if (compat == NULL || file_pos == NULL)
        return VV_UNZ_PARAMERROR;

    err = vv_mz_zip_goto_entry(compat->handle, file_pos->pos_in_zip_directory);
    if (err == VV_MZ_OK)
        compat->entry_index = file_pos->num_of_file;
    return err;
}

int32_t vv_unzGetOffset(vv_unzFile file)
{
    return (int32_t)vv_unzGetOffset64(file);
}

int64_t vv_unzGetOffset64(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    return vv_mz_zip_get_entry(compat->handle);
}

int vv_unzSetOffset(vv_unzFile file, uint32_t pos)
{
    return vv_unzSetOffset64(file, pos);
}

int vv_unzSetOffset64(vv_unzFile file, int64_t pos)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    return (int)vv_mz_zip_goto_entry(compat->handle, pos);
}

int vv_unzGetLocalExtrafield(vv_unzFile file, void *buf, unsigned int len)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    int32_t err = VV_MZ_OK;
    int32_t bytes_to_copy = 0;

    if (compat == NULL || buf == NULL || len >= INT32_MAX)
        return VV_UNZ_PARAMERROR;

    err = vv_mz_zip_entry_get_local_info(compat->handle, &file_info);
    if (err != VV_MZ_OK)
        return err;

    bytes_to_copy = (int32_t)len;
    if (bytes_to_copy > file_info->extrafield_size)
        bytes_to_copy = file_info->extrafield_size;

    memcpy(buf, file_info->extrafield, bytes_to_copy);
    return VV_MZ_OK;
}

int64_t vv_unztell(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    return (int64_t)compat->total_out;
}

int32_t vv_unzTell(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    return (int32_t)compat->total_out;
}

int64_t vv_unzTell64(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    return (int64_t)compat->total_out;
}

int vv_unzSeek(vv_unzFile file, int32_t offset, int origin)
{
    return vv_unzSeek64(file, offset, origin);
}

int vv_unzSeek64(vv_unzFile file, int64_t offset, int origin)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    int64_t position = 0;
    int32_t err = VV_MZ_OK;
    void *stream = NULL;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_entry_get_info(compat->handle, &file_info);
    if (err != VV_MZ_OK)
        return err;
    if (file_info->compression_method != VV_MZ_COMPRESS_METHOD_STORE)
        return VV_UNZ_ERRNO;

    if (origin == SEEK_SET)
        position = offset;
    else if (origin == SEEK_CUR)
        position = compat->total_out + offset;
    else if (origin == SEEK_END)
        position = (int64_t)file_info->compressed_size + offset;
    else
        return VV_UNZ_PARAMERROR;

    if (position > (int64_t)file_info->compressed_size)
        return VV_UNZ_PARAMERROR;

    err = vv_mz_zip_get_stream(compat->handle, &stream);
    if (err == VV_MZ_OK)
        err = vv_mz_stream_seek(stream, compat->entry_pos + position, VV_MZ_SEEK_SET);
    if (err == VV_MZ_OK)
        compat->total_out = position;
    return err;
}

int vv_unzEndOfFile(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    vv_mz_zip_file *file_info = NULL;
    int32_t err = VV_MZ_OK;

    if (compat == NULL)
        return VV_UNZ_PARAMERROR;
    err = vv_mz_zip_entry_get_info(compat->handle, &file_info);
    if (err != VV_MZ_OK)
        return err;
    if (compat->total_out == (int64_t)file_info->uncompressed_size)
        return 1;
    return 0;
}

void* vv_unzGetStream(vv_unzFile file)
{
    vv_mz_compat *compat = (vv_mz_compat *)file;
    if (compat == NULL)
        return NULL;
    return (void *)compat->stream;
}

/***************************************************************************/

void vv_fill_fopen_filefunc(zlib_filefunc_def *pzlib_filefunc_def)
{
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_os_get_interface();
}

void vv_fill_fopen64_filefunc(zlib_filefunc64_def *pzlib_filefunc_def)
{
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_os_get_interface();
}

void vv_fill_win32_filefunc(zlib_filefunc_def *pzlib_filefunc_def)
{
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_os_get_interface();
}

void vv_fill_win32_filefunc64(zlib_filefunc64_def *pzlib_filefunc_def)
{
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_os_get_interface();
}

void vv_fill_win32_filefunc64A(zlib_filefunc64_def *pzlib_filefunc_def)
{
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_os_get_interface();
}

void vv_fill_win32_filefunc64W(zlib_filefunc64_def *pzlib_filefunc_def)
{
    /* NOTE: You should no longer pass in widechar string to open function */
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_os_get_interface();
}

void vv_fill_memory_filefunc(zlib_filefunc_def *pzlib_filefunc_def)
{
    if (pzlib_filefunc_def != NULL)
        *pzlib_filefunc_def = vv_mz_stream_mem_get_interface();
}
