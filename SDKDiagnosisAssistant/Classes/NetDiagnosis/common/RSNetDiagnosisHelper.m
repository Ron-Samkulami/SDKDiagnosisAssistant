//
//  RSNetDiagnosisHelper.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSNetDiagnosisHelper.h"



@implementation RSNetDiagnosisHelper


#pragma mark - Resolve host
+ (NSArray<NSString *> *)resolveHost:(NSString *)hostname {
//    NSMutableArray<NSString *> *resolve = [NSMutableArray array];
//    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname);
//    if (hostRef != NULL) {
//        Boolean result = CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL); // 开始DNS解析
//        if (result == true) {
//            CFArrayRef addresses = CFHostGetAddressing(hostRef, &result);
//            for(int i = 0; i < CFArrayGetCount(addresses); i++){
//                CFDataRef saData = (CFDataRef)CFArrayGetValueAtIndex(addresses, i);
//                struct sockaddr *addressGeneric = (struct sockaddr *)CFDataGetBytePtr(saData);
//
//                if (addressGeneric != NULL) {
//                    switch (addressGeneric->sa_family) {
//                        case AF_INET:
//                        {
//                            struct sockaddr_in *remoteAddr = (struct sockaddr_in *)CFDataGetBytePtr(saData);
//                            [resolve addObject:[self formatIPv4Address:remoteAddr->sin_addr]];
//                        }
//                            break;
//                        case AF_INET6:
//                        {
//                            struct sockaddr_in6 *remoteAddr6 = (struct sockaddr_in6 *)CFDataGetBytePtr(saData);
//                            [resolve addObject:[self formatIPv6Address:remoteAddr6->sin6_addr]];
//                        }
//                            break;
//                        default:
//                            break;
//                    }
//
//                }
//            }
//        }
//    }
//
//    return [resolve copy];

    NSMutableArray<NSString *> *resolve = [NSMutableArray array];

    struct addrinfo hints, *res, *p;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    int status = getaddrinfo([hostname UTF8String], NULL, &hints, &res);
    if (status != 0) {
        NSLog(@"getaddrinfo error: %s", gai_strerror(status));
        return [resolve copy];
    }

    for (p = res; p != NULL; p = p->ai_next) {
        char ipstr[INET6_ADDRSTRLEN];
        void *addr;

        if (p->ai_family == AF_INET) { // IPv4
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
            addr = &(ipv4->sin_addr);
        } else if (p->ai_family == AF_INET6) { // IPv6
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr = &(ipv6->sin6_addr);
        } else {
            continue;
        }

        // convert pointer to string
        inet_ntop(p->ai_family, addr, ipstr, sizeof(ipstr));
        [resolve addObject:[NSString stringWithUTF8String:ipstr]];
    }

    freeaddrinfo(res);
    return [resolve copy];
}

+ (NSString *)formatIPv4Address:(struct in_addr)ipv4Addr {
    NSString *address = nil;
    char dstStr[INET_ADDRSTRLEN];
    char srcStr[INET_ADDRSTRLEN];
    memcpy(srcStr, &ipv4Addr, sizeof(struct in_addr));
    if(inet_ntop(AF_INET, srcStr, dstStr, INET_ADDRSTRLEN) != NULL) {
        address = [NSString stringWithUTF8String:dstStr];
    }
    return address;
}

+ (NSString *)formatIPv6Address:(struct in6_addr)ipv6Addr {
    NSString *address = nil;
    char dstStr[INET6_ADDRSTRLEN];
    char srcStr[INET6_ADDRSTRLEN];
    memcpy(srcStr, &ipv6Addr, sizeof(struct in6_addr));
    if(inet_ntop(AF_INET6, srcStr, dstStr, INET6_ADDRSTRLEN) != NULL) {
        address = [NSString stringWithUTF8String:dstStr];
    }
    return address;
}


#pragma mark - ICMP Ping Packet

+ (RSICMPPacket *)constructICMPEchoPacketWithSeq:(uint16_t)seq
                                   andIdentifier:(uint16_t)identifier
                                          isIPv6:(BOOL)isIPv6
{
    RSICMPPacket *packet = (RSICMPPacket *)malloc(sizeof(RSICMPPacket));
    packet->type  = isIPv6 ? RSICMPv6Type_EchoRequest : RSICMPType_EchoRequest;
    packet->code = 0;
    packet->identifier = OSSwapHostToBigInt16(identifier);
    packet->seq = OSSwapHostToBigInt16(seq);
    memset(packet->data, 65, 56);
    packet->checksum = 0;
    packet->checksum = [self in_cksumWithBuffer:packet andSize:sizeof(RSICMPPacket)];
//    NSLog(@"Send packet with identifier：%d", identifier);
    return packet;
}


