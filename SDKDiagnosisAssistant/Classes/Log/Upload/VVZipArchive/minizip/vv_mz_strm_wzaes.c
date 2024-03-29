/* vv_mz_strm_wzaes.c -- Stream for WinZip AES encryption
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
      https://github.com/nmoinvaz/minizip
   Copyright (C) 1998-2010 Brian Gladman, Worcester, UK

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include "vv_mz.h"
#include "vv_mz_crypt.h"
#include "vv_mz_strm.h"
#include "vv_mz_strm_wzaes.h"

/***************************************************************************/

#define VV_MZ_AES_KEYING_ITERATIONS    (1000)
#define VV_MZ_AES_SALT_LENGTH(MODE)    (4 * (MODE & 3) + 4)
#define VV_MZ_AES_SALT_LENGTH_MAX      (16)
#define VV_MZ_AES_PW_LENGTH_MAX        (128)
#define VV_MZ_AES_PW_VERIFY_SIZE       (2)
#define VV_MZ_AES_AUTHCODE_SIZE        (10)

/***************************************************************************/

static vv_mz_stream_vtbl vv_mz_stream_wzaes_vtbl = {
    vv_mz_stream_wzaes_open,
    vv_mz_stream_wzaes_is_open,
    vv_mz_stream_wzaes_read,
    vv_mz_stream_wzaes_write,
    vv_mz_stream_wzaes_tell,
    vv_mz_stream_wzaes_seek,
    vv_mz_stream_wzaes_close,
    vv_mz_stream_wzaes_error,
    vv_mz_stream_wzaes_create,
    vv_mz_stream_wzaes_delete,
    vv_mz_stream_wzaes_get_prop_int64,
    vv_mz_stream_wzaes_set_prop_int64
};

/***************************************************************************/

typedef struct vv_mz_stream_wzaes_s {
    vv_mz_stream       stream;
    int32_t         mode;
    int32_t         error;
    int16_t         initialized;
    uint8_t         buffer[UINT16_MAX];
    int64_t         total_in;
    int64_t         max_total_in;
    int64_t         total_out;
    int16_t         encryption_mode;
    const char      *password;
    void            *aes;
    uint32_t        crypt_pos;
    uint8_t         crypt_block[VV_MZ_AES_BLOCK_SIZE];
    void            *hmac;
    uint8_t         nonce[VV_MZ_AES_BLOCK_SIZE];
} vv_mz_stream_wzaes;

/***************************************************************************/

int32_t vv_mz_stream_wzaes_open(void *stream, const char *path, int32_t mode)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    uint16_t salt_length = 0;
    uint16_t password_length = 0;
    uint16_t key_length = 0;
    uint8_t kbuf[2 * VV_MZ_AES_KEY_LENGTH_MAX + VV_MZ_AES_PW_VERIFY_SIZE];
    uint8_t verify[VV_MZ_AES_PW_VERIFY_SIZE];
    uint8_t verify_expected[VV_MZ_AES_PW_VERIFY_SIZE];
    uint8_t salt_value[VV_MZ_AES_SALT_LENGTH_MAX];
    const char *password = path;

    wzaes->total_in = 0;
    wzaes->total_out = 0;
    wzaes->initialized = 0;

    if (vv_mz_stream_is_open(wzaes->stream.base) != VV_MZ_OK)
        return VV_MZ_OPEN_ERROR;

    if (password == NULL)
        password = wzaes->password;
    if (password == NULL)
        return VV_MZ_PARAM_ERROR;
    password_length = (uint16_t)strlen(password);
    if (password_length > VV_MZ_AES_PW_LENGTH_MAX)
        return VV_MZ_PARAM_ERROR;

    if (wzaes->encryption_mode < 1 || wzaes->encryption_mode > 3)
        return VV_MZ_PARAM_ERROR;

    salt_length = VV_MZ_AES_SALT_LENGTH(wzaes->encryption_mode);

    if (mode & VV_MZ_OPEN_MODE_WRITE)
    {
#ifdef VV_MZ_ZIP_NO_COMPRESSION
        return VV_MZ_SUPPORT_ERROR;
#else
        vv_mz_crypt_rand(salt_value, salt_length);
#endif
    }
    else if (mode & VV_MZ_OPEN_MODE_READ)
    {
#ifdef VV_MZ_ZIP_NO_DECOMPRESSION
        return VV_MZ_SUPPORT_ERROR;
#else
        if (vv_mz_stream_read(wzaes->stream.base, salt_value, salt_length) != salt_length)
            return VV_MZ_READ_ERROR;
#endif
    }

    key_length = VV_MZ_AES_KEY_LENGTH(wzaes->encryption_mode);

    /* Derive the encryption and authentication keys and the password verifier */
    vv_mz_crypt_pbkdf2((uint8_t *)password, password_length, salt_value, salt_length,
        VV_MZ_AES_KEYING_ITERATIONS, kbuf, 2 * key_length + VV_MZ_AES_PW_VERIFY_SIZE);

    /* Initialize the encryption nonce and buffer pos */
    wzaes->crypt_pos = VV_MZ_AES_BLOCK_SIZE;
    memset(wzaes->nonce, 0, sizeof(wzaes->nonce));

    /* Initialize for encryption using key 1 */
    vv_mz_crypt_aes_reset(wzaes->aes);
    vv_mz_crypt_aes_set_mode(wzaes->aes, wzaes->encryption_mode);
    vv_mz_crypt_aes_set_encrypt_key(wzaes->aes, kbuf, key_length);

    /* Initialize for authentication using key 2 */
    vv_mz_crypt_hmac_reset(wzaes->hmac);
    vv_mz_crypt_hmac_set_algorithm(wzaes->hmac, VV_MZ_HASH_SHA1);
    vv_mz_crypt_hmac_init(wzaes->hmac, kbuf + key_length, key_length);

    memcpy(verify, kbuf + (2 * key_length), VV_MZ_AES_PW_VERIFY_SIZE);

    if (mode & VV_MZ_OPEN_MODE_WRITE)
    {
        if (vv_mz_stream_write(wzaes->stream.base, salt_value, salt_length) != salt_length)
            return VV_MZ_WRITE_ERROR;

        wzaes->total_out += salt_length;

        if (vv_mz_stream_write(wzaes->stream.base, verify, VV_MZ_AES_PW_VERIFY_SIZE) != VV_MZ_AES_PW_VERIFY_SIZE)
            return VV_MZ_WRITE_ERROR;

        wzaes->total_out += VV_MZ_AES_PW_VERIFY_SIZE;
    }
    else if (mode & VV_MZ_OPEN_MODE_READ)
    {
        wzaes->total_in += salt_length;

        if (vv_mz_stream_read(wzaes->stream.base, verify_expected, VV_MZ_AES_PW_VERIFY_SIZE) != VV_MZ_AES_PW_VERIFY_SIZE)
            return VV_MZ_READ_ERROR;

        wzaes->total_in += VV_MZ_AES_PW_VERIFY_SIZE;

        if (memcmp(verify_expected, verify, VV_MZ_AES_PW_VERIFY_SIZE) != 0)
            return VV_MZ_PASSWORD_ERROR;
    }

    wzaes->mode = mode;
    wzaes->initialized = 1;

    return VV_MZ_OK;
}

