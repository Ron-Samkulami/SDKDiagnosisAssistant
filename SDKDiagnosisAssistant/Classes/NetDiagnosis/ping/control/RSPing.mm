//
//  RSPing.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSPing.h"
#import "RSNetDiagnosisLog.h"
#import "RSNetQueue.h"
#import "RSNetInfoUtils.h"
#import "RSNetDiagnosisHelper.h"

#define KPingICMPIdBeginNum     8000

@interface RSPing()
{
    int socket_client;
    struct sockaddr *destination;
    uint16_t identifier;
}

@property (nonatomic,assign) BOOL stopPingFlag;
@property (nonatomic,assign) BOOL isPinging;
@property (nonatomic,strong) NSString *host;
@property (nonatomic,strong) NSDate   *sendDate;
@property (nonatomic,assign) int pingPacketCount;
@end

@implementation RSPing

- (instancetype)init
{
    self = [super init];
    if (self) {
        _stopPingFlag = NO;
        _isPinging = NO;
    }
    return self;
}

- (void)stopPing
{
    _stopPingFlag = YES;
    _isPinging = NO;
    [self reportPingResWithSorceIp:self.host ttl:0 timeMillSecond:0 seq:0 icmpId:0 dataSize:0 pingStatus:RSPingStatusFinished];
}

- (BOOL)isPinging
{
    return _isPinging;
}

- (void)startPingHosts:(NSString *)host 
           packetCount:(int)count
{
    if (![self verificationHost:host]) {
        [self stopPing];
        log4cplus_warn("RSPing", "There is no valid domain...\n");
        return;
    }
    
    if (count > 0) {
        _pingPacketCount = count;
    }
    
    [RSNetQueue rs_net_ping_async:^{
        [self buildICMPSocket];
        [self sendAndrecevPingPacket];
    }];
}

- (BOOL)verificationHost:(NSString *)host
{
    // Doing host resolve here
    NSArray *address = [RSNetDiagnosisHelper resolveHost:host];
    if (address.count > 0) {
        NSString *ipAddress = [address firstObject];
//        if ([[RSNetInfoUtils shareInstance] isIPv6Environment]) {
//             // IPv6 net, try reach IPv6 IPAddress
//            for (NSString *add in address) {
//                if ([add rangeOfString:@":"].location != NSNotFound) {
//                    ipAddress = add;
//                }
//            }
//        }
        _host = ipAddress;
    } else {
       log4cplus_warn("Ping", "access %s DNS error , remove this ip..\n",[host UTF8String]);
    }
    
    if (_host == NULL) {
        return NO;
    }
    return YES;
}

