/* vv_mz_strm_zlib.c -- Stream for zlib inflate/deflate
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
      https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include "vv_mz.h"
#include "vv_mz_strm.h"
#include "vv_mz_strm_zlib.h"

#include "zlib.h"
#if defined(ZLIBNG_VERNUM) && !defined(ZLIB_COMPAT)
#  include "zlib-ng.h"
#endif

/***************************************************************************/

#if defined(ZLIBNG_VERNUM) && !defined(ZLIB_COMPAT)
#  define ZLIB_PREFIX(x) zng_ ## x
   typedef zng_stream zlib_stream;
#else
#  define ZLIB_PREFIX(x) x
   typedef z_stream zlib_stream;
#endif

#if !defined(DEF_MEM_LEVEL)
#  if MAX_MEM_LEVEL >= 8
#    define DEF_MEM_LEVEL 8
#  else
#    define DEF_MEM_LEVEL  MAX_MEM_LEVEL
#  endif
#endif

/***************************************************************************/

static vv_mz_stream_vtbl vv_mz_stream_zlib_vtbl = {
    vv_mz_stream_zlib_open,
    vv_mz_stream_zlib_is_open,
    vv_mz_stream_zlib_read,
    vv_mz_stream_zlib_write,
    vv_mz_stream_zlib_tell,
    vv_mz_stream_zlib_seek,
    vv_mz_stream_zlib_close,
    vv_mz_stream_zlib_error,
    vv_mz_stream_zlib_create,
    vv_mz_stream_zlib_delete,
    vv_mz_stream_zlib_get_prop_int64,
    vv_mz_stream_zlib_set_prop_int64
};

/***************************************************************************/

typedef struct vv_mz_stream_zlib_s {
    vv_mz_stream   stream;
    zlib_stream zstream;
    uint8_t     buffer[INT16_MAX];
    int32_t     buffer_len;
    int64_t     total_in;
    int64_t     total_out;
    int64_t     max_total_in;
    int8_t      initialized;
    int16_t     level;
    int32_t     window_bits;
    int32_t     mode;
    int32_t     error;
} vv_mz_stream_zlib;

/***************************************************************************/

