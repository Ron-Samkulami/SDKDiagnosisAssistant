//
//  RVDebugViewController.m
//
//  Created by 石学谦 on 2020/4/13.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import "RVDebugViewController.h"
#import "RVLogService.h"
#import "RVOnlyLog.h"
#import "NSUserDefaults+SDKUserDefaults.h"

@interface RVDebugViewController ()

/// 显示所有日志文件
@property (nonatomic, strong) UIButton *displayAllLogFilesButton;
/// 清空当前日志文件内容
@property (nonatomic, strong) UIButton *clearCurrentLogButton;

/// 关闭界面
@property (nonatomic, strong) UIButton *closePageButton;

/// log写入到沙盒文件
@property (nonatomic, strong) UILabel *writeLogToFileLabel;
@property (nonatomic, strong) UISwitch *writeLogToFileSwitch;
/// 在控制台显示log
@property (nonatomic, strong) UILabel *showLogInConsoleLabel;
@property (nonatomic, strong) UISwitch *showLogInConsoleSwitch;
/// 每次启动生成新的log文件
@property (nonatomic, strong) UILabel *createNewLogEveryLaunchLabel;
@property (nonatomic, strong) UISwitch *createNewLogEveryLaunchSwitch;
/// 下次启动打开log浮窗
@property (nonatomic, strong) UILabel *showDebugWindowNextLaunchLabel;
@property (nonatomic, strong) UISwitch *showDebugWindowNextLaunchSwitch;

/// 切换日志控制类型，默认是控制Console输出的日志等级，可以切换成控制写入文件的日志等级
@property (nonatomic, strong) UISegmentedControl *logLevelControTypeSeg;
/// Warn日志等级
@property (nonatomic, strong) UIButton *logLevelWarnButton;
/// Info日志等级
@property (nonatomic, strong) UIButton *logLevelInfoButton;
/// Debug日志等级
@property (nonatomic, strong) UIButton *logLevelDebugButton;
/// Verbose日志等级
@property (nonatomic, strong) UIButton *logLevelVerboseButton;

@end

@implementation RVDebugViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self configUI];
}


- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationController.toolbarHidden = YES;
    [self.view addSubview:self.displayAllLogFilesButton];
    [self.view addSubview:self.clearCurrentLogButton];
    [self.view addSubview:self.closePageButton];
    
    [self.view addSubview:self.logLevelControTypeSeg];
    [self.view addSubview:self.logLevelWarnButton];
    [self.view addSubview:self.logLevelInfoButton];
    [self.view addSubview:self.logLevelDebugButton];
    [self.view addSubview:self.logLevelVerboseButton];
    
    [self.view addSubview:self.writeLogToFileLabel];
    [self.view addSubview:self.writeLogToFileSwitch];
    [self.view addSubview:self.showLogInConsoleLabel];
    [self.view addSubview:self.showLogInConsoleSwitch];
    [self.view addSubview:self.createNewLogEveryLaunchLabel];
    [self.view addSubview:self.createNewLogEveryLaunchSwitch];
    [self.view addSubview:self.showDebugWindowNextLaunchLabel];
    [self.view addSubview:self.showDebugWindowNextLaunchSwitch];
}


- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat leading = 20;
    CGFloat padding = 10;
    CGFloat buttonWidth = 240;
    CGFloat buttonHeight = 30;
    CGFloat switchWidth = 60;
    self.displayAllLogFilesButton.frame = CGRectMake(leading, 100, buttonWidth, buttonHeight);
    self.clearCurrentLogButton.frame = CGRectMake(leading, CGRectGetMaxY(self.displayAllLogFilesButton.frame) + padding, buttonWidth, buttonHeight);
    self.closePageButton.frame = CGRectMake(leading, CGRectGetMaxY(self.clearCurrentLogButton.frame) + padding, buttonWidth, buttonHeight);
    
    self.logLevelControTypeSeg.frame = CGRectMake(leading, CGRectGetMaxY(self.closePageButton.frame) + padding, 300, buttonHeight);
    self.logLevelWarnButton.frame = CGRectMake(leading, CGRectGetMaxY(self.logLevelControTypeSeg.frame) + padding, buttonWidth, buttonHeight);
    self.logLevelInfoButton.frame = CGRectMake(leading, CGRectGetMaxY(self.logLevelWarnButton.frame) + padding, buttonWidth, buttonHeight);
    self.logLevelDebugButton.frame = CGRectMake(leading, CGRectGetMaxY(self.logLevelInfoButton.frame) + padding, buttonWidth, buttonHeight);
    self.logLevelVerboseButton.frame = CGRectMake(leading, CGRectGetMaxY(self.logLevelDebugButton.frame) + padding, buttonWidth, buttonHeight);
    
    self.writeLogToFileLabel.frame = CGRectMake(leading, CGRectGetMaxY(self.logLevelVerboseButton.frame) + padding, buttonWidth, buttonHeight);
    self.writeLogToFileSwitch.frame = CGRectMake(CGRectGetMaxX(self.writeLogToFileLabel.frame) + leading, CGRectGetMaxY(self.logLevelVerboseButton.frame) + padding, switchWidth, buttonHeight);
    
    self.showLogInConsoleLabel.frame = CGRectMake(leading, CGRectGetMaxY(self.writeLogToFileLabel.frame) + padding, buttonWidth, buttonHeight);
    self.showLogInConsoleSwitch.frame = CGRectMake(CGRectGetMaxX(self.showLogInConsoleLabel.frame) + leading, CGRectGetMaxY(self.writeLogToFileLabel.frame) + padding, switchWidth, buttonHeight);
    
    self.createNewLogEveryLaunchLabel.frame = CGRectMake(leading, CGRectGetMaxY(self.showLogInConsoleLabel.frame) + padding, buttonWidth, buttonHeight);
    self.createNewLogEveryLaunchSwitch.frame = CGRectMake(CGRectGetMaxX(self.createNewLogEveryLaunchLabel.frame) + leading, CGRectGetMaxY(self.showLogInConsoleLabel.frame) + padding, switchWidth, buttonHeight);
    
    self.showDebugWindowNextLaunchLabel.frame = CGRectMake(leading, CGRectGetMaxY(self.createNewLogEveryLaunchLabel.frame) + padding, buttonWidth, buttonHeight);
    self.showDebugWindowNextLaunchSwitch.frame = CGRectMake(CGRectGetMaxX(self.showDebugWindowNextLaunchLabel.frame) + leading, CGRectGetMaxY(self.createNewLogEveryLaunchLabel.frame) + padding, switchWidth, buttonHeight);
}

- (void)configUI {
    // 读取本地保存的开关值
    self.writeLogToFileSwitch.on = [RVLogService sharedInstance].writeLogToFile;
    self.showLogInConsoleSwitch.on = [RVLogService sharedInstance].showlogInConsole;
    self.createNewLogEveryLaunchSwitch.on = [RVLogService sharedInstance].createNewLogEveryLaunching;
    self.showDebugWindowNextLaunchSwitch.on = [RVLogService sharedInstance].showDebugWindowConfig;
    
    //根据当前logLevel设置btn状态是否可点击
    [self settingLevelBtnStatus];
}

/// 根据当前logLevel设置btn状态是否可点击
- (void)settingLevelBtnStatus {
    
    // NSLogInfo(@"vvLogLevel=%zd",vvLogLevel);
    NSUserDefaults *logUserDefault = [NSUserDefaults sdkLogUserDefaults];
    VVLogLevel fileLogLevel = [logUserDefault integerForKey:RVConsoleLogLevelKey];
    if (self.logLevelControTypeSeg.selectedSegmentIndex == 1) {
        fileLogLevel = [logUserDefault integerForKey:RVFileLogLevelKey];
        NSLogInfo(@"设置写入文件的日志等级=%zd",fileLogLevel);
    }  else {
        NSLogInfo(@"设置控制台的日志等级=%zd",fileLogLevel);
    }
   
    self.logLevelWarnButton.enabled = YES;
    self.logLevelInfoButton.enabled = YES;
    self.logLevelDebugButton.enabled = YES;
    self.logLevelVerboseButton.enabled = YES;
    
    switch (fileLogLevel) {
        case VVLogLevelWarning:
            self.logLevelWarnButton.enabled = NO;
            break;
        case VVLogLevelInfo:
            self.logLevelInfoButton.enabled = NO;
            break;
        case VVLogLevelDebug:
            self.logLevelDebugButton.enabled = NO;
            break;
        case VVLogLevelVerbose:
            self.logLevelVerboseButton.enabled = NO;
            break;
        default:
            break;
    }
}

#pragma mark - UI Elements
- (UIButton *)displayAllLogFilesButton {
    if (!_displayAllLogFilesButton) {
        _displayAllLogFilesButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_displayAllLogFilesButton setTitle:@"显示所有日志文件" forState:UIControlStateNormal];
        [_displayAllLogFilesButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_displayAllLogFilesButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _displayAllLogFilesButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_displayAllLogFilesButton addTarget:self action:@selector(displayAllLogFiles) forControlEvents:UIControlEventTouchUpInside];
    }
    return _displayAllLogFilesButton;
}