- (void)buildICMPSocket {
    NSData *addrData = nil;
    BOOL isIPv6 = [self.host rangeOfString:@":"].location != NSNotFound;
    if (isIPv6) {
        struct sockaddr_in6 nativeAddr6;
        memset(&nativeAddr6,0,sizeof(nativeAddr6));
        nativeAddr6.sin6_len = sizeof(nativeAddr6);
        nativeAddr6.sin6_family = AF_INET6;
        inet_pton(AF_INET6, self.host.UTF8String, &nativeAddr6.sin6_addr);
        addrData = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
    } else {
        struct sockaddr_in nativeAddr4;
        memset(&nativeAddr4,0,sizeof(nativeAddr4));
        nativeAddr4.sin_len =sizeof(nativeAddr4);
        nativeAddr4.sin_family = AF_INET;
        inet_pton(AF_INET, self.host.UTF8String, &nativeAddr4.sin_addr.s_addr);
        addrData = [NSData dataWithBytes:&nativeAddr4 length:sizeof(nativeAddr4)];
    }
    
    destination = (struct sockaddr *)[addrData bytes];
    
    struct timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    
    socket_client = socket(destination->sa_family, SOCK_DGRAM, isIPv6?IPPROTO_ICMPV6:IPPROTO_ICMP);
    if (socket_client < 0) {
        NSLog(@"Error creating socket: %s\n", strerror(errno));
    }
    int res = setsockopt(socket_client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    if (res < 0) {
        log4cplus_warn("RSPing", "ping %s , set timeout error..\n",[self.host UTF8String]);
    }
    
    // IPv6 must set IPV6_RECVPKTINFO on
    if (isIPv6) {
        int on = 1;
        int res = setsockopt(socket_client, IPPROTO_IPV6, IPV6_RECVPKTINFO, &on, sizeof(on));
        if (res < 0) {
            log4cplus_warn("RSPing", "ping %s , set ipv6 receive on error..\n",[self.host UTF8String]);
        }
    }
}

- (void)sendAndrecevPingPacket
{
    if (_isPinging) {
        return;
    }
    _isPinging = YES;
    _stopPingFlag = NO;

    
    BOOL isIPv6 = destination->sa_family == AF_INET6;
    
    int index = 0;
    BOOL isReceiverRemoteIpPingRes = NO;
    
    do {
        _sendDate = [NSDate date];
        identifier = (uint16_t)(getpid() + KPingICMPIdBeginNum + index);
        socklen_t length = isIPv6 ? sizeof(struct sockaddr_in6) : sizeof(struct sockaddr_in);
        
        RSICMPPacket *packet = [RSNetDiagnosisHelper constructICMPEchoPacketWithSeq:index andIdentifier:identifier isIPv6:isIPv6];
        ssize_t sent = sendto(socket_client, packet, sizeof(RSICMPPacket), 0, (struct sockaddr *)destination, length);
       
        if (sent < 0) {
            log4cplus_warn("RSPing", "ping %s , send icmp packet error..\n",[self.host UTF8String]);
        }
        
        isReceiverRemoteIpPingRes = [self receiverRemoteIpPingRes];
        
        if (isReceiverRemoteIpPingRes) {
            index++;
        }
        usleep(1000*500);
    } while (!self.stopPingFlag && index < _pingPacketCount && isReceiverRemoteIpPingRes);
    
    if (index == _pingPacketCount) {
        log4cplus_debug("RSPing", "ping complete..\n");
        /*
         int shutdown(int s, int how); // s is socket descriptor
         int how can be:
         SHUT_RD or 0 Further receives are disallowed
         SHUT_WR or 1 Further sends are disallowed
         SHUT_RDWR or 2 Further sends and receives are disallowed
         */
        shutdown(socket_client, SHUT_RDWR); //
        close(socket_client);
        
        [self stopPing];
    }
    
}

- (BOOL)receiverRemoteIpPingRes
{
    BOOL isIPv6 = destination->sa_family == AF_INET6;
    BOOL res = NO;
    char buffer[1024];
    
    ssize_t bytesRead = 0;
    if (isIPv6) {
        struct sockaddr_in6 ret_addr6;
        socklen_t addrLen6 = sizeof(sockaddr_in6);
        bytesRead = recvfrom(socket_client, buffer, sizeof(buffer), 0, (struct sockaddr *)&ret_addr6, &addrLen6);
    } else {
        struct sockaddr_in ret_addr;
        socklen_t addrLen = sizeof(sockaddr_in);
        bytesRead = recvfrom(socket_client, buffer, sizeof(buffer), 0, (struct sockaddr *)&ret_addr, &addrLen);
    }
    
    if (bytesRead < 0) {
        [self reportPingResWithSorceIp:self.host ttl:0 timeMillSecond:0 seq:0 icmpId:0 dataSize:0 pingStatus:RSPingStatusTimeout];
        res = YES;
        
    } else if(bytesRead == 0) {
        log4cplus_warn("RSPing", "ping %s , receive icmp packet error , bytesRead=0",[self.host UTF8String]);
        
    } else {
        if ([RSNetDiagnosisHelper isValidICMPPingResponseWithBuffer:(char *)buffer length:(int)bytesRead identifier:identifier isIPv6:isIPv6]) {
            
            RSICMPPacket *icmpPtr = (RSICMPPacket *)[RSNetDiagnosisHelper icmpPacketFromBuffer:(char *)buffer length:(int)bytesRead isIPv6:isIPv6];
            int seq = OSSwapBigToHostInt16(icmpPtr->seq);
            int identifier = OSSwapBigToHostInt16(icmpPtr->identifier);
            //FIXME: IPv6 hopLimit look like seq, don't know why
            int ttl = isIPv6 ? ((RSNetIPv6Header *)buffer)->hopLimit : ((RSNetIPHeader *)buffer)->timeToLive;
            int size = isIPv6 ? (int)bytesRead : (int)(bytesRead-sizeof(RSNetIPHeader));
            
            NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:_sendDate];
            
            NSString *sorceIp = self.host;
            
            [self reportPingResWithSorceIp:sorceIp ttl:ttl timeMillSecond:duration*1000 seq:seq icmpId:identifier dataSize:size pingStatus:RSPingStatusReceivePacket];
            res = YES;
        } else {
            [self reportPingResWithSorceIp:self.host ttl:0 timeMillSecond:0 seq:0 icmpId:0 dataSize:0 pingStatus:RSPingStatusReceiveUnexpectedPacket];
            res = YES;
        }
        
        usleep(500);
    }
    
    return res;
}

- (void)reportPingResWithSorceIp:(NSString *)sorceIp 
                             ttl:(int)ttl
                  timeMillSecond:(float)timeMillSec
                             seq:(int)seq 
                          icmpId:(int)icmpId
                        dataSize:(int)size 
                      pingStatus:(RSPingStatus)status
{
    RSPingResult *pingResModel = [[RSPingResult alloc] init];
    pingResModel.status = status;
    pingResModel.IPAddress = sorceIp;
    
    switch (status) {
        case RSPingStatusReceivePacket:
        {
            pingResModel.ICMPSequence = seq;
            pingResModel.timeToLive = ttl;
            pingResModel.timeMilliseconds = timeMillSec;
            pingResModel.dateBytesLength = size;
        }
            break;
        case RSPingStatusFinished:
        {
            pingResModel.ICMPSequence = _pingPacketCount;
        }
            break;
        case RSPingStatusTimeout:
        {
            pingResModel.ICMPSequence = seq;
        }
            break;
            
        default:
            break;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(ping:reportResult:withStatus:)]) {
            [self.delegate ping:self reportResult:pingResModel withStatus:status];
        }
        
    });
    
}


@end
