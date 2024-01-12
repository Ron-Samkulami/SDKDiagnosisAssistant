//
//  RSICMPTraceRoute.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSICMPTraceRoute.h"

#import "RSNetDiagnosisLog.h"
#import "RSNetInfoUtils.h"
#import "RSNetQueue.h"
#import "RSNetDiagnosisHelper.h"

typedef NS_ENUM(NSUInteger, RSTraceRouteRecICMPType)
{
    RSTraceRouteRecICMPType_None = 0,
    RSTraceRouteRecICMPType_noReply,
    RSTraceRouteRecICMPType_routeReceive,
    RSTraceRouteRecICMPType_Destination
};

@interface RSICMPTraceRoute()
{
    int socket_client;
    struct sockaddr_in  remote_addr;
    struct sockaddr_in6 remote_addr6;
    struct sockaddr * destination;
}

@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) BOOL stopTraceFlag;
@property (nonatomic, assign) BOOL isTracerouting;
@property (nonatomic, assign) RSTraceRouteRecICMPType lastTraceRouteRecICMPType;
@property (nonatomic, strong) NSDate *sendDate;
@end

@implementation RSICMPTraceRoute

- (instancetype)init
{
    if ([super init]) {
        _stopTraceFlag = NO;
        _isTracerouting = NO;
        _lastTraceRouteRecICMPType = RSTraceRouteRecICMPType_None;
    }
    return self;
}

- (void)stopTraceroute
{
    _stopTraceFlag = YES;
    _isTracerouting = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(traceRouteDidFinished:)]) {
        [self.delegate traceRouteDidFinished: self];
    }
}

- (BOOL)isTracerouting
{
    return _isTracerouting;
}

- (void)settingICMPSocket
{
    NSString *ipAddress = _host;
    NSData *addrData = nil;
    BOOL isIPv6 = [ipAddress rangeOfString:@":"].location != NSNotFound;
    if (isIPv6) {
        memset(&remote_addr6,0,sizeof(remote_addr6));
        remote_addr6.sin6_len = sizeof(remote_addr6);
        remote_addr6.sin6_family = AF_INET6;
        inet_pton(AF_INET6, ipAddress.UTF8String, &remote_addr6.sin6_addr);
        addrData = [NSData dataWithBytes:&remote_addr6 length:sizeof(remote_addr6)];
        
    } else {
        memset(&remote_addr,0,sizeof(remote_addr));
        remote_addr.sin_len =sizeof(remote_addr);
        remote_addr.sin_family = AF_INET;
        inet_pton(AF_INET, ipAddress.UTF8String, &remote_addr.sin_addr.s_addr);
        addrData = [NSData dataWithBytes:&remote_addr length:sizeof(remote_addr)];
    }
    
    destination = (struct sockaddr *)[addrData bytes];
    
    struct timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    
    socket_client = socket(destination->sa_family, SOCK_DGRAM, isIPv6?IPPROTO_ICMPV6:IPPROTO_ICMP);
    int res = setsockopt(socket_client, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    if (res < 0) {
        log4cplus_warn("PhoneNetTracert", "tracert %s , set timeout error..\n", [ipAddress UTF8String]);
    }
    
    // IPv6 must set IPV6_RECVPKTINFO on
    if (isIPv6) {
        int on = 1;
        int res = setsockopt(socket_client, IPPROTO_IPV6, IPV6_RECVPKTINFO, &on, sizeof(on));
        if (res < 0) {
            log4cplus_warn("PhoneNetPing", "ping %s , set ipv6 receive on error..\n",[self.host UTF8String]);
        }
    }
    
}

- (BOOL)verificationHost:(NSString *)host
{
    // Doing host resolve here
    NSArray *address = [RSNetDiagnosisHelper resolveHost:host];
    if (address.count > 0) {
        NSString *ipAddress = [address firstObject];
        if ([[RSNetInfoUtils shareInstance] isIPv6Environment]) {
            // Traceroute to IPv4 address always failed under IPv6 network circumstance, try to find a IPv6 address.
            for (NSString *add in address) {
                if ([add rangeOfString:@":"].location != NSNotFound) {
                    ipAddress = add;
                }
            }
        }
        _host = ipAddress;
    } else {
        log4cplus_warn("PhoneNetTracert", "access %s DNS error , remove this ip..\n",[host UTF8String]);
    }
    
    if (_host == NULL) {
        return NO;
    }
    return YES;
}

- (void)startTracerouteHost:(NSString *)host
{
    if (![self verificationHost:host]) {
        [self stopTraceroute];
        log4cplus_warn("PhoneNetTracert", "there is no valid domain in the domain list , traceroute complete..\n");
        return;
    }
    
    [RSNetQueue rs_net_trace_async:^{
        [self settingICMPSocket];
        [self startTraceroute];
    }];
}

- (void)startTraceroute
{
    if (_isTracerouting) {
        return;
    }
    _isTracerouting = YES;
    _stopTraceFlag = NO;
    
    BOOL isIPv6 = destination->sa_family == AF_INET6;
    
    int ttl = 1;
    int continuousLossPacketRoute = 0;
    RSTraceRouteRecICMPType rec = RSTraceRouteRecICMPType_noReply;
    log4cplus_debug("PhoneNetTracert", "begin tracert ip: %s \n", [self.host UTF8String]);
    do {
        int setTtlRes = setsockopt(socket_client,
                                   isIPv6 ? IPPROTO_IPV6 : IPPROTO_IP,
                                   isIPv6 ? IPV6_UNICAST_HOPS : IP_TTL,
                                   &ttl,
                                   sizeof(ttl));
        
        if (setTtlRes < 0) {
            log4cplus_debug("PhoneNetTracert", "set TTL for icmp packet error..\n");
        }
        
        uint16_t identifier = (uint16_t)(5000 +  ttl);
        RSICMPTraceRoutePacket *packet = [RSNetDiagnosisHelper constructICMPTraceRoutePacketWithSeq:ttl andIdentifier:identifier isIPv6:isIPv6];
        
        RSTraceRouteResult *record = [[RSTraceRouteResult alloc] initWithHop:ttl countPerNode:kTraceRoutePacketCountPerNode];
        
        for (int trytime = 0; trytime < kTraceRoutePacketCountPerNode; trytime++) {
            _sendDate = [NSDate date];
            socklen_t addrLen = isIPv6 ? sizeof(struct sockaddr_in6) : sizeof(struct sockaddr_in);
            size_t sent = sendto(socket_client, packet, sizeof(RSICMPTraceRoutePacket), 0, (struct sockaddr *)destination, addrLen);
            
            if ((int)sent < 0) {
                log4cplus_debug("PhoneNetTracert", "send icmp packet failed, error info :%s\n", strerror(errno));
                break;
            }
            rec = RSTraceRouteRecICMPType_noReply;
            rec = [self receiverRemoteIpTracertRes:ttl packetSeq:trytime record:record];
            
            if (self.lastTraceRouteRecICMPType == RSTraceRouteRecICMPType_None) {
                self.lastTraceRouteRecICMPType = rec;
            }
            
            if (rec == RSTraceRouteRecICMPType_noReply && self.lastTraceRouteRecICMPType == RSTraceRouteRecICMPType_noReply) {
                continuousLossPacketRoute++;
                if (continuousLossPacketRoute == kTraceRouteMaxNoResCount * kTraceRoutePacketCountPerNode) {
                    log4cplus_debug("PhoneNetTracert", "%d consecutive routes are not responding ,and end the tracert ip: %s\n", kTraceRouteMaxNoResCount, [self.host UTF8String]);
                    rec = RSTraceRouteRecICMPType_Destination;
                    
                    record.dstIp = self.host;
                    record.status = RSTracerouteStatusFinish;
                    break;
                }
            } else {
                continuousLossPacketRoute = 0;
            }
            self.lastTraceRouteRecICMPType = rec;
            
            if (self.stopTraceFlag) {
                break;
            }
        }
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(traceRoute:reportTracerResult:)]) {
            [self.delegate traceRoute:self reportTracerResult:record];
        }
        
    } while (++ttl <= kTraceRouteMaxHop && 
             (rec == RSTraceRouteRecICMPType_routeReceive || rec == RSTraceRouteRecICMPType_noReply) &&
             !self.stopTraceFlag);
    
    if (rec == RSTraceRouteRecICMPType_Destination) {
        log4cplus_debug("PhoneNetTracert", "done tracert , ip :%s \n", [self.host UTF8String]);
        shutdown(socket_client, SHUT_RDWR);
        
        [self stopTraceroute];
    }
}

