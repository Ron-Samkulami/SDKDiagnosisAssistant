//
//  RSNetDetector.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSNetDetector.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "RSDomainLookup.h"
#import "RSPingService.h"
#import "RSTraceRouteService.h"
#import "RSTCPPing.h"
#import "RSAsyncTaskQueue.h"

@implementation RSNetDetector

+ (instancetype)shared 
{
    static id instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}

- (void)detectHost:(NSString *)host 
          complete:(void(^)(NSString *detectLog))complete
{
    if (_isDetecting) {
        return;
    }
    _isDetecting = YES;
    
    // create async task queue
    NSString *queueID = [NSString stringWithFormat:@"com.RVSDK.NetworkDetector-%f",[[NSDate date] timeIntervalSince1970]];
    RSAsyncTaskQueue *queue = [[RSAsyncTaskQueue alloc] initWithIdentifier:[queueID UTF8String]];
    
    __block NSMutableString *log = [[NSMutableString alloc] initWithString:@""];
    
    // NSLog(@"=== Detecting host：%@ ===",host);
    [log appendFormat:@"\n=== Detecting host：%@ ===", host];
    
    // 1、DNS Loopup
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        // NSLog(@">>> DNS Lookup \n");
        [log appendString:@"\n>>> DNS Lookup \n"];
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        [self dnsLookupWithHost:host complete:^(NSString * _Nonnull detectLog) {
            // NSLog(@"%@", detectLog);
            taskFinished();
            [log appendFormat:@"host = %@,\nlookup result = %@\n",host, detectLog];
            CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
            [log appendFormat:@"<<< DNS Lookup done! Time consuming: %fs \n",endTime];
        }];
    }];
    
    // 2、TCP Ping
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        // NSLog(@">>> TCP Ping \n");
        [log appendString:@"\n>>> TCP Ping \n"];
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        [self tcpPingWithHost:host complete:^(NSString * _Nonnull detectLog) {
            // NSLog(@"%@", detectLog);
            taskFinished();
            [log appendFormat:@"%@\n",detectLog];
            CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
            [log appendFormat:@"<<< TCP Ping done! Time consuming: %fs \n",endTime];
        }];
    }];
    
    // 3、icmp Ping
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        // NSLog(@">>> ICMP Ping \n");
        [log appendString:@"\n>>> ICMP Ping \n"];
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        [self icmpPingWithHost:host complete:^(NSString * _Nonnull detectLog) {
            // NSLog(@"%@", detectLog);
            taskFinished();
            [log appendFormat:@"%@\n",detectLog];
            CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
            [log appendFormat:@"<<<  ICMP Ping done! Time consuming: %fs \n",endTime];
        }];
    }];
    
    // 4、icmp traceroute
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        // NSLog(@">>> ICMP Traceroute \n");
        [log appendString:@"\n>>> ICMP Traceroute \n"];
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        [self icmpTracerouteWithHost:host complete:^(NSString * _Nonnull detectLog) {
            // NSLog(@"%@", detectLog);
            taskFinished();
            [log appendFormat:@"%@\n",detectLog];
            CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
            [log appendFormat:@"<<<  ICMP Traceroute done! Time consuming: %fs \n",endTime];
        }];
    }];
    
    
    queue.completeHandler = ^{
        self.isDetecting = NO;
        if (complete) {
            complete(log);
        }
    };
    
    [queue engage];
}


- (void)detectHostList:(NSArray<NSString *> *)hostList 
              complete:(void(^)(NSString *detectLog))complete
{
    if (hostList.count <= 0) {
        return;
    }

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    __block NSMutableString *log = [[NSMutableString alloc] initWithString:@""];
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
        for (NSString *host in hostList) {
            
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            [self detectHost:host complete:^(NSString * _Nonnull detectLog) {
                [log appendString:detectLog];
                dispatch_semaphore_signal(sema);
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            
        }
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
        [log appendFormat:@"\n=== All Done! Time consuming in total: %f s",endTime];
        // NSLog(@"==== All Done! Time consuming in total: %f s",endTime);
        if (complete) {
            complete(log);
        }
    });
}

#pragma mark - Dectect Single Items

- (void)dnsLookupWithHost:(NSString *)host 
                 complete:(void(^)(NSString *detectLog))complete
{
    if (!complete) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No lookup complete handler" userInfo:nil];
        return;
    }
    [[RSDomainLookup shareInstance] lookupDomain:host completeHandler:^(NSMutableArray<RSDomainLookUpResult *> * _Nullable lookupRes, NSError * _Nullable error) {
//        NSLog(@"%@", lookupRes.description);
        if (complete) {
            dispatch_async(dispatch_get_main_queue(), ^{
                complete(lookupRes.description);
            });
        }
    }];
}


- (void)tcpPingWithHost:(NSString *)host 
               complete:(void(^)(NSString *detectLog))complete
{
    if (!complete) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No tcp ping complete handler" userInfo:nil];
        return;
    }
    [RSTCPPing start:host port:80 count:10 complete:^(NSMutableString *tcpPingRes, BOOL isDone) {
        if (isDone) {
//            NSLog(@"%@", tcpPingRes);
            if (complete) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(tcpPingRes);
                });
            }
        }
    }];
}

- (void)icmpPingWithHost:(NSString *)host 
                complete:(void(^)(NSString *detectLog))complete
{
    if (!complete) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No ping complete handler" userInfo:nil];
        return;
    }
    
    __block NSMutableString *log = [[NSMutableString alloc] initWithString:@""];
    int packetCount = 10;
    [[RSPingService shareInstance] startPingHost:host packetCount:packetCount resultHandler:^(NSString * _Nullable pingres, BOOL isDone) {
//        NSLog(@"%@", pingres);
        [log appendFormat:@"%@\n",pingres];
        if (isDone) {
            if (complete) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(log);
                });
            }
        }
    }];
}


- (void)icmpTracerouteWithHost:(NSString *)host 
                      complete:(void(^)(NSString *detectLog))complete
{
    if (!complete) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No traceroute complete handler" userInfo:nil];
        return;
    }
    __block NSMutableString *log = [[NSMutableString alloc] initWithString:@""];
    [[RSTraceRouteService shareInstance] startTracerouteHost:host resultHandler:^(NSString * _Nullable tracertRes, NSString * _Nullable destIp, BOOL isDone) {
        if (tracertRes) {
//            NSLog(@"%@\n",tracertRes);
            [log appendFormat:@"%@\n",tracertRes];
        }
        if (isDone) {
            if (complete) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(log);
                });
            }
        }
    }];
}


- (void)setLogLevel:(RSNetDiagnosisLogLevel)logLevel {
    [RSNetDiagnosisLog setLogLevel:logLevel];
}

@end
