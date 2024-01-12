/* vv_mz_crypt_apple.c -- Crypto/hash functions for Apple
   Version 2.9.2, February 12, 2020
   part of the MiniZip project

   Copyright (C) 2010-2020 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include "vv_mz.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#include <Security/Security.h>
#include <Security/SecPolicy.h>

/***************************************************************************/

int32_t vv_mz_crypt_rand(uint8_t *buf, int32_t size)
{
    if (SecRandomCopyBytes(kSecRandomDefault, size, buf) != errSecSuccess)
        return 0;
    return size;
}

/***************************************************************************/

typedef struct vv_mz_crypt_sha_s {
    CC_SHA1_CTX     ctx1;
    CC_SHA256_CTX   ctx256;
    int32_t         error;
    int32_t         initialized;
    uint16_t        algorithm;
} vv_mz_crypt_sha;

/***************************************************************************/

void vv_mz_crypt_sha_reset(void *handle)
{
    vv_mz_crypt_sha *sha = (vv_mz_crypt_sha *)handle;

    sha->error = 0;
    sha->initialized = 0;
}

int32_t vv_mz_crypt_sha_begin(void *handle)
{
    vv_mz_crypt_sha *sha = (vv_mz_crypt_sha *)handle;

    if (sha == NULL)
        return VV_MZ_PARAM_ERROR;

    vv_mz_crypt_sha_reset(handle);

    if (sha->algorithm == VV_MZ_HASH_SHA1)
        sha->error = CC_SHA1_Init(&sha->ctx1);
    else if (sha->algorithm == VV_MZ_HASH_SHA256)
        sha->error = CC_SHA256_Init(&sha->ctx256);
    else
        return VV_MZ_PARAM_ERROR;

    if (!sha->error)
        return VV_MZ_HASH_ERROR;

    sha->initialized = 1;
    return VV_MZ_OK;
}

int32_t vv_mz_crypt_sha_update(void *handle, const void *buf, int32_t size)
{
    vv_mz_crypt_sha *sha = (vv_mz_crypt_sha *)handle;

    if (sha == NULL || buf == NULL || !sha->initialized)
        return VV_MZ_PARAM_ERROR;

    if (sha->algorithm == VV_MZ_HASH_SHA1)
        sha->error = CC_SHA1_Update(&sha->ctx1, buf, size);
    else
        sha->error = CC_SHA256_Update(&sha->ctx256, buf, size);

    if (!sha->error)
        return VV_MZ_HASH_ERROR;

    return size;
}

int32_t vv_mz_crypt_sha_end(void *handle, uint8_t *digest, int32_t digest_size)
{
    vv_mz_crypt_sha *sha = (vv_mz_crypt_sha *)handle;

    if (sha == NULL || digest == NULL || !sha->initialized)
        return VV_MZ_PARAM_ERROR;

    if (sha->algorithm == VV_MZ_HASH_SHA1)
    {
        if (digest_size < VV_MZ_HASH_SHA1_SIZE)
            return VV_MZ_BUF_ERROR;
        sha->error = CC_SHA1_Final(digest, &sha->ctx1);
    }
    else
    {
        if (digest_size < VV_MZ_HASH_SHA256_SIZE)
            return VV_MZ_BUF_ERROR;
        sha->error = CC_SHA256_Final(digest, &sha->ctx256);
    }

    if (!sha->error)
        return VV_MZ_HASH_ERROR;

    return VV_MZ_OK;
}

void vv_mz_crypt_sha_set_algorithm(void *handle, uint16_t algorithm)
{
    vv_mz_crypt_sha *sha = (vv_mz_crypt_sha *)handle;
    sha->algorithm = algorithm;
}

void *vv_mz_crypt_sha_create(void **handle)
{
    vv_mz_crypt_sha *sha = NULL;

    sha = (vv_mz_crypt_sha *)VV_MZ_ALLOC(sizeof(vv_mz_crypt_sha));
    if (sha != NULL)
    {
        memset(sha, 0, sizeof(vv_mz_crypt_sha));
        sha->algorithm = VV_MZ_HASH_SHA256;
    }
    if (handle != NULL)
        *handle = sha;

    return sha;
}

void vv_mz_crypt_sha_delete(void **handle)
{
    vv_mz_crypt_sha *sha = NULL;
    if (handle == NULL)
        return;
    sha = (vv_mz_crypt_sha *)*handle;
    if (sha != NULL)
    {
        vv_mz_crypt_sha_reset(*handle);
        VV_MZ_FREE(sha);
    }
    *handle = NULL;
}

