//
//  RVLogUploadConfigModel.m
//  RVSDK
//
//  Created by 石学谦 on 2020/7/6.
//  Copyright © 2020 SDK. All rights reserved.
//

#import "RVLogUploadConfigModel.h"

#import "RVOnlyLog.h"
#import "NSStringUtils.h"
#import "RVNetUtils.h"

@implementation RVLogUploadConfigModel

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (self = [super init]) {
        
        //默认配置
        _logLevel = VVLogLevelInfo;
        _mode = RVLogUploadNetModeNormal;
        _sliceSize = 256*1024;
        _path = nil;
        
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return self;
        }
        
        NSString *levelStr = dict[@"level"];
        NSString *mode = dict[@"model"];
        NSString *sliceSize = dict[@"slice"];
        NSString *path = dict[@"path"];

        //log等级设置
        if (!isStringEmpty(levelStr)) {
            NSInteger level = [levelStr integerValue];
            switch (level) {
                case 0:
                {
                    _logLevel = VVLogLevelOff;
                   break;
                }
                case 1:
                {
                    _logLevel = VVLogLevelError;
                   break;
                }
                case 2:
                {
                    _logLevel = VVLogLevelWarning;
                   break;
                }
                case 3:
                {
                    _logLevel = VVLogLevelInfo;
                   break;
                }
                case 4:
                {
                    _logLevel = VVLogLevelDebug;
                   break;
                }
                case 5:
                {
                    _logLevel = VVLogLevelVerbose;
                   break;
                }
                default:
                    break;
            }
        }
        
        //上传模式设置
        if (!isStringEmpty(mode)) {
            NSInteger modeValue = mode.integerValue;
            if (modeValue == 1) {
                _mode = RVLogUploadNetModeWifi;
            }
        }
        //切片大小设置
        if (!isStringEmpty(sliceSize)) {
            //后台返回来的单位是K，我们用的单位是B 1K = 1024B
            _sliceSize = sliceSize.longLongValue * 1024;
        }
        if (!isStringEmpty(path)) {
            _path = path;
        }
        
    }
    return self;
}

@end
