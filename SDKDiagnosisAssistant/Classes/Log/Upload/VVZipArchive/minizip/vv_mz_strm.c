/* vv_mz_strm.c -- Stream interface
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/

#include "vv_mz.h"
#include "vv_mz_strm.h"

/***************************************************************************/

#define VV_MZ_STREAM_FIND_SIZE (1024)

/***************************************************************************/

int32_t vv_mz_stream_open(void *stream, const char *path, int32_t mode)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->open == NULL)
        return VV_MZ_STREAM_ERROR;
    return strm->vtbl->open(strm, path, mode);
}

int32_t vv_mz_stream_is_open(void *stream)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->is_open == NULL)
        return VV_MZ_STREAM_ERROR;
    return strm->vtbl->is_open(strm);
}

int32_t vv_mz_stream_read(void *stream, void *buf, int32_t size)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->read == NULL)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_stream_is_open(stream) != VV_MZ_OK)
        return VV_MZ_STREAM_ERROR;
    return strm->vtbl->read(strm, buf, size);
}

static int32_t vv_mz_stream_read_value(void *stream, uint64_t *value, int32_t len)
{
    uint8_t buf[8];
    int32_t n = 0;
    int32_t i = 0;

    *value = 0;
    if (vv_mz_stream_read(stream, buf, len) == len)
    {
        for (n = 0; n < len; n += 1, i += 8)
            *value += ((uint64_t)buf[n]) << i;
    }
    else if (vv_mz_stream_error(stream))
        return VV_MZ_STREAM_ERROR;
    else
        return VV_MZ_END_OF_STREAM;

    return VV_MZ_OK;
}

int32_t vv_mz_stream_read_uint8(void *stream, uint8_t *value)
{
    int32_t err = VV_MZ_OK;
    uint64_t value64 = 0;

    *value = 0;
    err = vv_mz_stream_read_value(stream, &value64, sizeof(uint8_t));
    if (err == VV_MZ_OK)
        *value = (uint8_t)value64;
    return err;
}

int32_t vv_mz_stream_read_uint16(void *stream, uint16_t *value)
{
    int32_t err = VV_MZ_OK;
    uint64_t value64 = 0;

    *value = 0;
    err = vv_mz_stream_read_value(stream, &value64, sizeof(uint16_t));
    if (err == VV_MZ_OK)
        *value = (uint16_t)value64;
    return err;
}

int32_t vv_mz_stream_read_uint32(void *stream, uint32_t *value)
{
    int32_t err = VV_MZ_OK;
    uint64_t value64 = 0;

    *value = 0;
    err = vv_mz_stream_read_value(stream, &value64, sizeof(uint32_t));
    if (err == VV_MZ_OK)
        *value = (uint32_t)value64;
    return err;
}

int32_t vv_mz_stream_read_int64(void *stream, int64_t *value)
{
    return vv_mz_stream_read_value(stream, (uint64_t *)value, sizeof(uint64_t));
}

int32_t vv_mz_stream_read_uint64(void *stream, uint64_t *value)
{
    return vv_mz_stream_read_value(stream, value, sizeof(uint64_t));
}

int32_t vv_mz_stream_write(void *stream, const void *buf, int32_t size)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (size == 0)
        return size;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->write == NULL)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_stream_is_open(stream) != VV_MZ_OK)
        return VV_MZ_STREAM_ERROR;
    return strm->vtbl->write(strm, buf, size);
}

static int32_t vv_mz_stream_write_value(void *stream, uint64_t value, int32_t len)
{
    uint8_t buf[8];
    int32_t n = 0;

    for (n = 0; n < len; n += 1)
    {
        buf[n] = (uint8_t)(value & 0xff);
        value >>= 8;
    }

    if (value != 0)
    {
        /* Data overflow - hack for ZIP64 (X Roche) */
        for (n = 0; n < len; n += 1)
            buf[n] = 0xff;
    }

    if (vv_mz_stream_write(stream, buf, len) != len)
        return VV_MZ_STREAM_ERROR;

    return VV_MZ_OK;
}

int32_t vv_mz_stream_write_uint8(void *stream, uint8_t value)
{
    return vv_mz_stream_write_value(stream, value, sizeof(uint8_t));
}

int32_t vv_mz_stream_write_uint16(void *stream, uint16_t value)
{
    return vv_mz_stream_write_value(stream, value, sizeof(uint16_t));
}

int32_t vv_mz_stream_write_uint32(void *stream, uint32_t value)
{
    return vv_mz_stream_write_value(stream, value, sizeof(uint32_t));
}

int32_t vv_mz_stream_write_int64(void *stream, int64_t value)
{
    return vv_mz_stream_write_value(stream, (uint64_t)value, sizeof(uint64_t));
}

