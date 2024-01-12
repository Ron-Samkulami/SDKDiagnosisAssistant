//
//  RSTraceRouteResult.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSTraceRouteResult.h"

@implementation RSTraceRouteResult

- (instancetype)initWithHop:(NSInteger)hop countPerNode:(NSInteger)countPerNode {
    if (self = [super init]) {
        _ip = nil;
        _hop = hop;
        _countPerNode = countPerNode;
        _durations = (NSTimeInterval*)calloc(countPerNode, sizeof(NSTimeInterval));
        _status = RSTracerouteStatusWoking;
    }
    return self;
}

- (NSString*)description {
    NSMutableString *mutableStr = [NSMutableString string];
    for (int i = 0; i < _countPerNode; i++) {
        if (_durations[i] <= 0) {
            [mutableStr appendString:@"* "];
        }else{
            [mutableStr appendString:[NSString stringWithFormat:@" %.3fms",_durations[i] * 1000]];
        }
    }
    return [NSString stringWithFormat:@"seq:%d , dstIp:%@, routeIp:%@, durations:%@ , status:%d",(int)_hop,_dstIp,_ip,mutableStr,(int)_status];
}


- (void)dealloc {
    free(_durations);
}
@end
