/* vv_mz_strm_mem.c -- Stream for memory access
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   This interface is designed to access memory rather than files.
   We do use a region of memory to put data in to and take it out of.

   Based on Unzip ioapi.c version 0.22, May 19th, 2003

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip
   Copyright (C) 2003 Justin Fletcher
   Copyright (C) 1998-2003 Gilles Vollant
     https://www.winimage.com/zLibDll/minizip.html

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include "vv_mz.h"
#include "vv_mz_strm.h"
#include "vv_mz_strm_mem.h"

/***************************************************************************/

static vv_mz_stream_vtbl vv_mz_stream_mem_vtbl = {
    vv_mz_stream_mem_open,
    vv_mz_stream_mem_is_open,
    vv_mz_stream_mem_read,
    vv_mz_stream_mem_write,
    vv_mz_stream_mem_tell,
    vv_mz_stream_mem_seek,
    vv_mz_stream_mem_close,
    vv_mz_stream_mem_error,
    vv_mz_stream_mem_create,
    vv_mz_stream_mem_delete,
    NULL,
    NULL
};

/***************************************************************************/

typedef struct vv_mz_stream_mem_s {
    vv_mz_stream   stream;
    int32_t     mode;
    uint8_t     *buffer;    /* Memory buffer pointer */
    int32_t     size;       /* Size of the memory buffer */
    int32_t     limit;      /* Furthest we've written */
    int32_t     position;   /* Current position in the memory */
    int32_t     grow_size;  /* Size to grow when full */
} vv_mz_stream_mem;

/***************************************************************************/

static int32_t vv_mz_stream_mem_set_size(void *stream, int32_t size)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    int32_t new_size = size;
    uint8_t *new_buf = NULL;


    new_buf = (uint8_t *)VV_MZ_ALLOC((uint32_t)new_size);
    if (new_buf == NULL)
        return VV_MZ_BUF_ERROR;

    if (mem->buffer)
    {
        memcpy(new_buf, mem->buffer, mem->size);
        VV_MZ_FREE(mem->buffer);
    }

    mem->buffer = new_buf;
    mem->size = new_size;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_mem_open(void *stream, const char *path, int32_t mode)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    int32_t err = VV_MZ_OK;

    VV_MZ_UNUSED(path);

    mem->mode = mode;
    mem->limit = 0;
    mem->position = 0;

    if (mem->mode & VV_MZ_OPEN_MODE_CREATE)
        err = vv_mz_stream_mem_set_size(stream, mem->grow_size);
    else
        mem->limit = mem->size;

    return err;
}

int32_t vv_mz_stream_mem_is_open(void *stream)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    if (mem->buffer == NULL)
        return VV_MZ_OPEN_ERROR;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_mem_read(void *stream, void *buf, int32_t size)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;

    if (size > mem->size - mem->position)
        size = mem->size - mem->position;
    if (mem->position + size > mem->limit)
        size = mem->limit - mem->position;

    if (size <= 0)
        return 0;

    memcpy(buf, mem->buffer + mem->position, size);
    mem->position += size;

    return size;
}

int32_t vv_mz_stream_mem_write(void *stream, const void *buf, int32_t size)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    int32_t new_size = 0;
    int32_t err = VV_MZ_OK;

    if (size == 0)
        return size;

    if (size > mem->size - mem->position)
    {
        if (mem->mode & VV_MZ_OPEN_MODE_CREATE)
        {
            new_size = mem->size;
            if (size < mem->grow_size)
                new_size += mem->grow_size;
            else
                new_size += size;

            err = vv_mz_stream_mem_set_size(stream, new_size);
            if (err != VV_MZ_OK)
                return err;
        }
        else
        {
            size = mem->size - mem->position;
        }
    }

    memcpy(mem->buffer + mem->position, buf, size);

    mem->position += size;
    if (mem->position > mem->limit)
        mem->limit = mem->position;

    return size;
}