int32_t vv_mz_stream_wzaes_is_open(void *stream)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    if (wzaes->initialized == 0)
        return VV_MZ_OPEN_ERROR;
    return VV_MZ_OK;
}

static int32_t vv_mz_stream_wzaes_ctr_encrypt(void *stream, uint8_t *buf, int32_t size)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    uint32_t pos = wzaes->crypt_pos;
    uint32_t i = 0;
    int32_t err = VV_MZ_OK;

    while (i < (uint32_t)size)
    {
        if (pos == VV_MZ_AES_BLOCK_SIZE)
        {
            uint32_t j = 0;

            /* Increment encryption nonce */
            while (j < 8 && !++wzaes->nonce[j])
                j += 1;

            /* Encrypt the nonce to form next xor buffer */
            memcpy(wzaes->crypt_block, wzaes->nonce, VV_MZ_AES_BLOCK_SIZE);
            vv_mz_crypt_aes_encrypt(wzaes->aes, wzaes->crypt_block, sizeof(wzaes->crypt_block));
            pos = 0;
        }

        buf[i++] ^= wzaes->crypt_block[pos++];
    }

    wzaes->crypt_pos = pos;
    return err;
}

int32_t vv_mz_stream_wzaes_read(void *stream, void *buf, int32_t size)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    int64_t max_total_in = 0;
    int32_t bytes_to_read = size;
    int32_t read = 0;

    max_total_in = wzaes->max_total_in - VV_MZ_AES_FOOTER_SIZE;
    if ((int64_t)bytes_to_read > (max_total_in - wzaes->total_in))
        bytes_to_read = (int32_t)(max_total_in - wzaes->total_in);

    read = vv_mz_stream_read(wzaes->stream.base, buf, bytes_to_read);

    if (read > 0)
    {
        vv_mz_crypt_hmac_update(wzaes->hmac, (uint8_t *)buf, read);
        vv_mz_stream_wzaes_ctr_encrypt(stream, (uint8_t *)buf, read);

        wzaes->total_in += read;
    }

    return read;
}

int32_t vv_mz_stream_wzaes_write(void *stream, const void *buf, int32_t size)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    const uint8_t *buf_ptr = (const uint8_t *)buf;
    int32_t bytes_to_write = sizeof(wzaes->buffer);
    int32_t total_written = 0;
    int32_t written = 0;

    if (size < 0)
        return VV_MZ_PARAM_ERROR;

    do
    {
        if (bytes_to_write > (size - total_written))
            bytes_to_write = (size - total_written);

        memcpy(wzaes->buffer, buf_ptr, bytes_to_write);
        buf_ptr += bytes_to_write;

        vv_mz_stream_wzaes_ctr_encrypt(stream, (uint8_t *)wzaes->buffer, bytes_to_write);
        vv_mz_crypt_hmac_update(wzaes->hmac, wzaes->buffer, bytes_to_write);

        written = vv_mz_stream_write(wzaes->stream.base, wzaes->buffer, bytes_to_write);
        if (written < 0)
            return written;

        total_written += written;
    }
    while (total_written < size && written > 0);

    wzaes->total_out += total_written;
    return total_written;
}

