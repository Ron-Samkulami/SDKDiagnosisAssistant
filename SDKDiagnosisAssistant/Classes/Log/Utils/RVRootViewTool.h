//
//  RVRootViewTool.h
//  RVSDK
//
//  Created by 石学谦 on 2018/11/27.
//  Copyright © 2018 SDK. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RVRootViewTool : NSObject

/// 获取最上面的那个rootViewController，这里会处理present的controller
+ (UIViewController *)getTopViewController;

/// 获取当前的普通window
+ (UIWindow *)getCurrentRootWindow;

/// 获取rootViewController，不处理prsent的controller
+ (UIViewController *)getRootViewController;

@end

NS_ASSUME_NONNULL_END
