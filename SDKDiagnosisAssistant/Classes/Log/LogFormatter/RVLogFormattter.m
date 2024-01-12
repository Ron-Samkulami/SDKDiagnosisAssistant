//
//  RVLogFormattter.m
//
//  Created by 石学谦 on 2020/4/1.
//  Copyright © 2020 shixueqian. All rights reserved.
//

#import "RVLogFormattter.h"

@implementation RVLogFormattter

- (instancetype)init {
    if (self = [super init]) {
        _isDebugMode = NO;
    }
    return  self;
}

 - (NSString *)formatLogMessage:(VVLogMessage *)logMessage {
     NSString *logLevel = nil;
     switch (logMessage->_flag) {
         case VVLogFlagError:
             logLevel = @"E";
             break;
         case VVLogFlagWarning:
             logLevel = @"W";
             break;
         case VVLogFlagInfo:
             logLevel = @"I";
             break;
         case VVLogFlagDebug:
             logLevel = @"D";
             break;
         default:
             logLevel = @"V";
             break;
     }
     NSString *formatLog = [NSString stringWithFormat:@"[XXSDK] %@ %@",logLevel,logMessage->_message];

     if (_isDebugMode == NO) {
         return formatLog;
     }
     
     // 该方法仍然受LogLevel控制(低于LogLevel不会走该方法)
     // 如果返回nil，对应的DDLog不会输出
     // printf方法无法在sib输出
     // NSLogError和NSLog可在sib输出,printf方法和其他等级均无法输出
     // NSLog和NSLogError过长会被截断，具体长度不清楚(可能跟系统相关)
     // iOS14.7.1和iOS16.2测试长度大概2万，windows平台只有1000左右
     
     static const int secLen = 1000;
     NSInteger count = (formatLog.length / secLen) + 1;
     
     if (count > 1) {
         
         NSString *randomStr = [[self class] generate6RandomLetterAndNumber];
         
         for (int i=0;i<count-1;i++) {
             // 分段规则：#$@#-某一段内容-第N段-总N段-6位随机数-#$@#
             NSLog(@"#$@#-%@-%d-%zd-%@-#$@#",[formatLog substringWithRange:NSMakeRange(i*secLen, secLen)], i+1, count, randomStr);
         }
         // 最后一段
         NSLog(@"#$@#-%@-%zd-%zd-%@-#$@#",[formatLog substringFromIndex:(count-1)*secLen], count, count, randomStr);
     } else {
         NSLog(@"%@",formatLog);
     }
     
     return nil;
 }

//返回6位大小写字母和数字
+ (NSString *)generate6RandomLetterAndNumber {
    //定义一个包含数字，大小写字母的字符串
    static const NSString *strAll = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    //定义一个结果
    NSString *result = [[NSMutableString alloc] initWithCapacity:6];
    for (int i = 0; i < 6; i++) {
        //获取随机数
        NSInteger index = arc4random() % (strAll.length-1);
        char tempStr = [strAll characterAtIndex:index];
        result = (NSMutableString *)[result stringByAppendingString:[NSString stringWithFormat:@"%c",tempStr]];
    }
    return result;
}

@end
