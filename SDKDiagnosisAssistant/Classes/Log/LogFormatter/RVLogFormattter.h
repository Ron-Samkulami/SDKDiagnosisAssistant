//
//  RVLogFormattter.h
//
//  Created by 石学谦 on 2020/4/1.
//  Copyright © 2020 shixueqian. All rights reserved.
//  实现VVLogFormatter协议，用来控制控制台的日志级别

#import <Foundation/Foundation.h>
#import "RVOnlyLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface RVLogFormattter : NSObject<VVLogFormatter>

@property (nonatomic,assign) BOOL isDebugMode;

@end

NS_ASSUME_NONNULL_END
