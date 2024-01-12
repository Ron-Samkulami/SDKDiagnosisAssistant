//
//  XXXLogService.m
//
//  Created by 石学谦 on 2020/4/2.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import "RVLogService.h"
//log格式控制
#import "RVLogFormattter.h"
#import "RVFileLogFormatter.h"
#import "RVLogFileManager.h"
//log视图
#import "RVLogFileTableViewController.h"
#import "RVDebugFloatWindow.h"
#import "RVDebugWindow.h"
#import "RVDebugViewController.h"
//log上传
#import "RVLogUploadManager.h"
//核心类
#import "RVRootViewTool.h"
#import "RSXToolSet.h"
#import "RVDeviceUtils.h"
#import "NSUserDefaults+SDKUserDefaults.h"

static NSString *const RVWriteLogToFileKey =        @"RVWriteLogToFileKey";
static NSString *const RVShowlogInConsoleKey =      @"RVShowlogInConsoleKey";
static NSString *const RVCreateLogEveryLaunchKey =  @"RVCreateLogEveryLaunchKey";
static NSString *const RVShowDebugWindowKey =       @"RVShowDebugWindowKey";
static NSString *const RVLogLevelKey =              @"RVLogLevelKey";

NSString *const RVFileLogLevelKey =         @"RVFileLogLevelKey";
NSString *const RVConsoleLogLevelKey =      @"RVConsoleLogLevelKey";
NSString *const RVManualFileLogLevelKey =   @"RVManualFileLogLevelKey";


@interface RVLogService ()<UIDocumentInteractionControllerDelegate>
/// log文件管理
@property (nonatomic, strong) RVLogFileManager *fileManager;
/// log格式控制器
@property (nonatomic, strong) RVLogFormattter *logFormatter;

/// 文件写入logger
@property (nonatomic, strong) VVFileLogger *fileLogger;
/// 控制台logger
@property (nonatomic, strong) VVAbstractLogger *consoleLogger;

/// 调试浮窗View
@property (nonatomic, strong) RVDebugFloatWindow *floatWindow;
/// 调试浮窗windows
@property (nonatomic, strong) RVDebugWindow *window;
/// 是否显示浮窗
@property (nonatomic, assign) BOOL showDebugWindow;

/// 是否是测试包。上传到iTC之后就不是调试包了，包括TestFlight
@property (nonatomic, assign) BOOL deubgPackage;

@end

@implementation RVLogService

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (void)start {
    [self sharedInstance];
}

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        
        _deubgPackage = [RSXToolSet isDebugPackage];
        
        _fileManager = [[RVLogFileManager alloc] init];
        _fileLogger = [[VVFileLogger alloc] initWithLogFileManager:_fileManager];
        _fileLogger.rollingFrequency = 60 * 60 * 24; // 一个文件有效期是24小时
        _fileLogger.logFileManager.maximumNumberOfLogFiles = 15;//最多文件数量
        _fileLogger.maximumFileSize = 1024*1024*30;//每个文件数量最大尺寸为30M
        _fileLogger.logFileManager.logFilesDiskQuota = 1024*1024*100;//文件夹最大100M
        [_fileLogger setLogFormatter:[[RVFileLogFormatter alloc] init]];
        
        RVLogFormattter *formatter = [[RVLogFormattter alloc] init];
        _logFormatter = formatter;
        
        if (@available(iOS 10.0,*)) {
            // 需要在控制台的菜单栏【操作】->勾选上【包括简介信息】和【包括调试信息】才能看到
            _consoleLogger = [VVOSLogger sharedInstance];
        } else {
            _consoleLogger = [VVASLLogger sharedInstance];
        }
        [_consoleLogger setLogFormatter:formatter];
        
        // 第一次启动进行设置
        [self firstLaunchConfig];
        
        // 控制台log显示
        [self setShowlogInConsole:[[NSUserDefaults sdkLogUserDefaults] boolForKey:RVShowlogInConsoleKey]];
        // 文件写入
        [self setWriteLogToFile:[[NSUserDefaults sdkLogUserDefaults] boolForKey:RVWriteLogToFileKey]];
        
        _createNewLogEveryLaunching = [[NSUserDefaults sdkLogUserDefaults] boolForKey:RVCreateLogEveryLaunchKey];
        // 每次启动都重新生成，不重用之前的文件
        self.fileLogger.doNotReuseLogFiles = _createNewLogEveryLaunching;
        
        // 显示调试浮窗
        _showDebugWindowConfig = [[NSUserDefaults sdkLogUserDefaults] boolForKey:RVShowDebugWindowKey];
        if (_showDebugWindowConfig) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //触发setter方法
                self.showDebugWindow  = YES;
            });
        }
        
        // 监听通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openLogDebugWindow) name:@"kRVShowDebugWindowNotification" object:nil];
        
        // 沙盒测试打印
        NSLogWarn(@"========== SDK初始化 ==========");
        if (_deubgPackage) {
            NSLogWarn(@"====== 当前包为测试包,可以进行沙盒储值 ======");
        } else {
            NSLogWarn(@"====== 当前包为线上包，无法进行沙盒储值 ======");
        }
        
    }
    return self;
}

