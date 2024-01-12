/* vv_mz_compat.h -- Backwards compatible interface for older versions
   Version 2.8.6, April 8, 2019
   part of the MiniZip project

   Copyright (C) 2010-2019 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip
   Copyright (C) 1998-2010 Gilles Vollant
     https://www.winimage.com/zLibDll/minizip.html

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/

#ifndef VV_MZ_COMPAT_H
#define VV_MZ_COMPAT_H

#include "vv_mz.h"
#include "../VVZipCommon.h"

#ifdef __cplusplus
extern "C" {
#endif

/***************************************************************************/

#if defined(MAX_MEM_LEVEL)
#ifndef DEF_MEM_LEVEL
#  if MAX_MEM_LEVEL >= 8
#    define DEF_MEM_LEVEL 8
#  else
#    define DEF_MEM_LEVEL  MAX_MEM_LEVEL
#  endif
#endif
#endif
#ifndef MAX_WBITS
#define MAX_WBITS     15
#endif
#ifndef DEF_MEM_LEVEL
#define DEF_MEM_LEVEL 8
#endif

#ifndef ZEXPORT
#  define ZEXPORT VV_MZ_EXPORT
#endif

/***************************************************************************/

#if defined(STRICTZIP) || defined(STRICTZIPUNZIP)
/* like the STRICT of WIN32, we define a pointer that cannot be converted
    from (void*) without cast */
typedef struct TagzipFile__ { int unused; } zip_file__;
typedef zip_file__ *zipFile;
#else
typedef void *zipFile;
#endif

/***************************************************************************/

typedef void *zlib_filefunc_def;
typedef void *zlib_filefunc64_def;
typedef const char *zipcharpc;

typedef struct tm tm_unz;
typedef struct tm tm_zip;

typedef uint64_t ZPOS64_T;

/***************************************************************************/

// ZipArchive 2.x uses dos_date
#define VV_MZ_COMPAT_VERSION 120

#if VV_MZ_COMPAT_VERSION <= 110
#define vv_mz_dos_date dosDate
#else
#define vv_mz_dos_date dos_date
#endif

typedef struct
{
    uint32_t    vv_mz_dos_date;
    struct tm   tvv_mz_date;
    uint16_t    internal_fa;        /* internal file attributes        2 bytes */
    uint32_t    external_fa;        /* external file attributes        4 bytes */
} zip_fileinfo;

/***************************************************************************/

#define ZIP_OK                          (0)
#define ZIP_EOF                         (0)
#define ZIP_ERRNO                       (-1)
#define ZIP_PARAMERROR                  (-102)
#define ZIP_BADZIPFILE                  (-103)
#define ZIP_INTERNALERROR               (-104)

#define Z_BZIP2ED                       (12)

#define APPEND_STATUS_CREATE            (0)
#define APPEND_STATUS_CREATEAFTER       (1)
#define APPEND_STATUS_ADDINZIP          (2)

/***************************************************************************/
/* Writing a zip file  */

ZEXPORT zipFile vv_zipOpen(const char *path, int append);
ZEXPORT zipFile vv_zipOpen64(const void *path, int append);
ZEXPORT zipFile vv_zipOpen2(const char *path, int append, const char **globalcomment,
    zlib_filefunc_def *pzlib_filefunc_def);
ZEXPORT zipFile vv_zipOpen2_64(const void *path, int append, const char **globalcomment,
    zlib_filefunc64_def *pzlib_filefunc_def);
        zipFile vv_zipOpen_MZ(void *stream, int append, const char **globalcomment);

ZEXPORT int     vv_zipOpenNewFileInZip5(zipFile file, const char *filename, const zip_fileinfo *zipfi,
    const void *extrafield_local, uint16_t size_extrafield_local, const void *extrafield_global,
    uint16_t size_extrafield_global, const char *comment, uint16_t compression_method, int level,
    int raw, int windowBits, int memLevel, int strategy, const char *password,
    signed char aes, uint16_t version_madeby, uint16_t flag_base, int zip64);