- (RSTraceRouteRecICMPType)receiverRemoteIpTracertRes:(int)ttl 
                                            packetSeq:(int)seq
                                               record:(RSTraceRouteResult *)record
{
    RSTraceRouteRecICMPType res = RSTraceRouteRecICMPType_routeReceive;
    record.dstIp = self.host;
    
    BOOL isIPv6 = destination->sa_family == AF_INET6;
    char buff[200];
    socklen_t addrLen = 0;
    ssize_t bytesRead = 0;
    NSString *remoteAddress = nil;
    if (isIPv6) {
        struct sockaddr_in6 ret_addr6;
        addrLen = sizeof(sockaddr_in6);
        bytesRead = recvfrom(socket_client, buff, sizeof(buff), 0, (struct sockaddr *)&ret_addr6, &addrLen);
        
        char ip[INET6_ADDRSTRLEN] = { 0 };
        struct sockaddr_in6 *addr_in6 = (struct sockaddr_in6 *)&ret_addr6;
        inet_ntop(AF_INET6, &(addr_in6)->sin6_addr, ip, sizeof(ip));
        remoteAddress = [NSString stringWithUTF8String:ip];
        
    } else {
        struct sockaddr_in ret_addr;
        addrLen = sizeof(sockaddr_in);
        bytesRead = recvfrom(socket_client, buff, sizeof(buff), 0, (struct sockaddr *)&ret_addr, &addrLen);
        
        char ip[INET_ADDRSTRLEN] = { 0 };
        struct sockaddr_in *addr_in = (struct sockaddr_in *)&ret_addr;
        inet_ntop(AF_INET, &(addr_in)->sin_addr.s_addr, ip, sizeof(ip));
        remoteAddress = [NSString stringWithUTF8String:ip];
    }
    
    if ((int)bytesRead < 0) {
        res = RSTraceRouteRecICMPType_noReply;
    } else {
        if ([RSNetDiagnosisHelper isTimeoutPacket:buff length:(int)bytesRead isIPv6:isIPv6] && ![remoteAddress isEqualToString: self.host]) {
            // Arriving at the intermediate routing node
            record.durations[seq] = [[NSDate date] timeIntervalSinceDate:_sendDate];
            record.ip = remoteAddress;
            
        } else if ([RSNetDiagnosisHelper isEchoReplyPacket:buff length:(int)bytesRead isIPv6:isIPv6] && [remoteAddress isEqualToString: self.host]) {
            // Reach to destination server
            res = RSTraceRouteRecICMPType_Destination;
            record.durations[seq] = [[NSDate date] timeIntervalSinceDate:_sendDate];
            record.ip = remoteAddress;
            record.status = RSTracerouteStatusFinish;
        }
    }
    return res;
}

@end
