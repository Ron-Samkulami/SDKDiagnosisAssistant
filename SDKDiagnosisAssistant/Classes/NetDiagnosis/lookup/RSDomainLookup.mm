//
//  RSDomainLookup.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSDomainLookup.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

#import "RSNetDiagnosisLog.h"

//MARK: - RSDomainLookUpResult

@implementation RSDomainLookUpResult

- (instancetype)initWithName:(NSString *)name address:(NSString *)address ipVersion:(int)ipVersion
{
    if (self = [super init]) {
        _name = name;
        _ip = address;
        _ipVersion = ipVersion;
    }
    return self;
}

+ (instancetype)instanceWithName:(NSString *)name address:(NSString *)address ipVersion:(int)ipVersion
{
    return [[self alloc] initWithName:name address:address ipVersion:ipVersion];
}

- (NSString *)description
{
    NSString *ipVersionDesc = @"IPv4";
    if (_ipVersion == AF_INET6) {
        ipVersionDesc = @"IPv6";
    }
    return [NSString stringWithFormat:@"Name: %@, ipVersion: %@, IP: %@", _name, ipVersionDesc, _ip];
}

@end


//MARK: - RSDomainLookup

@interface RSDomainLookup()
{
    int socket_client;
    struct sockaddr_in remote_addr;
}
@end

@implementation RSDomainLookup

- (instancetype)init
{
    if (self = [super init]) {}
    return self;
}

+ (instancetype)shareInstance
{
    static id instace = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instace = [[self alloc] init];
    });
    return instace;
}

- (void)lookupDomainForIpv4:(NSString * _Nonnull)domain 
            completeHandler:(RSLookupResultHandler _Nonnull)handler
{
    if (![self isValidDomain:domain]) {
        log4cplus_warn("RSNetDiagnosisLookup", "your setting domain invalid..\n");
        handler(nil, [NSError errorWithDomain:@"domain invalid" code:-1 userInfo:nil]);
        return;
    }
    const char *hostaddr = [domain UTF8String];
    memset(&remote_addr, 0, sizeof(remote_addr));
    remote_addr.sin_addr.s_addr = inet_addr(hostaddr);
    
    if (remote_addr.sin_addr.s_addr == INADDR_NONE) {
        struct hostent *remoteHost = gethostbyname(hostaddr);
        if (remoteHost == NULL || remoteHost->h_addr == NULL) {
            log4cplus_warn("RSNetDiagnosisLookup", "DNS parsing error...\n");
            handler(nil, [NSError errorWithDomain:@"DNS Parsing failure" code:-1 userInfo:nil]);
            return;
        }
        
        NSMutableArray *mutArray = [NSMutableArray array];
        for (int i = 0; remoteHost->h_addr_list[i]; i++) {
            log4cplus_debug("RSNetDiagnosisLookup", "IP addr %d , name: %s , addr:%s  \n",i+1,remoteHost->h_name,inet_ntoa(*(struct in_addr*)remoteHost->h_addr_list[i]));
            [mutArray addObject:[RSDomainLookUpResult  instanceWithName:[NSString stringWithUTF8String:remoteHost->h_name] address:[NSString stringWithUTF8String:inet_ntoa(*(struct in_addr*)remoteHost->h_addr_list[i])] ipVersion:AF_INET]];
        }
        handler(mutArray,nil);
        return;
    }
    
    log4cplus_warn("RSNetDiagnosisLookup", "your setting domain error..\n");
    handler(nil, [NSError errorWithDomain:@"domain error" code:-1 userInfo:nil]);
    return;
}


- (void)lookupDomain:(NSString * _Nonnull)domain
     completeHandler:(RSLookupResultHandler _Nonnull)handler
{
    if (![self isValidDomain:domain]) {
        log4cplus_warn("RSNetDiagnosisLookup", "your setting domain invalid..\n");
        handler(nil, [NSError errorWithDomain:@"domain invalid" code:-1 userInfo:nil]);
        return;
    }
    const char *hostName = [domain UTF8String];
    NSMutableArray *result = [NSMutableArray array];
    
    struct addrinfo hints, *res, *res0;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_DEFAULT;
    
    int error = getaddrinfo(hostName, NULL, &hints, &res0);
    if (error) {
        NSLog(@"getaddrinfo host :%s ,error: %s", hostName, gai_strerror(error));
        log4cplus_warn("RSNetDiagnosisLookup", "getaddrinfo error: %s", gai_strerror(error));
        handler(nil, [NSError errorWithDomain:@"DNS Parsing failure" code:-1 userInfo:nil]);
        return;
    }
    
    for (res = res0; res; res = res->ai_next) {
        char buf[INET6_ADDRSTRLEN];
        if (res->ai_family == AF_INET) {
            struct sockaddr_in *s = (struct sockaddr_in *)res->ai_addr;
            inet_ntop(res->ai_family, &s->sin_addr, buf, sizeof(buf));
        } else if (res->ai_family == AF_INET6) {
            struct sockaddr_in6 *s = (struct sockaddr_in6 *)res->ai_addr;
            inet_ntop(res->ai_family, &s->sin6_addr, buf, sizeof(buf));
        } else {
            buf[0] = '\0';
        }
        NSString *ip = [NSString stringWithUTF8String:buf];
        NSString *name = domain;
        if (res->ai_canonname) {
            name = [NSString stringWithUTF8String:res->ai_canonname];
        }
        [result addObject:[RSDomainLookUpResult instanceWithName:name address:ip ipVersion:res->ai_family]];
    }
    freeaddrinfo(res0);
    
    handler(result, nil);
    return;
}

- (BOOL)isValidDomain:(NSString *)domain
{
    BOOL result = NO;
    NSString *regex = @"^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    result = [pred evaluateWithObject:domain];
    return result;
}

- (NSInteger)currentTimestamp
{
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    return (NSInteger)currentTime;
}
@end
