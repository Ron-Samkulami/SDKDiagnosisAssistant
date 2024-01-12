//
//  RSTCPPing.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSTCPPing.h"
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#include <netinet/in.h>
#include <netinet/tcp.h>

#import "RSNetDiagnosisHelper.h"
#import "RSNetInfoUtils.h"

//MARK: - RSTCPPingResult

@implementation RSTCPPingResult

- (instancetype)init:(NSString *)ip
                loss:(NSUInteger)loss
               count:(NSUInteger)count
                 max:(NSTimeInterval)maxTime
                 min:(NSTimeInterval)minTime
                 avg:(NSTimeInterval)avgTime
{
    if (self = [super init]) {
        _ip = ip;
        _loss = loss;
        _count = count;
        _max_time = maxTime;
        _avg_time = avgTime;
        _min_time = minTime;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"TCP connect loss=%lu,  min/avg/max = %.2f/%.2f/%.2fms",(unsigned long)self.loss,self.min_time,self.avg_time,self.max_time];
}

@end


//MARK: - RSTCPPing

static RSTCPPing *g_tcpPing = nil;
void tcp_connect_handler(int value)
{
    if (g_tcpPing) {
        [g_tcpPing processLongConnect];
    }
}


@interface RSTCPPing()
{
    int sock;
}
@property (nonatomic,readonly) NSString  *host;
@property (nonatomic,readonly) NSUInteger port;
@property (nonatomic,readonly) NSUInteger count;
@property (copy,readonly) RSTCPPingHandler complete;
@property (atomic) BOOL isStop;
@property (nonatomic,assign) BOOL isSucc;
@property (nonatomic,copy) NSMutableString *pingDetails;
@end

@implementation RSTCPPing

- (instancetype)init:(NSString *)host
                port:(NSUInteger)port
               count:(NSUInteger)count
            complete:(RSTCPPingHandler)complete
{
    if (self = [super init]) {
        _host = host;
        _port = port;
        _count = count;
        _complete = complete;
        _isStop = NO;
        _isSucc = YES;
    }
    return self;
}

+ (instancetype)start:(NSString * _Nonnull)host
             complete:(RSTCPPingHandler _Nonnull)complete
{
    return [[self class] start:host port:80 count:3 complete:complete];
}


+ (instancetype)start:(NSString * _Nonnull)host
                 port:(NSUInteger)port
                count:(NSUInteger)count
             complete:(RSTCPPingHandler _Nonnull)complete
{
    RSTCPPing *tcpPing = [[RSTCPPing alloc] init:host port:port count:count complete:complete];
    g_tcpPing = tcpPing;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [tcpPing sendAndRec];
    });
    return tcpPing;
}

- (BOOL)isPinging
{
    return !_isStop;
}

- (void)stopPing
{
    _isStop = YES;
}

- (void)sendAndRec
{
    _pingDetails = [NSMutableString stringWithString:@"\n"];
    NSString *ip = nil;
    NSArray *address = [RSNetDiagnosisHelper resolveHost:self.host];
    if (address.count > 0) {
        ip = [address firstObject];
//        if ([[RSNetInfoUtils shareInstance] isIPv6Environment]) {
//            // IPv6 net, try reach IPv6 IPAddress
//            for (NSString *add in address) {
//                if ([add rangeOfString:@":"].location != NSNotFound) {
//                    ip = add;
//                }
//            }
//        }
    }
    if (ip == NULL) {
        [_pingDetails appendString:[NSString stringWithFormat:@"access %@ DNS error..\n", self.host]];
        _complete(_pingDetails, YES);
        return;
    }
    
    BOOL isIPv6 = [ip rangeOfString:@":"].location != NSNotFound;
    
    NSTimeInterval *intervals = (NSTimeInterval *)malloc(sizeof(NSTimeInterval) * _count);
    int index = 0;
    int r = 0;
    BOOL isSuccess = NO;
    int loss = 0;
    do {
        NSDate *t_begin = [NSDate date];
        r = [self connect:ip isIPv6:isIPv6];
        NSTimeInterval connect_time = [[NSDate date] timeIntervalSinceDate:t_begin];
        intervals[index] = connect_time * 1000;
        // IPv4 , socket connect success with return code 0
        // IPv6, socket connect success with return code non -1
        if ((!isIPv6 && r == 0) || (isIPv6 && r != -1)) {
            isSuccess = YES;
        }
        if (isSuccess) {
            [_pingDetails appendString:[NSString stringWithFormat:@"connect to %@:%lu,  %.2f ms \n",ip,_port,connect_time * 1000]];
        } else {
            [_pingDetails appendString:[NSString stringWithFormat:@"connect failed to %@:%lu, %f ms, error %d\n", ip, (unsigned long)_port, connect_time * 1000, r]];
            loss++;
        }
        _complete(_pingDetails, NO);
        if (index < _count && !_isStop && isSuccess) {
            usleep(1000*100);
        }
    } while (++index < _count && !_isStop && isSuccess);
    
    NSInteger code = r;
    if (_isStop) {
        code = -5;
    }else{
        _isStop = YES;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        if (self.isSucc) {
            RSTCPPingResult *pingRes = [self conclusePingRes:code ip:ip durations:intervals loss:loss count:index isIPv6:isIPv6];
            [self.pingDetails appendString:pingRes.description];
        }
        self.complete(self.pingDetails, YES);
        free(intervals);
    });
}


