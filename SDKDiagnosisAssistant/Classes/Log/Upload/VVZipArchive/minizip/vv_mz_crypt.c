/* vv_mz_crypt.c -- Crypto/hash functions
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include "vv_mz.h"
#include "vv_mz_crypt.h"


#  include "zlib.h"
#  if defined(ZLIBNG_VERNUM) && !defined(ZLIB_COMPAT)
#    include "zlib-ng.h"
#  endif


/***************************************************************************/
/* Define z_crc_t in zlib 1.2.5 and less or if using zlib-ng */

#if defined(ZLIBNG_VERNUM)
#  if defined(ZLIB_COMPAT)
#    define ZLIB_PREFIX(x) x
#  else
#    define ZLIB_PREFIX(x) zng_ ## x
#  endif
   typedef uint32_t z_crc_t;
#else
#  define ZLIB_PREFIX(x) x
#  if (ZLIB_VERNUM < 0x1270)
     typedef unsigned long z_crc_t;
#  endif
#endif

/***************************************************************************/

uint32_t vv_mz_crypt_crc32_update(uint32_t value, const uint8_t *buf, int32_t size)
{

    return (uint32_t)ZLIB_PREFIX(crc32)((z_crc_t)value, buf, (uInt)size);
}

#ifndef VV_MZ_ZIP_NO_ENCRYPTION
int32_t  vv_mz_crypt_pbkdf2(uint8_t *password, int32_t password_length, uint8_t *salt,
    int32_t salt_length, int32_t iteration_count, uint8_t *key, int32_t key_length)
{
    void *hmac1 = NULL;
    void *hmac2 = NULL;
    void *hmac3 = NULL;
    int32_t err = VV_MZ_OK;
    uint16_t i = 0;
    uint16_t j = 0;
    uint16_t k = 0;
    uint16_t block_count = 0;
    uint8_t uu[VV_MZ_HASH_SHA1_SIZE];
    uint8_t ux[VV_MZ_HASH_SHA1_SIZE];

    if (password == NULL || salt == NULL || key == NULL)
        return VV_MZ_PARAM_ERROR;

    memset(key, 0, key_length);

    vv_mz_crypt_hmac_create(&hmac1);
    vv_mz_crypt_hmac_create(&hmac2);
    vv_mz_crypt_hmac_create(&hmac3);

    vv_mz_crypt_hmac_set_algorithm(hmac1, VV_MZ_HASH_SHA1);
    vv_mz_crypt_hmac_set_algorithm(hmac2, VV_MZ_HASH_SHA1);
    vv_mz_crypt_hmac_set_algorithm(hmac3, VV_MZ_HASH_SHA1);

    err = vv_mz_crypt_hmac_init(hmac1, password, password_length);
    if (err == VV_MZ_OK)
        err = vv_mz_crypt_hmac_init(hmac2, password, password_length);
    if (err == VV_MZ_OK)
        err = vv_mz_crypt_hmac_update(hmac2, salt, salt_length);

    block_count = 1 + ((uint16_t)key_length - 1) / VV_MZ_HASH_SHA1_SIZE;

    for (i = 0; (err == VV_MZ_OK) && (i < block_count); i += 1)
    {
        memset(ux, 0, sizeof(ux));

        err = vv_mz_crypt_hmac_copy(hmac2, hmac3);
        if (err != VV_MZ_OK)
            break;

        uu[0] = (uint8_t)((i + 1) >> 24);
        uu[1] = (uint8_t)((i + 1) >> 16);
        uu[2] = (uint8_t)((i + 1) >> 8);
        uu[3] = (uint8_t)(i + 1);

        for (j = 0, k = 4; j < iteration_count; j += 1)
        {
            err = vv_mz_crypt_hmac_update(hmac3, uu, k);
            if (err == VV_MZ_OK)
                err = vv_mz_crypt_hmac_end(hmac3, uu, sizeof(uu));
            if (err != VV_MZ_OK)
                break;

            for(k = 0; k < VV_MZ_HASH_SHA1_SIZE; k += 1)
                ux[k] ^= uu[k];

            err = vv_mz_crypt_hmac_copy(hmac1, hmac3);
            if (err != VV_MZ_OK)
                break;
        }

        if (err != VV_MZ_OK)
            break;

        j = 0;
        k = i * VV_MZ_HASH_SHA1_SIZE;

        while (j < VV_MZ_HASH_SHA1_SIZE && k < key_length)
            key[k++] = ux[j++];
    }

    /* hmac3 uses the same provider as hmac2, so it must be deleted
       before the context is destroyed. */
    vv_mz_crypt_hmac_delete(&hmac3);
    vv_mz_crypt_hmac_delete(&hmac1);
    vv_mz_crypt_hmac_delete(&hmac2);

    return err;
}
#endif

/***************************************************************************/
