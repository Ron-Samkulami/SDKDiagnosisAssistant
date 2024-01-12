//
//  RSPingConclusion.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSPingConclusion : NSObject

@property (nonatomic, assign) int totolPackets;
@property (nonatomic, assign) int loss;
@property (nonatomic, assign) int ttl;
@property (nonatomic, assign) float delay;
@property (nonatomic, copy) NSString *src_ip;
@property (nonatomic, copy) NSString *dst_ip;

+ (instancetype)pingConclusionWithDict:(NSDictionary *)dict;

- (instancetype)initWithDict:(NSDictionary *)dict;

- (NSDictionary *)beanToDict;

@end


