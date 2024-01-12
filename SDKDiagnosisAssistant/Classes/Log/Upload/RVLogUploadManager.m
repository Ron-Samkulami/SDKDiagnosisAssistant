//
//  RVUploadLogFileManager.m
//
//  Created by 石学谦 on 2020/4/20.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import "RVLogUploadManager.h"

#import "AFRVSDKNetworking.h"
#import "RVResponseParser.h"
#import "VVZipArchive.h"
#import "RVFileStream.h"
#import "RVLogUploadSettingModel.h"
#import "RVLogUploadNetManager.h"
#import "RVLogService.h"
#import "RVOnlyLog.h"

#import "RVNetUtils.h"
#import "NSStringUtils.h"
#import "RSXToolSet.h"

/// 上传文件的配置文件名
static NSString *const RVUploadArchiveName = @"RVLogUploadArchive.archive";
/// 上传的queue名
static const char *RVLogUploadQueueName = "com.sdk.log.upload";

@interface RVLogUploadManager ()
/// 文件流处理
@property (nonatomic, strong) RVFileStream *fileStream;
/// 信号量
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
/// 串行队列
@property (nonatomic, strong) dispatch_queue_t queue;
/// 是否正在运行
@property (nonatomic, assign) BOOL isRunning;
/// 后台返回token失败的次数(对次数做限制，防止死循环)
@property (nonatomic, assign) int invalidTokenCount;
/// 上传设置
@property (nonatomic, strong) RVLogUploadSettingModel *settingModel;

/// 上传类型
@property (nonatomic, strong) LogUploadType uploadType;
/// 上传文件关联的单据ID
@property (nonatomic, strong) NSString *uploadRelateId;

/*
 沙盒缓存日志文件目录结构
 RVLog
    upload
        xx.zip
        xx.archive
        logs
            sdklog
            cplog
 */

@end

@implementation RVLogUploadManager

