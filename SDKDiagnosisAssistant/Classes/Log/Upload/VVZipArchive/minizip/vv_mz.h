/* vv_mz.h -- Errors codes, zip flags and magic
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/

#ifndef VV_MZ_H
#define VV_MZ_H

/***************************************************************************/

/* VV_MZ_VERSION */
#define VV_MZ_VERSION                      ("2.9.2")

/* VV_MZ_ERROR */
#define VV_MZ_OK                           (0)  /* zlib */
#define VV_MZ_STREAM_ERROR                 (-1) /* zlib */
#define VV_MZ_DATA_ERROR                   (-3) /* zlib */
#define VV_MZ_MEM_ERROR                    (-4) /* zlib */
#define VV_MZ_BUF_ERROR                    (-5) /* zlib */
#define VV_MZ_VERSION_ERROR                (-6) /* zlib */

#define VV_MZ_END_OF_LIST                  (-100)
#define VV_MZ_END_OF_STREAM                (-101)

#define VV_MZ_PARAM_ERROR                  (-102)
#define VV_MZ_FORMAT_ERROR                 (-103)
#define VV_MZ_INTERNAL_ERROR               (-104)
#define VV_MZ_CRC_ERROR                    (-105)
#define VV_MZ_CRYPT_ERROR                  (-106)
#define VV_MZ_EXIST_ERROR                  (-107)
#define VV_MZ_PASSWORD_ERROR               (-108)
#define VV_MZ_SUPPORT_ERROR                (-109)
#define VV_MZ_HASH_ERROR                   (-110)
#define VV_MZ_OPEN_ERROR                   (-111)
#define VV_MZ_CLOSE_ERROR                  (-112)
#define VV_MZ_SEEK_ERROR                   (-113)
#define VV_MZ_TELL_ERROR                   (-114)
#define VV_MZ_READ_ERROR                   (-115)
#define VV_MZ_WRITE_ERROR                  (-116)
#define VV_MZ_SIGN_ERROR                   (-117)
#define VV_MZ_SYMLINK_ERROR                (-118)

/* VV_MZ_OPEN */
#define VV_MZ_OPEN_MODE_READ               (0x01)
#define VV_MZ_OPEN_MODE_WRITE              (0x02)
#define VV_MZ_OPEN_MODE_READWRITE          (VV_MZ_OPEN_MODE_READ | VV_MZ_OPEN_MODE_WRITE)
#define VV_MZ_OPEN_MODE_APPEND             (0x04)
#define VV_MZ_OPEN_MODE_CREATE             (0x08)
#define VV_MZ_OPEN_MODE_EXISTING           (0x10)

/* VV_MZ_SEEK */
#define VV_MZ_SEEK_SET                     (0)
#define VV_MZ_SEEK_CUR                     (1)
#define VV_MZ_SEEK_END                     (2)

/* VV_MZ_COMPRESS */
#define VV_MZ_COMPRESS_METHOD_STORE        (0)
#define VV_MZ_COMPRESS_METHOD_DEFLATE      (8)
#define VV_MZ_COMPRESS_METHOD_BZIP2        (12)
#define VV_MZ_COMPRESS_METHOD_LZMA         (14)
#define VV_MZ_COMPRESS_METHOD_AES          (99)

#define VV_MZ_COMPRESS_LEVEL_DEFAULT       (-1)
#define VV_MZ_COMPRESS_LEVEL_FAST          (2)
#define VV_MZ_COMPRESS_LEVEL_NORMAL        (6)
#define VV_MZ_COMPRESS_LEVEL_BEST          (9)

/* VV_MZ_ZIP_FLAG */
#define VV_MZ_ZIP_FLAG_ENCRYPTED           (1 << 0)
#define VV_MZ_ZIP_FLAG_LZMA_EOS_MARKER     (1 << 1)
#define VV_MZ_ZIP_FLAG_DEFLATE_MAX         (1 << 1)
#define VV_MZ_ZIP_FLAG_DEFLATE_NORMAL      (0)
#define VV_MZ_ZIP_FLAG_DEFLATE_FAST        (1 << 2)
#define VV_MZ_ZIP_FLAG_DEFLATE_SUPER_FAST  (VV_MZ_ZIP_FLAG_DEFLATE_FAST | \
                                         VV_MZ_ZIP_FLAG_DEFLATE_MAX)
#define VV_MZ_ZIP_FLAG_DATA_DESCRIPTOR     (1 << 3)
#define VV_MZ_ZIP_FLAG_UTF8                (1 << 11)
#define VV_MZ_ZIP_FLAG_MASK_LOCAL_INFO     (1 << 13)

/* VV_MZ_ZIP_EXTENSION */
#define VV_MZ_ZIP_EXTENSION_ZIP64          (0x0001)
#define VV_MZ_ZIP_EXTENSION_NTFS           (0x000a)
#define VV_MZ_ZIP_EXTENSION_AES            (0x9901)
#define VV_MZ_ZIP_EXTENSION_UNIX1          (0x000d)
#define VV_MZ_ZIP_EXTENSION_SIGN           (0x10c5)
#define VV_MZ_ZIP_EXTENSION_HASH           (0x1a51)
#define VV_MZ_ZIP_EXTENSION_CDCD           (0xcdcd)

/* VV_MZ_ZIP64 */
#define VV_MZ_ZIP64_AUTO                   (0)
#define VV_MZ_ZIP64_FORCE                  (1)
#define VV_MZ_ZIP64_DISABLE                (2)