ZEXPORT int     vv_zipWriteInFileInZip(zipFile file, const void *buf, uint32_t len);

ZEXPORT int     vv_zipCloseFileInZipRaw(zipFile file, uint32_t uncompressed_size, uint32_t crc32);
ZEXPORT int     vv_zipCloseFileInZipRaw64(zipFile file, int64_t uncompressed_size, uint32_t crc32);
ZEXPORT int     vv_zipCloseFileInZip(zipFile file);
ZEXPORT int     vv_zipCloseFileInZip64(zipFile file);

ZEXPORT int     vv_zipClose(zipFile file, const char *global_comment);
ZEXPORT int     vv_zipClose_64(zipFile file, const char *global_comment);
ZEXPORT int     vv_zipClose2_64(zipFile file, const char *global_comment, uint16_t version_madeby);
        int     vv_zipClose_MZ(zipFile file, const char *global_comment);
        int     vv_zipClose2_MZ(zipFile file, const char *global_comment, uint16_t version_madeby);
ZEXPORT void*   vv_zipGetStream(zipFile file);

/***************************************************************************/

#if defined(STRICTUNZIP) || defined(STRICTZIPUNZIP)
/* like the STRICT of WIN32, we define a pointer that cannot be converted
    from (void*) without cast */
typedef struct TagunzFile__ { int unused; } vv_unz_file__;
typedef vv_unz_file__ *vv_unzFile;
#else
typedef void *vv_unzFile;
#endif

/***************************************************************************/

#define VV_UNZ_OK                          (0)
#define VV_UNZ_END_OF_LIST_OF_FILE         (-100)
#define VV_UNZ_ERRNO                       (-1)
#define VV_UNZ_EOF                         (0)
#define VV_UNZ_PARAMERROR                  (-102)
#define VV_UNZ_BADZIPFILE                  (-103)
#define VV_UNZ_INTERNALERROR               (-104)
#define VV_UNZ_CRCERROR                    (-105)
#define VV_UNZ_BADPASSWORD                 (-106)

/***************************************************************************/

typedef int (*vv_unzFileNameComparer)(vv_unzFile file, const char *filename1, const char *filename2);
typedef int (*vv_unzIteratorFunction)(vv_unzFile file);
typedef int (*vv_unzIteratorFunction2)(vv_unzFile file, vv_unz_file_info64 *pfile_info, char *filename,
    uint16_t filename_size, void *extrafield, uint16_t extrafield_size, char *comment,
    uint16_t comment_size);

/***************************************************************************/
/* Reading a zip file */

ZEXPORT vv_unzFile vv_unzOpen(const char *path);
ZEXPORT vv_unzFile vv_unzOpen64(const void *path);
ZEXPORT vv_unzFile vv_unzOpen2(const char *path, zlib_filefunc_def *pzlib_filefunc_def);
ZEXPORT vv_unzFile vv_unzOpen2_64(const void *path, zlib_filefunc64_def *pzlib_filefunc_def);
        vv_unzFile vv_unzOpen_MZ(void *stream);

ZEXPORT int     vv_unzClose(vv_unzFile file);
        int     vv_unzClose_MZ(vv_unzFile file);

ZEXPORT int     vv_unzGetGlobalInfo(vv_unzFile file, vv_unz_global_info* pglobal_info32);
ZEXPORT int     vv_unzGetGlobalInfo64(vv_unzFile file, vv_unz_global_info64 *pglobal_info);
ZEXPORT int     vv_unzGetGlobalComment(vv_unzFile file, char *comment, uint16_t comment_size);

ZEXPORT int     vv_unzOpenCurrentFile(vv_unzFile file);
ZEXPORT int     vv_unzOpenCurrentFilePassword(vv_unzFile file, const char *password);
ZEXPORT int     vv_unzOpenCurrentFile2(vv_unzFile file, int *method, int *level, int raw);
ZEXPORT int     vv_unzOpenCurrentFile3(vv_unzFile file, int *method, int *level, int raw, const char *password);
ZEXPORT int     vv_unzReadCurrentFile(vv_unzFile file, void *buf, uint32_t len);
ZEXPORT int     vv_unzCloseCurrentFile(vv_unzFile file);


