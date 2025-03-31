//
//  RSPingResult.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RSPingStatus) {
    RSPingStatusStart,
    RSPingStatusSendPacketFailed,
    RSPingStatusReceivePacket,
    RSPingStatusReceiveUnexpectedPacket,
    RSPingStatusTimeout,
    RSPingStatusError,
    RSPingStatusFinished,
};

@interface RSPingResult : NSObject

@property (nonatomic) NSString *originalAddress;
@property (nonatomic, copy) NSString *IPAddress;
@property (nonatomic) NSUInteger dateBytesLength;
@property (nonatomic) float timeMilliseconds;
@property (nonatomic) NSInteger timeToLive;
@property (nonatomic) NSInteger tracertCount;
@property (nonatomic) NSInteger ICMPSequence;
@property (nonatomic) RSPingStatus status;


@end