/* VV_MZ_HOST_SYSTEM */
#define VV_MZ_HOST_SYSTEM(VERSION_MADEBY)  ((uint8_t)(VERSION_MADEBY >> 8))
#define VV_MZ_HOST_SYSTEM_MSDOS            (0)
#define VV_MZ_HOST_SYSTEM_UNIX             (3)
#define VV_MZ_HOST_SYSTEM_WINDOWS_NTFS     (10)
#define VV_MZ_HOST_SYSTEM_RISCOS           (13)
#define VV_MZ_HOST_SYSTEM_OSX_DARWIN       (19)

/* VV_MZ_PKCRYPT */
#define VV_MZ_PKCRYPT_HEADER_SIZE          (12)

/* VV_MZ_AES */
#define VV_MZ_AES_VERSION                  (1)
#define VV_MZ_AES_ENCRYPTION_MODE_128      (0x01)
#define VV_MZ_AES_ENCRYPTION_MODE_192      (0x02)
#define VV_MZ_AES_ENCRYPTION_MODE_256      (0x03)
#define VV_MZ_AES_KEY_LENGTH(MODE)         (8 * (MODE & 3) + 8)
#define VV_MZ_AES_KEY_LENGTH_MAX           (32)
#define VV_MZ_AES_BLOCK_SIZE               (16)
#define VV_MZ_AES_HEADER_SIZE(MODE)        ((4 * (MODE & 3) + 4) + 2)
#define VV_MZ_AES_FOOTER_SIZE              (10)

/* VV_MZ_HASH */
#define VV_MZ_HASH_MD5                     (10)
#define VV_MZ_HASH_MD5_SIZE                (16)
#define VV_MZ_HASH_SHA1                    (20)
#define VV_MZ_HASH_SHA1_SIZE               (20)
#define VV_MZ_HASH_SHA256                  (23)
#define VV_MZ_HASH_SHA256_SIZE             (32)
#define VV_MZ_HASH_MAX_SIZE                (256)

/* VV_MZ_ENCODING */
#define VV_MZ_ENCODING_CODEPAGE_437        (437)
#define VV_MZ_ENCODING_CODEPAGE_932        (932)
#define VV_MZ_ENCODING_CODEPAGE_936        (936)
#define VV_MZ_ENCODING_CODEPAGE_950        (950)
#define VV_MZ_ENCODING_UTF8                (65001)

/* VV_MZ_UTILITY */
#define VV_MZ_UNUSED(SYMBOL)               ((void)SYMBOL)

#ifndef VV_MZ_CUSTOM_ALLOC
#define VV_MZ_ALLOC(SIZE)                  (malloc(SIZE))
#endif
#ifndef VV_MZ_CUSTOM_FREE
#define VV_MZ_FREE(PTR)                    (free(PTR))
#endif

#if defined(_WINDOWS) && defined(VV_MZ_EXPORTS)
#define VV_MZ_EXPORT __declspec(dllexport)
#else
#define VV_MZ_EXPORT
#endif

/***************************************************************************/

#include <stdlib.h> /* size_t, NULL, malloc */
#include <time.h>   /* time_t, time() */
#include <string.h> /* memset, strncpy, strlen */
#include <limits.h>


#  include <stdint.h>


#ifndef __INT8_TYPE__
typedef signed char        int8_t;
#endif
#ifndef __INT16_TYPE__
typedef short              int16_t;
#endif
#ifndef __INT32_TYPE__
typedef int                int32_t;
#endif
#ifndef __INT64_TYPE__
typedef long long          int64_t;
#endif
#ifndef __UINT8_TYPE__
typedef unsigned char      uint8_t;
#endif
#ifndef __UINT16_TYPE__
typedef unsigned short     uint16_t;
#endif
#ifndef __UINT32_TYPE__
typedef unsigned int       uint32_t;
#endif
#ifndef __UINT64_TYPE__
typedef unsigned long long uint64_t;
#endif

#  include <inttypes.h>

#ifndef PRId8
#  define PRId8  "hhd"
#endif
#ifndef PRId16
#  define PRId16 "hd"
#endif
#ifndef PRId32
#  define PRId32 "d"
#endif
#ifndef PRIu32
#  define PRIu32 "u"
#endif
#ifndef PRIx32
#  define PRIx32 "x"
#endif
#if ULONG_MAX == 4294967295UL
#  ifndef PRId64
#    define PRId64 "lld"
#  endif
#  ifndef PRIu64
#    define PRIu64 "llu"
#  endif
#  ifndef PRIx64
#    define PRIx64 "llx"
#  endif
#else
#  ifndef PRId64
#    define PRId64 "ld"
#  endif
#  ifndef PRIu64
#    define PRIu64 "lu"
#  endif
#  ifndef PRIx64
#    define PRIx64 "lx"
#  endif
#endif

#ifndef INT16_MAX
#  define INT16_MAX   32767
#endif
#ifndef INT32_MAX
#  define INT32_MAX   2147483647L
#endif
#ifndef INT64_MAX
#  define INT64_MAX   9223372036854775807LL
#endif
#ifndef UINT16_MAX
#  define UINT16_MAX  65535U
#endif
#ifndef UINT32_MAX
#  define UINT32_MAX  4294967295UL
#endif
#ifndef UINT64_MAX
#  define UINT64_MAX  18446744073709551615ULL
#endif

/***************************************************************************/

#endif
