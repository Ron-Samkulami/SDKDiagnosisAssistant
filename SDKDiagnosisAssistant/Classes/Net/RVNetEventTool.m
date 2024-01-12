//
//  RVNetEventTool.m
//  RVSDK
//
//  Created by 石学谦 on 2021/3/16.
//  Copyright © 2021 SDK. All rights reserved.
//

#import "RVNetEventTool.h"
#import "RVOnlyLog.h"
#import "NSStringUtils.h"


/**
 逻辑处理如下：
 1.kSDKRequestTaskDidFinishCollectingMetrics这个网络耗时通知是在网络有结果之后返回的。 (我们往AF库设置了监听block，然后在block里面发送了通知)，通知会在我们收到AF网络成功或者失败结果之前触发
 2.我们收到耗时通知之后，会将metrics存到metricsDic里面，key为taskIdentifier。  (根据苹果的文档，同一个session的taskIdentifier是不同的，而我们用的是sessionManager单例，session会是同一个）
 3.kSDKRequestNetworkSuccessNotification 这个是收到网络成功时发送的通知
 4.kSDKRequestNetworkErrorNotification   这个是收到网络失败时发送的通知
 5.当收到成功或者失败通知的时候，会尝试通过taskIdentifier从metricsDic里面取出对应的metrics， 计算网络请求耗时。拿出来后会从数组中删除。
 6.不管是否能拿到metrics，都会上报网络耗时事件
 */

@interface RVNetEventTool ()

@property (nonatomic, strong) NSMutableDictionary *metricsDic;
/// URL耗时上报PATH白名单列表
@property (nonatomic, strong) NSArray *allowPathList;
/// URL耗时上报PATH黑名单列表
@property (nonatomic, strong) NSArray *blockPathList;

/// 网络请求metrics数据处理回调
@property (nonatomic, copy) requestTimeInfoHandler handler;
@end


@implementation RVNetEventTool

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (void)startWithHandler:(requestTimeInfoHandler)handler {
    if (!handler) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"RVNetEventTool must start with a handler!" userInfo:nil];
        return;
    }
    RVNetEventTool *instance = [RVNetEventTool sharedTool];
    instance.handler = handler;
}

+ (instancetype)sharedTool {
    static dispatch_once_t onceToken;
    static id  sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        
        _metricsDic = [NSMutableDictionary dictionary];
        
        // 设置URL耗时上报的黑白名单
        [self settingReportPathList];
        
        NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
        // 监听网络请求耗时通知(我们自定义的网络请求类发出来的通知)
        [defaultCenter addObserver:self
                          selector:@selector(rv_networkTaskDidFinishCollectingMetrics:)
                              name:@"kSDKRequestTaskDidFinishCollectingMetrics"
                            object:nil];
        
        // 监听网络失败通知(我们自定义的网络请求类发出来的通知)
        [defaultCenter addObserver:self
                          selector:@selector(rv_handleNetworkErrorNotification:)
                              name:@"kSDKRequestNetworkErrorNotification"
                            object:nil];
        // 监听网络成功通知(我们自定义的网络请求类发出来的通知)
        [defaultCenter addObserver:self
                          selector:@selector(rv_handleNetworkSuccessNotification:)
                              name:@"kSDKRequestNetworkSuccessNotification"
                            object:nil];
    }
    return self;
}

/// 设置URL耗时上报的黑白名单
- (void)settingReportPathList {
    
    // 默认的URL Path白名单
    NSString *allowPathStr = @"";
    //TODO: 自行设置URL path白名单读取
    //    NSString *allowPathStrFromYun = [RVYunPlistManager readValueFromYunForKey:INFO_URL_REPORT_ALLOW_LIST_KEY];
    //    if (!isStringEmpty(allowPathStrFromYun)) {
    //        allowPathStr = allowPathStrFromYun;
    //    }
    NSArray *tempAllowPathList = [allowPathStr componentsSeparatedByString:@","];
    NSMutableArray *mutableAllowPathList = [NSMutableArray array];
    for (int i=0; i<tempAllowPathList.count; i++) {
        NSString *path = [tempAllowPathList[i] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (!isStringEmpty(path)) {
            [mutableAllowPathList addObject:path];
        }
    }
    _allowPathList = mutableAllowPathList.copy;
    NSLogRVSDK(@"_allowPathList=%@",_allowPathList);
    
    
    // 默认的URL Path黑名单
    NSString *blockPathStr = @"/user_em,/appstore/notifyUserEvents";
    //TODO: 自行设置 URL path黑名单读取
    //    NSString *blockPathStrFromYun = [RVYunPlistManager readValueFromYunForKey:INFO_URL_REPORT_BLOCK_LIST_KEY];
    //    if (!isStringEmpty(blockPathStrFromYun)) {
    //        blockPathStr = blockPathStrFromYun;
    //    }
    NSArray *tempBlockPathList = [blockPathStr componentsSeparatedByString:@","];
    NSMutableArray *mutableBlockPathList = [NSMutableArray array];
    for (int i=0; i<tempBlockPathList.count; i++) {
        NSString *path = [tempBlockPathList[i] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (!isStringEmpty(path)) {
            [mutableBlockPathList addObject:path];
        }
    }
    _blockPathList = mutableBlockPathList.copy;
    NSLogRVSDK(@"_blockPathList=%@",_blockPathList);
}


#pragma mark - 网络耗时通知

/// 网络耗时上报处理
- (void)rv_networkTaskDidFinishCollectingMetrics:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _rv_networkTaskDidFinishCollectingMetrics:notification];
    });
}