int32_t vv_mz_stream_write_uint64(void *stream, uint64_t value)
{
    return vv_mz_stream_write_value(stream, value, sizeof(uint64_t));
}

int32_t vv_mz_stream_copy(void *target, void *source, int32_t len)
{
    return vv_mz_stream_copy_stream(target, NULL, source, NULL, len);
}

int32_t vv_mz_stream_copy_to_end(void *target, void *source)
{
    return vv_mz_stream_copy_stream_to_end(target, NULL, source, NULL);
}

int32_t vv_mz_stream_copy_stream(void *target, vv_mz_stream_write_cb write_cb, void *source,
    vv_mz_stream_read_cb read_cb, int32_t len)
{
    uint8_t buf[16384];
    int32_t bytes_to_copy = 0;
    int32_t read = 0;
    int32_t written = 0;

    if (write_cb == NULL)
        write_cb = vv_mz_stream_write;
    if (read_cb == NULL)
        read_cb = vv_mz_stream_read;

    while (len > 0)
    {
        bytes_to_copy = len;
        if (bytes_to_copy > (int32_t)sizeof(buf))
            bytes_to_copy = sizeof(buf);
        read = read_cb(source, buf, bytes_to_copy);
        if (read <= 0)
            return VV_MZ_STREAM_ERROR;
        written = write_cb(target, buf, read);
        if (written != read)
            return VV_MZ_STREAM_ERROR;
        len -= read;
    }

    return VV_MZ_OK;
}

int32_t vv_mz_stream_copy_stream_to_end(void *target, vv_mz_stream_write_cb write_cb, void *source,
    vv_mz_stream_read_cb read_cb)
{
    uint8_t buf[16384];
    int32_t read = 0;
    int32_t written = 0;

    if (write_cb == NULL)
        write_cb = vv_mz_stream_write;
    if (read_cb == NULL)
        read_cb = vv_mz_stream_read;

    read = read_cb(source, buf, sizeof(buf));
    while (read > 0)
    {
        written = write_cb(target, buf, read);
        if (written != read)
            return VV_MZ_STREAM_ERROR;
        read = read_cb(source, buf, sizeof(buf));
    }

    if (read < 0)
        return VV_MZ_STREAM_ERROR;

    return VV_MZ_OK;
}

int64_t vv_mz_stream_tell(void *stream)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->tell == NULL)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_stream_is_open(stream) != VV_MZ_OK)
        return VV_MZ_STREAM_ERROR;
    return strm->vtbl->tell(strm);
}

int32_t vv_mz_stream_seek(void *stream, int64_t offset, int32_t origin)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->seek == NULL)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_stream_is_open(stream) != VV_MZ_OK)
        return VV_MZ_STREAM_ERROR;
    if (origin == VV_MZ_SEEK_SET && offset < 0)
        return VV_MZ_SEEK_ERROR;
    return strm->vtbl->seek(strm, offset, origin);
}

int32_t vv_mz_stream_find(void *stream, const void *find, int32_t find_size, int64_t max_seek, int64_t *position)
{
    uint8_t buf[VV_MZ_STREAM_FIND_SIZE];
    int32_t buf_pos = 0;
    int32_t read_size = sizeof(buf);
    int32_t read = 0;
    int64_t read_pos = 0;
    int64_t start_pos = 0;
    int64_t disk_pos = 0;
    int32_t i = 0;
    uint8_t first = 1;
    int32_t err = VV_MZ_OK;

    if (stream == NULL || find == NULL || position == NULL)
        return VV_MZ_PARAM_ERROR;
    if (find_size < 0 || find_size >= (int32_t)sizeof(buf))
        return VV_MZ_PARAM_ERROR;

    *position = -1;

    start_pos = vv_mz_stream_tell(stream);

    while (read_pos < max_seek)
    {
        if (read_size > (int32_t)(max_seek - read_pos - buf_pos) && (max_seek - read_pos - buf_pos) < (int64_t)sizeof(buf))
            read_size = (int32_t)(max_seek - read_pos - buf_pos);

        read = vv_mz_stream_read(stream, buf + buf_pos, read_size);
        if ((read <= 0) || (read + buf_pos < find_size))
            break;

        for (i = 0; i <= read + buf_pos - find_size; i += 1)
        {
            if (memcmp(&buf[i], find, find_size) != 0)
                continue;

            disk_pos = vv_mz_stream_tell(stream);

            /* Seek to position on disk where the data was found */
            err = vv_mz_stream_seek(stream, disk_pos - ((int64_t)read + buf_pos - i), VV_MZ_SEEK_SET);
            if (err != VV_MZ_OK)
                return VV_MZ_EXIST_ERROR;

            *position = start_pos + read_pos + i;
            return VV_MZ_OK;
        }

        if (first)
        {
            read -= find_size;
            read_size -= find_size;
            buf_pos = find_size;
            first = 0;
        }

        memmove(buf, buf + read, find_size);
        read_pos += read;
    }

    return VV_MZ_EXIST_ERROR;
}

