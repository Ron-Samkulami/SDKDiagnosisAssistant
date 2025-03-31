//
//  RSPingService.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSPingService.h"
#import "RSPing.h"
#import "RSPingResult.h"
#import "RSNetDiagnosisLog.h"

@interface RSPingService() <RSPingDelegate>
@property (nonatomic, strong) RSPing *icmpPing;
@property (nonatomic, strong) NSMutableDictionary *pingResDic;
@property (nonatomic, copy, readonly) RSPingResultHandler pingResultHandler;
@property (nonatomic, copy, readonly) RSPingConclusionHandler pingConclusionHandler;
@end

@implementation RSPingService


+ (instancetype)shareInstance
{
    static id instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}

- (void)startPingHost:(NSString *)host packetCount:(int)count resultHandler:(RSPingResultHandler)handler
{
    // remove old task
    if (_icmpPing) {
        _icmpPing.delegate = nil;
        [_icmpPing stopPing];
        _icmpPing = nil;
    }
    
    // remove incompatible handler
    if (_pingConclusionHandler) {
        _pingConclusionHandler = nil;
    }
    
    // create new task
    _icmpPing = [[RSPing alloc] init];
    _icmpPing.delegate = self;
    
    // set handler
    _pingResultHandler = handler;
    
    // start
    [_icmpPing startPingHosts:host packetCount:count];
}

- (void)startPingHost:(NSString *)host packetCount:(int)count pingInterval:(float)pingInterval conclusionHandler:(RSPingConclusionHandler)handler
{
    // remove old task
    if (_icmpPing) {
        _icmpPing.delegate = nil;
        [_icmpPing stopPing];
        _icmpPing = nil;
    }
    
    // remove incompatible handler
    if (_pingResultHandler) {
        _pingResultHandler = nil;
    }
    
    // create new task
    _icmpPing = [[RSPing alloc] init];
    _icmpPing.delegate = self;
    _icmpPing.pingInterval = pingInterval;
    
    // set handler
    _pingConclusionHandler = handler;
    
    // start
    [_icmpPing startPingHosts:host packetCount:count];
}

#pragma mark - status
- (void)stopPing
{
    [_icmpPing stopPing];
}

- (BOOL)isPinging
{
    return [_icmpPing isPinging];
}

#pragma mark - RSPingDelegate
- (void)ping:(RSPing *)ping reportResult:(RSPingResult *)pingRes withStatus:(RSPingStatus)status
{
    [self savePingRes:pingRes forIpAddress:pingRes.IPAddress];
    
    if (status == RSPingStatusFinished) {
        // caclute loss and report
        [self calculateLossOfIp:pingRes.IPAddress];
        return;
    }
    
    if (_pingResultHandler) {
        // report single response
        NSString *pingDetail = [NSString stringWithFormat:@"%d bytes form %@ icmp_seq=%d ttl=%d time=%.3fms",(int)pingRes.dateBytesLength, pingRes.IPAddress, (int)pingRes.ICMPSequence,(int)pingRes.timeToLive,pingRes.timeMilliseconds];
        _pingResultHandler(pingDetail, NO);
    }
    
}

#pragma mark - result
- (void)savePingRes:(RSPingResult *)pingRes forIpAddress:(NSString *)ipAddress
{
    if (ipAddress == NULL || pingRes == NULL) {
        return;
    }
    
    NSMutableArray *pingItems = [self.pingResDic objectForKey:ipAddress];
    if (pingItems == NULL) {
        pingItems = [NSMutableArray arrayWithArray:@[pingRes]];
    } else {
        try {
            [pingItems addObject:pingRes];
        } catch (NSException *exception) {
            log4cplus_warn("PhoneNetPing", "func: %s, exception info: %s , line: %d",__func__,[exception.description UTF8String],__LINE__);
        }
    }
    
    [self.pingResDic setObject:pingItems forKey:ipAddress];
}

- (void)calculateLossOfIp:(NSString *)ipAddress
{
    if (ipAddress == NULL) {
        NSString *pingSummary = @"Ping failed with empty destination ip address";
        if (_pingResultHandler) _pingResultHandler(pingSummary, YES);
        if (_pingConclusionHandler) _pingConclusionHandler(nil);
        return;
    }
    
    NSArray *pingResultArr = [self.pingResDic objectForKey:ipAddress];
    RSPingConclusion *pingConclusion = [RSPingConclusion pingConclusionWithPingResults:pingResultArr];
    if (_pingConclusionHandler) _pingConclusionHandler(pingConclusion);
    
    NSString *pingSummary = [NSString stringWithFormat:@"%d packets transmitted , loss:%d%% , min:%0.3fms , avg:%0.3fms , max:%0.3fms , stddev:%0.3fms , ttl:%d", pingConclusion.totolPackets, pingConclusion.loss, pingConclusion.min, pingConclusion.avg, pingConclusion.max, pingConclusion.stddev, pingConclusion.ttl];
    if (_pingResultHandler) _pingResultHandler(pingSummary, YES);
    
    [self removePingResForIpAddress:ipAddress];
}

- (void)removePingResForIpAddress:(NSString *)ipAddress
{
    if (ipAddress == NULL) {
        return;
    }
    [self.pingResDic removeObjectForKey:ipAddress];
}

#pragma mark - Getter

- (NSMutableDictionary *)pingResDic
{
    if (!_pingResDic) {
        _pingResDic = [NSMutableDictionary dictionary];
    }
    return _pingResDic;
}

@end
