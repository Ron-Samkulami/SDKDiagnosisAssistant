//
//  RSPingResult.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSPingResult.h"

@implementation RSPingResult

- (NSString *)description {
    return [NSString stringWithFormat:@"ICMPSequence:%d , originalAddress:%@ , IPAddress:%@ , dateBytesLength:%d , timeMilliseconds:%.3fms , timeToLive:%d , tracertCount:%d , status：%d",(int)_ICMPSequence,_originalAddress,_IPAddress,(int)_dateBytesLength,_timeMilliseconds,(int)_timeToLive,(int)_tracertCount,(int)_status];
}

+ (NSDictionary *)pingResultWithPingItems:(NSArray *)pingItems
{
    NSString *address = [pingItems.firstObject originalAddress];
    NSString *dst     = [pingItems.firstObject IPAddress];
    __block NSInteger receivedCount = 0, allCount = 0;
    __block NSInteger ttlSum = 0;
    __block double    timeSum = 0;
    [pingItems enumerateObjectsUsingBlock:^(RSPingResult *obj, NSUInteger idx, BOOL *stop) {
        if (obj.status != RSPingStatusFinished && obj.status != RSPingStatusError) {
            allCount ++;
            if (obj.status == RSPingStatusReceivePacket) {
                receivedCount ++;
                ttlSum += obj.timeToLive;
                timeSum += obj.timeMilliseconds;
            }
        }
    }];
    
    float lossPercent = (allCount - receivedCount) / MAX(1.0, allCount) * 100;
    double avgTime = 0; NSInteger avgTTL = 0;
    int allPacketCount = (int)allCount;
    if (receivedCount > 0) {
        avgTime = timeSum/receivedCount;
        avgTTL = ttlSum/receivedCount;
    } else {
        avgTime = 0;
        avgTTL = 0;
    }
    
    if (address == NULL) {
        address = @"null";
    }
    
    NSDictionary *dict = @{
        @"src_ip":address,
        @"dst_ip":dst,
        @"totolPackets":[NSNumber numberWithInt:allPacketCount],
        @"loss":[NSNumber numberWithFloat:lossPercent],
        @"delay":[NSNumber  numberWithDouble:avgTime],
        @"ttl":[NSNumber numberWithLong:avgTTL]
    };
    return dict;
    
    return NULL;
}

@end
