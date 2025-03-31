//
//  RSPingConclusion.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSPingResult.h"

@interface RSPingConclusion : NSObject

@property (nonatomic, assign) int totolPackets;
@property (nonatomic, assign) int loss;
@property (nonatomic, assign) int ttl;
@property (nonatomic, assign) float avg;
@property (nonatomic, assign) float stddev;
@property (nonatomic, assign) float max;
@property (nonatomic, assign) float min;
@property (nonatomic, copy) NSString *src_ip;
@property (nonatomic, copy) NSString *dst_ip;
@property (nonatomic, copy) NSString *dst_host;
@property (nonatomic, assign) NSTimeInterval timestamp;

/**
 Create a conclusion from an array of ping result
 */
+ (instancetype)pingConclusionWithPingResults:(NSArray <RSPingResult *>*)pingResultArr;

+ (instancetype)pingConclusionWithDict:(NSDictionary *)dict;

- (instancetype)initWithDict:(NSDictionary *)dict;

- (NSDictionary *)beanToDict;

@end


