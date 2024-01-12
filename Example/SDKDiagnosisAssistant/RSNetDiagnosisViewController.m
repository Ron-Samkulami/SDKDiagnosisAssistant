//
//  RSNetDiagnosisViewController.m
//  SDKDiagnosisAssistant_Example
//
//  Created by 黄雄荣 on 2024/1/3.
//  Copyright © 2024 Ron-Samkulami. All rights reserved.
//

#import "RSNetDiagnosisViewController.h"
#import <SDKDiagnosisAssistant/RSNetDetector.h>

@interface RSNetDiagnosisViewController ()
/// loading
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
@end

@implementation RSNetDiagnosisViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"网络检测";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *button1 = [[UIButton alloc] initWithFrame:CGRectMake(30, 120, 150, 30)];
    [button1 setTitle:@"Detect Single Item" forState:UIControlStateNormal];
    [button1 setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [button1 addTarget:self action:@selector(testSingleItem) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];
    
    UIButton *button2 = [[UIButton alloc] initWithFrame:CGRectMake(30, 170, 150, 30)];
    [button2 setTitle:@"Detect Multi Items" forState:UIControlStateNormal];
    [button2 setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [button2 addTarget:self action:@selector(testMultiItems) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _loadingView.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/2);
    [self.view addSubview:_loadingView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)testSingleItem
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Detect Single Item" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Enter host name";
        textField.text = [NSString stringWithFormat:@"www.baidu.com"];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Domain Lookup" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *host = [[alert.textFields[0].text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        [self lookupHost:host];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"TCP Ping" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *host = [[alert.textFields[0].text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        [self tcpPingHost:host];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"ICMP Ping" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *host = [[alert.textFields[0].text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        [self icmpPingHost:host];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"ICMP Traceroute" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *host = [[alert.textFields[0].text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        [self icmpTracerouteHost:host];
    }]];
    
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)testMultiItems
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Detect Multi Items" message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Enter host name, separate by \",\"";
        textField.text = [NSString stringWithFormat:@"www.baidu.com, www.google.com"];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Start" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *host = [[alert.textFields[0].text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        if (host.length <= 0) {
            return;
        }
        NSArray *hostList = [host componentsSeparatedByString:@","];
        
        [self showLoading];
        
        [[RSNetDetector shared] detectHostList:hostList complete:^(NSString *detectLog) {
            NSLog(@"%@",detectLog);
            [self hideLoading];
            [self simpleAlertWithTitle:@"Result" Message:detectLog];
        }];
    }]];
    
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - 单项检测

- (void)lookupHost:(NSString *)host
{
    [self showLoading];
    
    [[RSNetDetector shared] dnsLookupWithHost:host complete:^(NSString * _Nonnull detectLog) {
        NSLog(@"%@",detectLog);
        [self hideLoading];
        [self simpleAlertWithTitle:@"DNS Lookup" Message:detectLog];
    }];
    
}


- (void)tcpPingHost:(NSString *)host
{
    [self showLoading];
    
    [[RSNetDetector shared] tcpPingWithHost:host complete:^(NSString * _Nonnull detectLog) {
        NSLog(@"%@",detectLog);
        [self hideLoading];
        [self simpleAlertWithTitle:@"TCP Ping" Message:detectLog];
    }];
}

- (void)icmpPingHost:(NSString *)host
{
    [self showLoading];
    
    [[RSNetDetector shared] icmpPingWithHost:host complete:^(NSString * _Nonnull detectLog) {
        NSLog(@"%@",detectLog);
        [self hideLoading];
        [self simpleAlertWithTitle:@"TCP Ping" Message:detectLog];
    }];
}


- (void)icmpTracerouteHost:(NSString *)host
{
    [self showLoading];
    
    [[RSNetDetector shared] icmpTracerouteWithHost:host complete:^(NSString * _Nonnull detectLog) {
        NSLog(@"%@",detectLog);
        [self hideLoading];
        [self simpleAlertWithTitle:@"ICMP Traceroute" Message:detectLog];
    }];
    
}


#pragma mark - UI

- (void)simpleAlertWithTitle:(NSString *)title Message:(NSString *)message
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    // 文本左对齐
    NSMutableAttributedString *messageText = [[NSMutableAttributedString alloc] initWithString:alertController.message];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    [messageText addAttributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:12],
        NSParagraphStyleAttributeName : paragraphStyle
    }
                         range:NSMakeRange(0, messageText.length)];
    
    [alertController setValue:messageText forKey:@"attributedMessage"];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:defaultAction];
    [self presentViewController:alertController animated:YES completion:nil];
}




- (void)showLoading {
    [_loadingView startAnimating];
    self.view.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    self.view.userInteractionEnabled = NO;
}

- (void)hideLoading {
    [_loadingView stopAnimating];
    self.view.backgroundColor = [UIColor whiteColor];
    self.view.userInteractionEnabled = YES;
}

@end
