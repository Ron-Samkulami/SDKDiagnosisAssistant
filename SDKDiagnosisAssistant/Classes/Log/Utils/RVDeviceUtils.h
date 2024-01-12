//
//  RVDeviceUtils.h
//  RVSDK
//
//  Created by 黄雄荣 on 2022/8/19.
//  Copyright © 2022 SDK. All rights reserved.
//

/**
 设备信息相关工具类
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RVDeviceUtils : NSObject

/// 获取手机Mac地址(iOS7开始会固定返回020000000000)
+ (NSString *)macaddress;

/// 获取设备原始型号
+ (NSString *)getOriginalDeviceType;

/// 由设备原始型号获取手机型号
+ (NSString *)deviceType:(NSString *)originalDeviceType;

/// 判断设备是否越狱
+ (BOOL)isJailBroken;

/// 是否是模拟器
+ (BOOL)isSimulator;

/// 识别是否为VPN状态
+ (BOOL)isVPNOn;

@end

NS_ASSUME_NONNULL_END
