//
//  RSViewController.m
//  SDKDiagnosisAssistant
//
//  Created by Ron-Samkulami on 01/02/2024.
//  Copyright (c) 2024 Ron-Samkulami. All rights reserved.
//

#import "RSViewController.h"
#import "RSNetDiagnosisViewController.h"
#import <SDKDiagnosisAssistant/RVPushDetector.h>
#import "RSJsonUtils.h"
#import <SDKDiagnosisAssistant/RVLogService.h>

#import <SDKDiagnosisAssistant/RVNetEventTool.h>
#import <SDKDiagnosisAssistant/RVRequestManager.h>

@interface RSViewController ()

@end

@implementation RSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *button1 = [[UIButton alloc] initWithFrame:CGRectMake(30, 100, 150, 30)];
    [button1 setTitle:@"网络检测" forState:UIControlStateNormal];
    [button1 setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    button1.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [button1 addTarget:self action:@selector(showNetDiagnosisVC) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];
    
    UIButton *button2 = [[UIButton alloc] initWithFrame:CGRectMake(30, 150, 150, 30)];
    [button2 setTitle:@"推送问题检测" forState:UIControlStateNormal];
    [button2 setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    button2.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [button2 addTarget:self action:@selector(doPushDetect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    UIButton *button3 = [[UIButton alloc] initWithFrame:CGRectMake(30, 200, 150, 30)];
    [button3 setTitle:@"显示日志浮窗" forState:UIControlStateNormal];
    [button3 setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    button3.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [button3 addTarget:self action:@selector(showLogDebugWindow) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button3];
    
    UIButton *button4 = [[UIButton alloc] initWithFrame:CGRectMake(30, 250, 150, 30)];
    [button4 setTitle:@"网络耗时检测" forState:UIControlStateNormal];
    [button4 setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    button4.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [button4 addTarget:self action:@selector(netRequestTimeConsumingMonitor) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button4];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/// 网络检测界面
- (void)showNetDiagnosisVC
{
    RSNetDiagnosisViewController *vc = [[RSNetDiagnosisViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

/// 推送检测
- (void)doPushDetect
{
    [RVPushDetector startDetectWithCompletionHandler:^(NSArray<NSDictionary *> *checkResult) {
        /**
         [
           {
             "result" : @"1",                                 // 检测项结果，1通过，0不通过
             "has_native_guide" : @"0",             //  检测项对应问题能否通过指引用户操作自行解决
             "content" : @"当前网络环境正常",    // 检测结果相关说明
             "type" : @"network_env",                 //  检测项类型
             "name" : @"网络环境检测"               //  检测项名称(多语言文本)
           },
           {
             "result" : @"0",
             "has_native_guide" : @"1",
             "content" : @"设备未授予游戏通知权限，请前往系统设置-通知，选择游戏并打开通知权限",
             "type" : @"notice_perm",
             "name" : @"通知权限检测"
           },
           {
             "result" : @"1",
             "has_native_guide" : @"1",
             "content" : @"获取推送token正常",
             "type" : @"push_service",
             "name" : @"推送服务检测"
           }
         ]
         */
        NSDictionary *result = @{
            @"detect_result" : checkResult
        };
        NSString *resultJsonString = [RSJsonUtils jsonStringFromDictionary:result];
        NSLog(@"%@", resultJsonString);
        [self simpleAlertWithTitle:@"推送检测结果" Message:resultJsonString];
    }];
}

/// 显示日志调试浮窗
- (void)showLogDebugWindow
{
    [[RVLogService sharedInstance] openLogDebugWindow];
}

/// 监听网络耗时
- (void)netRequestTimeConsumingMonitor
{
    // 先设置好网络耗时监听器
    [RVNetEventTool startWithHandler:^(NSDictionary * _Nonnull timeConsumingInfo) {
        NSString *resultString = [NSString stringWithFormat:@"%@\n\n\
* DNSLoopup耗时 : %@ms\n\
* TCPConnect耗时 : %@ms\n\
* TLSHandShake耗时 : %@ms\n\
* request耗时 : %@ms\n\
* response耗时 : %@ms\n\
* 总耗时 : %@ms",
                                      timeConsumingInfo[NetTaskInfo_url],
                                      timeConsumingInfo[NetEventTime_DNSLoopup],
                                      timeConsumingInfo[NetEventTime_TCPConnect],
                                      timeConsumingInfo[NetEventTime_TLSHandshake],
                                      timeConsumingInfo[NetEventTime_Request],
                                      timeConsumingInfo[NetEventTime_Response],
                                      timeConsumingInfo[NetEventTime_TaskTotal]
        ];
      
        NSLog(@"%@", resultString);
        [self simpleAlertWithTitle:@"网络请求耗时" Message:resultString];
    }];
    
    // 再调用网络请求
    NSString *urlString = @"https://www.wanandroid.com/friend/json";
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{
       }];
    [[RVRequestManager sharedManager] POST:urlString parameters:params success:^(id successResponse) {
        NSLog(@"%@", successResponse);
    } failure:^(NSError *error) {
        NSLog(@"%@", error);
    }];
}

#pragma mark - Utils

- (void)simpleAlertWithTitle:(NSString *)title Message:(NSString *)message
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    // 文本左对齐
    NSMutableAttributedString *messageText = [[NSMutableAttributedString alloc] initWithString:alertController.message];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    [messageText addAttributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:13],
        NSParagraphStyleAttributeName : paragraphStyle
    }
                         range:NSMakeRange(0, messageText.length)];
    
    [alertController setValue:messageText forKey:@"attributedMessage"];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:defaultAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
