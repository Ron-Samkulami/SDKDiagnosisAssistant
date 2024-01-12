//
//  NSUserDefaults+SDKUserDefaults.h
//  RVSDK
//
//  Created by 石学谦 on 2020/7/7.
//  Copyright © 2020 SDK. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSUserDefaults (SDKUserDefaults)

///SDK Log相关功能使用
+ (instancetype)sdkLogUserDefaults;

///SDK内普通功能使用
+ (instancetype)sdkCommonUserDefaults;
@end

NS_ASSUME_NONNULL_END