- (void)_rv_networkTaskDidFinishCollectingMetrics:(NSNotification *)notification {
    
    if (!notification) {
        return;
    }
    
    if (@available(iOS 10.0, *)) {
        
        NSURLSessionTask *task = notification.userInfo[@"task"];
        if (!task) {
            NSLogRVSDK(@"CollectingMetrics task不存在");
            return;
        }
        if ([task isKindOfClass:[NSNull class]]) {
            NSLogRVSDK(@"CollectingMetrics task 为 null");
            return;
        }
        NSUInteger taskIdentifier = task.taskIdentifier;
        NSString *taskId = [NSString stringWithFormat:@"%zd",taskIdentifier];
        NSURLSessionTaskMetrics *metrics = notification.userInfo[@"metrics"];
        if (!metrics) {
            NSLogRVSDK(@"CollectingMetrics metrics不存在");
            return;
        }
        if ([metrics isKindOfClass:[NSNull class]]) {
            NSLogRVSDK(@"CollectingMetrics metrics为null");
            return;
        }
        [_metricsDic setObject:metrics forKey:taskId];
    }
    
}

#pragma mark - 网络成功通知

/// 网络成功上报
- (void)rv_handleNetworkSuccessNotification:(NSNotification *)noti {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _rv_handleNetworkSuccessNotification:noti];
    });
}
- (void)_rv_handleNetworkSuccessNotification:(NSNotification *)noti {
    NSDictionary *userInfo = noti.userInfo;
    //上报网络请求结果事件
    [self handleNetworkInfoWithUserInfo:userInfo errorValues:nil];
}

#pragma mark - 网络失败通知

/// 网络失败上报
- (void)rv_handleNetworkErrorNotification:(NSNotification *)noti {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _rv_handleNetworkErrorNotification:noti];
    });
}
- (void)_rv_handleNetworkErrorNotification:(NSNotification *)noti {
    
    NSDictionary *userInfo = noti.userInfo;
    NSError *error = userInfo[@"error"];
    if (![error isKindOfClass:[NSError class]]) {
        NSLogError(@"handleNetworkError:error nil!");
        //上报网络请求结果事件
        [self handleNetworkInfoWithUserInfo:userInfo errorValues:@{@"msg":@"error为nil"}];
        return;
    }
    
    NSString *errorCode = [NSString stringWithFormat:@"%zd",error.code];
    NSString *localizedDescription = error.localizedDescription;
    NSDictionary *eventValues = @{
        @"code":errorCode?:@"",
        @"msg":localizedDescription?:@"",
    };
    // 上报网络请求结果事件
    [self handleNetworkInfoWithUserInfo:userInfo errorValues:eventValues];
}


#pragma mark - 内部方法