int32_t vv_mz_stream_find_reverse(void *stream, const void *find, int32_t find_size, int64_t max_seek, int64_t *position)
{
    uint8_t buf[VV_MZ_STREAM_FIND_SIZE];
    int32_t buf_pos = 0;
    int32_t read_size = VV_MZ_STREAM_FIND_SIZE;
    int64_t read_pos = 0;
    int32_t read = 0;
    int64_t start_pos = 0;
    int64_t disk_pos = 0;
    uint8_t first = 1;
    int32_t i = 0;
    int32_t err = VV_MZ_OK;

    if (stream == NULL || find == NULL || position == NULL)
        return VV_MZ_PARAM_ERROR;
    if (find_size < 0 || find_size >= (int32_t)sizeof(buf))
        return VV_MZ_PARAM_ERROR;

    *position = -1;

    start_pos = vv_mz_stream_tell(stream);

    while (read_pos < max_seek)
    {
        if (read_size > (int32_t)(max_seek - read_pos) && (max_seek - read_pos) < (int64_t)sizeof(buf))
            read_size = (int32_t)(max_seek - read_pos);

        if (vv_mz_stream_seek(stream, start_pos - (read_pos + read_size), VV_MZ_SEEK_SET) != VV_MZ_OK)
            break;
        read = vv_mz_stream_read(stream, buf, read_size);
        if ((read <= 0) || (read + buf_pos < find_size))
            break;
        if (read + buf_pos < VV_MZ_STREAM_FIND_SIZE)
            memmove(buf + VV_MZ_STREAM_FIND_SIZE - (read + buf_pos), buf, read);

        for (i = find_size; i <= (read + buf_pos); i += 1)
        {
            if (memcmp(&buf[VV_MZ_STREAM_FIND_SIZE - i], find, find_size) != 0)
                continue;

            disk_pos = vv_mz_stream_tell(stream);

            /* Seek to position on disk where the data was found */
            err = vv_mz_stream_seek(stream, disk_pos + buf_pos - i, VV_MZ_SEEK_SET);
            if (err != VV_MZ_OK)
                return VV_MZ_EXIST_ERROR;

            *position = start_pos - (read_pos - buf_pos + i);
            return VV_MZ_OK;
        }

        if (first)
        {
            read -= find_size;
            read_size -= find_size;
            buf_pos = find_size;
            first = 0;
        }

        if (read == 0)
            break;

        memmove(buf + read_size, buf, find_size);
        read_pos += read;
    }

    return VV_MZ_EXIST_ERROR;
}

int32_t vv_mz_stream_close(void *stream)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->close == NULL)
        return VV_MZ_PARAM_ERROR;
    if (vv_mz_stream_is_open(stream) != VV_MZ_OK)
        return VV_MZ_STREAM_ERROR;
    return strm->vtbl->close(strm);
}

int32_t vv_mz_stream_error(void *stream)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->error == NULL)
        return VV_MZ_PARAM_ERROR;
    return strm->vtbl->error(strm);
}

int32_t vv_mz_stream_set_base(void *stream, void *base)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    strm->base = (vv_mz_stream *)base;
    return VV_MZ_OK;
}

void* vv_mz_stream_get_interface(void *stream)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL)
        return NULL;
    return (void *)strm->vtbl;
}

int32_t vv_mz_stream_get_prop_int64(void *stream, int32_t prop, int64_t *value)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->get_prop_int64 == NULL)
        return VV_MZ_PARAM_ERROR;
    return strm->vtbl->get_prop_int64(stream, prop, value);
}

int32_t vv_mz_stream_set_prop_int64(void *stream, int32_t prop, int64_t value)
{
    vv_mz_stream *strm = (vv_mz_stream *)stream;
    if (strm == NULL || strm->vtbl == NULL || strm->vtbl->set_prop_int64 == NULL)
        return VV_MZ_PARAM_ERROR;
    return strm->vtbl->set_prop_int64(stream, prop, value);
}

void *vv_mz_stream_create(void **stream, vv_mz_stream_vtbl *vtbl)
{
    if (stream == NULL)
        return NULL;
    if (vtbl == NULL || vtbl->create == NULL)
        return NULL;
    return vtbl->create(stream);
}

