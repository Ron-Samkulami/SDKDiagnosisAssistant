/* vv_mz_strm_pkcrypt.c -- Code for traditional PKWARE encryption
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
      https://github.com/nmoinvaz/minizip
   Copyright (C) 1998-2005 Gilles Vollant
      Modifications for Info-ZIP crypting
      https://www.winimage.com/zLibDll/minizip.html
   Copyright (C) 2003 Terry Thorsen

   This code is a modified version of crypting code in Info-ZIP distribution

   Copyright (C) 1990-2000 Info-ZIP.  All rights reserved.

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.

   This encryption code is a direct transcription of the algorithm from
   Roger Schlafly, described by Phil Katz in the file appnote.txt. This
   file (appnote.txt) is distributed with the PKZIP program (even in the
   version without encryption capabilities).
*/


#include "vv_mz.h"
#include "vv_mz_crypt.h"
#include "vv_mz_strm.h"
#include "vv_mz_strm_pkcrypt.h"

/***************************************************************************/

static vv_mz_stream_vtbl vv_mz_stream_pkcrypt_vtbl = {
    vv_mz_stream_pkcrypt_open,
    vv_mz_stream_pkcrypt_is_open,
    vv_mz_stream_pkcrypt_read,
    vv_mz_stream_pkcrypt_write,
    vv_mz_stream_pkcrypt_tell,
    vv_mz_stream_pkcrypt_seek,
    vv_mz_stream_pkcrypt_close,
    vv_mz_stream_pkcrypt_error,
    vv_mz_stream_pkcrypt_create,
    vv_mz_stream_pkcrypt_delete,
    vv_mz_stream_pkcrypt_get_prop_int64,
    vv_mz_stream_pkcrypt_set_prop_int64
};

/***************************************************************************/

typedef struct vv_mz_stream_pkcrypt_s {
    vv_mz_stream       stream;
    int32_t         error;
    int16_t         initialized;
    uint8_t         buffer[UINT16_MAX];
    int64_t         total_in;
    int64_t         max_total_in;
    int64_t         total_out;
    uint32_t        keys[3];          /* keys defining the pseudo-random sequence */
    uint8_t         verify1;
    uint8_t         verify2;
    const char      *password;
} vv_mz_stream_pkcrypt;

/***************************************************************************/

#define vv_mz_stream_pkcrypt_decode(strm, c)                                   \
    (vv_mz_stream_pkcrypt_update_keys(strm,                                    \
        c ^= vv_mz_stream_pkcrypt_decrypt_byte(strm)))

#define vv_mz_stream_pkcrypt_encode(strm, c, t)                                \
    (t = vv_mz_stream_pkcrypt_decrypt_byte(strm),                              \
        vv_mz_stream_pkcrypt_update_keys(strm, (uint8_t)c), (uint8_t)(t^(c)))

/***************************************************************************/

static uint8_t vv_mz_stream_pkcrypt_decrypt_byte(void *stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;

    unsigned temp; /* POTENTIAL BUG:  temp*(temp^1) may overflow in an */
                   /* unpredictable manner on 16-bit systems; not a problem */
                   /* with any known compiler so far, though. */

    temp = pkcrypt->keys[2] | 2;
    return (uint8_t)(((temp * (temp ^ 1)) >> 8) & 0xff);
}

static uint8_t vv_mz_stream_pkcrypt_update_keys(void *stream, uint8_t c)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    uint8_t buf = c;

    pkcrypt->keys[0] = (uint32_t)~vv_mz_crypt_crc32_update(~pkcrypt->keys[0], &buf, 1);

    pkcrypt->keys[1] += pkcrypt->keys[0] & 0xff;
    pkcrypt->keys[1] *= 134775813L;
    pkcrypt->keys[1] += 1;

    buf = (uint8_t)(pkcrypt->keys[1] >> 24);
    pkcrypt->keys[2] = (uint32_t)~vv_mz_crypt_crc32_update(~pkcrypt->keys[2], &buf, 1);

    return (uint8_t)c;
}

static void vv_mz_stream_pkcrypt_init_keys(void *stream, const char *password)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;

    pkcrypt->keys[0] = 305419896L;
    pkcrypt->keys[1] = 591751049L;
    pkcrypt->keys[2] = 878082192L;

    while (*password != 0)
    {
        vv_mz_stream_pkcrypt_update_keys(stream, (uint8_t)*password);
        password += 1;
    }
}