/***************************************************************************/

typedef struct vv_mz_crypt_aes_s {
    CCCryptorRef crypt;
    int32_t      mode;
    int32_t      error;
} vv_mz_crypt_aes;

/***************************************************************************/

void vv_mz_crypt_aes_reset(void *handle)
{
    vv_mz_crypt_aes *aes = (vv_mz_crypt_aes *)handle;

    if (aes->crypt != NULL)
        CCCryptorRelease(aes->crypt);
    aes->crypt = NULL;
}

int32_t vv_mz_crypt_aes_encrypt(void *handle, uint8_t *buf, int32_t size)
{
    vv_mz_crypt_aes *aes = (vv_mz_crypt_aes *)handle;
    size_t data_moved = 0;

    if (aes == NULL || buf == NULL)
        return VV_MZ_PARAM_ERROR;
    if (size != VV_MZ_AES_BLOCK_SIZE)
        return VV_MZ_PARAM_ERROR;

    aes->error = CCCryptorUpdate(aes->crypt, buf, size, buf, size, &data_moved);

    if (aes->error != kCCSuccess)
        return VV_MZ_HASH_ERROR;

    return size;
}

int32_t vv_mz_crypt_aes_decrypt(void *handle, uint8_t *buf, int32_t size)
{
    vv_mz_crypt_aes *aes = (vv_mz_crypt_aes *)handle;
    size_t data_moved = 0;

    if (aes == NULL || buf == NULL)
        return VV_MZ_PARAM_ERROR;
    if (size != VV_MZ_AES_BLOCK_SIZE)
        return VV_MZ_PARAM_ERROR;

    aes->error = CCCryptorUpdate(aes->crypt, buf, size, buf, size, &data_moved);

    if (aes->error != kCCSuccess)
        return VV_MZ_HASH_ERROR;

    return size;
}

int32_t vv_mz_crypt_aes_set_encrypt_key(void *handle, const void *key, int32_t key_length)
{
    vv_mz_crypt_aes *aes = (vv_mz_crypt_aes *)handle;


    if (aes == NULL || key == NULL || key_length == 0)
        return VV_MZ_PARAM_ERROR;

    vv_mz_crypt_aes_reset(handle);

    aes->error = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES, kCCOptionECBMode,
        key, key_length, NULL, &aes->crypt);

    if (aes->error != kCCSuccess)
        return VV_MZ_HASH_ERROR;

    return VV_MZ_OK;
}

int32_t vv_mz_crypt_aes_set_decrypt_key(void *handle, const void *key, int32_t key_length)
{
    vv_mz_crypt_aes *aes = (vv_mz_crypt_aes *)handle;


    if (aes == NULL || key == NULL || key_length == 0)
        return VV_MZ_PARAM_ERROR;

    vv_mz_crypt_aes_reset(handle);

    aes->error = CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES, kCCOptionECBMode,
        key, key_length, NULL, &aes->crypt);

    if (aes->error != kCCSuccess)
        return VV_MZ_HASH_ERROR;

    return VV_MZ_OK;
}

void vv_mz_crypt_aes_set_mode(void *handle, int32_t mode)
{
    vv_mz_crypt_aes *aes = (vv_mz_crypt_aes *)handle;
    aes->mode = mode;
}

void *vv_mz_crypt_aes_create(void **handle)
{
    vv_mz_crypt_aes *aes = NULL;

    aes = (vv_mz_crypt_aes *)VV_MZ_ALLOC(sizeof(vv_mz_crypt_aes));
    if (aes != NULL)
        memset(aes, 0, sizeof(vv_mz_crypt_aes));
    if (handle != NULL)
        *handle = aes;

    return aes;
}

void vv_mz_crypt_aes_delete(void **handle)
{
    vv_mz_crypt_aes *aes = NULL;
    if (handle == NULL)
        return;
    aes = (vv_mz_crypt_aes *)*handle;
    if (aes != NULL)
    {
        vv_mz_crypt_aes_reset(*handle);
        VV_MZ_FREE(aes);
    }
    *handle = NULL;
}

/***************************************************************************/

typedef struct vv_mz_crypt_hmac_s {
    CCHmacContext   ctx;
    int32_t         initialized;
    int32_t         error;
    uint16_t        algorithm;
} vv_mz_crypt_hmac;

/***************************************************************************/