/// 上报网络请求结果事件
- (void)handleNetworkInfoWithUserInfo:(NSDictionary *)userInfo errorValues:(NSDictionary *)errorValues {
    
    NSString *urlString = userInfo[@"urlString"];
    if (![urlString isKindOfClass:[NSString class]]) {
        NSLogInfo(@"handleNetworkError:urlString empty!");
        return;
    }
    NSURL *URL = [NSURL URLWithString:urlString];
    if (!URL) {
        NSLogInfo(@"handleNetworkError:URL nil!");
        return;
    }
    
    //拼接URL，不需要query参数
    urlString = [NSString stringWithFormat:@"%@://%@%@",URL.scheme,URL.host,URL.path];
    
    //判断是否需要上报URL耗时(根据白名单设置过滤，减少事件上报的数量)
    BOOL canReport = [self isAllowReport:URL];
    if (canReport == NO) {
        NSLogRVSDK(@"未通过验证，不上报URL耗时 urlString=%@",urlString);
        // 不上报的话从字典删除Metricks，避免内存一直增长
        [self removeMetricksWithTaskIdentifier:userInfo];
        return;
    }
    NSLogRVSDK(@"已通过验证，将上报URL耗时 urlString=%@",urlString);
    
    //有errorValues代表是失败了
    BOOL isFailed = (errorValues != nil);
    
    //网络结果公共信息
    NSMutableDictionary *eventValues = @{
        NetTaskInfo_url : urlString?:@"",
        NetTaskInfo_isCallFailed : isFailed?@"1":@"0",
        NetTaskInfo_triedTimes : userInfo[@"triedTimes"]?:@"0",  //重试次数
        @"isDNSTried" : userInfo[@"isDNSTried"]?:@"",   //是否DNS重试，是为1，否为0
        NetTaskInfo_requestSign : userInfo[@"requestSign"]?:@"", //一次请求的MD5sign，重试的请求跟初始请求相同
    }.mutableCopy;
    //添加网络失败信息
    if ([errorValues isKindOfClass:[NSDictionary class]]) {
        [eventValues addEntriesFromDictionary:errorValues];
    }
    
    //添加网络请求各阶段的耗时数据
    NSURLSessionDataTask *task = userInfo[@"task"];
    if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
        NSDictionary *networkTimeDic = nil;
        networkTimeDic = [self getNetworkTimeDicWithTaskIdentifier:task.taskIdentifier];
        if (networkTimeDic) {
            [eventValues addEntriesFromDictionary:networkTimeDic];
        }
    }
    
    //TODO: 这里也可以做数据上报
    //    [RVInSDKEventTools addSDKStatisticsEvent:@"network" eventValues:eventValues];
    
    NSLogDebug(@"网络耗时数据：%@",eventValues);
    if (self.handler) {
        self.handler(eventValues);
    }
}

/**
 判断是否需要上报URL耗时(减少事件上报的数量)
 
 子域白名单(默认) + URLpath白名单 - URLpath黑名单
 */
- (BOOL)isAllowReport:(NSURL *)URL {
    
    // TODO: 这里现将过滤规则关闭了，可自行设置
    return YES;
    
    //在这里设置默认允许的子域白名单
    NSArray *allowSubDomain = @[
        @"SubDomain01",
        @"SubDomain02",
    ];
    BOOL canReport = NO;
    // 子域白名单验证
    for (int i=0; i<allowSubDomain.count; i++) {
        if ([URL.host hasPrefix:allowSubDomain[i]]) {
            canReport = YES;
            break;
        }
    }
    // path白名单验证
    if (canReport == NO) {
        NSArray *allowList = _allowPathList;
        if ([allowList isKindOfClass:[NSArray class]]) {
            for (int i=0; i<allowList.count; i++) {
                if ([URL.path hasSuffix:allowList[i]]) {
                    canReport = YES;
                    break;
                }
            }
        }
    }
    if (canReport == NO) {
        return canReport;
    }
    
    // path黑名单验证
    NSArray *blockPathList = _blockPathList;
    if ([blockPathList isKindOfClass:[NSArray class]]) {
        for (int i=0; i<blockPathList.count; i++) {
            if ([URL.path hasSuffix:blockPathList[i]]) {
                canReport = NO;
                break;
            }
        }
    }
    return canReport;
}

/// 根据taskIdentifier删除metrics信息，避免内存一直增长
- (void)removeMetricksWithTaskIdentifier:(NSDictionary *)userInfo  {
    
    NSURLSessionDataTask *task = userInfo[@"task"];
    if (![task isKindOfClass:[NSURLSessionDataTask class]]) {
        return;
    }
    NSUInteger taskIdentifier = task.taskIdentifier;
    
    NSString *taskId = [NSString stringWithFormat:@"%zd",taskIdentifier];
    //从字典里面删除
    [_metricsDic removeObjectForKey:taskId];
}

