//
//  XXXLogService.h
//
//  Created by 石学谦 on 2020/4/2.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RVOnlyLog.h"


NS_ASSUME_NONNULL_BEGIN

extern NSString *const RVFileLogLevelKey;
extern NSString *const RVConsoleLogLevelKey;
extern NSString *const RVManualFileLogLevelKey;


@interface RVLogService : NSObject

/// log写入到沙盒文件
@property (nonatomic, assign)BOOL writeLogToFile;
/// 在控制台显示log
@property (nonatomic, assign)BOOL showlogInConsole;
/// 每次启动生成新的log文件
@property (nonatomic, assign)BOOL createNewLogEveryLaunching;
/// 下次启动打开log浮窗
@property (nonatomic, assign)BOOL showDebugWindowConfig;

/// 初始化
+ (void)start;
/// 单例
+ (instancetype)sharedInstance;

#pragma mark - 界面操作

/// 显示Log文件夹内容
- (void)displayLogs;
/// 显示当前的log内容
- (void)dispalyCurrentLog;
/// 显示日志调试浮窗
- (void)openLogDebugWindow;

#pragma mark - 路径获取

/// 返回log文件夹路径
- (NSString *)logsDir;
/// 返回所有log文件路径
- (NSArray *)filePaths;

#pragma mark - log操作

/// 切换log等级
- (void)settingFileLogLevel:(VVLogLevel)logLevel;
- (void)settingConsoleLogLevel:(VVLogLevel)logLevel;

/// 根据服务器的配置修改log等级
- (void)settingFileLogLevelAccordingToServer:(VVLogLevel)logLevel;

/// 使用新的log文件写入
- (void)createAndRollToNewFile;

#pragma mark - log上传操作
/// 获取上一次未完成的上传任务ID
+ (nullable NSString *)getLastUploadId;
/// 根据日志上传配置信息，开启上传任务
+ (void)startUploadLogWitTaskInfo:(NSDictionary *_Nonnull)taskInfo;

#pragma mark - log读取操作
/// 生成新的日志文件
+ (void)createNewLogFile;

/// 读取当前日志文件内容
+ (NSString *)readCurrentLogFile;

@end
NS_ASSUME_NONNULL_END