int64_t vv_mz_stream_wzaes_tell(void *stream)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    return vv_mz_stream_tell(wzaes->stream.base);
}

int32_t vv_mz_stream_wzaes_seek(void *stream, int64_t offset, int32_t origin)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    return vv_mz_stream_seek(wzaes->stream.base, offset, origin);
}

int32_t vv_mz_stream_wzaes_close(void *stream)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    uint8_t expected_hash[VV_MZ_AES_AUTHCODE_SIZE];
    uint8_t computed_hash[VV_MZ_HASH_SHA1_SIZE];

    vv_mz_crypt_hmac_end(wzaes->hmac, computed_hash, sizeof(computed_hash));

    if (wzaes->mode & VV_MZ_OPEN_MODE_WRITE)
    {
        if (vv_mz_stream_write(wzaes->stream.base, computed_hash, VV_MZ_AES_AUTHCODE_SIZE) != VV_MZ_AES_AUTHCODE_SIZE)
            return VV_MZ_WRITE_ERROR;

        wzaes->total_out += VV_MZ_AES_AUTHCODE_SIZE;
    }
    else if (wzaes->mode & VV_MZ_OPEN_MODE_READ)
    {
        if (vv_mz_stream_read(wzaes->stream.base, expected_hash, VV_MZ_AES_AUTHCODE_SIZE) != VV_MZ_AES_AUTHCODE_SIZE)
            return VV_MZ_READ_ERROR;

        wzaes->total_in += VV_MZ_AES_AUTHCODE_SIZE;

        /* If entire entry was not read this will fail */
        if (memcmp(computed_hash, expected_hash, VV_MZ_AES_AUTHCODE_SIZE) != 0)
            return VV_MZ_CRC_ERROR;
    }

    wzaes->initialized = 0;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_wzaes_error(void *stream)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    return wzaes->error;
}

void vv_mz_stream_wzaes_set_password(void *stream, const char *password)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    wzaes->password = password;
}

void vv_mz_stream_wzaes_set_encryption_mode(void *stream, int16_t encryption_mode)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    wzaes->encryption_mode = encryption_mode;
}

int32_t vv_mz_stream_wzaes_get_prop_int64(void *stream, int32_t prop, int64_t *value)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN:
        *value = wzaes->total_in;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_OUT:
        *value = wzaes->total_out;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        *value = wzaes->max_total_in;
        break;
    case VV_MZ_STREAM_PROP_HEADER_SIZE:
        *value = VV_MZ_AES_SALT_LENGTH((int64_t)wzaes->encryption_mode) + VV_MZ_AES_PW_VERIFY_SIZE;
        break;
    case VV_MZ_STREAM_PROP_FOOTER_SIZE:
        *value = VV_MZ_AES_AUTHCODE_SIZE;
        break;
    default:
        return VV_MZ_EXIST_ERROR;
    }
    return VV_MZ_OK;
}

int32_t vv_mz_stream_wzaes_set_prop_int64(void *stream, int32_t prop, int64_t value)
{
    vv_mz_stream_wzaes *wzaes = (vv_mz_stream_wzaes *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        wzaes->max_total_in = value;
        break;
    default:
        return VV_MZ_EXIST_ERROR;
    }
    return VV_MZ_OK;
}

void *vv_mz_stream_wzaes_create(void **stream)
{
    vv_mz_stream_wzaes *wzaes = NULL;

    wzaes = (vv_mz_stream_wzaes *)VV_MZ_ALLOC(sizeof(vv_mz_stream_wzaes));
    if (wzaes != NULL)
    {
        memset(wzaes, 0, sizeof(vv_mz_stream_wzaes));
        wzaes->stream.vtbl = &vv_mz_stream_wzaes_vtbl;
        wzaes->encryption_mode = VV_MZ_AES_ENCRYPTION_MODE_256;

        vv_mz_crypt_hmac_create(&wzaes->hmac);
        vv_mz_crypt_aes_create(&wzaes->aes);
    }
    if (stream != NULL)
        *stream = wzaes;

    return wzaes;
}

void vv_mz_stream_wzaes_delete(void **stream)
{
    vv_mz_stream_wzaes *wzaes = NULL;
    if (stream == NULL)
        return;
    wzaes = (vv_mz_stream_wzaes *)*stream;
    if (wzaes != NULL)
    {
        vv_mz_crypt_aes_delete(&wzaes->aes);
        vv_mz_crypt_hmac_delete(&wzaes->hmac);
        VV_MZ_FREE(wzaes);
    }
    *stream = NULL;
}

void *vv_mz_stream_wzaes_get_interface(void)
{
    return (void *)&vv_mz_stream_wzaes_vtbl;
}
