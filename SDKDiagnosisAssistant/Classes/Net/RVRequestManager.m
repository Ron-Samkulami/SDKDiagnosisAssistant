//
//  RVRequestManager.m
//

#import "RVRequestManager.h"
#import "RVLogService.h"
#import "RVNetUtils.h"

/**
 Foundation/NSURLError.h 里面有NSURLErrorDomain枚举，里面是URLSession网络失败的错误码列表。苹果文档地址是
 https://developer.apple.com/documentation/foundation/1508628-url_loading_system_error_codes
 */


@interface RVRequestManager()

@end

@implementation RVRequestManager

+ (instancetype)sharedManager {
    static RVRequestManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RVRequestManager alloc] init];
    });
    return instance;
}

/// sessionManager懒加载
- (AFRVSDKHTTPSessionManager *)sessionManager
{
    if (_sessionManager == nil) {
        _sessionManager = [AFRVSDKHTTPSessionManager manager];
        //设置可接受类型
        _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",@"text/plain", @"text/json", @"text/javascript", @"text/html", nil];
        
//        _sessionManager.responseSerializer = [AFRVSDKHTTPResponseSerializer serializer];
        
//        //解决https的问题
//        AFRVSDKSecurityPolicy *securityPolicy = [[AFRVSDKSecurityPolicy alloc] init];
//        securityPolicy.allowInvalidCertificates = YES;
//        securityPolicy.validatesDomainName = NO;
//        [_sessionManager setSecurityPolicy:securityPolicy];
//        _sessionManager.securityPolicy = AFSSLPinningModeNone;
        [_sessionManager.requestSerializer setHTTPShouldHandleCookies:YES];
        
        //设置超时时间
        _sessionManager.requestSerializer.timeoutInterval = 30.f;
        
        if (@available(iOS 10.0, *)) {
            
            //设置block，用关于获取网络耗时数据
            [_sessionManager setTaskDidFinishCollectingMetricsBlock:^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLSessionTaskMetrics * _Nullable metrics) {
                
                NSDictionary *userInfo = @{
                    @"sesssion":session?:[NSNull null],
                    @"task":task?:[NSNull null],
                    @"metrics":metrics?:[NSNull null],
                };
                //发送通知
                [[NSNotificationCenter defaultCenter] postNotificationName:@"kSDKRequestTaskDidFinishCollectingMetrics" object:nil userInfo:userInfo];
            }];
        }
    }
    return _sessionManager;
}


/// GET请求
- (void)GET:(NSString *)URLString
 parameters:(NSDictionary *)parameters
    success:(void (^)(id successResponse))success
    failure:(void (^)(NSError *failureResponse))failure {
    NSString *rid = [[self class] generate6RandomLetterAndNumber];
    NSLogRVSDK(@"RVRequest rid=%@,url=%@,params=%@,method=post,triedTimes=%d", rid,URLString, [RVNetUtils convertObjToJsonStringIfValid:parameters], 0);
    [self.sessionManager GET:URLString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLogRVSDK(@"RVResponse success rid=%@,url=%@,params=%@,triedTimes=%d", rid, URLString, [RVNetUtils convertObjToJsonStringIfValid:responseObject], 0);
        if (success) success(responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLogInfo(@"RVResponse failed rid=%@,url=%@,error:%@", rid, URLString, error.description);
        if (failure) failure(error);
    }];
    
}


/// POST请求
- (void)POST:(NSString *)URLString
 parameters:(NSDictionary *)parameters
    success:(void (^)(id))success
    failure:(void (^)(NSError * error))failure {
    
//    NSLogRVSDK(@"请求url=%@\nparameters=%@",URLString,parameters);
//    [self.sessionManager POST:URLString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//        NSLogRVSDK(@"响应url=%@\nparameters=%@",URLString,responseObject);
//        if (success) success(responseObject);
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//        NSLogInfo(@"网络失败url=%@,error: %@", URLString,error.description);
//        if (failure) failure(error);
//    }];
    
    [self POST:URLString parameters:parameters firstTryDelay:0 tryInterval:0 maxTryTimes:0 success:success failure:failure];
    
}


/// POST请求
- (void)POST:(NSString *)URLString parameters:(NSDictionary *)parameters firstTryDelay:(NSTimeInterval)firstTryDelayInterval tryInterval:(NSTimeInterval)tryInterval maxTryTimes:(int)maxTryTimes success:(void (^)(id))success failure:(void (^)(NSError * error))failure {
    
    [self POST:URLString parameters:parameters firstTryDelay:firstTryDelayInterval tryInterval:tryInterval maxTryTimes:maxTryTimes triedTimes:0 isDNSTried:NO requestSign:nil success:success failure:failure];
}