- (UIButton *)clearCurrentLogButton {
    if (!_clearCurrentLogButton) {
        _clearCurrentLogButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_clearCurrentLogButton setTitle:@"清空当前日志" forState:UIControlStateNormal];
        [_clearCurrentLogButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_clearCurrentLogButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _clearCurrentLogButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_clearCurrentLogButton addTarget:self action:@selector(cleanCurrentLog) forControlEvents:UIControlEventTouchUpInside];
    }
    return _clearCurrentLogButton;
}

- (UIButton *)closePageButton {
    if (!_closePageButton) {
        _closePageButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_closePageButton setTitle:@"关闭界面" forState:UIControlStateNormal];
        [_closePageButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_closePageButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _closePageButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_closePageButton addTarget:self action:@selector(closePage) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closePageButton;
}

- (UISegmentedControl *)logLevelControTypeSeg {
    if (!_logLevelControTypeSeg) {
        _logLevelControTypeSeg = [[UISegmentedControl alloc] initWithItems:@[@"控制台日志等级", @"写入文件日志等级"]];
        _logLevelControTypeSeg.apportionsSegmentWidthsByContent = YES;
        _logLevelControTypeSeg.selectedSegmentIndex = 0;
        [_logLevelControTypeSeg addTarget:self action:@selector(logLevelControlTypeChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _logLevelControTypeSeg;
}

- (UIButton *)logLevelWarnButton {
    if (!_logLevelWarnButton) {
        _logLevelWarnButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_logLevelWarnButton setTitle:@"设置日志等级-Warn" forState:UIControlStateNormal];
        [_logLevelWarnButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_logLevelWarnButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _logLevelWarnButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_logLevelWarnButton addTarget:self action:@selector(setLogLevelToWarn) forControlEvents:UIControlEventTouchUpInside];
    }
    return _logLevelWarnButton;
}

- (UIButton *)logLevelInfoButton {
    if (!_logLevelInfoButton) {
        _logLevelInfoButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_logLevelInfoButton setTitle:@"设置日志等级-Info" forState:UIControlStateNormal];
        [_logLevelInfoButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_logLevelInfoButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _logLevelInfoButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_logLevelInfoButton addTarget:self action:@selector(setLogLevelToInfo) forControlEvents:UIControlEventTouchUpInside];
    }
    return _logLevelInfoButton;
}

- (UIButton *)logLevelDebugButton {
    if (!_logLevelDebugButton) {
        _logLevelDebugButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_logLevelDebugButton setTitle:@"设置日志等级-Debug" forState:UIControlStateNormal];
        [_logLevelDebugButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_logLevelDebugButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _logLevelDebugButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_logLevelDebugButton addTarget:self action:@selector(setLogLevelToDebug) forControlEvents:UIControlEventTouchUpInside];
    }
    return _logLevelDebugButton;
}

- (UIButton *)logLevelVerboseButton {
    if (!_logLevelVerboseButton) {
        _logLevelVerboseButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_logLevelVerboseButton setTitle:@"设置日志等级-Verbose" forState:UIControlStateNormal];
        [_logLevelVerboseButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        [_logLevelVerboseButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateDisabled];
        _logLevelVerboseButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_logLevelVerboseButton addTarget:self action:@selector(setLogLevelToVerbose) forControlEvents:UIControlEventTouchUpInside];
    }
    return _logLevelVerboseButton;
}