/// 根据taskIdentifier获取网络耗时上报数据
- (nullable NSDictionary *)getNetworkTimeDicWithTaskIdentifier:(NSUInteger)taskIdentifier {
    
    NSDictionary *networkTimeDic = nil;
    
    NSString *taskId = [NSString stringWithFormat:@"%zd",taskIdentifier];
    //从字典里获取
    NSURLSessionTaskMetrics *metrics = [_metricsDic objectForKey:taskId];
    
    if (!metrics) {
        NSLogRVSDK(@"!!!!没找到NSURLSessionTaskMetrics taskId=%@",taskId);
        return networkTimeDic;
    }
    if (![metrics isKindOfClass:[NSURLSessionTaskMetrics class]]) {
        NSLogRVSDK(@"!!!!NSURLSessionTaskMetrics类型不符合 cls=%@", NSStringFromClass([metrics class]));
        // 从字典里面删除
        [_metricsDic removeObjectForKey:taskId];
        return networkTimeDic;
    }
    
    for (NSURLSessionTaskTransactionMetrics *tr in metrics.transactionMetrics) {
        
        if (![tr isKindOfClass:[NSURLSessionTaskTransactionMetrics class]]) {
            continue;
        }
        
        //跳过非网络加载，主要为了排除NSURLSessionTaskMetricsResourceFetchTypeLocalCache的情况
        if (tr.resourceFetchType != NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad) {
            NSLogRVSDK(@"tr.resourceFetchType = %zd",tr.resourceFetchType);
            continue;
        }
        
        NSTimeInterval request = 0;//请求耗时
        if (tr.requestEndDate && tr.requestStartDate) {
            request = [tr.requestEndDate timeIntervalSinceDate:tr.requestStartDate];
        }
        NSTimeInterval response = 0;//响应耗时
        if (tr.responseEndDate && tr.responseStartDate) {
            response = [tr.responseEndDate timeIntervalSinceDate:tr.responseStartDate];
        }
        NSTimeInterval DNSLookup = 0;//DNS耗时
        if (tr.domainLookupEndDate && tr.domainLookupStartDate) {
            DNSLookup = [tr.domainLookupEndDate timeIntervalSinceDate:tr.domainLookupStartDate];
        }
        NSTimeInterval TCPConnect = 0;//TCPConnect耗时
        if (tr.connectEndDate && tr.connectStartDate) {
            TCPConnect = [tr.secureConnectionStartDate timeIntervalSinceDate:tr.connectStartDate];
        }
        NSTimeInterval TLSHandshake = 0;//TLS耗时
        if (tr.secureConnectionEndDate && tr.secureConnectionStartDate) {
            TLSHandshake = [tr.secureConnectionEndDate timeIntervalSinceDate:tr.secureConnectionStartDate];
        }
        NSTimeInterval total = 0;//总耗时
        if (tr.responseEndDate && tr.fetchStartDate) {
            total = [tr.responseEndDate timeIntervalSinceDate:tr.fetchStartDate];
        }
        
        //注意:
        //reusedConnection为1时代表是连接复用，此时DNSLookup，TCPConnect，TLSHandshake都为0
        //响应超时的时候，response和total都为0
        networkTimeDic = @{
            NetEventTime_DNSLoopup:[self milisecondNumberWithTimeInterval:DNSLookup],
            NetEventTime_TCPConnect:[self milisecondNumberWithTimeInterval:TCPConnect],
            NetEventTime_TLSHandshake:[self milisecondNumberWithTimeInterval:TLSHandshake],
            NetEventTime_Request:[self milisecondNumberWithTimeInterval:request],
            NetEventTime_Response:[self milisecondNumberWithTimeInterval:response],
            NetEventTime_FetchTotal:[self milisecondNumberWithTimeInterval:total],
            NetEventTime_TaskTotal:[self milisecondNumberWithTimeInterval:metrics.taskInterval.duration],
            NetTaskInfo_isReusedConnection:tr.isReusedConnection?@"1":@"0",
            
        };
        
        // 找到有效记录即退出
        break;
    }
    
    //从字典里面删除
    [_metricsDic removeObjectForKey:taskId];
    
    return networkTimeDic;
    
    /*
     https://www.jianshu.com/p/c56f063397c1
     fetchStartDate:客户端开始请求的时间，无论资源是从服务器还是本地缓存中获取
     domainLookupStartDate:DNS 解析开始时间，Domain -> IP 地址
     domainLookupEndDate:DNS 解析完成时间，客户端已经获取到域名对应的 IP 地址
     connectStartDate:客户端与服务器开始建立 TCP 连接的时间
     secureConnectionStartDate:HTTPS 的 TLS 握手开始时间
     secureConnectionEndDate:HTTPS 的 TLS 握手结束时间
     connectEndDate:客户端与服务器建立 TCP 连接完成时间，包括 TLS 握手时间
     requestStartDate:开始传输 HTTP 请求的 header 第一个字节的时间
     requestEndDate:HTTP 请求最后一个字节传输完成的时间
     responseStartDate:客户端从服务器接收到响应的第一个字节的时间
     responseEndDate:客户端从服务器接收到最后一个字节的时间
     */
}

/// 获取毫秒值
- (NSNumber *)milisecondNumberWithTimeInterval:(NSTimeInterval)timeInterval {
    // 先*1000变成毫秒，然后去除小数点，最后转成Number
    NSNumber *number = [NSNumber numberWithLong:(long)(timeInterval*1000)];
    return number?:@(0);
}

@end
