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


@end
