//
//  NSStringUtils.m
//  RVSDK
//
//  Created by 黄雄荣 on 2022/8/12.
//  Copyright © 2022 SDK. All rights reserved.
//

#import "NSStringUtils.h"
#import "RVOnlyLog.h"

@implementation NSStringUtils

#pragma mark - JSON字符串与字典转换
//dictonary转JSON字符串(JSON带格式)
+ (NSString *)jsonStringFromDictionary:(NSDictionary *)dict
{
    if (!dict) {
        NSLogInfo(@"字典转JSON字符串出错 dict==nil");
        return nil;
    }
    
    NSError *error = nil;
    NSData *jsonData = nil;
    @try {
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    } @catch (NSException *exception) {
        NSLogError(@"字典转JSON字符串异常，请检查字典key-value是否合法 jsonData==nil dict=%@,error=%@",dict, error);
    }
    
    if (!jsonData) {
        NSLogError(@"字典转JSON字符串出错 jsonData==nil dict=%@,error=%@",dict, error);
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}


//dictonary转JSON字符串(JSON不带格式)
+ (NSString *)jsonStringWithoutFormatFromDictionary:(NSDictionary *)dict
{
    NSString *jsonString = [self jsonStringFromDictionary:dict];
    if (!jsonString) {
        NSLogInfo(@"字典转JSON字符串出错 dict=%@ jsonString=nil",dict);
        return nil;
    }
    
    //去除JSON字符串中的格式
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    NSRange range = {0,jsonString.length};
    //去掉字符串中的空格
    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    NSRange range2 = {0,mutStr.length};
    //去掉字符串中的换行符
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    
    return mutStr;
}


//JSON字符串转dictonary
+ (NSDictionary *)dictionaryFromJsonString:(NSString *)jsonString
{
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    if (!jsonData) {
        NSLogError(@"JSON字符串转字典出错 jsonData==nil");
        return nil;
    }
    
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    if(error) {
        NSLogError(@"JSON字符串转字典出错 error=%@",error.description);
        return nil;
    }
    
    return dict;
}


//dictonary转JSON字符串(JSON不带格式)
+ (NSString *)jsonStringWithoutNewlineFromDictionary:(NSDictionary *)dict
{
    if (!dict) {
        NSLogInfo(@"字典转JSON字符串出错 dict==nil");
        return nil;
    }
    
    //dictonary转JSON字符串(JSON不带格式)
    NSError *error = nil;
    NSData *jsonData = nil;
    @try {
        // 注
        if (@available(iOS 11.0, *)) {
            jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingSortedKeys error:&error];
        } else {
            //这个全系统版本通用
            jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        }
    } @catch (NSException *exception) {
        NSLogError(@"字典转JSON字符串异常，请检查字典key-value是否合法 jsonData==nil dict=%@,error=%@",dict, error);
    }
    
    NSString *jsonString;
    if (!jsonData) {
        NSLogError(@"字典转JSON字符串出错 jsonData==nil dict=%@,error=%@",dict, error);
        return nil;
    }
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
}


+ (NSString *)returnStringFromObject:(id)object {
    
    //空类型
    if (!object) {
        return @"";
    }
    //字符串类型，直接返回
    if ([object isKindOfClass:[NSString class]]) {
        return object;
    }
    //数字类型，转换成字符串类型返回
    if ([object isKindOfClass:[NSNumber class]]) {
        NSInteger integerValue = ((NSNumber *)object).integerValue;
        NSString *integerString = [NSString stringWithFormat:@"%zd",integerValue];
        return integerString;
    }
    //其他类型，返回空字符串
    return @"";
}


