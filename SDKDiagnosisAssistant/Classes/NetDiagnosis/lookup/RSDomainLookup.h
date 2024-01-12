//
//  RSDomainLookup.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//MARK: - RSDomainLookUpResult

@interface RSDomainLookUpResult : NSObject
@property (nonatomic, copy) NSString * name;
@property (nonatomic, copy) NSString * ip;
@property (nonatomic, assign) int ipVersion;    // AF_INET or AF_INET6

+ (instancetype)instanceWithName:(NSString *)name address:(NSString *)address ipVersion:(int)ipVersion;

@end


//MARK: - RSDomainLookup

typedef void (^RSLookupResultHandler)(NSMutableArray<RSDomainLookUpResult *>  *_Nullable lookupRes, NSError *_Nullable error);

@interface RSDomainLookup : NSObject

+ (instancetype)shareInstance;

/**
 @brief Loopup domain
 @discussion Only support IPv4
 
 @param domain domain name
 @param handler lookup result callback
 */
- (void)lookupDomainForIpv4:(NSString * _Nonnull)domain completeHandler:(RSLookupResultHandler _Nonnull)handler;

/**
 @brief Loopup domain
 @discussion Support both IPv4 & IPv6
 
 @param domain domain name
 @param handler lookup result callback
 */
- (void)lookupDomain:(NSString * _Nonnull)domain completeHandler:(RSLookupResultHandler _Nonnull)handler;

@end

NS_ASSUME_NONNULL_END
