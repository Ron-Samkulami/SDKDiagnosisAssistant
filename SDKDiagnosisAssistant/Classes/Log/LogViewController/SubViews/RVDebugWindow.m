//
//  RVDebugWindow.m
//  RVSDK
//
//  Created by 石学谦 on 2019/7/31.
//  Copyright © 2019 SDK. All rights reserved.
//

#import "RVDebugWindow.h"
#import "RVRootViewTool.h"
#import "RVOnlyLog.h"
@interface RVRVDebugWindowRootController : UIViewController

@end

@implementation RVRVDebugWindowRootController

#pragma mark - 旋转问题

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
        
    //默认横屏
    UIInterfaceOrientationMask interfaceOrientation = UIInterfaceOrientationMaskLandscape;
    //使用APP的rootViewController的设置
    UIViewController *rootViewController = [RVRootViewTool getRootViewController];
    if (rootViewController) {
        interfaceOrientation = rootViewController.supportedInterfaceOrientations;
    }
    
    return interfaceOrientation;
}

//隐藏状态栏
- (BOOL)prefersStatusBarHidden {
    
    return YES;
}

@end

@implementation RVDebugWindow

- (instancetype)init{
    self = [super init];
    if (self) {
        
        self.backgroundColor = [UIColor clearColor];
        
        //这样浮窗就可以悬浮在最上面
        self.windowLevel = UIWindowLevelAlert + 1;
        //设置浮窗window的rootViewController
        self.rootViewController = [[RVRVDebugWindowRootController alloc] init];
        
        //关闭暗黑模式
        if (@available(iOS 13.0, *)) {
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
        }
        
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        
        [self makeKeyAndVisible];
        //还回keyWindow，这个window不需要作为keywindow
        if (keyWindow) {
            [keyWindow makeKeyWindow];
        }
        
    }
    return self;
}


//拦截响应链。触摸点在_floatView里面则响应，不在则由其他window处理
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    
    //将坐标转化成在_floatView上的坐标
    point = [self convertPoint:point toView:_floatView];
    
    //如果触摸的点在_floatView里面
    if ([_floatView pointInside:point withEvent:event]) {
        
        //让_floatView来响应这个事件
        return [_floatView hitTest:point withEvent:event];
    }
    else {
        //如果触摸的点不在_floatView里面，那么就让下一个控件来响应（下一个window的控件）
        return nil;
    }
}

- (void)dealloc {
    NSLogRVSDK(@"调用%s",__func__);
}

@end
