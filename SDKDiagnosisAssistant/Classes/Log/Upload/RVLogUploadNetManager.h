//
//  RVLogUploadNetManager.h
//  RVSDK
//
//  Created by 石学谦 on 2020/4/24.
//  Copyright © 2020 SDK. All rights reserved.
//

#import <Foundation/Foundation.h>

#define NETWORK_ERR_CODE 10001

//TODO: 这里列举了海外SDK日志上传的接口设计逻辑，请根据具体业务场景进行调整
/// 从后台获取日志上传参数
#define RV_LOG_CREATEUPLOAD_URL @"从后台获取日志上传参数的URL"
/// 获取上传进度
#define RV_LOG_RESUMEUPLOAD_URL @"从后台获取当前上传任务进度的URL"
/// 上传单个日志文件分片
#define RV_LOG_UPLOADPART_URL @"上传单个日志文件分片的URL"

/// 日志上传类型
typedef NSString * LogUploadType;
static LogUploadType _Nonnull const LogUploadTypeSDKLog = @"sdklog";       //猎影日志回捞类型
static LogUploadType _Nonnull const LogUploadTypeService = @"service";     //客服工单关联日志类型

typedef void (^RVLogUploadFailure)(NSInteger code, NSString * _Nullable msg);//失败
typedef void (^RVLogUploadSuccess)(NSDictionary * _Nonnull result);//成功

NS_ASSUME_NONNULL_BEGIN

@interface RVLogUploadNetManager : NSObject


+ (instancetype)sharedManager;

/**
 获取日志上传的授权Token和相关配置信息
 */
- (void)fetchAuthorityToUploadWithUploadId:(NSString *)uploadId success:(RVLogUploadSuccess)success failure:(RVLogUploadFailure)failure;

/**
 获取上传进度
 */
- (void)getUploadProgressWithUploadId:(NSString *)uploadId success:(RVLogUploadSuccess)success failure:(RVLogUploadFailure)failure;

/**
 上传日志分片
 - Parameters:
 - partData: 分片数据
 - uploadId: 上传ID
 - partNumber: 分片序号
 - token: 授权token
 - isLast: 是否最后一片
 - size: 分片大小
 - fileName: 文件名
 - uploadType: 上传类型
 - uploadRelateId: 关联单据ID
 - success: 成功回调
 - failure: 失败回调
 */
- (void)uploadPartData:(NSData *)partData
              uploadId:(NSString *)uploadId
            partNumber:(NSString *)partNumber
                 token:(NSString *)token
                isLast:(NSString *)isLast
                  size:(NSString *)size
              fileName:(NSString *)fileName
            uploadType:(LogUploadType)uploadType
        uploadRelateId:(NSString *)uploadRelateId
               success:(RVLogUploadSuccess)success
               failure:(RVLogUploadFailure)failure;

@end

NS_ASSUME_NONNULL_END
