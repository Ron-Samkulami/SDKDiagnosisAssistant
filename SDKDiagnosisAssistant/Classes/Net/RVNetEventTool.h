//
//  RVNetEventTool.h
//  RVSDK
//
//  Created by 石学谦 on 2021/3/16.
//  Copyright © 2021 SDK. All rights reserved.
//

/**
 网络耗时监听工具
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define NetEventTime_DNSLoopup      @"DNSLookup"    // DNS查询耗时
#define NetEventTime_TCPConnect     @"TCPConnect"   // TCP连接耗时
#define NetEventTime_TLSHandshake   @"TLSHandshake" // 三次握手耗时
#define NetEventTime_Request        @"Request"      // 请求耗时
#define NetEventTime_Response       @"Response"     // 响应耗时
#define NetEventTime_FetchTotal     @"FetchTotal"   // 开始获取数据到响应的总耗时（不包含DNS解析及连接建立）
#define NetEventTime_TaskTotal      @"TaskTotal"    // 网络请求总耗时

#define NetTaskInfo_isCallFailed    @"isCallFailed" // 请求是否失败
#define NetTaskInfo_isReusedConnection @"isReusedConnection" // 是否是复用连接，1是/0否
#define NetTaskInfo_requestSign     @"requestSign"  // 请求的签名
#define NetTaskInfo_triedTimes      @"triedTimes"   // 请求的重试次数
#define NetTaskInfo_url             @"url"          // 请求的URL
//#define NetStatus_isDNSTried @"isDNSTried"

typedef void (^ requestTimeInfoHandler )(NSDictionary *timeConsumingInfo);

@interface RVNetEventTool : NSObject

+ (void)startWithHandler:(requestTimeInfoHandler)handler;

@end

NS_ASSUME_NONNULL_END