+ (instancetype)sharedManager {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


+ (void)startManager {
    // 重启未完成的上传任务
    [[RVLogUploadManager sharedManager] reStartUpload];
}


/// 重启未完成的上传任务
- (void)reStartUpload {
    
    //防止上传的时候被多次调用
    if (_isRunning) {
        NSLogInfo(@"RVLogUploadManager _isRunning = YES");
        return;
    }
    _isRunning = YES;
    
    NSString *lastUploadId = nil;
    // 尝试读取本地缓存
    [self unarchiveUploadFileStream];
    if (self.fileStream && !isStringEmpty(self.fileStream.uploadId)) {
        // 本地有缓存，继续上次的文件上传操作
        lastUploadId = self.fileStream.uploadId;
    }
    // 获取配置信息
    [[RVLogUploadNetManager sharedManager] fetchAuthorityToUploadWithUploadId:lastUploadId success:^(NSDictionary *result) {
        NSLogDebug(@"result=%@",result);
        // 根据上传配置处理上传任务
        [self handleUploadTaskWithUploadInfo:result lastUploadId:lastUploadId];
        
    } failure:^(NSInteger code, NSString * _Nullable msg) {
        NSLogDebug(@"code=%zd,msg=%@",code,msg);
        if (code != NETWORK_ERR_CODE) {
            [self removeUploadFileCache];
        }
        [self sessionDealloc];
    }];
}


/// 从本地缓存获取最近一次日志上传的任务id
- (NSString *)getLastUploadId {
    
    // 防止上传的时候被多次调用
    if (_isRunning) {
        NSLogInfo(@"RVLogUploadManager _isRunning = YES");
        return nil;
    }
    NSString *lastUploadId = nil;
    //尝试读取本地缓存
    [self unarchiveUploadFileStream];
    if (self.fileStream && !isStringEmpty(self.fileStream.uploadId)) {
        //本地有缓存，继续上次的文件上传操作
        lastUploadId = self.fileStream.uploadId;
    }
    return lastUploadId;
}

- (void)startUploadLogWitTaskInfo:(NSDictionary *)taskInfo {
    
    //防止上传的时候被多次调用
    if (_isRunning) {
        NSLogInfo(@"RVLogUploadManager _isRunning = YES");
        return;
    }
    _isRunning = YES;
    
    if (![taskInfo isKindOfClass:[NSDictionary class]]) {
        [self sessionDealloc];
        return;
    }
    RVResponseParser *logParser = [[RVResponseParser alloc] initWithURL:nil];
    [logParser parseResponseObject:taskInfo];
    if (logParser.code != 1) {
        [self removeUploadFileCache];
        [self sessionDealloc];
        return;
    }
    NSDictionary *result = logParser.resultData;
    
    NSLogDebug(@"result=%@",result);
    
    //猎影日志回捞类型，不需要关联单据
    self.uploadType = LogUploadTypeSDKLog;
    self.uploadRelateId = nil;
    
    NSString *lastUploadId = self.fileStream.uploadId;
    // 根据上传配置处理上传任务
    [self handleUploadTaskWithUploadInfo:result lastUploadId:lastUploadId];
}

/// 直接创建新的上传任务
- (void)startUploadWithUploadId:(NSString *)uploadId token:(NSString *)token uploadRelateId:(NSString *)uploadRelateId {
    // uploadId和token不能为空
    if (!token || !uploadId) {
        NSLogError(@"RVLogUploadManager uploadId or token is nil! Abort upload");
        return;
    }
    
    //防止上传的时候被多次调用
    if (_isRunning) {
        NSLogInfo(@"RVLogUploadManager _isRunning = YES");
        return;
    }
    _isRunning = YES;
    
    // 客服工单日志类型，需要关联单据
    self.uploadType = LogUploadTypeService;
    self.uploadRelateId = uploadRelateId;
    
    NSString *mode = [NSString stringWithFormat:@"%zd",RVLogUploadNetModeNormal];
    
    NSDictionary *uploadConfigDict = @{
        @"model":mode,              // 数据网络允许上传
        @"slice":@"5120",         // 日志分片大小
    };
    NSDictionary *uploadInfo = @{
        @"uploadId":uploadId,
        @"token":[RSXToolSet URLEncodeString:token],
        @"isAllowed":@1,
        @"config":uploadConfigDict,
    };
    // 根据上传配置处理上传任务
    [self handleUploadTaskWithUploadInfo:uploadInfo lastUploadId:nil];
}

/// 根据上传配置处理上传任务
- (void)handleUploadTaskWithUploadInfo:(NSDictionary *)infoDict lastUploadId:(NSString *)lastUploadId
{
    //获取设置模型
    self.settingModel = [[RVLogUploadSettingModel alloc] initWithDict:infoDict];
    
    NSString *logLevel = [infoDict valueForKeyPath:@"config.logLevel"];
    if (logLevel != nil) {
        // 有传日志等级时，根据服务器的配置修改log等级
        [[RVLogService sharedInstance] settingFileLogLevelAccordingToServer:self.settingModel.config.logLevel];
    }
    
    BOOL isWLAN = [AFRVSDKNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFRVSDKNetworkReachabilityStatusReachableViaWWAN;
    if (self.settingModel.config.mode == RVLogUploadNetModeWifi && isWLAN) {
        //后台设置了只wifi上传，那么蜂窝数据网络的情况下就不上传
        [self sessionDealloc];
        return;
    }

    NSString *uploadId = self.settingModel.uploadId;
    //后台允许才能进行上传
    if (self.settingModel.isAllowed) {
        
        //新上传：lastUploadId=nil；继续上传：lastUploadId=uploadId
        if ([uploadId isEqualToString:lastUploadId]) {
            //继续上次的上传
            [self contineLastUpload:uploadId];
        } else {
            //新上传
            if (!_queue) {
                //因为有压缩过程，故在子线程运行
                _queue = dispatch_queue_create(RVLogUploadQueueName, NULL);
            }
            dispatch_async(_queue, ^{
                [self uploadNewLogWithUploadId:uploadId];
            });
        }
        
    } else {
        //没有权限了，删除文件吧
        [self removeUploadFileCache];
        [self sessionDealloc];
    }
}

#pragma mark - 新上传

//压缩并上传新文件
- (void)uploadNewLogWithUploadId:(NSString *)uploadId {
    
    NSLogInfo(@"新上传...uploadId=%@",uploadId);
    //压缩log文件夹
    NSString *zipPath = [self zipArchiveLogs];
    if (!zipPath) {
        NSLogInfo(@"zipPath 不存在");
        [self sessionDealloc];
        return;
    }
    
    //获取文件流(里面有文件信息和分片信息)
    long long sliceSize = self.settingModel.config.sliceSize;
    RVFileStream *fileStream = [[RVFileStream alloc] initWithFilePath:zipPath uploadId:uploadId cutFragmenSize:sliceSize];
    if (!fileStream) {
        [self sessionDealloc];
        return;
    }
    
    //创建新上传时，手动设置上传类型及关联ID
    fileStream.uploadType = self.uploadType;
    fileStream.uploadRelateId = self.uploadRelateId;
    
    self.fileStream = fileStream;
    //归档文件流(断点续传需要)
    [self archiveUploadFileStream];
    
    //文件上传操作
    [self uploadFileDataInQueue];
}

//压缩RVLog/upload/logs文件夹，logs文件夹里面有SDK和研发的log文件
- (NSString *)zipArchiveLogs {
    
    //拷贝SDK的log
    [self copySDKLog];
    
    //拷贝研发的log
    [self copyCPLog];

    
    //【upload】文件夹所在的路径
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *uploadDir = [self getUploadDirPath];
    if (![fileMgr fileExistsAtPath:uploadDir]) {
        NSLogInfo(@"upload文件夹不存在");
        return nil;
    }
    //需要处理的【logs】文件夹所在的路径
    NSString *logsDirPath = [self getUploadLogsDirPath];;
    if (![fileMgr fileExistsAtPath:logsDirPath]) {
        NSLogInfo(@"logs文件夹不存在");
        return nil;
    }
    
    //压缩包文件路径
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyy.MM.dd-HH.mm.ss"];
    NSString *dateString = [dateFormatter stringFromDate:NSDate.date];
    NSString *zipPath = [[self getUploadDirPath] stringByAppendingFormat:@"/%@.zip",dateString];
    
    
    BOOL success = NO;
    NSString *beforeSizeStr = nil;
    NSString *afterSizeStr = nil;
    
    
    //=====压缩整个logs文件夹======
    //显示处理前文件大小
    beforeSizeStr = [self getFileSizeStrWithPath:logsDirPath];
    NSLogInfo(@"beforeSizeStr=%@",beforeSizeStr);
    //压缩整个logs文件夹
    success = [VVZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:logsDirPath];
    //显示处理后文件大小
    afterSizeStr = [self getFileSizeStrWithPath:zipPath];
    NSLogInfo(@"createZip logs success=%d,\n afterSizeStr=%@",success,afterSizeStr);
    if (success) {
        return zipPath;
    }

    
    //=====压缩最新的sdklog文件======
    //文件夹压缩失败后，直接压缩最新的sdklog文件
    NSArray *logPaths = [RVLogService sharedInstance].filePaths;
    if (logPaths.count <= 0) {
        return nil;
    }
    NSString *logPath = [logPaths firstObject];
    //显示处理前文件大小
    beforeSizeStr = [self getFileSizeStrWithPath:logPath];
    NSLogInfo(@"beforeSizeStr=%@",beforeSizeStr);
    //压缩最新的log文件
    success = [VVZipArchive createZipFileAtPath:zipPath withFilesAtPaths:@[logPath]];
    //显示处理后文件大小
    afterSizeStr = [self getFileSizeStrWithPath:zipPath];
    NSLogInfo(@"createZip log success=%d,\n afterSizeStr=%@",success,afterSizeStr);
    if (success) {
        return zipPath;
    }
    
    
    //=====拷贝最新的sdklog文件======
    //文件压缩也失败，直接拷贝最新的sdklog文件进行上传
    NSString *logFileName = [logPath lastPathComponent];
    NSString *desLogPath = [uploadDir stringByAppendingPathComponent:logFileName];
    //显示处理后文件大小
    afterSizeStr = [self getFileSizeStrWithPath:desLogPath];
    NSLogInfo(@"copy log success=%d,\n afterSizeStr=%@",success,afterSizeStr);
    //拷贝log文件
    success = [[NSFileManager defaultManager] copyItemAtPath:logPath toPath:desLogPath error:nil];
    if (success) {
        return desLogPath;
    }
    
    
    //所有方式都失败
    NSLogWarn(@"zip failed!");
    return nil;
}

#pragma mark - 继续上次的上传

//继续上传上次未传完的文件
- (void)contineLastUpload:(NSString *)uploadId {
    
    NSLogInfo(@"继续上次的上传uploadId=%@",uploadId);
    //获取上一次的上传记录，以后端返回为准
    [[RVLogUploadNetManager sharedManager] getUploadProgressWithUploadId:uploadId success:^(NSDictionary *result) {
        
        //"parts":"1,2,3"
        NSString *partsStr = result[@"parts"];
        NSArray *parts = @[];
        if (!isStringEmpty(partsStr)) {
            parts = [partsStr componentsSeparatedByString:@","];
        }
        NSLogInfo(@"进度 parts=%@",parts);
        int fragmentCount = (int)self.fileStream.streamFragments.count;
        for (int i=0; i<fragmentCount; i++) {
            // 文件分片上传是否成功，以后端返回为准
            RVStreamFragment *fragment = self.fileStream.streamFragments[i];
            NSString *partNumStr = fragment.fragmentId;
            if ([parts containsObject:partNumStr]) {
                fragment.status = YES;
            } else {
                fragment.status = NO;
            }
        }
        //文件上传配置保存到本地
        [self archiveUploadFileStream];
        //文件上传操作
        [self uploadFileDataInQueue];
        
    } failure:^(NSInteger code, NSString * _Nullable msg) {
        if (code != NETWORK_ERR_CODE) {
            [self removeUploadFileCache];
        }
        [self sessionDealloc];
    }];
}

#pragma mark - 上传操作
//文件上传操作
- (void)uploadFileDataInQueue {
    
    if (self.semaphore == nil) {
        //用来限制并发个数，目前是限制为一个
        self.semaphore = dispatch_semaphore_create(0);
    }
    if (!_queue) {
        _queue = dispatch_queue_create(RVLogUploadQueueName, NULL);
    }
    dispatch_async(_queue, ^{
        //需要在独立的queue上传，不影响主线程。而且semaphore也不能在主线程使用,否则很容易卡线程
        [self uploadLogData];
    });
}


//按顺序一片一片进行上传，不做并发上传
- (void)uploadLogData {
    
    if ([NSThread isMainThread]) {
        NSLogError(@"当前在主线程，直接返回");
        return;
    }
    
    __block BOOL isFailed = NO;
    __block BOOL isInvalidToken = NO;
    
    NSLogDebug(@"fileStream fileSize=%zd",self.fileStream.fileSize);
    
    int fragmentCount = (int)self.fileStream.streamFragments.count;
    for (int i=0; i<fragmentCount; i++) {
        //文件片信息
        RVStreamFragment *fragment = self.fileStream.streamFragments[i];
        if (fragment.status) {
            //已经上传成功的不再处理
            NSLogDebug(@"i=%d,fragmentStatus == YES",i);
            continue;
        }
        @autoreleasepool {
            //根据文件片信息来读取文件数据流(通过offset+size来定位)
            NSData *partData = [self.fileStream readDataOfFragment:fragment];
            
            if (!partData) {
                NSLogWarn(@"partData为空");
                [self removeUploadFileCache];
                isFailed = YES;
                break;
            }
            NSString *uploadId = self.fileStream.uploadId;
            NSString *partNum = fragment.fragmentId;
            NSString *isLast = (i==(fragmentCount-1))?@"1":@"0";
            NSString *fileSize = [NSString stringWithFormat:@"%zd",self.fileStream.fileSize];
            NSString *fileName = self.fileStream.fileName;
            // 上传类型和关联ID
            LogUploadType uploadType = self.fileStream.uploadType;
            NSString *uploadRelateId = self.fileStream.uploadRelateId;
            
            NSString *token = self.settingModel.token;
            
            //使用网络库上传，如果网络失败，会延时重试两次
            [self uploadPartData:partData uploadId:uploadId partNumber:partNum token:token isLast:isLast size:fileSize fileName:fileName currentRepeatTimes:0 uploadType:uploadType uploadRelateId:uploadRelateId success:^(NSDictionary * _Nonnull result) {

                NSLogDebug(@"uploadPartData success=%@",result);
                fragment.status = YES;
                //上传配置保存到本地
                [self archiveUploadFileStream];
                
                //通过semaphore来控制每次只上传一片，可以继续下一片了
                dispatch_semaphore_signal(self.semaphore);

            } failure:^(NSInteger code, NSString * _Nullable msg) {
                NSLogInfo(@"uploadPartData error code=%zd,msg=%@",code,msg);
                
                isFailed = YES;
                if (code == NETWORK_ERR_CODE) {
                    //网络不删除文件缓存
                } else if (code == -10001) {
                    //-10001代表token无效，需要重新申请token
                    isInvalidToken = YES;
                    NSLogInfo(@"code == -10001");
                } else {
                    //除了上面的情况，其他失败都删除文件缓存，避免一直失败
                    [self removeUploadFileCache];
                }
                
                //通过semaphore来控制每次只上传一片，可以进行后面的操作了(就是break操作)
                dispatch_semaphore_signal(self.semaphore);
            }];
            
            //通过semaphore来控制每次只上传一片，这里进行堵塞
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
            
            if (isFailed) {
                //为什么要加这玩意？因为在上传的block里面用break无效。。。
                NSLogInfo(@"上传失败了，不再处理");
                break;
            }
        }
    }
    
    NSLogInfo(@"完成了循环");
    
    if(!isFailed) {
        //整个循环顺利走完了，删除文件缓存
        [self removeUploadFileCache];
    }
    
    [self sessionDealloc];
    
    //Token失效直接重新开始走所有上传流程(限制次数，防止死循环)
    if (isInvalidToken) {
        self.invalidTokenCount += 1;
        if (self.invalidTokenCount<3) {
            NSLogInfo(@"invalidTokenCount=%d",self.invalidTokenCount);
            // 重启未完成的上传任务，会重新获取有效token
            [self reStartUpload];
        }
    }
    
}

//网络上传，网络失败会重试两次
- (void)uploadPartData:(NSData *)partData
              uploadId:(NSString *)uploadId
            partNumber:(NSString *)partNumber
                 token:(NSString *)token
                isLast:(NSString *)isLast
                  size:(NSString *)size
              fileName:(NSString *)fileName
     currentRepeatTimes:(int)times
            uploadType:(LogUploadType)uploadType
        uploadRelateId:(NSString *)uploadRelateId
               success:(RVLogUploadSuccess)success
               failure:(RVLogUploadFailure)failure
{
    static int const maxTimes = 3;//一共3次
    if (times >= maxTimes) {
        NSLogInfo(@"网络超时超过重试次数，返回失败");
        if (failure) failure(NETWORK_ERR_CODE,@"网络超时超过重试次数，返回失败");
        return;
    }
    NSLogInfo(@"uploadPartData times=%d",times);
    [[RVLogUploadNetManager sharedManager] uploadPartData:partData uploadId:uploadId partNumber:partNumber token:token isLast:isLast size:size fileName:fileName uploadType:uploadType uploadRelateId:uploadRelateId success:success failure:^(NSInteger code, NSString * _Nullable msg) {
        
        //网络失败的话重试2次
        if (code == NETWORK_ERR_CODE) {
            //延迟重试
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //递归调用
                [self uploadPartData:partData uploadId:uploadId partNumber:partNumber token:token isLast:isLast size:size fileName:fileName currentRepeatTimes:times+1 uploadType:uploadType uploadRelateId:uploadRelateId success:success failure:failure];
            });
            
        } else {
            
            if (failure) failure(code,msg);
        }
    }];
    
}

