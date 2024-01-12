//
//  RVRootViewTool.m
//  RVSDK
//
//  Created by 石学谦 on 2018/11/27.
//  Copyright © 2018 SDK. All rights reserved.
//

#import "RVRootViewTool.h"
#import "RVOnlyLog.h"
@implementation RVRootViewTool

/// 获取当前屏幕显示的viewcontroller
+ (UIViewController *)getTopViewController
{
    UIWindow *rootWindow =  [self getCurrentRootWindow];
    UIViewController *rootViewController = rootWindow.rootViewController;
    if (!rootViewController) {
        // 这里以后再来处理
        NSLogWarn(@"rootViewController为nil");
        return nil;
    }
    UIViewController *topViewController = rootViewController;
    // 视图是被presented出来的
    while (topViewController.presentedViewController) {
        
        UIViewController *tempTopController = topViewController.presentedViewController;
        if ([tempTopController isKindOfClass:[UIAlertController class]]) {
            // 如果是UIAlertController，不再继续
            break;
        } else {
            topViewController = tempTopController;
        }
        
    }
    
    NSLogVerbose(@"getTopViewController topViewController=%@",topViewController);
    NSLogVerbose(@"getTopViewController mainScreen.bounds=%@",NSStringFromCGRect([UIScreen mainScreen].bounds));
    NSLogVerbose(@"getTopViewController rootWindow=%@",rootWindow);
    NSLogVerbose(@"getTopViewController rootWindow.frame=%@",NSStringFromCGRect(rootWindow.frame));
    NSLogVerbose(@"getTopViewController rootWindow.bounds=%@",NSStringFromCGRect(rootWindow.bounds));
    NSLogVerbose(@"getTopViewController topView=%@",topViewController.view);
    NSLogVerbose(@"getTopViewController topView.frame=%@",NSStringFromCGRect(topViewController.view.frame));
    NSLogVerbose(@"getTopViewController topView.bounds=%@",NSStringFromCGRect(topViewController.view.bounds));
    return topViewController;
}


/// 获取rootViewController，不处理prsent的controller
+ (UIViewController *)getRootViewController
{
    UIWindow *rootWindow =  [self getCurrentRootWindow];
    UIViewController *rootViewController = rootWindow.rootViewController;
    if (!rootViewController) {
        // 这里以后再来处理
        NSLogWarn(@"rootViewController为nil");
        return nil;
    }
    UIViewController *topViewController = rootViewController;
    
    NSLogVerbose(@"getRootViewController topViewController=%@",topViewController);
    NSLogVerbose(@"getRootViewController mainScreen.bounds=%@",NSStringFromCGRect([UIScreen mainScreen].bounds));
    NSLogVerbose(@"getRootViewController rootWindow=%@",rootWindow);
    NSLogVerbose(@"getRootViewController rootWindow.frame=%@",NSStringFromCGRect(rootWindow.frame));
    NSLogVerbose(@"getRootViewController rootWindow.bounds=%@",NSStringFromCGRect(rootWindow.bounds));
    NSLogVerbose(@"getRootViewController topView=%@",topViewController.view);
    NSLogVerbose(@"getRootViewController topView.frame=%@",NSStringFromCGRect(topViewController.view.frame));
    NSLogVerbose(@"getRootViewController topView.bounds=%@",NSStringFromCGRect(topViewController.view.bounds));
    return topViewController;
}


/// 获取当前屏幕显示的viewcontroller
+ (UIWindow *)getCurrentRootWindow
{
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *rootWindow = nil;
    // 先获取delegate的window(越南三国群英传的delegate没有window属性)
    if ([application.delegate respondsToSelector:@selector(window)]) {
        
        rootWindow = application.delegate.window;
    } else {
        NSLogRVSDK(@"Application.delegate respondsToSelector:@selector(window)] 失败");
        // 获取keyWindow
        UIWindow *window = [application keyWindow];
        // keyWindow有时为空
        if (window && [NSStringFromClass([window class]) isEqualToString:@"UIWindow"] && window.windowLevel == UIWindowLevelNormal && window.rootViewController) {
            NSLogRVSDK(@"keyWindow 符合要求");
            rootWindow = window;
        } else {
            NSLog(@"Application.delegate respondsToSelector:@selector(window)] 失败");
        }
        
        // 判断delegate的window是否是keywindow
        if (rootWindow && [rootWindow isKeyWindow]) {
            
        } else {
            NSLogRVSDK(@"keyWindow不符合要求，从windows数组中找");
            // keyWindow不符合要求，从windows数组中找
            NSArray *windows = [application windows];
            for(UIWindow *tmpWin in windows)
            {
                if ([tmpWin isKindOfClass:[UIWindow class]] && tmpWin.windowLevel == UIWindowLevelNormal)
                {
                    NSLogRVSDK(@"循环windows找到了符合要求的window");
                    rootWindow = tmpWin;
                    break;
                }
            }
        }
    }
    
    if (rootWindow && rootWindow.rootViewController) {
        
    } else {
        NSLogInfo(@"都找不到合适的window，使用windows[0]");
        NSArray *windows = [application windows];
        if (windows.count>0) {
            rootWindow = windows[0];
        } else {
            NSLogWarn(@"windows为nil！！！");
        }
        
    }
    
    return rootWindow;
}

@end