/***************************************************************************/

int32_t vv_mz_stream_pkcrypt_open(void *stream, const char *path, int32_t mode)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    uint16_t t = 0;
    int16_t i = 0;
    uint8_t verify1 = 0;
    uint8_t verify2 = 0;
    uint8_t header[VV_MZ_PKCRYPT_HEADER_SIZE];
    const char *password = path;

    pkcrypt->total_in = 0;
    pkcrypt->total_out = 0;
    pkcrypt->initialized = 0;

    if (vv_mz_stream_is_open(pkcrypt->stream.base) != VV_MZ_OK)
        return VV_MZ_OPEN_ERROR;

    if (password == NULL)
        password = pkcrypt->password;
    if (password == NULL)
        return VV_MZ_PARAM_ERROR;

    vv_mz_stream_pkcrypt_init_keys(stream, password);

    if (mode & VV_MZ_OPEN_MODE_WRITE)
    {
#ifdef VV_MZ_ZIP_NO_COMPRESSION
        VV_MZ_UNUSED(t);
        VV_MZ_UNUSED(i);

        return VV_MZ_SUPPORT_ERROR;
#else
        /* First generate RAND_HEAD_LEN - 2 random bytes. */
        vv_mz_crypt_rand(header, VV_MZ_PKCRYPT_HEADER_SIZE - 2);

        /* Encrypt random header (last two bytes is high word of crc) */
        for (i = 0; i < VV_MZ_PKCRYPT_HEADER_SIZE - 2; i++)
            header[i] = vv_mz_stream_pkcrypt_encode(stream, header[i], t);

        header[i++] = vv_mz_stream_pkcrypt_encode(stream, pkcrypt->verify1, t);
        header[i++] = vv_mz_stream_pkcrypt_encode(stream, pkcrypt->verify2, t);

        if (vv_mz_stream_write(pkcrypt->stream.base, header, sizeof(header)) != sizeof(header))
            return VV_MZ_WRITE_ERROR;

        pkcrypt->total_out += VV_MZ_PKCRYPT_HEADER_SIZE;
#endif
    }
    else if (mode & VV_MZ_OPEN_MODE_READ)
    {
#ifdef VV_MZ_ZIP_NO_DECOMPRESSION
        VV_MZ_UNUSED(t);
        VV_MZ_UNUSED(i);
        VV_MZ_UNUSED(verify1);
        VV_MZ_UNUSED(verify2);

        return VV_MZ_SUPPORT_ERROR;
#else
        if (vv_mz_stream_read(pkcrypt->stream.base, header, sizeof(header)) != sizeof(header))
            return VV_MZ_READ_ERROR;

        for (i = 0; i < VV_MZ_PKCRYPT_HEADER_SIZE - 2; i++)
            header[i] = vv_mz_stream_pkcrypt_decode(stream, header[i]);

        verify1 = vv_mz_stream_pkcrypt_decode(stream, header[i++]);
        verify2 = vv_mz_stream_pkcrypt_decode(stream, header[i++]);

        /* Older versions used 2 byte check, newer versions use 1 byte check. */
        VV_MZ_UNUSED(verify1);
        if ((verify2 != 0) && (verify2 != pkcrypt->verify2))
            return VV_MZ_PASSWORD_ERROR;

        pkcrypt->total_in += VV_MZ_PKCRYPT_HEADER_SIZE;
#endif
    }

    pkcrypt->initialized = 1;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_pkcrypt_is_open(void *stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    if (pkcrypt->initialized == 0)
        return VV_MZ_OPEN_ERROR;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_pkcrypt_read(void *stream, void *buf, int32_t size)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    uint8_t *buf_ptr = (uint8_t *)buf;
    int32_t bytes_to_read = size;
    int32_t read = 0;
    int32_t i = 0;


    if ((int64_t)bytes_to_read > (pkcrypt->max_total_in - pkcrypt->total_in))
        bytes_to_read = (int32_t)(pkcrypt->max_total_in - pkcrypt->total_in);

    read = vv_mz_stream_read(pkcrypt->stream.base, buf, bytes_to_read);

    for (i = 0; i < read; i++)
        buf_ptr[i] = vv_mz_stream_pkcrypt_decode(stream, buf_ptr[i]);

    if (read > 0)
        pkcrypt->total_in += read;

    return read;
}

