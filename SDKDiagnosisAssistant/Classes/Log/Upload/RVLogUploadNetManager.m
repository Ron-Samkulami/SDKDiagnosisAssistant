//
//  RVLogUploadNetManager.m
//  RVSDK
//
//  Created by 石学谦 on 2020/4/24.
//  Copyright © 2020 SDK. All rights reserved.
//

#import "RVLogUploadNetManager.h"
#import "RVRequestManager.h"
#import "RVResponseParser.h"
#import "RVOnlyLog.h"

@implementation RVLogUploadNetManager

+ (instancetype)sharedManager
{
    static id sharedInstance = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init]; 
    });
    return sharedInstance;
}

#pragma mark 获取上传的授权和相关信息

- (void)fetchAuthorityToUploadWithUploadId:(NSString *)uploadId 
                                   success:(RVLogUploadSuccess)success
                                   failure:(RVLogUploadFailure)failure
{
    NSMutableDictionary *mDic = [[NSMutableDictionary alloc] init];
    [mDic setObject:@"用户ID" forKey:@"uid"];
    [mDic setObject:@"设备ID" forKey:@"deviceId"];
    [mDic setObject:uploadId?:@"" forKey:@"uploadId"];
    
    NSString *urlString = RV_LOG_CREATEUPLOAD_URL;
    
    [[RVRequestManager sharedManager] POST:urlString parameters:mDic success:^(id successResponse) {

        RVResponseParser *parser = [[RVResponseParser alloc] initWithURL:urlString];
        [parser parseResponseObject:successResponse];

        if (parser.code == 1) {
            if(success) success(parser.resultData);
        } else {
            if(failure) failure(parser.code,parser.message);
        }
    } failure:^(NSError *error) {

        if(failure) failure(NETWORK_ERR_CODE, error.localizedDescription?:@"");
    }];
}

#pragma mark 获取上传进度
- (void)getUploadProgressWithUploadId:(NSString *)uploadId 
                              success:(RVLogUploadSuccess)success
                              failure:(RVLogUploadFailure)failure 
{
    NSMutableDictionary *mDic = [[NSMutableDictionary alloc] init];
    [mDic setObject:@"用户ID" forKey:@"uid"];
    [mDic setObject:@"设备ID" forKey:@"deviceId"];
    [mDic setObject:uploadId?:@"" forKey:@"uploadId"];
    
    NSString *urlString = RV_LOG_RESUMEUPLOAD_URL;
    [[RVRequestManager sharedManager] POST:urlString parameters:mDic success:^(id successResponse) {

        RVResponseParser *parser = [[RVResponseParser alloc] initWithURL:urlString];
        [parser parseResponseObject:successResponse];

        if (parser.code == 1) {
            if(success) success(parser.resultData);
        } else {
            if(failure) failure(parser.code,parser.message);
        }
    } failure:^(NSError *error) {
        if(failure) failure(NETWORK_ERR_CODE, error.localizedDescription?:@"");
    }];
}

#pragma mark 文件上传
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
               failure:(RVLogUploadFailure)failure
{
    NSMutableDictionary *mDic = [[NSMutableDictionary alloc] init];
    [mDic setObject:@"用户ID" forKey:@"uid"];
    [mDic setObject:@"设备ID" forKey:@"deviceId"];
    [mDic setObject:uploadId?:@"" forKey:@"uploadId"];
    [mDic setObject:partNumber?:@"" forKey:@"partNumber"];
    [mDic setObject:token?:@"" forKey:@"token"];
    [mDic setObject:isLast?:@"" forKey:@"isLast"];
    [mDic setObject:size?:@"" forKey:@"size"];
    
    NSString *urlString = RV_LOG_UPLOADPART_URL;
    
    AFRVSDKHTTPSessionManager *manager = [RVRequestManager sharedManager].sessionManager;

    [manager POST:urlString parameters:mDic headers:nil constructingBodyWithBlock:^(id<AFRVSDKMultipartFormData>  _Nonnull formData) {

        //上传文件参数
        [formData appendPartWithFileData:partData name:@"body" fileName:fileName?:@"test.zip" mimeType:@"multipart/form-data"];

    } progress:^(NSProgress * _Nonnull uploadProgress) {

        //打印上传进度
        CGFloat progress = 100.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount;
        NSLogDebug(@"%.2lf%%", progress);

    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

        RVResponseParser *parser = [[RVResponseParser alloc] initWithURL:urlString];
        [parser parseResponseObject:responseObject];

        if (parser.code == 1) {
           if(success) success(parser.resultData);
        } else {
           if(failure) failure(parser.errorCode,parser.message);
        }

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        //请求失败
        NSLogDebug(@"urlString = %@ error=%@", urlString, error.localizedDescription);
        if(failure) failure(NETWORK_ERR_CODE, error.localizedDescription?:@"");
    }];
    
}

@end
