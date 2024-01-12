//
//  RVFileLogFormatter.m
//  RVSDK
//
//  Created by 石学谦 on 2020/4/30.
//  Copyright © 2020 SDK. All rights reserved.
//

#import "RVFileLogFormatter.h"

@implementation RVFileLogFormatter

 - (NSString *)formatLogMessage:(VVLogMessage *)logMessage {
     NSString *logLevel = nil;
     switch (logMessage->_flag) {
         case VVLogFlagError:
             logLevel = @"E";
             break;
         case VVLogFlagWarning:
             logLevel = @"W";
             break;
         case VVLogFlagInfo:
             logLevel = @"I";
             break;
         case VVLogFlagDebug:
             logLevel = @"D";
             break;
         default:
             logLevel = @"V";
             break;
     }
     NSString *formatLog = [NSString stringWithFormat:@"%@[%@] %@",[self getTimeStringWithDate:logMessage->_timestamp], logLevel, logMessage->_message];
     return formatLog;
 }


- (NSString *)getTimeStringWithDate:(NSDate *)date {
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyy.MM.dd-HH.mm.ss.S z"];
    });
    return [dateFormatter stringFromDate:NSDate.date];
}

@end
