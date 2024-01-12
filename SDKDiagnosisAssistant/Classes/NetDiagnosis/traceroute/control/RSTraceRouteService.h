//
//  RSTraceRouteService.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^RSTraceRouteResultHandler)(NSString *_Nullable traceRouteRes ,NSString *_Nullable destIp , BOOL isDone);

@interface RSTraceRouteService : NSObject

+ (instancetype)shareInstance;

/**
 @brief Traceroute a  host.
 
 @discussion Start traceroute a  host addresses

 @param host ip or doman
 @param handler traceroute results
 */
- (void)startTracerouteHost:(NSString *)host resultHandler:(RSTraceRouteResultHandler)handler;

- (void)stopTraceroute;

- (BOOL)isTracerouting;

NS_ASSUME_NONNULL_END

@end