#pragma mark - 界面操作
/// 显示Log文件夹内容
- (void)displayLogs {
    
    NSArray *filePaths = [_fileManager sortedLogFilePaths];
    RVLogFileTableViewController *controller = [[RVLogFileTableViewController alloc] initWithStyle:UITableViewStylePlain];
    controller.filePaths = filePaths.mutableCopy;
    
    UIViewController *rootViewController = [RVRootViewTool getTopViewController];
    [rootViewController presentViewController:controller animated:NO completion:nil];
}

/// 显示当前的log内容
- (void)dispalyCurrentLog {
    [self displayLocalLogWithFilePath:_fileLogger.currentLogFileInfo.filePath];
}

/// 显示沙盒本地log（在iOS13模拟器会报错，真机不会，这是一个苹果的bug）
- (void)displayLocalLogWithFilePath:(NSString *)filePath
{
    // 由文件路径初始化UIDocumentInteractionController
    UIDocumentInteractionController *documentInteractionController  = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];
    // 设置代理
    documentInteractionController .delegate = self;
    // 显示预览界面
    [documentInteractionController  presentPreviewAnimated:YES];
}

#pragma mark - UIDocumentInteractionControllerDelegate
/// 在哪个控制器显示预览界面
-(UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller
{
    return [UIApplication sharedApplication].delegate.window.rootViewController;
}

/// 显示日志调试浮窗
- (void)openLogDebugWindow {
    
    if (_floatWindow) {
        return;
    }
    
    NSString *msg = [NSString stringWithFormat:@"输入密码开启调试模式"];
    
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Tips" message:msg preferredStyle:(UIAlertControllerStyleAlert)];
    [alertVC addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入密码";
    }];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"cancel" style:(UIAlertActionStyleCancel) handler:nil]];
    [alertVC addAction:[UIAlertAction actionWithTitle:@"ok" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
        //TODO: 这里先关掉密码校验，有需要的话可打开，或自行设置密码
//        UITextField *textFiled = [alertVC.textFields firstObject];
//        NSString *password = [self getDynamicPassword];
//        if (![textFiled.text isEqualToString:password]) {
//            return;
//        }
        
        NSLogWarn(@"打开了调试浮窗");
        self.showDebugWindow = YES;
        self.showDebugWindowConfig = YES;
    }]];

    UIViewController *rootViewController = [RVRootViewTool getTopViewController];
    [rootViewController presentViewController:alertVC animated:NO completion:nil];
}

#pragma mark - 路径获取

/// 返回log文件夹路径
- (NSString *)logsDir {
    return _fileLogger.logFileManager.logsDirectory;
}

/// 返回所有log文件路径
- (NSArray *)filePaths {
    NSLogDebug(@"filePaths=%@",_fileLogger.logFileManager.sortedLogFilePaths);
    return _fileLogger.logFileManager.sortedLogFilePaths;
}

