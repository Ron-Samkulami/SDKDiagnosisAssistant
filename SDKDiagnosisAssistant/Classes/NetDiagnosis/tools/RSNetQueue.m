//
//  RSNetQueue.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSNetQueue.h"

@interface RSNetQueue()
@property (nonatomic) dispatch_queue_t pingQueue;
@property (nonatomic) dispatch_queue_t traceQueue;

@end

@implementation RSNetQueue

+ (instancetype)shareInstance
{
    static RSNetQueue *unetQueue = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        unetQueue = [[self alloc] init];
    });
    return unetQueue;
}

- (instancetype)init
{
    if (self = [super init]) {
        _pingQueue = dispatch_queue_create("rs_net_ping_queue", DISPATCH_QUEUE_SERIAL);
        _traceQueue = dispatch_queue_create("rs_net_trace_queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (void)rs_net_ping_async:(dispatch_block_t)block
{
    dispatch_async([RSNetQueue shareInstance].pingQueue, ^{
        block();
    });
}

+ (void)rs_net_trace_async:(dispatch_block_t)block
{
    dispatch_async([RSNetQueue shareInstance].traceQueue , ^{
        block();
    });
}

@end
