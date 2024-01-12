//
//  RSXToolSet.h

//
//  Created by 朱 圣 on 8/16/13.
//  Copyright (c) 2013 37wan. All rights reserved.
//

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface RSXToolSet : NSObject

#pragma mark - Version


// 是否为测试包
+ (BOOL)isDebugPackage;

/**
 bundleId版本号比较
 >: 1;
 =: 0;
 <: -1;
 */
+ (int)versionCompareVer1:(NSString *)ver1 ver2:(NSString *)ver2;


#pragma mark - Hook
//方法交换
+ (void)swizzlingInClass:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector;
//方法交换
+ (void)swizzlingInOriginalClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector;
//hook instance对象所在类的originalSelector方法，如果方法不存在，将会先注入一个方法
+ (void)swizzlingDelegateMethodInOriginalClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector noopSelector:(SEL)noopSelector;

//方法交换
+ (void)swizzlingClassMehthodInOriginalClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector;



#pragma mark - Other
//用纯颜色生成image
+ (UIImage *)createImageWithColor:(UIColor *)color;

//openURL方法封装，兼容iOS10以下版本
+ (void)openURL:(NSURL*)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^ __nullable)(BOOL success))completion;


// 获取文件或者文件夹大小(单位：B)
+ (unsigned long long)sizeAtPath:(NSString *)path;

//可以避免给定的View中多个按钮同时点击
+ (void)setExclusiveTouchForButtons:(UIView *)view;



// 沙盒路径中 Library/Application Support/RVSDK 路径为SDK文件的主要存储路径
+ (NSString *)getSDKApplicationSupportPath;




+ (NSString *)URLEncodeString:(NSString *)str;



//从Token中获得值
+ (NSString *)saveToken:(NSString *)token;


//杀死程序（有动画效果）
+ (void)exitApplication;


NS_ASSUME_NONNULL_END

@end