// 十六进制转换为普通字符串的。
+ (NSString *)stringFromHexString:(NSString *)hexString {
    
    //异常处理
    if (hexString.length < 2) {
        NSLogError(@"stringFromHexString error 字符串长度小于2！！！");
        return @"";
    }
    char *myBuffer = (char *)malloc((int)[hexString length] / 2 + 1);
    bzero(myBuffer, [hexString length] / 2 + 1);
    for (int i = 0; i < [hexString length] - 1; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [hexString substringWithRange:NSMakeRange(i, 2)];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        [scanner scanHexInt:&anInt];
        myBuffer[i / 2] = (char)anInt;
    }
    NSString *unicodeString = [NSString stringWithCString:myBuffer encoding:4];
    return unicodeString;
}

//普通字符串转换为十六进制的。
+ (NSString *)hexStringFromString:(NSString *)string {
    NSData *myD = [string dataUsingEncoding:NSUTF8StringEncoding];
    Byte *bytes = (Byte *)[myD bytes];
    //下面是Byte 转换为16进制。
    NSString *hexStr=@"";
    for(int i=0;i<[myD length];i++) {
        
        NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];///16进制数
        if([newHexStr length]==1){
            
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        }
        else {
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
        }
    }
    return hexStr;
}


//判断一个字符串是否可以转化为整数
+ (BOOL)isPureInt:(NSString *)string {
    
    if (!string || ![string isKindOfClass:[NSString class]] ) {
        return NO;
    }
    NSScanner *scan = [NSScanner scannerWithString:string];
    int val;
    return[scan scanInt:&val] && [scan isAtEnd];
}

#pragma mark - 格式控制

//字符串最多40个字符
+ (NSString *)return40CharacterStringWithString:(NSString *)string {
    
    if (![string isKindOfClass:[NSString class]]) {
        return string;
    }
    
    static NSInteger const maxLength = 40;//长度40
    NSInteger length = string.length;
    if (length <= maxLength) {
        return string;
    }
    NSInteger preCount = maxLength/2;
    NSString *prefixString = [string substringToIndex:preCount];
    
    NSInteger subCount = maxLength-preCount-1;
    NSString *subfixString = [string substringWithRange:NSMakeRange(length-subCount, subCount)];
    //取前面的19个，后面的20个字符串进行拼接
    string = [NSString stringWithFormat:@"%@_%@",prefixString,subfixString];
    return string;
}

//返回最多maxLength个字符的字符串，从头开始截取
+ (NSString *)returnStringWithString:(NSString *)string forMaxLength:(NSInteger)maxLength {
    
    if (![string isKindOfClass:[NSString class]]) {
        return string;
    }
    
    if (maxLength < 1) {
        maxLength = 1;
    }
    
    NSInteger length = string.length;
    if (length <= maxLength) {
        return string;
    }
    string = [string substringToIndex:maxLength];
    return string;
}


///删除字符串中的16进制字符串
+ (NSString *)deleteHexadecimalString:(NSString *)str {
    
    if (![str isKindOfClass:[NSString class]]) {
        return @"";
    }
    
    //为了数据库查询统计时合并msg方便，删除msg中的NSUnderlyingErrorKey对象(NSError)地址字符串
    NSRange hexRange = [str rangeOfString:@"0x"];
    while (hexRange.location != NSNotFound) {
        NSUInteger addressLocation = hexRange.location;
        NSUInteger addressLength = 11;
        if (str.length >= (addressLocation+addressLength)) {
            NSString *addressStr = [str substringWithRange:NSMakeRange(addressLocation, addressLength)];
            str = [str stringByReplacingOccurrencesOfString:addressStr withString:@""];
            NSLogRVSDK(@"删除Hex地址 addressStr=%@",addressStr);
        } else {
            NSLogRVSDK(@"居然超出了范围 str=%@,addressLocation=%zd",str,addressLocation);
            break;
        }
        hexRange = [str rangeOfString:@"0x"];
    }
    return str;
}

/// 删除Base64格式前缀
+ (NSString *)removeBase64DataFormatPrefix:(NSString *)originalBase64Str {
    NSString *resultStr = originalBase64Str;
    NSArray *components = [originalBase64Str componentsSeparatedByString:@"base64,"];
    if (components.count > 1) {
        resultStr = components[1];
    }
    return resultStr;
}
@end
