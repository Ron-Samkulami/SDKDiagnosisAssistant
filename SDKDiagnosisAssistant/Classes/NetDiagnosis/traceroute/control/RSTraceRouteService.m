//
//  RSTraceRouteService.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSTraceRouteService.h"
#import "RSICMPTraceRoute.h"
#import "RSTraceRouteResult.h"

@interface RSTraceRouteService() <RSICMPTraceRouteDelegate>
@property (nonatomic, strong) RSICMPTraceRoute *traceroute;
@property (nonatomic, copy, readonly) RSTraceRouteResultHandler traceRouteResultHandler;
@end

@implementation RSTraceRouteService


+ (instancetype)shareInstance
{
    static id instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}


- (void)stopTraceroute
{
    [self.traceroute stopTraceroute];
}

- (BOOL)isTracerouting
{
    return [self.traceroute isTracerouting];
}

- (void)startTracerouteHost:(NSString *)host 
              resultHandler:(RSTraceRouteResultHandler)handler
{
    if (_traceroute) {
        // remove old task
        _traceroute.delegate = nil;
        [_traceroute stopTraceroute];
        _traceroute = nil;
    }
    
    // create new task
    _traceroute = [[RSICMPTraceRoute alloc] init];
    _traceroute.delegate = self;
    
    _traceRouteResultHandler = handler;
    
    [_traceroute startTracerouteHost:host];
}

#pragma mark -RSICMPTraceRouteDelegate
- (void)traceRoute:(RSICMPTraceRoute *)traceRoute reportTracerResult:(RSTraceRouteResult *)tracertRes
{
    NSMutableString *mutableDurations = [NSMutableString string];
    BOOL hasValidRes = NO;
    for (int i = 0; i < tracertRes.countPerNode; i++) {
        if (tracertRes.durations[i] <= 0) {
            [mutableDurations appendString:@" *"];
        } else {
            [mutableDurations appendString:[NSString stringWithFormat:@" %.3fms",tracertRes.durations[i] * 1000]];
            hasValidRes = YES;
        }
    }
    NSMutableString *tracertDetail = [NSMutableString string];
    if (hasValidRes) {
        NSString *tracertNormalDetail = [NSString stringWithFormat:@"%d  %@(%@) %@",(int)tracertRes.hop, tracertRes.ip, tracertRes.ip, mutableDurations];
        [tracertDetail appendString:tracertNormalDetail];
        _traceRouteResultHandler(tracertDetail,tracertRes.dstIp, NO);
    } else {
        [tracertDetail appendString:[NSString stringWithFormat:@"%d %@", (int)tracertRes.hop, mutableDurations]];
        _traceRouteResultHandler(tracertDetail,tracertRes.dstIp, NO);
    }
}

- (void)traceRouteDidFinished:(RSICMPTraceRoute *)traceRoute
{
    BOOL isDone = YES;
    _traceRouteResultHandler(nil,nil, isDone);
}

@end
