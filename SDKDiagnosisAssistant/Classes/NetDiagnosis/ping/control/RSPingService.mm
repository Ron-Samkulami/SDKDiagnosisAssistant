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
#import "RSPingConclusion.h"
#import "RSNetDiagnosisLog.h"

@interface RSPingService() <RSPingDelegate>
@property (nonatomic, strong) RSPing *icmpPing;
@property (nonatomic, strong) NSMutableDictionary *pingResDic;
@property (nonatomic, copy, readonly) RSPingResultHandler pingResultHandler;

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
    //    if ([self isPinging]) {
    //        return;
    //    }
    if (_icmpPing) {
        // remove old task
        _icmpPing.delegate = nil;
        [_icmpPing stopPing];
        _icmpPing = nil;
    }
    
    // create new task
    _icmpPing = [[RSPing alloc] init];
    _icmpPing.delegate = self;
    
    _pingResultHandler = handler;
    
    [_icmpPing startPingHosts:host packetCount:count];
}

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
    [self addPingResToPingResContainer:pingRes andHost:pingRes.IPAddress];
    
    if (status == RSPingStatusFinished) {
        [self calculateLossOfHost:pingRes.IPAddress];
        return;
    }
    
    NSString *pingDetail = [NSString stringWithFormat:@"%d bytes form %@ icmp_seq=%d ttl=%d time=%.3fms",(int)pingRes.dateBytesLength, pingRes.IPAddress, (int)pingRes.ICMPSequence,(int)pingRes.timeToLive,pingRes.timeMilliseconds];
    _pingResultHandler(pingDetail, NO);
}

#pragma mark - result
- (void)addPingResToPingResContainer:(RSPingResult *)pingItem andHost:(NSString *)host
{
    if (host == NULL || pingItem == NULL) {
        return;
    }
    
    NSMutableArray *pingItems = [self.pingResDic objectForKey:host];
    if (pingItems == NULL) {
        pingItems = [NSMutableArray arrayWithArray:@[pingItem]];
    } else {
        try {
            [pingItems addObject:pingItem];
        } catch (NSException *exception) {
            log4cplus_warn("PhoneNetPing", "func: %s, exception info: %s , line: %d",__func__,[exception.description UTF8String],__LINE__);
        }
    }
    
    [self.pingResDic setObject:pingItems forKey:host];
}

- (void)calculateLossOfHost:(NSString *)host
{
    if (host == NULL) {
        NSString *pingSummary = @"Ping failed with empty destination ip address";
        self.pingResultHandler(pingSummary, YES);
        return;
    }
    NSArray *pingItems = [self.pingResDic objectForKey:host];
    NSDictionary *dict = [RSPingResult pingResultWithPingItems:pingItems];
    RSPingConclusion *reportPingModel = [RSPingConclusion pingConclusionWithDict:dict];
    
    NSString *pingSummary = [NSString stringWithFormat:@"%d packets transmitted , loss:%d%% , delay:%0.3fms , ttl:%d",reportPingModel.totolPackets,reportPingModel.loss,reportPingModel.delay,reportPingModel.ttl];
    self.pingResultHandler(pingSummary, YES);
    
    [self removePingResFromPingResContainerWithHostName:host];
}

- (void)removePingResFromPingResContainerWithHostName:(NSString *)host
{
    if (host == NULL) {
        return;
    }
    [self.pingResDic removeObjectForKey:host];
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