+ (BOOL)isValidICMPPingResponseWithBuffer:(char *)buffer 
                                   length:(int)length
                               identifier:(uint16_t)identifier
                                   isIPv6:(BOOL)isIPv6
{
    RSICMPPacket *icmpPtr = (RSICMPPacket *)[self icmpPacketFromBuffer:buffer length:length isIPv6:isIPv6];
    
    if (icmpPtr == NULL) {
        return NO;
    }
    
//    NSLog(@"Receive packet with identifier：%d ,type：%hu ", OSSwapBigToHostInt16(icmpPtr->identifier), icmpPtr->type);
    if (isIPv6) {
        return icmpPtr->type == RSICMPv6Type_EchoReply && icmpPtr->code == 0;
    } else {
        uint16_t receivedChecksum = icmpPtr->checksum;
        icmpPtr->checksum = 0;
        uint16_t calculatedChecksum = [self in_cksumWithBuffer:icmpPtr andSize:length-((char*)icmpPtr - buffer)];
        
        return receivedChecksum == calculatedChecksum &&
        icmpPtr->type == RSICMPType_EchoReply &&
        icmpPtr->code == 0 &&
        OSSwapBigToHostInt16(icmpPtr->identifier) >= identifier;
//        OSSwapBigToHostInt16(icmpPtr->identifier) == identifier;
//        OSSwapBigToHostInt16(icmpPtr->seq) <= seq;
    }
}

+ (char *)icmpPacketFromBuffer:(char *)buffer 
                        length:(int)length
                        isIPv6:(BOOL)isIPv6 {
    if (isIPv6) {
        return [self icmpv6PacketFromBuffer:buffer length:length];
    } else {
        return [self icmpPacketFromBuffer:buffer length:length];
    }
}

+ (char *)icmpv6PacketFromBuffer:(char *)buffer 
                          length:(int)length
{
//    if (length < (sizeof(RSNetIPv6Header) + sizeof(RSICMPPacket))) {
//        return NULL;
//    }
//    const struct RSNetIPv6Header *ipPtr = (const RSNetIPv6Header *)buffer;
//    if (ipPtr->nextHeader != 58) { // ICMPv6
//        return NULL;
//    }
//
//    size_t ipHeaderLength = sizeof(uint8_t) * 40;
//
//    if (length < ipHeaderLength + sizeof(RSICMPPacket)) {
//        return NULL;
//    }
//
//    return (char *)buffer + ipHeaderLength;
    return (char *)buffer;
}


+ (char *)icmpPacketFromBuffer:(char *)buffer 
                        length:(int)length
{
    if (length < (sizeof(RSNetIPHeader) + sizeof(RSICMPPacket))) {
        return NULL;
    }
    const struct RSNetIPHeader *ipPtr = (const RSNetIPHeader *)buffer;
    // If not IPv4 or not ICMP type
    if ((ipPtr->versionAndHeaderLength & 0xF0) != 0x40 || ipPtr->protocol != 1) {
        return NULL;
    }
    size_t ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
    
    if (length < ipHeaderLength + sizeof(RSICMPPacket)) {
        return NULL;
    }
    
    return (char *)buffer + ipHeaderLength;
}



#pragma mark - ICMP TraceRoute Packet

+ (RSICMPTraceRoutePacket *)constructICMPTraceRoutePacketWithSeq:(uint16_t)seq 
                                                   andIdentifier:(uint16_t)identifier
                                                          isIPv6:(BOOL)isIPv6
{
    RSICMPTraceRoutePacket *packet = (RSICMPTraceRoutePacket *)malloc(sizeof(RSICMPTraceRoutePacket));
    packet->type  = isIPv6 ? RSICMPv6Type_EchoRequest : RSICMPType_EchoRequest;
    packet->code = 0;
    packet->identifier = OSSwapHostToBigInt16(identifier);
    packet->seq = OSSwapHostToBigInt16(seq);
//    NSLog(@"Send packet with identifier：%d", identifier);
//    memset(packet->data, 65, 2);
    // ICMP6 do not need checksum manually
    if (!isIPv6) {
        packet->checksum = 0;
        packet->checksum = [self in_cksumWithBuffer:packet andSize:sizeof(RSICMPTraceRoutePacket)];
    }
    return packet;
}