ZEXPORT int     vv_unzGetCurrentFileInfo(vv_unzFile file, vv_unz_file_info *pfile_info, char *filename,
    uint16_t filename_size, void *extrafield, uint16_t extrafield_size, char *comment,
    uint16_t comment_size);
ZEXPORT int     vv_unzGetCurrentFileInfo64(vv_unzFile file, vv_unz_file_info64 * pfile_info, char *filename,
    uint16_t filename_size, void *extrafield, uint16_t extrafield_size, char *comment,
    uint16_t comment_size);

ZEXPORT int     vv_unzGoToFirstFile(vv_unzFile file);
ZEXPORT int     vv_unzGoToNextFile(vv_unzFile file);
ZEXPORT int     vv_unzLocateFile(vv_unzFile file, const char *filename, vv_unzFileNameComparer filename_compare_func);

ZEXPORT int     vv_unzGetLocalExtrafield(vv_unzFile file, void *buf, unsigned int len);

/***************************************************************************/
/* Raw access to zip file */

typedef struct vv_unz_file_pos_s
{
    uint32_t pos_in_zip_directory;  /* offset in zip file directory */
    uint32_t num_of_file;           /* # of file */
} vv_unz_file_pos;

ZEXPORT int     vv_unzGetFilePos(vv_unzFile file, vv_unz_file_pos *file_pos);
ZEXPORT int     vv_unzGoToFilePos(vv_unzFile file, vv_unz_file_pos *file_pos);

typedef struct vv_unz64_file_pos_s
{
    int64_t  pos_in_zip_directory;   /* offset in zip file directory  */
    uint64_t num_of_file;            /* # of file */
} vv_unz64_file_pos;

ZEXPORT int     vv_unzGetFilePos64(vv_unzFile file, vv_unz64_file_pos *file_pos);
ZEXPORT int     vv_unzGoToFilePos64(vv_unzFile file, const vv_unz64_file_pos *file_pos);

ZEXPORT int64_t vv_unzGetOffset64(vv_unzFile file);
ZEXPORT int32_t vv_unzGetOffset(vv_unzFile file);
ZEXPORT int     vv_unzSetOffset64(vv_unzFile file, int64_t pos);
ZEXPORT int     vv_unzSetOffset(vv_unzFile file, uint32_t pos);
ZEXPORT int64_t vv_unztell(vv_unzFile file);
ZEXPORT int32_t vv_unzTell(vv_unzFile file);
ZEXPORT int64_t vv_unzTell64(vv_unzFile file);
ZEXPORT int     vv_unzSeek(vv_unzFile file, int32_t offset, int origin);
ZEXPORT int     vv_unzSeek64(vv_unzFile file, int64_t offset, int origin);
ZEXPORT int     vv_unzEndOfFile(vv_unzFile file);
ZEXPORT void*   vv_unzGetStream(vv_unzFile file);

/***************************************************************************/

ZEXPORT void vv_fill_fopen_filefunc(zlib_filefunc_def *pzlib_filefunc_def);
ZEXPORT void vv_fill_fopen64_filefunc(zlib_filefunc64_def *pzlib_filefunc_def);
ZEXPORT void vv_fill_win32_filefunc(zlib_filefunc_def *pzlib_filefunc_def);
ZEXPORT void vv_fill_win32_filefunc64(zlib_filefunc64_def *pzlib_filefunc_def);
ZEXPORT void vv_fill_win32_filefunc64A(zlib_filefunc64_def *pzlib_filefunc_def);
ZEXPORT void vv_fill_win32_filefunc64W(zlib_filefunc64_def *pzlib_filefunc_def);
ZEXPORT void vv_fill_memory_filefunc(zlib_filefunc_def *pzlib_filefunc_def);

/***************************************************************************/

#ifdef __cplusplus
}
#endif

#endif
