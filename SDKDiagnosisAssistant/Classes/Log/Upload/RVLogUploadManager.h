//
//  RVUploadLogFileManager.h
//
//  Created by 石学谦 on 2020/4/20.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RVLogUploadManager : NSObject

+ (instancetype)sharedManager;

/**
 启动上传管理器，本地有未上传完成的任务时会继续上传，没有则不理
 */
+ (void)startManager;


/**
 从本地缓存获取最近一次日志上传的任务id
 */
- (nullable NSString *)getLastUploadId;


/**
 根据日志上传配置处理执行上传任务
 - Parameter taskInfo: 日志上传信息
 */
- (void)startUploadLogWitTaskInfo:(NSDictionary *)taskInfo;


/**
 直接创建新的上传任务，跳过本地缓存的未上传记录（目前用于工单上传关联的日志）
 - Parameters:
 - uploadId: 上传ID
 - token: 上传Token
 - uploadRelateId: 关联的工单ID
 */
- (void)startUploadWithUploadId:(NSString *)uploadId token:(NSString *)token uploadRelateId:(NSString *)uploadRelateId ;

@end

NS_ASSUME_NONNULL_END
