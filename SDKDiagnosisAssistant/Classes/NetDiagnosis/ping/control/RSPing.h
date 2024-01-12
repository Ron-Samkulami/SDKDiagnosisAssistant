//
//  RSPing.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

// Add this to use some newer macro
#define __APPLE_USE_RFC_3542

#import <Foundation/Foundation.h>
#import "RSPingResult.h"

@class RSPing;

@protocol RSPingDelegate  <NSObject>

@optional
- (void)ping:(RSPing *)ping reportResult:(RSPingResult *)pingRes withStatus:(RSPingStatus)status;

@end

@interface RSPing : NSObject

@property (nonatomic,strong) id<RSPingDelegate> delegate;

- (void)startPingHosts:(NSString *)host packetCount:(int)count;

- (void)stopPing;
- (BOOL)isPinging;
@end