- (void)processLongConnect 
{
    close(sock);
    _isStop = YES;
    _isSucc = NO;
}

- (int)connect:(NSString *)ipAddr 
        isIPv6:(BOOL)isIPv6
{
    NSData *addrData = nil;
    if (isIPv6) {
        struct sockaddr_in6 nativeAddr6;
        memset(&nativeAddr6,0,sizeof(nativeAddr6));
        nativeAddr6.sin6_len = sizeof(nativeAddr6);
        nativeAddr6.sin6_family = AF_INET6;
        nativeAddr6.sin6_port = htons(_port);
        inet_pton(AF_INET6, ipAddr.UTF8String, &nativeAddr6.sin6_addr);
        addrData = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
    } else {
        struct sockaddr_in nativeAddr4;
        memset(&nativeAddr4,0,sizeof(nativeAddr4));
        nativeAddr4.sin_len =sizeof(nativeAddr4);
        nativeAddr4.sin_family = AF_INET;
        nativeAddr4.sin_port = htons(_port);
        inet_pton(AF_INET, ipAddr.UTF8String, &nativeAddr4.sin_addr.s_addr);
        addrData = [NSData dataWithBytes:&nativeAddr4 length:sizeof(nativeAddr4)];
    }
    
    const struct sockaddr * destination = (struct sockaddr *)[addrData bytes];
    
    sock = socket(destination->sa_family, SOCK_STREAM, IPPROTO_TCP);
    
    if (sock == -1) {
        return errno;
    }
    int on = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *)&on, sizeof(on));
    
    struct timeval timeout;
    timeout.tv_sec = 10;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char *)&timeout, sizeof(timeout));
    
    sigset(SIGALRM, tcp_connect_handler);
    alarm(1);
    int connect_res = connect(sock, destination, sizeof(struct sockaddr));
    alarm(0);
    sigrelse(SIGALRM);
    
    if (connect_res < 0) {
        int err = errno;
        close(sock);
        return err;
    }
    close(sock);
    return 0;
}

- (RSTCPPingResult *)conclusePingRes:(NSInteger)code
                                  ip:(NSString *)ip
                           durations:(NSTimeInterval *)durations
                                loss:(NSUInteger)loss
                               count:(NSUInteger)count
                              isIPv6:(BOOL)isIPv6
{
    if ((!isIPv6 && code != 0 && code != -5) || (isIPv6 && code == -1)) {
        return [[RSTCPPingResult alloc] init:ip loss:1 count:1 max:0 min:0 avg:0];
    }
    
    NSTimeInterval max = 0;
    NSTimeInterval min = 10000000;
    NSTimeInterval sum = 0;
    for (int i= 0; i < count; i++) {
        if (durations[i] > max) {
            max = durations[i];
        }
        if (durations[i] < min) {
            min = durations[i];
        }
        sum += durations[i];
    }
    
    NSTimeInterval avg = sum/count;
    return [[RSTCPPingResult alloc] init:ip loss:loss count:count max:max min:min avg:avg];
}

@end