/// 返回当前使用的log文件路径
- (NSString *)currentFilePath {
    NSString *filePath = _fileLogger.currentLogFileInfo.filePath;
    NSLogDebug(@"filePath=%@",filePath);
    return filePath;
}


#pragma mark - log操作

/// 切换log等级
- (void)settingFileLogLevel:(VVLogLevel)logLevel {
    
    VVLogLevel lastLogLevel = [[NSUserDefaults sdkLogUserDefaults] integerForKey:RVFileLogLevelKey];
    if (logLevel != lastLogLevel) {
        [[NSUserDefaults sdkLogUserDefaults] setInteger:logLevel forKey:RVFileLogLevelKey];
        [[NSUserDefaults sdkLogUserDefaults] synchronize];
    }
    if (!self.writeLogToFile) {
        return;
    }
    
    // 如果当前等级的logger已经加过了，不需要处理
    NSArray *allLoggers = [VVLog allLoggersWithLevel];
    for (VVLoggerInformation *loggerInfo in allLoggers) {
        if ([loggerInfo.logger isEqual:_fileLogger] && loggerInfo.level == logLevel) {
            NSLogRVSDK(@"当前等级已经加过，不需要处理 fileLogger logLevel=%zd",logLevel);
            return;
        }
    }
    // 这种方式调等级不太好，每次调完之后都会重新生成一个新的log文件
    [VVLog removeLogger:_fileLogger];
    [VVLog addLogger:_fileLogger withLevel:logLevel];
}

/// 设置控制台日志输出等级
- (void)settingConsoleLogLevel:(VVLogLevel)logLevel {
    
    VVLogLevel lastLogLevel = [[NSUserDefaults sdkLogUserDefaults] integerForKey:RVConsoleLogLevelKey];
    if (logLevel != lastLogLevel) {
        [[NSUserDefaults sdkLogUserDefaults] setInteger:logLevel forKey:RVConsoleLogLevelKey];
        [[NSUserDefaults sdkLogUserDefaults] synchronize];
    }
    if (!self.showlogInConsole) {
        return;
    }
    // 如果当前等级的logger已经加过了，不需要处理
    NSArray *allLoggers = [VVLog allLoggersWithLevel];
    for (VVLoggerInformation *loggerInfo in allLoggers) {
        if ([loggerInfo.logger isEqual:_consoleLogger] && loggerInfo.level == logLevel) {
            NSLogRVSDK(@"当前等级已经加过，不需要处理 consoleLogger logLevel=%zd",logLevel);
            return;
        }
    }
    [VVLog removeLogger:_consoleLogger];
    [VVLog addLogger:_consoleLogger withLevel:logLevel];
}

/// 根据服务器的配置修改log等级
- (void)settingFileLogLevelAccordingToServer:(VVLogLevel)logLevel {
    
    // 如果调试浮窗显示过，则不再关心后端的logLevel设置，只由本地控制
    BOOL settingWindowHadShowed  = [[NSUserDefaults sdkLogUserDefaults] boolForKey:RVManualFileLogLevelKey];
    if (settingWindowHadShowed) {
        NSLogWarn(@"log等级将由手动控制");
        return;
    }
    if ([RVDeviceUtils isJailBroken]) {
        //越狱的情况，不打印
        NSLogRVSDK(@"越狱机不跟随后台设置");
        return;
    }
    // 使用服务器配置进行设置
    [self settingFileLogLevel:logLevel];
}

/// 使用新的log文件写入
- (void)createAndRollToNewFile {
    // achive现在的文件，新生成一个文件，并将以后的log写入新文件
    [_fileLogger rollLogFileWithCompletionBlock:^{
        NSLogInfo(@"rollLogFileWithCompletionBlock");
    }];
}

