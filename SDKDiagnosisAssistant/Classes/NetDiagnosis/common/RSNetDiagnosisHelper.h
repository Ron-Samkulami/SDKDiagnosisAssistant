//
//  RSNetDiagnosisHelper.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AssertMacros.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/tcp.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

//MARK: - IP Header
typedef struct RSNetIPHeader {
    uint8_t     versionAndHeaderLength;
    uint8_t     differentiatedServices;
    uint16_t    totalLength;
    uint16_t    identification;
    uint16_t    flagsAndFragmentOffset;
    uint8_t     timeToLive;
    uint8_t     protocol;       // protocol type，1 is ICMP: https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
    uint16_t    headerChecksum;
    uint8_t     sourceAddress[4];
    uint8_t     destinationAddress[4];
    // options...
    // data...
} RSNetIPHeader;

__Check_Compile_Time(sizeof(RSNetIPHeader) == 20);
__Check_Compile_Time(offsetof(RSNetIPHeader, versionAndHeaderLength) == 0);
__Check_Compile_Time(offsetof(RSNetIPHeader, differentiatedServices) == 1);
__Check_Compile_Time(offsetof(RSNetIPHeader, totalLength) == 2);
__Check_Compile_Time(offsetof(RSNetIPHeader, identification) == 4);
__Check_Compile_Time(offsetof(RSNetIPHeader, flagsAndFragmentOffset) == 6);
__Check_Compile_Time(offsetof(RSNetIPHeader, timeToLive) == 8);
__Check_Compile_Time(offsetof(RSNetIPHeader, protocol) == 9);
__Check_Compile_Time(offsetof(RSNetIPHeader, headerChecksum) == 10);
__Check_Compile_Time(offsetof(RSNetIPHeader, sourceAddress) == 12);
__Check_Compile_Time(offsetof(RSNetIPHeader, destinationAddress) == 16);

//MARK: - IPv6 Header
typedef struct RSNetIPv6Header {
    uint32_t    versionClassFlow;
    uint16_t    payloadLength;
    uint8_t     nextHeader;
    uint8_t     hopLimit;
    uint8_t     sourceAddress[16];
    uint8_t     destinationAddress[16];
    // data
} RSNetIPv6Header;

__Check_Compile_Time(sizeof(RSNetIPv6Header) == 40);
__Check_Compile_Time(offsetof(RSNetIPv6Header, versionClassFlow) == 0);
__Check_Compile_Time(offsetof(RSNetIPv6Header, payloadLength) == 4);
__Check_Compile_Time(offsetof(RSNetIPv6Header, nextHeader) == 6);
__Check_Compile_Time(offsetof(RSNetIPv6Header, hopLimit) == 7);
__Check_Compile_Time(offsetof(RSNetIPv6Header, sourceAddress) == 8);
__Check_Compile_Time(offsetof(RSNetIPv6Header, destinationAddress) == 24);


//MARK: - ICMP Packet

// reference to netinet/icmp.h
typedef enum RSICMPType {
    RSICMPType_EchoReply    = 0,
    RSICMPType_EchoRequest  = 8,
    RSICMPType_TimeOut      = 11
} RSICMPType;

// reference to netinet/icmp6.h
typedef enum RSICMPv6Type {
    RSICMPv6Type_UNREACH        = 1,
    RSICMPv6Type_EXCEEDED       = 3,
    RSICMPv6Type_EchoRequest    = 128,
    RSICMPv6Type_EchoReply      = 129,
    RSICMPv6Type_ROUTER_SOLICIT     = 133,
    RSICMPv6Type_ROUTER_ADVERT      = 134,
    RSICMPv6Type_NEIGHBOR_SOLICIT   = 135,
    RSICMPv6Type_NEIGHBOR_ADVERT    = 136,
    RSICMPv6Type_NEIGHBOR_REDIRECT  = 137,
} RSICMPv6Type;

/*
 use linux style . totals 64B
 */
typedef struct RSICMPPacket {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    seq;
    char        data[56];  // data
} RSICMPPacket;

__Check_Compile_Time(sizeof(RSICMPPacket) == 64);
__Check_Compile_Time(offsetof(RSICMPPacket, type) == 0);
__Check_Compile_Time(offsetof(RSICMPPacket, code) == 1);
__Check_Compile_Time(offsetof(RSICMPPacket, checksum) == 2);
__Check_Compile_Time(offsetof(RSICMPPacket, identifier) == 4);
__Check_Compile_Time(offsetof(RSICMPPacket, seq) == 6);


typedef struct RSICMPTraceRoutePacket {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    seq;
//    char        data[2];  // data is optional
} RSICMPTraceRoutePacket;

__Check_Compile_Time(sizeof(RSICMPTraceRoutePacket) == 8);
__Check_Compile_Time(offsetof(RSICMPTraceRoutePacket, type) == 0);
__Check_Compile_Time(offsetof(RSICMPTraceRoutePacket, code) == 1);
__Check_Compile_Time(offsetof(RSICMPTraceRoutePacket, checksum) == 2);
__Check_Compile_Time(offsetof(RSICMPTraceRoutePacket, identifier) == 4);
__Check_Compile_Time(offsetof(RSICMPTraceRoutePacket, seq) == 6);



//MARK: - RSNetDiagnosisHelper

@interface RSNetDiagnosisHelper : NSObject

//MARK: - Resolve host
+ (NSArray<NSString *> *)resolveHost:(NSString *)hostname;

//MARK: - ICMP Ping Packet

+ (RSICMPPacket *)constructICMPEchoPacketWithSeq:(uint16_t)seq 
                                   andIdentifier:(uint16_t)identifier
                                          isIPv6:(BOOL)isIPv6;

+ (BOOL)isValidICMPPingResponseWithBuffer:(char *)buffer
                                   length:(int)length
                               identifier:(uint16_t)identifier
                                   isIPv6:(BOOL)isIPv6;

+ (char *)icmpPacketFromBuffer:(char *)buffer 
                        length:(int)length
                        isIPv6:(BOOL)isIPv6;


//MARK: - ICMP TraceRoute Packet

+ (RSICMPTraceRoutePacket *)constructICMPTraceRoutePacketWithSeq:(uint16_t)seq 
                                                   andIdentifier:(uint16_t)identifier
                                                          isIPv6:(BOOL)isIPv6;

+ (BOOL)isTimeoutPacket:(char *)packetBuffer 
                 length:(int)length
                 isIPv6:(BOOL)isIPv6;

+ (BOOL)isEchoReplyPacket:(char *)packetBuffer 
                   length:(int)length
                   isIPv6:(BOOL)isIPv6;


@end