void vv_mz_stream_delete(void **stream)
{
    vv_mz_stream *strm = NULL;
    if (stream == NULL)
        return;
    strm = (vv_mz_stream *)*stream;
    if (strm != NULL && strm->vtbl != NULL && strm->vtbl->destroy != NULL)
        strm->vtbl->destroy(stream);
    *stream = NULL;
}

/***************************************************************************/

typedef struct vv_mz_stream_raw_s {
    vv_mz_stream   stream;
    int64_t     total_in;
    int64_t     total_out;
    int64_t     max_total_in;
} vv_mz_stream_raw;

/***************************************************************************/

int32_t vv_mz_stream_raw_open(void *stream, const char *path, int32_t mode)
{
    VV_MZ_UNUSED(stream);
    VV_MZ_UNUSED(path);
    VV_MZ_UNUSED(mode);

    return VV_MZ_OK;
}

int32_t vv_mz_stream_raw_is_open(void *stream)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    return vv_mz_stream_is_open(raw->stream.base);
}

int32_t vv_mz_stream_raw_read(void *stream, void *buf, int32_t size)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    int32_t bytes_to_read = size;
    int32_t read = 0;

    if (raw->max_total_in > 0)
    {
        if ((int64_t)bytes_to_read > (raw->max_total_in - raw->total_in))
            bytes_to_read = (int32_t)(raw->max_total_in - raw->total_in);
    }

    read = vv_mz_stream_read(raw->stream.base, buf, bytes_to_read);

    if (read > 0)
    {
        raw->total_in += read;
        raw->total_out += read;
    }

    return read;
}

int32_t vv_mz_stream_raw_write(void *stream, const void *buf, int32_t size)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    int32_t written = 0;

    written = vv_mz_stream_write(raw->stream.base, buf, size);

    if (written > 0)
    {
        raw->total_out += written;
        raw->total_in += written;
    }

    return written;
}

int64_t vv_mz_stream_raw_tell(void *stream)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    return vv_mz_stream_tell(raw->stream.base);
}

int32_t vv_mz_stream_raw_seek(void *stream, int64_t offset, int32_t origin)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    return vv_mz_stream_seek(raw->stream.base, offset, origin);
}

int32_t vv_mz_stream_raw_close(void *stream)
{
    VV_MZ_UNUSED(stream);
    return VV_MZ_OK;
}

int32_t vv_mz_stream_raw_error(void *stream)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    return vv_mz_stream_error(raw->stream.base);
}

int32_t vv_mz_stream_raw_get_prop_int64(void *stream, int32_t prop, int64_t *value)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN:
        *value = raw->total_in;
        return VV_MZ_OK;
    case VV_MZ_STREAM_PROP_TOTAL_OUT:
        *value = raw->total_out;
        return VV_MZ_OK;
    }
    return VV_MZ_EXIST_ERROR;
}

int32_t vv_mz_stream_raw_set_prop_int64(void *stream, int32_t prop, int64_t value)
{
    vv_mz_stream_raw *raw = (vv_mz_stream_raw *)stream;
    switch (prop)
    {
    case VV_MZ_STREAM_PROP_TOTAL_IN_MAX:
        raw->max_total_in = value;
        return VV_MZ_OK;
    }
    return VV_MZ_EXIST_ERROR;
}

/***************************************************************************/

static vv_mz_stream_vtbl vv_mz_stream_raw_vtbl = {
    vv_mz_stream_raw_open,
    vv_mz_stream_raw_is_open,
    vv_mz_stream_raw_read,
    vv_mz_stream_raw_write,
    vv_mz_stream_raw_tell,
    vv_mz_stream_raw_seek,
    vv_mz_stream_raw_close,
    vv_mz_stream_raw_error,
    vv_mz_stream_raw_create,
    vv_mz_stream_raw_delete,
    vv_mz_stream_raw_get_prop_int64,
    vv_mz_stream_raw_set_prop_int64
};

/***************************************************************************/

void *vv_mz_stream_raw_create(void **stream)
{
    vv_mz_stream_raw *raw = NULL;

    raw = (vv_mz_stream_raw *)VV_MZ_ALLOC(sizeof(vv_mz_stream_raw));
    if (raw != NULL)
    {
        memset(raw, 0, sizeof(vv_mz_stream_raw));
        raw->stream.vtbl = &vv_mz_stream_raw_vtbl;
    }
    if (stream != NULL)
        *stream = raw;

    return raw;
}

void vv_mz_stream_raw_delete(void **stream)
{
    vv_mz_stream_raw *raw = NULL;
    if (stream == NULL)
        return;
    raw = (vv_mz_stream_raw *)*stream;
    if (raw != NULL)
        VV_MZ_FREE(raw);
    *stream = NULL;
}
