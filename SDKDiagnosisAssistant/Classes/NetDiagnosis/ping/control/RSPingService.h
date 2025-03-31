//
//  RSPingService.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSPingConclusion.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(^RSPingResultHandler)(NSString *_Nullable pingres, BOOL isDone);
typedef void(^RSPingConclusionHandler)(RSPingConclusion *_Nullable pingConclusion);

@interface RSPingService : NSObject

+ (instancetype)shareInstance;

- (void)startPingHost:(NSString *)host
          packetCount:(int)count
        resultHandler:(RSPingResultHandler)handler;

- (void)startPingHost:(NSString *)host
          packetCount:(int)count
         pingInterval:(float)pingInterval
    conclusionHandler:(RSPingConclusionHandler)handler;

- (void)stopPing;
- (BOOL)isPinging;

NS_ASSUME_NONNULL_END
@end