int32_t vv_mz_stream_zlib_open(void *stream, const char *path, int32_t mode)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;

    VV_MZ_UNUSED(path);

    zlib->zstream.data_type = Z_BINARY;
    zlib->zstream.zalloc = Z_NULL;
    zlib->zstream.zfree = Z_NULL;
    zlib->zstream.opaque = Z_NULL;
    zlib->zstream.total_in = 0;
    zlib->zstream.total_out = 0;

    zlib->total_in = 0;
    zlib->total_out = 0;

    if (mode & VV_MZ_OPEN_MODE_WRITE)
    {
#ifdef VV_MZ_ZIP_NO_COMPRESSION
        return VV_MZ_SUPPORT_ERROR;
#else
        zlib->zstream.next_out = zlib->buffer;
        zlib->zstream.avail_out = sizeof(zlib->buffer);

        zlib->error = ZLIB_PREFIX(deflateInit2)(&zlib->zstream, (int8_t)zlib->level, Z_DEFLATED,
            zlib->window_bits, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY);
#endif
    }
    else if (mode & VV_MZ_OPEN_MODE_READ)
    {
#ifdef VV_MZ_ZIP_NO_DECOMPRESSION
        return VV_MZ_SUPPORT_ERROR;
#else
        zlib->zstream.next_in = zlib->buffer;
        zlib->zstream.avail_in = 0;

        zlib->error = ZLIB_PREFIX(inflateInit2)(&zlib->zstream, zlib->window_bits);
#endif
    }

    if (zlib->error != Z_OK)
        return VV_MZ_OPEN_ERROR;

    zlib->initialized = 1;
    zlib->mode = mode;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_zlib_is_open(void *stream)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    if (zlib->initialized != 1)
        return VV_MZ_OPEN_ERROR;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_zlib_read(void *stream, void *buf, int32_t size)
{
#ifdef VV_MZ_ZIP_NO_DECOMPRESSION
    VV_MZ_UNUSED(stream);
    VV_MZ_UNUSED(buf);
    VV_MZ_UNUSED(size);
    return VV_MZ_SUPPORT_ERROR;
#else
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    uint64_t total_in_before = 0;
    uint64_t total_in_after = 0;
    uint64_t total_out_before = 0;
    uint64_t total_out_after = 0;
    uint32_t total_in = 0;
    uint32_t total_out = 0;
    uint32_t in_bytes = 0;
    uint32_t out_bytes = 0;
    int32_t bytes_to_read = sizeof(zlib->buffer);
    int32_t read = 0;
    int32_t err = Z_OK;


    zlib->zstream.next_out = (Bytef*)buf;
    zlib->zstream.avail_out = (uInt)size;

    do
    {
        if (zlib->zstream.avail_in == 0)
        {
            if (zlib->max_total_in > 0)
            {
                if ((int64_t)bytes_to_read > (zlib->max_total_in - zlib->total_in))
                    bytes_to_read = (int32_t)(zlib->max_total_in - zlib->total_in);
            }

            read = vv_mz_stream_read(zlib->stream.base, zlib->buffer, bytes_to_read);

            if (read < 0)
                return read;

            zlib->zstream.next_in = zlib->buffer;
            zlib->zstream.avail_in = read;
        }

        total_in_before = zlib->zstream.avail_in;
        total_out_before = zlib->zstream.total_out;

        err = ZLIB_PREFIX(inflate)(&zlib->zstream, Z_SYNC_FLUSH);
        if ((err >= Z_OK) && (zlib->zstream.msg != NULL))
        {
            zlib->error = Z_DATA_ERROR;
            break;
        }

        total_in_after = zlib->zstream.avail_in;
        total_out_after = zlib->zstream.total_out;

        in_bytes = (uint32_t)(total_in_before - total_in_after);
        out_bytes = (uint32_t)(total_out_after - total_out_before);

        total_in += in_bytes;
        total_out += out_bytes;

        zlib->total_in += in_bytes;
        zlib->total_out += out_bytes;

        if (err == Z_STREAM_END)
            break;
        if (err != Z_OK)
        {
            zlib->error = err;
            break;
        }
    }
    while (zlib->zstream.avail_out > 0);

    if (zlib->error != 0)
    {
        /* Zlib errors are compatible with MZ */
        return zlib->error;
    }

    return total_out;
#endif
}

#ifndef VV_MZ_ZIP_NO_COMPRESSION
static int32_t vv_mz_stream_zlib_flush(void *stream)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    if (vv_mz_stream_write(zlib->stream.base, zlib->buffer, zlib->buffer_len) != zlib->buffer_len)
        return VV_MZ_WRITE_ERROR;
    return VV_MZ_OK;
}

static int32_t vv_mz_stream_zlib_deflate(void *stream, int flush)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    uint64_t total_out_before = 0;
    uint64_t total_out_after = 0;
    int32_t out_bytes = 0;
    int32_t err = Z_OK;


    do
    {
        if (zlib->zstream.avail_out == 0)
        {
            err = vv_mz_stream_zlib_flush(zlib);
            if (err != VV_MZ_OK)
                return err;

            zlib->zstream.avail_out = sizeof(zlib->buffer);
            zlib->zstream.next_out = zlib->buffer;

            zlib->buffer_len = 0;
        }

        total_out_before = zlib->zstream.total_out;
        err = ZLIB_PREFIX(deflate)(&zlib->zstream, flush);
        total_out_after = zlib->zstream.total_out;

        out_bytes = (uint32_t)(total_out_after - total_out_before);

        zlib->buffer_len += out_bytes;
        zlib->total_out += out_bytes;

        if (err == Z_STREAM_END)
            break;
        if (err != Z_OK)
        {
            zlib->error = err;
            return VV_MZ_DATA_ERROR;
        }
    }
    while ((zlib->zstream.avail_in > 0) || (flush == Z_FINISH && err == Z_OK));

    return VV_MZ_OK;
}
#endif

int32_t vv_mz_stream_zlib_write(void *stream, const void *buf, int32_t size)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    int32_t err = size;