#pragma mark - 配置文件操作

//上传配置保存到本地
- (BOOL)archiveUploadFileStream {
    
    if (!self.fileStream) {
        NSLogInfo(@"!self.fileStream");
        return NO;
    }
    NSString *dirPath = [self getUploadDirPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        NSLogInfo(@"createDirectoryAtPath error=%@",error);
    }
    NSString *filePath = [dirPath stringByAppendingPathComponent:RVUploadArchiveName];
    BOOL success = [NSKeyedArchiver archiveRootObject:self.fileStream toFile:filePath];
    return success;
}

/// 读取上一次保存的配置文件
- (void)unarchiveUploadFileStream {
    
    NSString *dirPath = [self getUploadDirPath];
    NSString *filePath = [dirPath stringByAppendingPathComponent:RVUploadArchiveName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSLogDebug(@"unarchiveUploadFileStream filePath不存在 filePath=%@",filePath);
        return;
    }
   
    RVFileStream *fileSteam = nil;
    @try {
        //使用NSKeyedUnarchiver的话必须使用try@catch,不然改类名后会崩溃
         fileSteam = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    } @catch (NSException *exception) {
        NSLogWarn(@"unarchiveUploadFileStream exception=%@",exception);
        //出现异常，删除文件
        [self removeUploadFileCache];
        fileSteam = nil;
    } @finally {
        
        //由于沙盒路径会变化，故重新赋值
        fileSteam.filePath = [[self getUploadDirPath] stringByAppendingPathComponent:fileSteam.fileName];
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileSteam.filePath]) {
            //上次压缩的文件已经不存在，删除记录
            NSLogWarn(@"上次压缩的文件已经不存在");
            [self removeUploadFileCache];
            return;
        }
        
        self.fileStream = fileSteam;
    }

}