/// 第一次启动进行设置
- (void)firstLaunchConfig {
    
    static NSString *const RVLogServiceFirstLaunchKey = @"RVLogServiceFirstLaunchKey";
    
    BOOL notFirst =  [[NSUserDefaults sdkLogUserDefaults] boolForKey:RVLogServiceFirstLaunchKey];
    if (notFirst) {
        return;
    }
    [[NSUserDefaults sdkLogUserDefaults] setBool:YES forKey:RVLogServiceFirstLaunchKey];
    [[NSUserDefaults sdkLogUserDefaults] synchronize];
    
    
    if (_deubgPackage) { //测试包
        //开启日志文件写入，默认Info
        self.writeLogToFile = YES;
        [self settingFileLogLevel:VVLogLevelInfo];
        //开启控制台日志，默认Warning
        self.showlogInConsole = YES;
        if ([RVDeviceUtils isSimulator] == YES) {
            NSLogWarn(@"当前为模拟器，开启LogDebug模式");
            [self settingConsoleLogLevel:VVLogLevelDebug];
        } else {
            [self settingConsoleLogLevel:VVLogLevelWarning];
        }
        
    } else if ([RVDeviceUtils isJailBroken]) { //越狱机
        //越狱的情况，都不打印
        return;
    } else { //线上包
        //开启日志文件写入，默认Info
        self.writeLogToFile = YES;
        [self settingFileLogLevel:VVLogLevelInfo];
    }
    
    //首次打开时根据特定名字开启浮窗
    NSString *deviveName =  [UIDevice currentDevice].name;
    NSString *password = [self getDynamicPassword];
    if (![deviveName isEqualToString:password]) {
        return;
    }
    NSLogWarn(@"打开了调试浮窗");
    //显示调试浮窗
    self.showDebugWindowConfig = YES;
    self.createNewLogEveryLaunching = YES;
    //显示log日志
    self.writeLogToFile = YES;
    [self settingFileLogLevel:VVLogLevelDebug];
    self.showlogInConsole = YES;
    [self settingConsoleLogLevel:VVLogLevelDebug];
}

#pragma mark - log上传操作
/// 获取上一次未完成的上传任务ID
+ (nullable NSString *)getLastUploadId {
    return [[RVLogUploadManager sharedManager] getLastUploadId];
}

/// 根据日志上传配置信息，开启上传任务
+ (void)startUploadLogWitTaskInfo:(NSDictionary *_Nonnull)taskInfo {
    [[RVLogUploadManager sharedManager] startUploadLogWitTaskInfo:taskInfo];
}

#pragma mark - Setter

/// log写入到沙盒文件
- (void)setWriteLogToFile:(BOOL)writeLogToFile {
    _writeLogToFile = writeLogToFile;
    [[NSUserDefaults sdkLogUserDefaults] setBool:writeLogToFile forKey:RVWriteLogToFileKey];
    [[NSUserDefaults sdkLogUserDefaults] synchronize];
    
    if (writeLogToFile) {
        VVLogLevel fileLogLevel = [[NSUserDefaults sdkLogUserDefaults] integerForKey:RVFileLogLevelKey];
        [self settingFileLogLevel:fileLogLevel];
    } else {
        [VVLog removeLogger:_fileLogger];
    }
}

/// 在控制台显示log
- (void)setShowlogInConsole:(BOOL)showlogInConsole {
    _showlogInConsole = showlogInConsole;
    [[NSUserDefaults sdkLogUserDefaults] setBool:showlogInConsole forKey:RVShowlogInConsoleKey];
    [[NSUserDefaults sdkLogUserDefaults] synchronize];
    
    if (showlogInConsole) {
        //设置Log等级
        VVLogLevel consoleLogLevel = [[NSUserDefaults sdkLogUserDefaults] integerForKey:RVConsoleLogLevelKey];
        [self settingConsoleLogLevel:consoleLogLevel];
    } else {
        [VVLog removeLogger:_consoleLogger];
    }
}

/// 每次启动生成新的log文件
- (void)setCreateNewLogEveryLaunching:(BOOL)createNewLogEveryLaunching {
    _createNewLogEveryLaunching = createNewLogEveryLaunching;
    _fileLogger.doNotReuseLogFiles = createNewLogEveryLaunching;//每次启动都重新生成，不重用之前的文件
    [[NSUserDefaults sdkLogUserDefaults] setBool:createNewLogEveryLaunching forKey:RVCreateLogEveryLaunchKey];
    [[NSUserDefaults sdkLogUserDefaults] synchronize];
}