int32_t vv_mz_stream_pkcrypt_write(void *stream, const void *buf, int32_t size)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    const uint8_t *buf_ptr = (const uint8_t *)buf;
    int32_t bytes_to_write = sizeof(pkcrypt->buffer);
    int32_t total_written = 0;
    int32_t written = 0;
    int32_t i = 0;
    uint16_t t = 0;

    if (size < 0)
        return VV_MZ_PARAM_ERROR;

    do
    {
        if (bytes_to_write > (size - total_written))
            bytes_to_write = (size - total_written);

        for (i = 0; i < bytes_to_write; i += 1)
        {
            pkcrypt->buffer[i] = vv_mz_stream_pkcrypt_encode(stream, *buf_ptr, t);
            buf_ptr += 1;
        }

        written = vv_mz_stream_write(pkcrypt->stream.base, pkcrypt->buffer, bytes_to_write);
        if (written < 0)
            return written;

        total_written += written;
    }
    while (total_written < size && written > 0);

    pkcrypt->total_out += total_written;
    return total_written;
}

int64_t vv_mz_stream_pkcrypt_tell(void *stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    return vv_mz_stream_tell(pkcrypt->stream.base);
}

int32_t vv_mz_stream_pkcrypt_seek(void *stream, int64_t offset, int32_t origin)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    return vv_mz_stream_seek(pkcrypt->stream.base, offset, origin);
}

int32_t vv_mz_stream_pkcrypt_close(void *stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    pkcrypt->initialized = 0;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_pkcrypt_error(void *stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    return pkcrypt->error;
}

void vv_mz_stream_pkcrypt_set_password(void *stream, const char *password)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    pkcrypt->password = password;
}

void vv_mz_stream_pkcrypt_set_verify(void *stream, uint8_t verify1, uint8_t verify2)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    pkcrypt->verify1 = verify1;
    pkcrypt->verify2 = verify2;
}

void vv_mz_stream_pkcrypt_get_verify(void *stream, uint8_t *verify1, uint8_t *verify2)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    *verify1 = pkcrypt->verify1;
    *verify2 = pkcrypt->verify2;
}

int32_t vv_mz_stream_pkcrypt_get_prop_int64(void *stream, int32_t prop, int64_t *value)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN:
        *value = pkcrypt->total_in;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_OUT:
        *value = pkcrypt->total_out;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        *value = pkcrypt->max_total_in;
        break;
    case VV_MZ_STREAM_PROP_HEADER_SIZE:
        *value = VV_MZ_PKCRYPT_HEADER_SIZE;
        break;
    case VV_MZ_STREAM_PROP_FOOTER_SIZE:
        *value = 0;
        break;
    default:
        return VV_MZ_EXIST_ERROR;
    }
    return VV_MZ_OK;
}

int32_t vv_mz_stream_pkcrypt_set_prop_int64(void *stream, int32_t prop, int64_t value)
{
    vv_mz_stream_pkcrypt *pkcrypt = (vv_mz_stream_pkcrypt *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        pkcrypt->max_total_in = value;
        break;
    default:
        return VV_MZ_EXIST_ERROR;
    }
    return VV_MZ_OK;
}

void *vv_mz_stream_pkcrypt_create(void **stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = NULL;

    pkcrypt = (vv_mz_stream_pkcrypt *)VV_MZ_ALLOC(sizeof(vv_mz_stream_pkcrypt));
    if (pkcrypt != NULL)
    {
        memset(pkcrypt, 0, sizeof(vv_mz_stream_pkcrypt));
        pkcrypt->stream.vtbl = &vv_mz_stream_pkcrypt_vtbl;
    }

    if (stream != NULL)
        *stream = pkcrypt;
    return pkcrypt;
}

void vv_mz_stream_pkcrypt_delete(void **stream)
{
    vv_mz_stream_pkcrypt *pkcrypt = NULL;
    if (stream == NULL)
        return;
    pkcrypt = (vv_mz_stream_pkcrypt *)*stream;
    if (pkcrypt != NULL)
        VV_MZ_FREE(pkcrypt);
    *stream = NULL;
}

void *vv_mz_stream_pkcrypt_get_interface(void)
{
    return (void *)&vv_mz_stream_pkcrypt_vtbl;
}
