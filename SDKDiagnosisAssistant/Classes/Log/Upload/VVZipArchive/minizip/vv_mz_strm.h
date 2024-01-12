/* vv_mz_strm.h -- Stream interface
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/

#ifndef VV_MZ_STREAM_H
#define VV_MZ_STREAM_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************************************************************/

#define VV_MZ_STREAM_PROP_TOTAL_IN             (1)
#define VV_MZ_STREAM_PROP_TOTAL_IN_MAX         (2)
#define VV_MZ_STREAM_PROP_TOTAL_OUT            (3)
#define VV_MZ_STREAM_PROP_TOTAL_OUT_MAX        (4)
#define VV_MZ_STREAM_PROP_HEADER_SIZE          (5)
#define VV_MZ_STREAM_PROP_FOOTER_SIZE          (6)
#define VV_MZ_STREAM_PROP_DISK_SIZE            (7)
#define VV_MZ_STREAM_PROP_DISK_NUMBER          (8)
#define VV_MZ_STREAM_PROP_COMPRESS_LEVEL       (9)
#define VV_MZ_STREAM_PROP_COMPRESS_ALGORITHM   (10)
#define VV_MZ_STREAM_PROP_COMPRESS_WINDOW      (11)

/***************************************************************************/

typedef int32_t (*vv_mz_stream_open_cb)           (void *stream, const char *path, int32_t mode);
typedef int32_t (*vv_mz_stream_is_open_cb)        (void *stream);
typedef int32_t (*vv_mz_stream_read_cb)           (void *stream, void *buf, int32_t size);
typedef int32_t (*vv_mz_stream_write_cb)          (void *stream, const void *buf, int32_t size);
typedef int64_t (*vv_mz_stream_tell_cb)           (void *stream);
typedef int32_t (*vv_mz_stream_seek_cb)           (void *stream, int64_t offset, int32_t origin);
typedef int32_t (*vv_mz_stream_close_cb)          (void *stream);
typedef int32_t (*vv_mz_stream_error_cb)          (void *stream);
typedef void*   (*vv_mz_stream_create_cb)         (void **stream);
typedef void    (*vv_mz_stream_destroy_cb)        (void **stream);

typedef int32_t (*vv_mz_stream_get_prop_int64_cb) (void *stream, int32_t prop, int64_t *value);
typedef int32_t (*vv_mz_stream_set_prop_int64_cb) (void *stream, int32_t prop, int64_t value);

typedef int32_t (*vv_mz_stream_find_cb)           (void *stream, const void *find, int32_t find_size,
                                                int64_t max_seek, int64_t *position);

/***************************************************************************/

typedef struct vv_mz_stream_vtbl_s
{
    vv_mz_stream_open_cb           open;
    vv_mz_stream_is_open_cb        is_open;
    vv_mz_stream_read_cb           read;
    vv_mz_stream_write_cb          write;
    vv_mz_stream_tell_cb           tell;
    vv_mz_stream_seek_cb           seek;
    vv_mz_stream_close_cb          close;
    vv_mz_stream_error_cb          error;
    vv_mz_stream_create_cb         create;
    vv_mz_stream_destroy_cb        destroy;

    vv_mz_stream_get_prop_int64_cb get_prop_int64;
    vv_mz_stream_set_prop_int64_cb set_prop_int64;
} vv_mz_stream_vtbl;

typedef struct vv_mz_stream_s {
    vv_mz_stream_vtbl              *vtbl;
    struct vv_mz_stream_s          *base;
} vv_mz_stream;

/***************************************************************************/

int32_t vv_mz_stream_open(void *stream, const char *path, int32_t mode);
int32_t vv_mz_stream_is_open(void *stream);
int32_t vv_mz_stream_read(void *stream, void *buf, int32_t size);
int32_t vv_mz_stream_read_uint8(void *stream, uint8_t *value);
int32_t vv_mz_stream_read_uint16(void *stream, uint16_t *value);
int32_t vv_mz_stream_read_uint32(void *stream, uint32_t *value);
int32_t vv_mz_stream_read_int64(void *stream, int64_t *value);
int32_t vv_mz_stream_read_uint64(void *stream, uint64_t *value);
int32_t vv_mz_stream_write(void *stream, const void *buf, int32_t size);
int32_t vv_mz_stream_write_uint8(void *stream, uint8_t value);
int32_t vv_mz_stream_write_uint16(void *stream, uint16_t value);
int32_t vv_mz_stream_write_uint32(void *stream, uint32_t value);
int32_t vv_mz_stream_write_int64(void *stream, int64_t value);
int32_t vv_mz_stream_write_uint64(void *stream, uint64_t value);
int32_t vv_mz_stream_copy(void *target, void *source, int32_t len);
int32_t vv_mz_stream_copy_to_end(void *target, void *source);
int32_t vv_mz_stream_copy_stream(void *target, vv_mz_stream_write_cb write_cb, void *source, vv_mz_stream_read_cb read_cb, int32_t len);
int32_t vv_mz_stream_copy_stream_to_end(void *target, vv_mz_stream_write_cb write_cb, void *source, vv_mz_stream_read_cb read_cb);
int64_t vv_mz_stream_tell(void *stream);
int32_t vv_mz_stream_seek(void *stream, int64_t offset, int32_t origin);
int32_t vv_mz_stream_find(void *stream, const void *find, int32_t find_size, int64_t max_seek, int64_t *position);
int32_t vv_mz_stream_find_reverse(void *stream, const void *find, int32_t find_size, int64_t max_seek, int64_t *position);
int32_t vv_mz_stream_close(void *stream);
int32_t vv_mz_stream_error(void *stream);

int32_t vv_mz_stream_set_base(void *stream, void *base);
void*   vv_mz_stream_get_interface(void *stream);
int32_t vv_mz_stream_get_prop_int64(void *stream, int32_t prop, int64_t *value);
int32_t vv_mz_stream_set_prop_int64(void *stream, int32_t prop, int64_t value);

void*   vv_mz_stream_create(void **stream, vv_mz_stream_vtbl *vtbl);
void    vv_mz_stream_delete(void **stream);

/***************************************************************************/

int32_t vv_mz_stream_raw_open(void *stream, const char *filename, int32_t mode);
int32_t vv_mz_stream_raw_is_open(void *stream);
int32_t vv_mz_stream_raw_read(void *stream, void *buf, int32_t size);
int32_t vv_mz_stream_raw_write(void *stream, const void *buf, int32_t size);
int64_t vv_mz_stream_raw_tell(void *stream);
int32_t vv_mz_stream_raw_seek(void *stream, int64_t offset, int32_t origin);
int32_t vv_mz_stream_raw_close(void *stream);
int32_t vv_mz_stream_raw_error(void *stream);

int32_t vv_mz_stream_raw_get_prop_int64(void *stream, int32_t prop, int64_t *value);
int32_t vv_mz_stream_raw_set_prop_int64(void *stream, int32_t prop, int64_t value);

void*   vv_mz_stream_raw_create(void **stream);
void    vv_mz_stream_raw_delete(void **stream);

/***************************************************************************/

#ifdef __cplusplus
}
#endif

#endif