#ifdef VV_MZ_ZIP_NO_COMPRESSION
    VV_MZ_UNUSED(zlib);
    VV_MZ_UNUSED(buf);
    err = VV_MZ_SUPPORT_ERROR;
#else
    zlib->zstream.next_in = (Bytef*)(intptr_t)buf;
    zlib->zstream.avail_in = (uInt)size;

    vv_mz_stream_zlib_deflate(stream, Z_NO_FLUSH);

    zlib->total_in += size;
#endif
    return err;
}

int64_t vv_mz_stream_zlib_tell(void *stream)
{
    VV_MZ_UNUSED(stream);

    return VV_MZ_TELL_ERROR;
}

int32_t vv_mz_stream_zlib_seek(void *stream, int64_t offset, int32_t origin)
{
    VV_MZ_UNUSED(stream);
    VV_MZ_UNUSED(offset);
    VV_MZ_UNUSED(origin);

    return VV_MZ_SEEK_ERROR;
}

int32_t vv_mz_stream_zlib_close(void *stream)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;


    if (zlib->mode & VV_MZ_OPEN_MODE_WRITE)
    {
#ifdef VV_MZ_ZIP_NO_COMPRESSION
        return VV_MZ_SUPPORT_ERROR;
#else
        vv_mz_stream_zlib_deflate(stream, Z_FINISH);
        vv_mz_stream_zlib_flush(stream);

        ZLIB_PREFIX(deflateEnd)(&zlib->zstream);
#endif
    }
    else if (zlib->mode & VV_MZ_OPEN_MODE_READ)
    {
#ifdef VV_MZ_ZIP_NO_DECOMPRESSION
        return VV_MZ_SUPPORT_ERROR;
#else
        ZLIB_PREFIX(inflateEnd)(&zlib->zstream);
#endif
    }

    zlib->initialized = 0;

    if (zlib->error != Z_OK)
        return VV_MZ_CLOSE_ERROR;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_zlib_error(void *stream)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    return zlib->error;
}

int32_t vv_mz_stream_zlib_get_prop_int64(void *stream, int32_t prop, int64_t *value)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN:
        *value = zlib->total_in;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        *value = zlib->max_total_in;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_OUT:
        *value = zlib->total_out;
        break;
    case VV_MZ_STREAM_PROP_HEADER_SIZE:
        *value = 0;
        break;
    case VV_MZ_STREAM_PROP_COMPRESS_WINDOW:
        *value = zlib->window_bits;
         break;
    default:
        return VV_MZ_EXIST_ERROR;
    }
    return VV_MZ_OK;
}

int32_t vv_mz_stream_zlib_set_prop_int64(void *stream, int32_t prop, int64_t value)
{
    vv_mz_stream_zlib *zlib = (vv_mz_stream_zlib *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_COMPRESS_LEVEL:
        zlib->level = (int16_t)value;
        break;
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        zlib->max_total_in = value;
        break;
    case VV_MZ_STREAM_PROP_COMPRESS_WINDOW:
        zlib->window_bits = (int32_t)value;
        break;
    default:
        return VV_MZ_EXIST_ERROR;
    }
    return VV_MZ_OK;
}

void *vv_mz_stream_zlib_create(void **stream)
{
    vv_mz_stream_zlib *zlib = NULL;

    zlib = (vv_mz_stream_zlib *)VV_MZ_ALLOC(sizeof(vv_mz_stream_zlib));
    if (zlib != NULL)
    {
        memset(zlib, 0, sizeof(vv_mz_stream_zlib));
        zlib->stream.vtbl = &vv_mz_stream_zlib_vtbl;
        zlib->level = Z_DEFAULT_COMPRESSION;
        zlib->window_bits = -MAX_WBITS;
    }
    if (stream != NULL)
        *stream = zlib;

    return zlib;
}

void vv_mz_stream_zlib_delete(void **stream)
{
    vv_mz_stream_zlib *zlib = NULL;
    if (stream == NULL)
        return;
    zlib = (vv_mz_stream_zlib *)*stream;
    if (zlib != NULL)
        VV_MZ_FREE(zlib);
    *stream = NULL;
}

void *vv_mz_stream_zlib_get_interface(void)
{
    return (void *)&vv_mz_stream_zlib_vtbl;
}
