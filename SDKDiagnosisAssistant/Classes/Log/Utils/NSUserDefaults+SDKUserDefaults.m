//
//  NSUserDefaults+SDKUserDefaults.m
//  RVSDK
//
//  Created by 石学谦 on 2020/7/7.
//  Copyright © 2020 SDK. All rights reserved.
//

#import "NSUserDefaults+SDKUserDefaults.h"

@implementation NSUserDefaults (SDKUserDefaults)

+ (instancetype)sdkLogUserDefaults {
    static id logUserDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.sdk.log.service"];
    });
    return logUserDefaults;
}

+ (instancetype)sdkCommonUserDefaults {
    static id logUserDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.sdk.common.config"];
    });
    return logUserDefaults;
}

@end
