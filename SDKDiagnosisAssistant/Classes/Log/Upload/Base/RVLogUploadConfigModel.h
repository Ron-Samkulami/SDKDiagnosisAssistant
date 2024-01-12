//
//  RVLogUploadConfigModel.h
//  RVSDK
//
//  Created by 石学谦 on 2020/7/6.
//  Copyright © 2020 SDK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RVOnlyLog.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    RVLogUploadNetModeNormal = 0,
    RVLogUploadNetModeWifi,
} RVLogUploadNetMode;

@interface RVLogUploadConfigModel : NSObject

@property (nonatomic, assign)VVLogLevel logLevel;//默认日志等级为3
@property (nonatomic, assign)RVLogUploadNetMode mode;//默认上传模式为0
@property (nonatomic, assign)long long sliceSize;//默认256KB
@property (nonatomic, copy)NSString *path;//研发日志路径
@property (nonatomic, copy)NSString *sign;//研发路径md5值，规则为：md5(gameId+package+model+level+path)

- (instancetype)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
