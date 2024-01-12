//
//  RVResponseParser.m
//  sqwsdk
//
//  Created by 朱 圣 on 11/5/13.
//  Copyright (c) 2013 37wan. All rights reserved.
//

#import "RVResponseParser.h"
#import "RVOnlyLog.h"

@interface RVResponseParser ()

@property (nonatomic, copy) NSString *urlString;

@end


@implementation RVResponseParser

- (instancetype)initWithURL:(NSString *)urlString {
    
    self = [super init];
    if (self) {
        _urlString = urlString ?: @"";
    }
    return self;
}

- (int)checkCode:(id )code
{
    int result = 0;
    if ([code isKindOfClass:[NSString class]]) {
         result =  [((NSString*)code) intValue];
    }
    if ([code isKindOfClass:[NSNumber class]]) {
        result =  [((NSNumber*)code) intValue];
    }
    
    return result;
}

- (NSString*)checkMessage:(id )message
{
     NSString *str = @"";
    if([message isKindOfClass:[NSString class]])
    {
       str = message;
    }
    return str;
}

- (void)parseResponseObject:(id)responseObj
{
    if(responseObj == nil)
    {
        NSLogRVSDK(@"返回的json字符串为空");
        _message = @"JSON parsed wrong.";
        return;
    }
        
    if (![responseObj isKindOfClass:[NSDictionary class]]) {
        _message = @"Response parsed wrong";
        NSLogInfo(@"(解析格式报错：responseObj为非NSDictionary类型)返回的响应：urlString=%@ responseObj=%@",_urlString,responseObj);
        return;
    }
    //将NSNULL转为空字符串
    _dicResult = (NSDictionary *)[self convertNullToEmptyStringForObject:responseObj];
//    NSLog(@"返回的响应：urlString=%@\n%@",_urlString,_dicResult);
    //解析result结果(无论是NSNumber类型还是NSString类型，都处理)
    id codeStr = [_dicResult objectForKey:@"result"];
    _code = [self checkCode:codeStr];
    //解析msg
    _message = [self checkMessage:[_dicResult objectForKey:@"msg"]];
    //解析data，当result为0时，data为[]
    NSDictionary *dicResult = (NSDictionary *)[_dicResult objectForKey:@"data"];
    if ([dicResult isKindOfClass:[NSDictionary class]] && dicResult.count>0) {
        _resultData = dicResult;
    }
    //解析错误码，只有失败时才解析
    if (_code != 1) {
        id errorCodeStr = [_dicResult objectForKey:@"code"];
        if (!errorCodeStr) {
             errorCodeStr = [_dicResult objectForKey:@"error_code"];
        }
        _errorCode = [self checkCode:errorCodeStr];
    }
}
-(id)convertNullToEmptyStringForObject:(id)myObj

{
    if ([myObj isKindOfClass:[NSDictionary class]])//字典类型
    {
        NSArray *keyArr = [(NSDictionary *)myObj allKeys];
        NSMutableDictionary *resDic = [[NSMutableDictionary alloc] init];
        for (id<NSCopying> key in keyArr) {
            id obj = [myObj objectForKey:key];
            //递归调用
            obj = [self convertNullToEmptyStringForObject:obj];
            [resDic setObject:obj forKey:key];
        }
        return resDic;
    }
    else if([myObj isKindOfClass:[NSArray class]])//数组类型
    {
        NSMutableArray *resArr = [NSMutableArray arrayWithCapacity:[(NSArray *)myObj count]];
        for (id value in (NSArray *)myObj) {
            //递归调用
            id obj = [self convertNullToEmptyStringForObject:value];
            [resArr addObject:obj];
        }
        return resArr;
    }
    else if([myObj isKindOfClass:[NSNull class]])//NSNull类型
    {
        return @"";
    }
    else//其他类型
    {
        return myObj;
    }
}
@end
