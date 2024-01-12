//
//  RVPushDetector.h
//  RVSDK
//
//  Created by 黄雄荣 on 2023/7/11.
//  Copyright © 2023 黄雄荣. All rights reserved.
//

/**
 推送检测
 */
#import <Foundation/Foundation.h>

// 推送检测项目类型，和前端约定好的字段，不可修改
#define PushDetectType NSString *
static PushDetectType const PushDetectType_Network_Env = @"network_env";      // 网络状态
static PushDetectType const PushDetectType_Notice_Perm = @"notice_perm";     // 通知权限开关
static PushDetectType const PushDetectType_Push_Service = @"push_service";   // 推送服务

// 回调给前端的数据字段
#define Type_Key @"type"        // 检测项类型
#define Name_Key @"name"        // 检测项名称
#define Result_Key @"result"    // 检测项结果，"1"为成功，"0"为失败
#define Content_Key @"content"  // 弹窗提醒内容
#define Has_Native_Guide_Key @"has_native_guide" // "1"需要原生引导操作,"0"不需要原生引导操作

@interface RVPushDetector : NSObject

/// 检测推送相关功能
/// - Parameter handler: 完成回调
+ (void)startDetectWithCompletionHandler:(void (^)(NSArray <NSDictionary *> * checkResult))handler;

/// 根据类型处理不同的指引操作
/// - Parameters:
///   - type: 检测项类型
///   - handler: 操作完成回调
+ (void)handlePushGuideOperateType:(PushDetectType)type 
                           handler:(void (^)(BOOL needFeedBack, NSString *result))handler;

@end

