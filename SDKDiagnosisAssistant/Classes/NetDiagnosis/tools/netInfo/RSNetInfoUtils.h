//
//  RSNetInfoUtils.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSNetInfoUtils : NSObject

+ (instancetype)shareInstance;

- (void)refreshNetInfo;

- (NSDictionary *)getLocalIpAddress;

- (NSString *)getNetworkType;
- (NSString *)getSubNetMask;
- (NSString *)getSSID;
- (NSString *)getBSSID;
- (NSString *)getWifiIpv4;
- (NSString *)getWifiIpv6;
- (NSString *)getCellIpv4;

- (BOOL)isIPv6Environment;


@end