/// POST请求
- (void)POST:(NSString *)URLString parameters:(NSDictionary *)parameters firstTryDelay:(NSTimeInterval)firstTryDelayInterval tryInterval:(NSTimeInterval)tryInterval maxTryTimes:(int)maxTryTimes triedTimes:(int)triedTimes isDNSTried:(BOOL)isDNSTried requestSign:(NSString *)requestSign success:(void (^)(id))success failure:(void (^)(NSError * error))failure {
    
    //对输入参数做异常输入处理
    if (firstTryDelayInterval < 0) { firstTryDelayInterval = 0; }
    if (tryInterval < 0) { tryInterval = 0; }
    if (maxTryTimes < 0) { maxTryTimes = 0; }
    if (triedTimes < 0) { triedTimes = 0; }
    
    // 一个请求的sign，如果是重试，不需重新生成
    if (requestSign == nil) {
        NSString *requestSignStr = [NSString stringWithFormat:@"%@%@",URLString,[RVNetUtils getCurrentTimeStamp]];
        requestSign = [RVNetUtils md5HexDigest:requestSignStr];
    }
    
    NSString *rid = [requestSign substringToIndex:6];
    NSLogRVSDK(@"RVRequest rid=%@,url=%@,params=%@,method=post,triedTimes=%d", rid,URLString, [RVNetUtils convertObjToJsonStringIfValid:parameters], triedTimes);
    
    [self.sessionManager POST:URLString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        NSLogRVSDK(@"RVResponse success rid=%@,url=%@,params=%@,triedTimes=%d", rid, URLString, [RVNetUtils convertObjToJsonStringIfValid:responseObject], triedTimes);
        if (success) success(responseObject);
        
        NSDictionary *userInfo = @{
            @"task":task?:[NSNull null],
            @"urlString":URLString?:@"",
            @"triedTimes":[NSString stringWithFormat:@"%d",triedTimes],
            @"isDNSTried":isDNSTried?@"1":@"0",
            @"requestSign":requestSign?:@"",
        };
        //发送通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kSDKRequestNetworkSuccessNotification" object:nil userInfo:userInfo];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLogInfo(@"RVResponse failed rid=%@,url=%@,error=%@,triedTimes=%d", rid, URLString,error.description,triedTimes);

        NSDictionary *userInfo = @{
            @"task":task?:[NSNull null],
            @"urlString":URLString?:@"",
            @"triedTimes":[NSString stringWithFormat:@"%d",triedTimes],
            @"error":error?:[NSNull null],
            @"isDNSTried":isDNSTried?@"1":@"0",
            @"requestSign":requestSign?:@"",
        };
        //发送通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kSDKRequestNetworkErrorNotification" object:nil userInfo:userInfo];
        
        
        BOOL isDNSFailed = NO;
        NSInteger errorCode = error.code;
        switch (errorCode) {
            case kCFHostErrorHostNotFound:
            case kCFHostErrorUnknown:
            case kCFURLErrorCannotFindHost://请求一个不存在的域名会是这个报错，有成功过
            case kCFURLErrorCannotConnectToHost://有成功过
            case kCFURLErrorDNSLookupFailed:
            case kCFNetServiceErrorDNSServiceFailure:
            case kCFErrorHTTPSProxyConnectionFailure:
            case kCFStreamErrorHTTPSProxyFailureUnexpectedResponseToCONNECTMethod:
            case kCFURLErrorSecureConnectionFailed://有成功过
            case kCFURLErrorServerCertificateHasBadDate:
            case kCFURLErrorServerCertificateUntrusted:
            case kCFURLErrorServerCertificateHasUnknownRoot:
            case kCFURLErrorServerCertificateNotYetValid:
            case kCFURLErrorClientCertificateRejected:
            case kCFURLErrorClientCertificateRequired:
            case kCFURLErrorCannotLoadFromNetwork:
                isDNSFailed = YES;
                break;
            default:
                break;
        }
         
        //失败后需要重试
        if (triedTimes < maxTryTimes && maxTryTimes != 0) {
            NSTimeInterval timeInterval = firstTryDelayInterval + (tryInterval * triedTimes);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //递归调用
                [self POST:URLString parameters:parameters firstTryDelay:firstTryDelayInterval tryInterval:tryInterval maxTryTimes:maxTryTimes triedTimes:triedTimes+1  isDNSTried:NO requestSign:requestSign success:success failure:failure];
            });
        } else {
            //失败回调
            if (failure) failure(error);
        }
    }];
}

/**
 *  AFN3.0 下载
 */
- (void)downloadTaskWithRequest:(NSURLRequest *)request
                       progress:(void (^)(NSProgress *downloadProgress))downloadProgressBlock
                    destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
              completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler;
{
    [self.sessionManager downloadTaskWithRequest:request progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
}

/// 获取网络信息
- (void)getNetworkInfo:(void (^)(NSString *))callback
{
    AFRVSDKNetworkReachabilityManager *manager = [AFRVSDKNetworkReachabilityManager sharedManager];
    
    [manager setReachabilityStatusChangeBlock:^(AFRVSDKNetworkReachabilityStatus status) {
        switch (status) {
                
            case AFRVSDKNetworkReachabilityStatusUnknown:
            {
               callback(@"");
               break;
            }
            case AFRVSDKNetworkReachabilityStatusNotReachable:
            {
                callback(@"0");
                break;
            }
            case AFRVSDKNetworkReachabilityStatusReachableViaWWAN:
            {
                callback(@"mobile");
                break;
            }
            case AFRVSDKNetworkReachabilityStatusReachableViaWiFi:
            {
                 callback(@"wifi");
                break;
            }
            default:
                break;
        }
        
//        NSLogInfo(@"network status=%@",nettype);
    }];
    [manager startMonitoring];
}

/// 返回6位大小写字母和数字
+ (NSString *)generate6RandomLetterAndNumber {
    //定义一个包含数字，大小写字母的字符串
    static const NSString *strAll = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    //定义一个结果
    NSString *result = [[NSMutableString alloc] initWithCapacity:6];
    for (int i = 0; i < 6; i++) {
        //获取随机数
        NSInteger index = arc4random() % (strAll.length-1);
        char tempStr = [strAll characterAtIndex:index];
        result = (NSMutableString *)[result stringByAppendingString:[NSString stringWithFormat:@"%c",tempStr]];
    }
    return result;
}

@end