- (UILabel *)writeLogToFileLabel {
    if (!_writeLogToFileLabel) {
        _writeLogToFileLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _writeLogToFileLabel.text = @"日志写入沙盒文件";
        _writeLogToFileLabel.textColor = [UIColor blackColor];
    }
    return _writeLogToFileLabel;
}
- (UISwitch *)writeLogToFileSwitch {
    if(!_writeLogToFileSwitch) {
        _writeLogToFileSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_writeLogToFileSwitch addTarget:self action:@selector(writeLogToFileSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _writeLogToFileSwitch;
}

- (UILabel *)showLogInConsoleLabel {
    if (!_showLogInConsoleLabel) {
        _showLogInConsoleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _showLogInConsoleLabel.text = @"在控制台显示日志";
        _showLogInConsoleLabel.textColor = [UIColor blackColor];
    }
    return _showLogInConsoleLabel;
}
- (UISwitch *)showLogInConsoleSwitch {
    if(!_showLogInConsoleSwitch) {
        _showLogInConsoleSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_showLogInConsoleSwitch addTarget:self action:@selector(showLogInConsoleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _showLogInConsoleSwitch;
}

- (UILabel *)createNewLogEveryLaunchLabel {
    if (!_createNewLogEveryLaunchLabel) {
        _createNewLogEveryLaunchLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _createNewLogEveryLaunchLabel.text = @"每次启动生成新的日志文件";
        _createNewLogEveryLaunchLabel.textColor = [UIColor blackColor];
    }
    return _createNewLogEveryLaunchLabel;
}
- (UISwitch *)createNewLogEveryLaunchSwitch {
    if(!_createNewLogEveryLaunchSwitch) {
        _createNewLogEveryLaunchSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_createNewLogEveryLaunchSwitch addTarget:self action:@selector(createNewLogEveryLaunchSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _createNewLogEveryLaunchSwitch;
}

- (UILabel *)showDebugWindowNextLaunchLabel {
    if (!_showDebugWindowNextLaunchLabel) {
        _showDebugWindowNextLaunchLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _showDebugWindowNextLaunchLabel.text = @"下次启动打开日志调试浮窗";
        _showDebugWindowNextLaunchLabel.textColor = [UIColor blackColor];
    }
    return _showDebugWindowNextLaunchLabel;
}
- (UISwitch *)showDebugWindowNextLaunchSwitch {
    if(!_showDebugWindowNextLaunchSwitch) {
        _showDebugWindowNextLaunchSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_showDebugWindowNextLaunchSwitch addTarget:self action:@selector(showDebugWindowNextLaunchSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _showDebugWindowNextLaunchSwitch;
}

#pragma mark - Action
/// 显示所有日志文件
- (void)displayAllLogFiles {
    [[RVLogService sharedInstance] displayLogs];
}

/// 清空当前log(其实是生成一个新的log文件)
- (void)cleanCurrentLog {
    [[RVLogService sharedInstance] createAndRollToNewFile];
}

/// 关闭当前界面
- (void)closePage {
    if (self.isBeingPresented) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
    
}

/// 切换日志等级控制对象
- (void)logLevelControlTypeChanged:(UISegmentedControl *)sender {
    // 根据当前logLevel设置btn状态是否可点击
    [self settingLevelBtnStatus];
    
    // 如果选中了控制写入文件等级，则标记写入等级
    if (sender.selectedSegmentIndex == 1) {
        // FIXME: 开启浮窗时已经设置为yes了，这里是不是多余了？
        [[NSUserDefaults sdkLogUserDefaults] setBool:YES forKey:RVManualFileLogLevelKey];
    }
}

/// 设置日志等级为Warn
- (void)setLogLevelToWarn {
    if (self.logLevelControTypeSeg.selectedSegmentIndex == 1) {
        [[RVLogService sharedInstance] settingFileLogLevel:(VVLogLevelWarning)];
    } else {
        [[RVLogService sharedInstance] settingConsoleLogLevel:VVLogLevelWarning];
    }
    [self settingLevelBtnStatus];
}

/// 设置日志等级为Info
- (void)setLogLevelToInfo {
    if (self.logLevelControTypeSeg.selectedSegmentIndex == 1) {
        [[RVLogService sharedInstance] settingFileLogLevel:(VVLogLevelInfo)];
    } else {
        [[RVLogService sharedInstance] settingConsoleLogLevel:VVLogLevelInfo];
    }
    [self settingLevelBtnStatus];
}

/// 设置日志等级为Debug
- (void)setLogLevelToDebug {
    if (self.logLevelControTypeSeg.selectedSegmentIndex == 1) {
        [[RVLogService sharedInstance] settingFileLogLevel:(VVLogLevelDebug)];
    } else {
        [[RVLogService sharedInstance] settingConsoleLogLevel:VVLogLevelDebug];
    }
    [self settingLevelBtnStatus];
}
/// 设置日志等级为Verbose
- (void)setLogLevelToVerbose {
    if (self.logLevelControTypeSeg.selectedSegmentIndex == 1) {
        [[RVLogService sharedInstance] settingFileLogLevel:(VVLogLevelVerbose)];
    } else {
        [[RVLogService sharedInstance] settingConsoleLogLevel:VVLogLevelVerbose];
    }
    [self settingLevelBtnStatus];
}

/// log写入到沙盒文件
- (void)writeLogToFileSwitchChanged:(UISwitch *)sender {
    [RVLogService sharedInstance].writeLogToFile = sender.on;
}

/// 在控制台显示log
- (void)showLogInConsoleSwitchChanged:(UISwitch *)sender {
    [RVLogService sharedInstance].showlogInConsole = sender.on;
}

/// 每次启动生成新的log文件
- (void)createNewLogEveryLaunchSwitchChanged:(UISwitch *)sender {
    [RVLogService sharedInstance].createNewLogEveryLaunching = sender.on;
}

/// 下次启动打开日志调试浮窗
- (void)showDebugWindowNextLaunchSwitchChanged:(UISwitch *)sender {
    [RVLogService sharedInstance].showDebugWindowConfig = sender.on;
}
@end