static void vv_mz_crypt_hmac_free(void *handle)
{
    vv_mz_crypt_hmac *hmac = (vv_mz_crypt_hmac *)handle;
    memset(&hmac->ctx, 0, sizeof(hmac->ctx));
}

void vv_mz_crypt_hmac_reset(void *handle)
{
    vv_mz_crypt_hmac *hmac = (vv_mz_crypt_hmac *)handle;
    vv_mz_crypt_hmac_free(handle);
    hmac->error = 0;
}

int32_t vv_mz_crypt_hmac_init(void *handle, const void *key, int32_t key_length)
{
    vv_mz_crypt_hmac *hmac = (vv_mz_crypt_hmac *)handle;
    CCHmacAlgorithm algorithm = 0;

    if (hmac == NULL || key == NULL)
        return VV_MZ_PARAM_ERROR;

    vv_mz_crypt_hmac_reset(handle);

    if (hmac->algorithm == VV_MZ_HASH_SHA1)
        algorithm = kCCHmacAlgSHA1;
    else if (hmac->algorithm == VV_MZ_HASH_SHA256)
        algorithm = kCCHmacAlgSHA256;
    else
        return VV_MZ_PARAM_ERROR;

    CCHmacInit(&hmac->ctx, algorithm, key, key_length);
    return VV_MZ_OK;
}

int32_t vv_mz_crypt_hmac_update(void *handle, const void *buf, int32_t size)
{
    vv_mz_crypt_hmac *hmac = (vv_mz_crypt_hmac *)handle;

    if (hmac == NULL || buf == NULL)
        return VV_MZ_PARAM_ERROR;

    CCHmacUpdate(&hmac->ctx, buf, size);
    return VV_MZ_OK;
}

int32_t vv_mz_crypt_hmac_end(void *handle, uint8_t *digest, int32_t digest_size)
{
    vv_mz_crypt_hmac *hmac = (vv_mz_crypt_hmac *)handle;

    if (hmac == NULL || digest == NULL)
        return VV_MZ_PARAM_ERROR;

    if (hmac->algorithm == VV_MZ_HASH_SHA1)
    {
        if (digest_size < VV_MZ_HASH_SHA1_SIZE)
            return VV_MZ_BUF_ERROR;
        CCHmacFinal(&hmac->ctx, digest);
    }
    else
    {
        if (digest_size < VV_MZ_HASH_SHA256_SIZE)
            return VV_MZ_BUF_ERROR;
        CCHmacFinal(&hmac->ctx, digest);
    }

    return VV_MZ_OK;
}

void vv_mz_crypt_hmac_set_algorithm(void *handle, uint16_t algorithm)
{
    vv_mz_crypt_hmac *hmac = (vv_mz_crypt_hmac *)handle;
    hmac->algorithm = algorithm;
}

int32_t vv_mz_crypt_hmac_copy(void *src_handle, void *target_handle)
{
    vv_mz_crypt_hmac *source = (vv_mz_crypt_hmac *)src_handle;
    vv_mz_crypt_hmac *target = (vv_mz_crypt_hmac *)target_handle;

    if (source == NULL || target == NULL)
        return VV_MZ_PARAM_ERROR;

    memcpy(&target->ctx, &source->ctx, sizeof(CCHmacContext));
    return VV_MZ_OK;
}

void *vv_mz_crypt_hmac_create(void **handle)
{
    vv_mz_crypt_hmac *hmac = NULL;

    hmac = (vv_mz_crypt_hmac *)VV_MZ_ALLOC(sizeof(vv_mz_crypt_hmac));
    if (hmac != NULL)
    {
        memset(hmac, 0, sizeof(vv_mz_crypt_hmac));
        hmac->algorithm = VV_MZ_HASH_SHA256;
    }
    if (handle != NULL)
        *handle = hmac;

    return hmac;
}

void vv_mz_crypt_hmac_delete(void **handle)
{
    vv_mz_crypt_hmac *hmac = NULL;
    if (handle == NULL)
        return;
    hmac = (vv_mz_crypt_hmac *)*handle;
    if (hmac != NULL)
    {
        vv_mz_crypt_hmac_free(*handle);
        VV_MZ_FREE(hmac);
    }
    *handle = NULL;
}

/***************************************************************************/