int64_t vv_mz_stream_mem_tell(void *stream)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    return mem->position;
}

int32_t vv_mz_stream_mem_seek(void *stream, int64_t offset, int32_t origin)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    int64_t new_pos = 0;
    int32_t err = VV_MZ_OK;

    switch (origin)
    {
        case VV_MZ_SEEK_CUR:
            new_pos = mem->position + offset;
            break;
        case VV_MZ_SEEK_END:
            new_pos = mem->limit + offset;
            break;
        case VV_MZ_SEEK_SET:
            new_pos = offset;
            break;
        default:
            return VV_MZ_SEEK_ERROR;
    }

    if (new_pos > mem->size)
    {
        if ((mem->mode & VV_MZ_OPEN_MODE_CREATE) == 0)
            return VV_MZ_SEEK_ERROR;

        err = vv_mz_stream_mem_set_size(stream, (int32_t)new_pos);
        if (err != VV_MZ_OK)
            return err;
    }
    else if (new_pos < 0)
    {
        return VV_MZ_SEEK_ERROR;
    }

    mem->position = (int32_t)new_pos;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_mem_close(void *stream)
{
    VV_MZ_UNUSED(stream);

    /* We never return errors */
    return VV_MZ_OK;
}

int32_t vv_mz_stream_mem_error(void *stream)
{
    VV_MZ_UNUSED(stream);

    /* We never return errors */
    return VV_MZ_OK;
}

void vv_mz_stream_mem_set_buffer(void *stream, void *buf, int32_t size)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    mem->buffer = (uint8_t *)buf;
    mem->size = size;
    mem->limit = size;
}

int32_t vv_mz_stream_mem_get_buffer(void *stream, const void **buf)
{
    return vv_mz_stream_mem_get_buffer_at(stream, 0, buf);
}

int32_t vv_mz_stream_mem_get_buffer_at(void *stream, int64_t position, const void **buf)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    if (buf == NULL || position < 0 || mem->size < position || mem->buffer == NULL)
        return VV_MZ_SEEK_ERROR;
    *buf = mem->buffer + position;
    return VV_MZ_OK;
}

int32_t vv_mz_stream_mem_get_buffer_at_current(void *stream, const void **buf)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    return vv_mz_stream_mem_get_buffer_at(stream, mem->position, buf);
}

void vv_mz_stream_mem_get_buffer_length(void *stream, int32_t *length)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    *length = mem->limit;
}

void vv_mz_stream_mem_set_buffer_limit(void *stream, int32_t limit)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    mem->limit = limit;
}

void vv_mz_stream_mem_set_grow_size(void *stream, int32_t grow_size)
{
    vv_mz_stream_mem *mem = (vv_mz_stream_mem *)stream;
    mem->grow_size = grow_size;
}

void *vv_mz_stream_mem_create(void **stream)
{
    vv_mz_stream_mem *mem = NULL;

    mem = (vv_mz_stream_mem *)VV_MZ_ALLOC(sizeof(vv_mz_stream_mem));
    if (mem != NULL)
    {
        memset(mem, 0, sizeof(vv_mz_stream_mem));
        mem->stream.vtbl = &vv_mz_stream_mem_vtbl;
        mem->grow_size = 4096;
    }
    if (stream != NULL)
        *stream = mem;

    return mem;
}

void vv_mz_stream_mem_delete(void **stream)
{
    vv_mz_stream_mem *mem = NULL;
    if (stream == NULL)
        return;
    mem = (vv_mz_stream_mem *)*stream;
    if (mem != NULL)
    {
        if ((mem->mode & VV_MZ_OPEN_MODE_CREATE) && (mem->buffer != NULL))
            VV_MZ_FREE(mem->buffer);
        VV_MZ_FREE(mem);
    }
    *stream = NULL;
}

void *vv_mz_stream_mem_get_interface(void)
{
    return (void *)&vv_mz_stream_mem_vtbl;
}
