//
//  RSPingConclusion.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSPingConclusion.h"

@implementation RSPingConclusion

+ (instancetype)pingConclusionWithDict:(NSDictionary *)dict
{
    return [[self alloc] initWithDict:dict];
}

+ (instancetype)pingConclusionWithPingResults:(NSArray <RSPingResult *>*)pingResultArr
{
    RSPingResult *firstRes = pingResultArr.firstObject;
    NSString *address = [firstRes originalAddress];
    NSString *dst     = [firstRes IPAddress];
    
    NSMutableArray<RSPingResult *> *validPingResultArr = [NSMutableArray array];
    __block int allCount = 0;
    __block NSInteger ttlSum = 0;
    __block double    timeSum = 0;
    __block double    timeMax = [firstRes timeMilliseconds];
    __block double    timeMin = [firstRes timeMilliseconds];
    [pingResultArr enumerateObjectsUsingBlock:^(RSPingResult *obj, NSUInteger idx, BOOL *stop) {
        if (obj.status != RSPingStatusFinished && obj.status != RSPingStatusError) {
            allCount ++;
            if (obj.status == RSPingStatusReceivePacket) {
                [validPingResultArr addObject:obj];
                ttlSum += obj.timeToLive;
                timeSum += obj.timeMilliseconds;
                timeMax = MAX(timeMax, obj.timeMilliseconds);
                timeMin = MIN(timeMin, obj.timeMilliseconds);
            }
        }
    }];
    
    NSUInteger validCount = validPingResultArr.count;
    // caclute loss
    float lossPercent = (allCount - validCount) / MAX(1.0, allCount) * 100;
    
    // caclute average time and ttl
    double avgTime = 0;
    NSInteger avgTTL = 0;
    if (validCount > 0) {
        avgTime = timeSum/validCount;
        avgTTL = ttlSum/validCount;
    }
    
    // caclute standardDeviation
    double varianceSum = 0.0;
    for (RSPingResult *pingRes in validPingResultArr) {
        double diff = pingRes.timeMilliseconds - avgTime;
        varianceSum += diff * diff;
    }
    double standardDeviation = sqrt(varianceSum / validCount);
    
    
    if (address == NULL) {
        address = @"null";
    }
    
    //
    NSDictionary *dict = @{
        @"src_ip": address,
        @"dst_ip": dst,
        @"totolPackets": [NSNumber numberWithInt:allCount],
        @"loss": [NSNumber numberWithFloat:lossPercent],
        @"avg": [NSNumber numberWithDouble:avgTime],
        @"stddev": [NSNumber numberWithDouble:standardDeviation],
        @"max": [NSNumber numberWithDouble:timeMax],
        @"min": [NSNumber numberWithDouble:timeMin],
        @"ttl": [NSNumber numberWithLong:avgTTL]
    };
    
    return [[self alloc] initWithDict:dict];

}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    if (self = [super init]) {
        self.src_ip = dict[@"src_ip"];
        self.dst_host = dict[@"dst_host"];
        self.dst_ip = dict[@"dst_ip"];
        self.totolPackets = [dict[@"totolPackets"] intValue];
        self.loss   = [dict[@"loss"] intValue];
        self.avg  = [dict[@"avg"] floatValue];
        self.stddev = [dict[@"stddev"] floatValue];
        self.max    = [dict[@"max"] floatValue];
        self.min    = [dict[@"min"] floatValue];
        self.ttl    = [dict[@"ttl"] intValue];
        self.timestamp = [dict[@"timestamp"] floatValue];
    }
    return self;
}

- (NSDictionary *)beanToDict
{
    return @{
        @"src_ip": self.src_ip,
        @"dst_host": self.dst_host,
        @"dst_ip": self.dst_ip,
        @"totolPackets": @(self.totolPackets),
        @"loss": @(self.loss),
        @"avg": @(self.avg),
        @"stddev": @(self.stddev),
        @"max": @(self.max),
        @"min": @(self.min),
        @"ttl": @(self.ttl),
        @"timestamp": @(self.timestamp)
    };
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"src_ip:%@ , dst_host:%@, dst_ip:%@ , totalPackets:%d , loss:%d%% , min:%@ , avg:%@ ,  max:%@ , stddev:%@ , ttl:%d , timestamp:%f",
            self.src_ip,
            self.dst_host,
            self.dst_ip,
            self.totolPackets,
            self.loss,
            [NSString stringWithFormat:@"%.3fms",self.min],
            [NSString stringWithFormat:@"%.3fms",self.avg],
            [NSString stringWithFormat:@"%.3fms",self.max],
            [NSString stringWithFormat:@"%.3fms",self.stddev],
            self.ttl,
            self.timestamp];
}

@end
