//
//  RSNetDetector.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSNetDiagnosisLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface RSNetDetector : NSObject

+ (instancetype)shared;

#pragma mark - Dectect All Items

/// There can only be one detection process at the same time.
/// Opening two icmp at the same time will cause packet stringing.
@property (nonatomic, assign) BOOL isDetecting;

/// Detect a domain
/// - Parameters:
///   - host: domain name
///   - complete: callback
- (void)detectHost:(NSString *)host 
          complete:(void(^)(NSString *detectLog))complete;


/// Detect a group of domain, by sequence
/// - Parameters:
///   - hostList: List of domain name
///   - complete: callback
- (void)detectHostList:(NSArray<NSString *> *)hostList 
              complete:(void(^)(NSString *detectLog))complete;


#pragma mark - Dectect Single Items
/**
 @brief DNS lookup
 
 @param host domain name
 @param complete dns lookup callback
 */
- (void)dnsLookupWithHost:(NSString *)host 
                 complete:(void(^)(NSString *detectLog))complete;

/**
 @brief TCP Ping connection detect
 
 @param host domain name
 @param complete ping callback
 */
- (void)tcpPingWithHost:(NSString *)host 
               complete:(void(^)(NSString *detectLog))complete;

/**
 @brief ICMP Ping connection detect
 
 @param host domain name
 @param complete ping callback
 */
- (void)icmpPingWithHost:(NSString *)host 
                complete:(void(^)(NSString *detectLog))complete;

/**
 @brief traceroute router path detect
 
 @param host domain name
 @param complete traceroute callback
 */
- (void)icmpTracerouteWithHost:(NSString *)host 
                      complete:(void(^)(NSString *detectLog))complete;

#pragma mark - Other

/**
 @brief Set log level
 @discussion  Default log level is `RSNetDiagnosisLogLevel_ERROR`
 @param logLevel Log level, type is an enumeration `RSNetDiagnosisLogLevel`
 */
- (void)setLogLevel:(RSNetDiagnosisLogLevel)logLevel;

@end

NS_ASSUME_NONNULL_END
