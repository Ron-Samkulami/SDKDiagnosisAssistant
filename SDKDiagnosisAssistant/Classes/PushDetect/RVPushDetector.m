//
//  RVPushDetector.m
//  RVSDK
//
//  Created by 黄雄荣 on 2023/7/11.
//  Copyright © 2023 黄雄荣. All rights reserved.
//

#import "RVPushDetector.h"
#import "RSAsyncTaskQueue.h"
#import <UserNotifications/UserNotifications.h>
#import "AFRVSDKNetworkReachabilityManager.h"

#define SDK_STATECODE_SUCCESS     1             /* 成功 */
#define SDK_STATECODE_FAILURE     0             /* 失败 */
#define SDK_STATECODE_CANCEL     -1             /* 取消 */
#define isValidString(obj)  ([(obj) isKindOfClass:[NSString class]] && ![(obj) isEqualToString:@""])


@implementation RVPushDetector

#pragma mark - Public

+ (void)startDetectWithCompletionHandler:(void (^)(NSArray<NSDictionary *> *))handler {
    
    NSMutableArray *dectectResult = [[NSMutableArray alloc] initWithCapacity:3];
    RSAsyncTaskQueue *queue = [[RSAsyncTaskQueue alloc] initWithIdentifier:"com.RVSDK.PushChecker"];
    
    // 1、检查网络情况
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        BOOL isNetWorkAvaliable = NO;
        AFRVSDKNetworkReachabilityStatus status = [AFRVSDKNetworkReachabilityManager sharedManager].networkReachabilityStatus;
        if (status == AFRVSDKNetworkReachabilityStatusReachableViaWWAN || status == AFRVSDKNetworkReachabilityStatusReachableViaWiFi) {
            isNetWorkAvaliable = YES;
        }
        // 记录结果
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setValue:PushDetectType_Network_Env forKey:Type_Key];
        [dict setValue:@"网络环境检测" forKey:Name_Key];
        [dict setValue:isNetWorkAvaliable?@"1":@"0" forKey:Result_Key];
        [dict setValue:isNetWorkAvaliable?@"网络正常":@"当前网络环境异常，请连接稳定的网络后再重试" forKey:Content_Key];
        [dict setValue:@"0" forKey:Has_Native_Guide_Key];
        
        [dectectResult addObject:dict];
        taskFinished();
    }];
    
    // 2、检查通知权限开关设置
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        [self checkNotificationSettingWithHandler:^(BOOL isAllowNotify) {
            // 记录结果
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setValue:PushDetectType_Notice_Perm forKey:Type_Key];
            [dict setValue:@"通知权限检测" forKey:Name_Key];
            [dict setValue:isAllowNotify?@"1":@"0" forKey:Result_Key];
            [dict setValue:isAllowNotify?@"通知权限正常":@"设备未授予游戏通知权限，请前往系统设置-通知，选择游戏并打开通知权限" forKey:Content_Key];
            [dict setValue:@"1" forKey:Has_Native_Guide_Key];

            [dectectResult addObject:dict];
            taskFinished();
        }];
    }];
    
    // 3、检查能否正常获取Firebase推送token
    [queue addTask:^(TaskFinished  _Nonnull taskFinished) {
        [self sdkGetFirebaseToken:^(int statusCode, NSDictionary * _Nullable params) {
            BOOL isFCMAvaliable = NO;
            if (statusCode == SDK_STATECODE_SUCCESS && isValidString(params[@"fcmToken"])) {
                isFCMAvaliable = YES;
            }
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setValue:PushDetectType_Push_Service forKey:Type_Key];
            [dict setValue:@"推送服务检测" forKey:Name_Key];
            [dict setValue:isFCMAvaliable?@"1":@"0" forKey:Result_Key];
            [dict setValue:isFCMAvaliable?@"推送服务连接正常":@"推送服务连接失败，请点击【连接】按钮进行服务器连接" forKey:Content_Key];
            [dict setValue:@"1" forKey:Has_Native_Guide_Key];
            
            [dectectResult addObject:dict];
            taskFinished();
        }];
    }];
    
    queue.completeHandler = ^{
        if (handler) {
            handler(dectectResult);
        }
    };
    
    [queue engage];
    
}

/// 处理指引操作
+ (void)handlePushGuideOperateType:(PushDetectType)type 
                           handler:(void (^)(BOOL, NSString *))handler 
{
    if ([type isEqualToString:PushDetectType_Notice_Perm]) {
        // 通知权限
        [self goToAppSystemSetting];
        if (handler) {
            handler(NO,nil);
        }
    } else if ([type isEqualToString:PushDetectType_Push_Service]) {
        // 获取Firebase推送token
        [self sdkGetFirebaseToken:^(int statusCode, NSDictionary * _Nullable params) {
            BOOL isFCMAvaliable = NO;
            if (statusCode == SDK_STATECODE_SUCCESS && isValidString(params[@"fcmToken"])) {
                isFCMAvaliable = YES;
            }
            if (handler) {
                handler(YES, isFCMAvaliable?@"1":@"0");
            }
        }];
        
    }
}

#pragma mark - Internal

/// 打开当前APP的系统通知设置界面
+ (void)goToAppSystemSetting {
    UIApplication *application = [UIApplication sharedApplication];
    NSURL *url = nil;
    if (@available(iOS 15.4, *)) {
        url = [NSURL URLWithString:UIApplicationOpenNotificationSettingsURLString];
    } else {
        url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    }
    if ([application canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

/// 检查系统通知权限设置
+ (void)checkNotificationSettingWithHandler:(void (^)(BOOL isAllowNotify))handler
{
    __block BOOL isAllowNotify = NO;
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            isAllowNotify = YES;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) handler(isAllowNotify);
        });
    }];
}


#pragma mark - To Be Implemented
/**
 请自行实现获取FCM Token的逻辑
 */
+ (void)sdkGetFirebaseToken:(void(^)(int statusCode, NSDictionary * params))callback {
    //TODO: 获取Firebase 推送 token，并通过callback回调
//    NSString *token = <Do Something To Get FCM Token>
    callback(1, @{@"fcmToken":@"YOUR_APPS_FCM_TOKEN" });
}
@end
