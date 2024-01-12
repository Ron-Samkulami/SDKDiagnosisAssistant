//
//  RVLogFileManager.m
//
//  Created by 石学谦 on 2020/1/2.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import "RVLogFileManager.h"
#import "RSXToolSet.h"

@implementation RVLogFileManager

//======重写newLogFileName和isLogFile方法来覆盖======

/// log文件名
- (NSString *)newLogFileName {
    
    NSString *timeStamp = [self getTimestamp];
    
    return [NSString stringWithFormat:@"%@.log", timeStamp];
}

/// 判断是否是log文件
- (BOOL)isLogFile:(NSString *)fileName {
    
    BOOL hasProperSuffix = [fileName hasSuffix:@".log"];
    
    return hasProperSuffix;
}

/// log存放文件夹
- (NSString *)defaultLogsDirectory {

    NSString *sdkApplicationSupportPath = [RSXToolSet getSDKApplicationSupportPath];
    NSString *logsDirectory = [sdkApplicationSupportPath stringByAppendingPathComponent:@"RVLog/log"];

    return logsDirectory;
}

#pragma mark - 内部方法

- (NSString *)getTimestamp {
    static dispatch_once_t onceToken;
    static NSDateFormatter *dateFormatter;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyy.MM.dd-HH.mm.ss"];
    });
    return [dateFormatter stringFromDate:NSDate.date];
}

@end