+ (BOOL)isTimeoutPacket:(char *)packetBuffer length:(int)length isIPv6:(BOOL)isIPv6
{
    RSICMPTraceRoutePacket *icmpPacket = (RSICMPTraceRoutePacket *)[self icmpTraceRoutePacketFromBuffer:packetBuffer length:length isIPv6:isIPv6];
    
    if (icmpPacket == NULL) {
        return NO;
    }
    
//    NSLog(@"Receive packet with identifier：%d ,type：%hu ", OSSwapBigToHostInt16(icmpPacket->identifier), icmpPacket->type);
    if (isIPv6) {
        return icmpPacket->type == RSICMPv6Type_ROUTER_SOLICIT
        || icmpPacket->type == RSICMPv6Type_ROUTER_ADVERT
        || icmpPacket->type == RSICMPv6Type_NEIGHBOR_SOLICIT
        || icmpPacket->type == RSICMPv6Type_NEIGHBOR_ADVERT
        || icmpPacket->type == RSICMPv6Type_NEIGHBOR_REDIRECT;
    } else {
        return icmpPacket->type == RSICMPType_TimeOut;
    }
}

+ (BOOL)isEchoReplyPacket:(char *)packetBuffer length:(int)length isIPv6:(BOOL)isIPv6
{
    RSICMPTraceRoutePacket *icmpPacket = (RSICMPTraceRoutePacket *)[self icmpTraceRoutePacketFromBuffer:packetBuffer length:length isIPv6:isIPv6];
    
    if (icmpPacket == NULL) {
        return NO;
    }
    
    return icmpPacket->type == (isIPv6 ? RSICMPv6Type_EchoReply : RSICMPType_EchoReply);
}


+ (char *)icmpTraceRoutePacketFromBuffer:(char *)buffer
                                  length:(int)length
                                  isIPv6:(BOOL)isIPv6
{
    if (isIPv6) {
        return [self icmp6TraceRoutePacketFromBuffer:buffer length:length];
    } else {
        return [self icmpTraceRoutePacketFromBuffer:buffer length:length];
    }
}

// https://tools.ietf.org/html/rfc2463
+ (char *)icmp6TraceRoutePacketFromBuffer:(char *)buffer 
                                   length:(int)length
{
//    if (len < (sizeof(RSNetIPv6Header) + sizeof(RSICMPTraceRoutePacket))) {
//        return NULL;
//    }
//    const struct RSNetIPv6Header *ipPtr = (const RSNetIPv6Header *)packet;
//    if (ipPtr->nextHeader != 58) { // ICMPv6
//        return NULL;
//    }
//
//    size_t ipHeaderLength = sizeof(uint8_t) * 40;
//
//    if (len < ipHeaderLength + sizeof(RSICMPTraceRoutePacket)) {
//        return NULL;
//    }
//
//    return (char *)packet + ipHeaderLength;
    return (char *)buffer;
}

+ (char *)icmpTraceRoutePacketFromBuffer:(char *)buffer 
                                  length:(int)length
{
    if (length < (sizeof(RSNetIPHeader) + sizeof(RSICMPTraceRoutePacket))) {
        return NULL;
    }
    const struct RSNetIPHeader *ipPtr = (const RSNetIPHeader *)buffer;
    // If not IPv4 or not ICMP type
    if ((ipPtr->versionAndHeaderLength & 0xF0) != 0x40 || ipPtr->protocol != 1) {
        return NULL;
    }
    size_t ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
    
    if (length < ipHeaderLength + sizeof(RSICMPTraceRoutePacket)) {
        return NULL;
    }
    
    return (char *)buffer + ipHeaderLength;
}


#pragma mark - Utils
+ (uint16_t) in_cksumWithBuffer:(const void *)buffer andSize:(size_t)bufferLen
{
    /*
     将数据以字（16位）为单位累加到一个双字中
     如果数据长度为奇数，最后一个字节将被扩展到字，累加的结果是一个双字，
     最后将这个双字的高16位和低16位相加后取反
     */
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = (uint16_t*)buffer;
    
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);    /* add hi 16 to low 16 */
    sum += (sum >> 16);            /* add carry */
    answer = (uint16_t) ~sum;   /* truncate to 16 bits */
    
    return answer;
}

+ (uint16_t)calculateChecksum:(const void *)icmpRequest withLength:(size_t)packetLength {
    uint32_t checksum = 0;
    uint16_t *dataPointer = (uint16_t *)icmpRequest;
    
    for (int i = 0; i < packetLength / 2; i++) {
        checksum += *dataPointer++;
    }
    
    // Handle any bytes in the last odd-sized block
    if (packetLength & 1) {
        uint16_t oddByte = 0;
        *((uint8_t *)&oddByte) = *(uint8_t *)dataPointer;
        checksum += oddByte;
    }
    
    // Fold 32-bit checksum to 16 bits
    while (checksum >> 16) {
        checksum = (checksum & 0xffff) + (checksum >> 16);
    }
    
    return ~checksum;
}
@end