/// 删除上传文件夹
- (void)removeUploadFileCache {
    NSLogDebug(@"removeUploadFileCache");
    NSString *dirPath = [self getUploadDirPath];
    [[NSFileManager defaultManager] removeItemAtPath:dirPath error:nil];
}

/// 上传时用的文件夹
- (NSString *)getUploadDirPath {
    NSString *sdkApplicationSupportPath = [RSXToolSet getSDKApplicationSupportPath];
    NSString *uploadDir = [sdkApplicationSupportPath stringByAppendingPathComponent:@"RVLog/upload"];

    return uploadDir;
}

/// 暂时存放log文件的文件夹 upload/logs
- (NSString *)getUploadLogsDirPath {
    NSString *uploadDir = [self getUploadDirPath];
    NSString *uploadLogsDir = [uploadDir stringByAppendingPathComponent:@"logs"];
    return uploadLogsDir;
}

/// 拷贝SDK的log
- (void)copySDKLog {
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    //SDK logs文件夹的路径
    NSString *logsDirPath = [RVLogService sharedInstance].logsDir;
    if (![fileMgr fileExistsAtPath:logsDirPath]) {
        NSLogWarn(@"log文件夹不存在");
        return;
    }
    NSString *uploadLogsDir = [self getUploadLogsDirPath];
    NSString *sdkUploadPath = [uploadLogsDir stringByAppendingPathComponent:@"sdklog"];
    if ([fileMgr fileExistsAtPath:sdkUploadPath]) {
        [fileMgr removeItemAtPath:sdkUploadPath error:nil];
    }
    [fileMgr createDirectoryAtPath:uploadLogsDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *error = nil;
    [fileMgr copyItemAtPath:logsDirPath toPath:sdkUploadPath error:&error];
    if (error) {
        NSLogInfo(@"sdkUploadPath error=%@",error);
        return;
    }
}


//拷贝研发的log
- (void)copyCPLog {
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];

//    NSString *cpRelativePath = @"/Library/ABLog";
//    NSString *logsPath = [NSHomeDirectory() stringByAppendingString:cpRelativePath];
    
    //路径从 self.cpLogPath读取,一般会是文件夹，也有极少可能是文件
    if (isStringEmpty(self.settingModel.config.path)) {
        NSLogInfo(@"没有传入研发日志路径");
        return;
    }
    NSString *logsPath = [NSHomeDirectory() stringByAppendingString:self.settingModel.config.path];

    //路径是否存在
    BOOL isDir = NO;
    if (![fileMgr fileExistsAtPath:logsPath isDirectory:&isDir]) {
        NSLogWarn(@"log文件夹不存在 logsDirPath=%@",logsPath);
        return;
    }
    //文件或文件夹大小
    unsigned long long fileSize = [RSXToolSet sizeAtPath:logsPath];
    NSLogInfo(@"fileSize=%lld",fileSize);
    
    //文件大小大于100M，只获取最新的log文件
    if (isDir && fileSize > 1024*1024*100) {
        
        logsPath = [self returnNewestLogFile:logsPath];
        if (!logsPath) {
            NSLogInfo(@"NewestLogFile nil");
            return;
        }
        
        fileSize = [RSXToolSet sizeAtPath:logsPath];
        NSLogInfo(@"使用最新的log文件 %@",logsPath);
        isDir = NO;
    }
    NSLogInfo(@"fileSize=%lld",fileSize);
    if (fileSize > 1024*1024*100) {
        NSLogInfo(@"文件大于100M");
        return;
    }
    
    //删除之前的cplog文件夹及其内容，创建新的文件夹
    NSString *uploadLogsDir = [self getUploadLogsDirPath];
    NSString *cpUploadPath = [uploadLogsDir stringByAppendingPathComponent:@"cplog"];
    if ([fileMgr fileExistsAtPath:cpUploadPath]) {
        [fileMgr removeItemAtPath:cpUploadPath error:nil];
    }
    [fileMgr createDirectoryAtPath:uploadLogsDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    //如果拷贝的是一个文件，需要特殊处理
    if (!isDir) {
        //创建文件夹
        [fileMgr createDirectoryAtPath:cpUploadPath withIntermediateDirectories:YES attributes:nil error:nil];
        //拼接文件路径
        NSString *logFileName = logsPath.lastPathComponent;
        cpUploadPath = [cpUploadPath stringByAppendingPathComponent:logFileName];
    }
   
    NSLogDebug(@"cpUploadPath=%@",cpUploadPath);
    NSError *error = nil;
    //将logs拷贝到对应路径
    [fileMgr copyItemAtPath:logsPath toPath:cpUploadPath error:&error];
    if (error) {
        NSLogInfo(@"cpUploadPath error=%@",error);
        return;
    }
}

//获取最新的log文件
- (NSString *)returnNewestLogFile:(NSString *)dirPath {
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *rootPath = dirPath;/*获取根目录*/
    NSArray *pathsArr = [fileMgr subpathsAtPath:rootPath];/*取得文件列表*/
    
    NSArray *sortedPaths = [pathsArr sortedArrayUsingComparator:^(NSString *firstPath, NSString *secondPath) {

        NSString *firstUrl = [rootPath stringByAppendingPathComponent:firstPath];/*获取前一个文件完整路径*/
        NSString *secondUrl = [rootPath stringByAppendingPathComponent:secondPath];/*获取后一个文件完整路径*/
        NSDictionary *firstFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:firstUrl error:nil];/*获取前一个文件信息*/
        NSDictionary *secondFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:secondUrl error:nil];/*获取后一个文件信息*/
        id firstData = [firstFileInfo objectForKey:NSFileCreationDate];/*获取前一个文件创建时间*/\
        id secondData = [secondFileInfo objectForKey:NSFileCreationDate];/*获取后一个文件创建时间*/
        return [firstData compare:secondData];//升序
        // return [secondData compare:firstData];//降序
    }];

    //    这样最后得到的sortedPaths就是我们按创建时间排序后的文件， 然后我们就可以根据自己的需求来操作已经排序过的文件了，如删除最先创建的文件等：
    NSEnumerator *e = [sortedPaths objectEnumerator];
    NSString *filename;
    while ((filename = [e nextObject])) {
        BOOL isLog = [filename hasSuffix:@".txt"] || [filename hasSuffix:@".log"];;
        if (isLog) {
            NSString *path = [rootPath stringByAppendingPathComponent:filename];//由于文件夹是升序排列
            NSLogDebug(@"最新的文件路径=%@",path);
            return path;
        }
    }
    
    return nil;
}


