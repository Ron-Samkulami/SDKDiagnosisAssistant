//
//  RVNetUtils.m
//  SDKDiagnosisAssistant
//
//  Created by 黄雄荣 on 2024/1/5.
//

#import "RVNetUtils.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation RVNetUtils

/// MD5加密
+ (NSString *)md5HexDigest:(NSString *)originalStr
{
    const char *original_str = [originalStr UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(original_str, (CC_LONG)strlen(original_str), result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [hash appendFormat:@"%02X", result[i]];
    return [hash lowercaseString];
}

/// 获取当前时间戳
+ (NSString *)getCurrentTimeStamp {
    UInt64 ts = [[NSDate date] timeIntervalSince1970] * 1000;
    NSString *tsStr = [NSString stringWithFormat:@"%lld",ts];
    
    return tsStr;
}

+ (id)convertObjToJsonStringIfValid:(id)object {
    
    //先判断是否能转化为JSON格式
    if (![NSJSONSerialization isValidJSONObject:object])  return object;
    NSError *error = nil;
    
    // 默认有格式
    NSJSONWritingOptions jsonOptions = NSJSONWritingPrettyPrinted;

    if (@available(iOS 11.0, *)) {
        //11.0之后，可以将JSON按照key排列后输出，看起来会更舒服
        jsonOptions =  jsonOptions | NSJSONWritingSortedKeys;
    }
    if (@available(iOS 13.0,*)) {
        //13.0之后，可以去除Json里面转义字符
        jsonOptions =  jsonOptions | NSJSONWritingWithoutEscapingSlashes;
    }
    //核心代码，字典转化为有格式输出的JSON字符串
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:jsonOptions  error:&error];
    if (error || !jsonData) return object;
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end
