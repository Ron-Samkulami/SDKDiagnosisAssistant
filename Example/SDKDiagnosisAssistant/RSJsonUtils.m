//
//  RSJsonUtils.m
//  SDKDiagnosisAssistant_Example
//
//  Created by 黄雄荣 on 2024/1/5.
//  Copyright © 2024 Ron-Samkulami. All rights reserved.
//

#import "RSJsonUtils.h"

@implementation RSJsonUtils

#pragma mark - JSON字符串与字典转换
//dictonary转JSON字符串(JSON带格式)
+ (NSString *)jsonStringFromDictionary:(NSDictionary *)dict
{
    if (!dict) {
        //NSLogInfo(@"字典转JSON字符串出错 dict==nil");
        return nil;
    }
    
    NSError *error = nil;
    NSData *jsonData = nil;
    @try {
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    } @catch (NSException *exception) {
        //NSLogError(@"字典转JSON字符串异常，请检查字典key-value是否合法 jsonData==nil dict=%@,error=%@",dict, error);
    }
    
    if (!jsonData) {
        //NSLogError(@"字典转JSON字符串出错 jsonData==nil dict=%@,error=%@",dict, error);
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end