#if defined(VV_MZ_ZIP_SIGNING)
int32_t vv_mz_crypt_sign(uint8_t *message, int32_t message_size, uint8_t *cert_data, int32_t cert_data_size,
    const char *cert_pwd, uint8_t **signature, int32_t *signature_size)
{
    CFStringRef password_ref = NULL;
    CFDictionaryRef options_dict = NULL;
    CFDictionaryRef identity_trust = NULL;
    CFDataRef signature_out = NULL;
    CFDataRef pkcs12_data = NULL;
    CFArrayRef items = 0;
    SecIdentityRef identity = NULL;
    SecTrustRef trust = NULL;
    OSStatus status = noErr;
    const void *options_key[2] = { kSecImportExportPassphrase, kSecReturnRef };
    const void *options_values[2] = { 0, kCFBooleanTrue };
    int32_t err = VV_MZ_SIGN_ERROR;


    if (message == NULL || cert_data == NULL || signature == NULL || signature_size == NULL)
        return VV_MZ_PARAM_ERROR;

    *signature = NULL;
    *signature_size = 0;

    password_ref = CFStringCreateWithCString(0, cert_pwd, kCFStringEncodingUTF8);
    options_values[0] = password_ref;

    options_dict = CFDictionaryCreate(0, options_key, options_values, 2, 0, 0);
    if (options_dict)
        pkcs12_data = CFDataCreate(0, cert_data, cert_data_size);
    if (pkcs12_data)
        status = SecPKCS12Import(pkcs12_data, options_dict, &items);
    if (status == noErr)
        identity_trust = CFArrayGetValueAtIndex(items, 0);
    if (identity_trust)
        identity = (SecIdentityRef)CFDictionaryGetValue(identity_trust, kSecImportItemIdentity);
    if (identity)
        trust = (SecTrustRef)CFDictionaryGetValue(identity_trust, kSecImportItemTrust);
    if (trust)
    {
        status = CMSEncodeContent(identity, NULL, NULL, FALSE, 0, message, message_size, &signature_out);

        if (status == errSecSuccess)
        {
            *signature_size = CFDataGetLength(signature_out);
            *signature = (uint8_t *)VV_MZ_ALLOC(*signature_size);

            memcpy(*signature, CFDataGetBytePtr(signature_out), *signature_size);

            err = VV_MZ_OK;
        }
    }

    if (signature_out)
        CFRelease(signature_out);
    if (items)
        CFRelease(items);
    if (pkcs12_data)
        CFRelease(pkcs12_data);
    if (options_dict)
        CFRelease(options_dict);
    if (password_ref)
        CFRelease(password_ref);

    return err;
}

int32_t vv_mz_crypt_sign_verify(uint8_t *message, int32_t message_size, uint8_t *signature, int32_t signature_size)
{
    CMSDecoderRef decoder = NULL;
    CMSSignerStatus signer_status = 0;
    CFDataRef message_out = NULL;
    SecPolicyRef trust_policy = NULL;
    OSStatus status = noErr;
    OSStatus verify_status = noErr;
    size_t signer_count = 0;
    size_t i = 0;
    int32_t err = VV_MZ_SIGN_ERROR;

    if (message == NULL || signature == NULL)
        return VV_MZ_PARAM_ERROR;

    status = CMSDecoderCreate(&decoder);
    if (status == errSecSuccess)
        status = CMSDecoderUpdateMessage(decoder, signature, signature_size);
    if (status == errSecSuccess)
        status = CMSDecoderFinalizeMessage(decoder);
    if (status == errSecSuccess)
        trust_policy = SecPolicyCreateBasicX509();

    if (status == errSecSuccess && trust_policy)
    {
        CMSDecoderGetNumSigners(decoder, &signer_count);
        if (signer_count > 0)
            err = VV_MZ_OK;
        for (i = 0; i < signer_count; i += 1)
        {
            status = CMSDecoderCopySignerStatus(decoder, i, trust_policy, TRUE, &signer_status, NULL, &verify_status);
            if (status != errSecSuccess || verify_status != 0 || signer_status != kCMSSignerValid)
            {
                err = VV_MZ_SIGN_ERROR;
                break;
            }
        }
    }

    if (err == VV_MZ_OK)
    {
        status = CMSDecoderCopyContent(decoder, &message_out);
        if ((status != errSecSuccess) ||
            (CFDataGetLength(message_out) != message_size) ||
            (memcmp(message, CFDataGetBytePtr(message_out), message_size) != 0))
            err = VV_MZ_SIGN_ERROR;
    }

    if (trust_policy)
        CFRelease(trust_policy);
    if (decoder)
        CFRelease(decoder);

    return err;
}

#endif
