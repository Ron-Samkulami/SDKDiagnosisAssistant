//
//  RSTCPPing.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//MARK: - RSTCPPingResult
@interface RSTCPPingResult : NSObject
@property (readonly) NSString *ip;
@property (readonly) NSUInteger loss;
@property (readonly) NSUInteger count;  
@property (readonly) NSTimeInterval max_time;
@property (readonly) NSTimeInterval avg_time;
@property (readonly) NSTimeInterval min_time;

- (instancetype)init:(NSString *)ip
                loss:(NSUInteger)loss
               count:(NSUInteger)count
                 max:(NSTimeInterval)maxTime
                 min:(NSTimeInterval)minTime
                 avg:(NSTimeInterval)avgTime;
@end


typedef void (^RSTCPPingHandler)(NSMutableString * tcpPingRes, BOOL isDone);

//MARK: - RSTCPPing
@interface RSTCPPing : NSObject

/**
 @brief start TCP ping
 
 @discussion the default port is 80

 @param host domain or ip
 @param complete tcp ping callback
 @return `RSTCPPing` instance
 */
+ (instancetype)start:(NSString * _Nonnull)host
             complete:(RSTCPPingHandler _Nonnull)complete;


/**
 @brief start TCP ping

 @param host domain or ip
 @param port port number
 @param count ping times
 @param complete tcp ping callback
 @return `RSTCPPing` instance
 */
+ (instancetype)start:(NSString * _Nonnull)host
                 port:(NSUInteger)port
                count:(NSUInteger)count
             complete:(RSTCPPingHandler _Nonnull)complete;


/**
 @brief check is doing tcp ping now.

 @return YES: is doing; NO: is not doing
 */
- (BOOL)isPinging;


/**
 @brief stop tcp ping
 */
- (void)stopPing;


/**
 @brief processing long tcp conn(ip or port can not be connected)
 */
- (void)processLongConnect;


NS_ASSUME_NONNULL_END

@end


