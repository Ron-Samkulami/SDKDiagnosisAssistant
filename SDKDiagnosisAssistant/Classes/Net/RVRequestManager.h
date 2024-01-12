//
//  RVRequestManager.h
//  170217AFN改写2
//
//  Created by 石学谦 on 17/2/17.
//  Copyright © 2017年 37互娱. All rights reserved.
//  请求管理类。封装了AFN的方法


#import <Foundation/Foundation.h>
#import "AFRVSDKNetworking.h"


@interface RVRequestManager : NSObject

@property (nonatomic, strong) AFRVSDKHTTPSessionManager *sessionManager;

+ (instancetype)sharedManager;

/// GET请求
- (void)GET:(NSString *)URLString
 parameters:(NSDictionary *)parameters
    success:(void (^)(id successResponse))success
    failure:(void (^)(NSError *failureResponse))failure ;


/// POST请求
- (void)POST:(NSString *)URLString
  parameters:(NSDictionary *)parameters
     success:(void (^)(id successResponse))success
     failure:(void (^)(NSError * error))failure;

/// 带失败重试的POST请求
- (void)POST:(NSString *)URLString
  parameters:(NSDictionary *)parameters
firstTryDelay:(NSTimeInterval)firstTryDelayInterval
 tryInterval:(NSTimeInterval)tryInterval
 maxTryTimes:(int)maxTryTimes
     success:(void (^)(id))success
     failure:(void (^)(NSError * error))failure;

/// 获取网络信息
- (void)getNetworkInfo:(void (^)(NSString* netStatus)) callback;

/// 文件下载
- (void)downloadTaskWithRequest:(NSURLRequest *)request
                       progress:(void (^)(NSProgress *downloadProgress))downloadProgressBlock
                    destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
              completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler;

@end