#pragma mark - 内存释放

- (void)sessionDealloc {
    NSLogDebug(@"sessionDealloc");
    _fileStream = nil;
    _semaphore = NULL;
    _queue = NULL;
    _isRunning = NO;
    _settingModel = nil;
    _uploadType = nil;
    _uploadRelateId = nil;
}

//MARK: - self getFileSizeStrWithPath 公用方法上浮
//根据传入的文件路径返回显示的字符串 xxB,xxK,,xxM,xxG
- (NSString *)getFileSizeStrWithPath:(NSString *)path {
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    NSString *fileSizeStr = @"0B";
    if(![fileMgr fileExistsAtPath:path isDirectory:&isDir]) {
        return fileSizeStr;
    }
    
    unsigned long long fileSize = 0;
    if (!isDir) {
        //显示文件大小
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        fileSize = attr.fileSize;
    } else {
        //我们只算一层的
        NSArray *subPaths =  [fileMgr subpathsAtPath:path];
        if (subPaths && subPaths.count > 0) {
            for (int i=0; i<subPaths.count; i++) {
                NSString *subPath = [path stringByAppendingPathComponent:subPaths[i]];
                NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:subPath error:nil];
                fileSize += attr.fileSize;
            }
        }
    }
    
    if (fileSize <= 0) {
        return fileSizeStr;
    }
    
    CGFloat unitSize = 1000.0f;
    
    if (fileSize < unitSize) {
        fileSizeStr = [NSString stringWithFormat:@"%lldB",fileSize];
    } else if (fileSize < unitSize*unitSize) {
        fileSizeStr = [NSString stringWithFormat:@"%fKB",fileSize/unitSize];
    } else if (fileSize < unitSize*unitSize*unitSize) {
        fileSizeStr = [NSString stringWithFormat:@"%.2fMB",fileSize/unitSize/unitSize];
    } else {
        fileSizeStr = [NSString stringWithFormat:@"%.2fGB",fileSize/unitSize/unitSize/unitSize];
    }
    return fileSizeStr;
}
@end
