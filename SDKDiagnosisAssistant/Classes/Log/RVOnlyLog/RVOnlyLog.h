//
//  RVOnlyLog.h
//  RVSDK
//
//  Created by 赵睿 on 2022/4/28.
//  Copyright © 2022 SDK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CocoaVVLog.h"

//! Project version number for RVOnlyLog.
FOUNDATION_EXPORT double RVOnlyLogVersionNumber;

//! Project version string for RVOnlyLog.
FOUNDATION_EXPORT const unsigned char RVOnlyLogVersionString[];

//需要设置这个变量，需要修改动态修改level，可以在代码中直接赋值
extern const VVLogLevel vvLogLevel;

#define NSLogRVSDK(frmt, ...)       NSLogDebug((frmt), ##__VA_ARGS__)
// 提供不同的宏，对应到特定参数的对外接口
#define NSLogError(frmt, ...)       VVLogError((frmt), ##__VA_ARGS__)
#define NSLogWarn(frmt, ...)        VVLogWarn((frmt), ##__VA_ARGS__)
#define NSLogInfo(frmt, ...)        VVLogInfo((frmt), ##__VA_ARGS__)
#define NSLogDebug(frmt, ...)       VVLogDebug((frmt), ##__VA_ARGS__)
#define NSLogVerbose(frmt, ...)     VVLogVerbose((frmt), ##__VA_ARGS__)


//extern NSString *const RVFileLogLevelKey;

