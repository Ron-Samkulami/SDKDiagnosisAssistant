//
//  NSStringUtils.h
//  RVSDK
//
//  Created by 黄雄荣 on 2022/8/12.
//  Copyright © 2022 SDK. All rights reserved.
//

/**
 NSString工具类
 */

#import <Foundation/Foundation.h>

/**
 @brief 判断NSString是否为空
 */
#define isStringEmpty(str)  (!(str) || ![(str) isKindOfClass:[NSString class]] || [(str) isEqualToString:@""])

/**
 @brief 判断对象是否是NSString或NSNumber
 */
#define isStringOrNumber(obj)  ([(obj) isKindOfClass:[NSString class]] || [(obj) isKindOfClass:[NSNumber class]])

/**
 @brief 判断NSString是有有效
 */
#define isValidString(obj)  ([(obj) isKindOfClass:[NSString class]] && ![(obj) isEqualToString:@""])

/**
 @brief 判断是否是NSString
 */
#define isString(obj)  ([(obj) isKindOfClass:[NSString class]])


NS_ASSUME_NONNULL_BEGIN

@interface NSStringUtils : NSObject


#pragma mark - JSON字符串与字典转换
/// dictonary转JSON字符串(JSON带格式)
+ (NSString *)jsonStringFromDictionary:(NSDictionary *)dict;
/// dictonary转JSON字符串(JSON不带格式)
+ (NSString *)jsonStringWithoutFormatFromDictionary:(NSDictionary *)dict;

/// JSON字符串转dictonary
+ (NSDictionary *)dictionaryFromJsonString:(NSString *)jsonString;
/// dictonary转JSON字符串(JSON不带格式换行符)
+ (NSString *)jsonStringWithoutNewlineFromDictionary:(NSDictionary *)dict;


#pragma mark - 格式转换
/// 将传入的对象处理后返回字符串或者空字符串
+ (nullable NSString *)returnStringFromObject:(id)object;

/// 十六进制转换为普通字符串的。
+ (nullable NSString *)stringFromHexString:(NSString *)hexString;
/// 普通字符串转换为十六进制的。
+ (nullable NSString *)hexStringFromString:(NSString *)string;

/// 判断一个字符串是否可以转化为整数
+ (BOOL)isPureInt:(NSString *)string;

#pragma mark - 格式控制
/// 字符串最多40个字符
+ (NSString *)return40CharacterStringWithString:(NSString *)string;

/// 返回最多maxLength个字符的字符串，从头开始截取
+ (NSString *)returnStringWithString:(NSString *)string forMaxLength:(NSInteger)maxLength;

/// 删除字符串中的16进制字符串
+ (NSString *)deleteHexadecimalString:(NSString *)str;

/// 删除Base64格式前缀
+ (NSString *)removeBase64DataFormatPrefix:(NSString *)originalBase64Str;
@end

NS_ASSUME_NONNULL_END
