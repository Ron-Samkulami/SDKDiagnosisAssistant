//
//  RSICMPTraceRoute.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

// Add this to use some newer macro
#define __APPLE_USE_RFC_3542

#import <Foundation/Foundation.h>
#import "RSTraceRouteResult.h"

#define kTraceRouteMaxNoResCount        10      // Max count of no result nodes
#define kTraceRouteMaxHop               30      // Max hops of traceroute
#define kTraceRoutePacketCountPerNode   3       // Send 3 packet on every router node

@class RSICMPTraceRoute;
@protocol RSICMPTraceRouteDelegate<NSObject>

@optional
- (void)traceRoute:(RSICMPTraceRoute *)traceRoute reportTracerResult:(RSTraceRouteResult *)tracertRes;
- (void)traceRouteDidFinished:(RSICMPTraceRoute *)traceRoute;

@end

@interface RSICMPTraceRoute : NSObject
@property (nonatomic,strong) id<RSICMPTraceRouteDelegate> delegate;

- (void)startTracerouteHost:(NSString *)host;

- (void)stopTraceroute;
- (BOOL)isTracerouting;
@end