/// 下次启动打开log浮窗
- (void)setShowDebugWindowConfig:(BOOL)showDebugWindowConfig {
    _showDebugWindowConfig = showDebugWindowConfig;
    [[NSUserDefaults sdkLogUserDefaults] setBool:showDebugWindowConfig forKey:RVShowDebugWindowKey];
    [[NSUserDefaults sdkLogUserDefaults] synchronize];
}

/// 是否显示浮窗
- (void)setShowDebugWindow:(BOOL)showDebugWindow {
    _showDebugWindow = showDebugWindow;
    if (showDebugWindow) {
        [self.floatWindow showWindow];
    } else {
        [self.floatWindow dissmissWindow];
        _floatWindow = nil;
        _window = nil;
    }
}


#pragma mark - getter

- (RVDebugFloatWindow *)floatWindow
{
    if (_floatWindow == nil)
    {
        //floatWindow 初始化
        _floatWindow = [[RVDebugFloatWindow alloc] initWithFrame:CGRectMake(0, 200, 50, 50) mainBtnName:@"调试" titles:@[@"界面",@"预览",@"隐藏",@"清空"] bgcolor:[UIColor purpleColor]];
        _window = [[RVDebugWindow alloc] init];
        _window.floatView = _floatWindow;
        [_window.rootViewController.view addSubview:_floatWindow];
        
        //浮窗显示出来之后，就不再关心后端的logLevel设置，将只由本地控制
        [[NSUserDefaults sdkLogUserDefaults] setBool:YES forKey:RVManualFileLogLevelKey];
        [[NSUserDefaults sdkLogUserDefaults] synchronize];
        
        __weak typeof(self) weakSelf = self;
        //点击事件处理
        _floatWindow.clickBolcks = ^(NSInteger i){
            
            switch (i)
            {
                case 0:
                {
                    RVDebugViewController *controller = [[RVDebugViewController alloc]init];
                    UIViewController *rootViewController = [RVRootViewTool getTopViewController];
                    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
                        [((UINavigationController *)rootViewController) pushViewController:controller animated:YES];
                    } else {
                        [rootViewController presentViewController:controller animated:YES completion:nil];
                    }
                }
                    break;
                case 1:
                {
                    [weakSelf dispalyCurrentLog];
                }
                    break;
                case 2:
                {
                    weakSelf.showDebugWindow = NO;
                }
                    break;
                case 3:
                {
                    [weakSelf createAndRollToNewFile];
                }
                    break;
                default:
                    break;
            }
            
        };
    }
    return _floatWindow;
}


#pragma mark - log读取操作

+ (void)createNewLogFile {
    NSLog(@"生成新的日志文件");
    [[RVLogService sharedInstance] createAndRollToNewFile];
}

+ (NSString *)readCurrentLogFile {
    NSLog(@"读取当前日志文件");
    return [[RVLogService sharedInstance] readCurrentLogFile];
}

- (NSString *)readCurrentLogFile {
    if (_fileLogger.currentLogFileInfo.filePath) {
        return [NSString stringWithContentsOfFile:_fileLogger.currentLogFileInfo.filePath encoding:NSUTF8StringEncoding error:nil];
    }
    return @"";
}


/// 获取动态密码
- (NSString *)getDynamicPassword
{
    //获取当前时间的月份和星期(星期从星期日开始，星期日为1，星期一为2，星期六为7)
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    NSInteger unitFlags = NSCalendarUnitMonth | NSCalendarUnitWeekday;
    comps = [calendar components:unitFlags fromDate:[NSDate date]];
    NSInteger month = [comps month];
    NSInteger week = [comps weekday];
    //拼接key
    NSString *psd = [NSString stringWithFormat:@"sdk%@",@"debug"];
    psd = [psd stringByAppendingFormat:@"%zd%zd",month,week];
    return psd;
}

@end
