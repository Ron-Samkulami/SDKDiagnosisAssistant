//
//  RSTraceRouteResult.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RSTracerouteStatus) {
    RSTracerouteStatusWoking = 0,
    RSTracerouteStatusFinish
};

@interface RSTraceRouteResult : NSObject

@property (readonly) NSInteger hop;
@property (readonly) NSInteger countPerNode;
@property (nonatomic, copy) NSString* ip;
@property (nonatomic, copy) NSString *dstIp;
@property (nonatomic, assign) NSTimeInterval* durations; //ms
@property (nonatomic, assign) RSTracerouteStatus status;


- (instancetype)initWithHop:(NSInteger)hop
               countPerNode:(NSInteger)countPerNode;
@end
