//
//  RVLogUploadSettingModel.m
//  RVSDK
//
//  Created by 石学谦 on 2020/7/6.
//  Copyright © 2020 SDK. All rights reserved.
//

#import "RVLogUploadSettingModel.h"
#import "RVLogUploadConfigModel.h"
#import "RVOnlyLog.h"
#import "NSStringUtils.h"

@implementation RVLogUploadSettingModel

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (self = [super init]) {
        
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        
        NSString *uploadId = dict[@"uploadId"];
        _uploadId = nil;
        if (!isStringEmpty(uploadId)) {
            _uploadId = uploadId;
        }
        
        NSString *token = dict[@"token"];
        _token = nil;
        if (!isStringEmpty(token)) {
            _token = token;
        }
        
        NSNumber *isAllowed = dict[@"isAllowed"];
        _isAllowed = NO;
        if ([isAllowed isKindOfClass:[NSNumber class]] || [isAllowed isKindOfClass:[NSString class]]) {
            _isAllowed = [isAllowed boolValue];
        }
        if (!_uploadId || !_token) {
            _isAllowed = NO;
        }
        
        NSDictionary *configDict = dict[@"config"];
        _config = [[RVLogUploadConfigModel alloc] initWithDict:configDict];
    }
    return self;
}

@end
