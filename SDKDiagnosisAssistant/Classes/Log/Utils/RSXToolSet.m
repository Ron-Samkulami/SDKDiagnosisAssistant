//
//  RSXToolSet.m

//
//  Created by 朱 圣 on 8/16/13.
//  Copyright (c) 2013 37wan. All rights reserved.
//

#import "RSXToolSet.h"
#import "RVDeviceUtils.h"
#import <objc/runtime.h>
#import "RVRootViewTool.h"
#import "RVOnlyLog.h"
#import "NSStringUtils.h"

@implementation RSXToolSet



//bundleId版本号比较
+ (int)versionCompareVer1:(NSString *)ver1 ver2:(NSString *)ver2
{
    NSArray *components1 = [ver1 componentsSeparatedByString:@"."];
    NSArray *components2 = [ver2 componentsSeparatedByString:@"."];
    NSUInteger minCount = MIN(components1.count, components2.count);
    for (int i = 0; i < minCount; ++i) {
        NSInteger v1 = [[components1 objectAtIndex:i] integerValue];
        NSInteger v2 = [[components2 objectAtIndex:i] integerValue];
        if (v1 < v2)
        {
            return -1;
        }
        else if(v1 > v2)
        {
            return 1;
        }
    }
    
    if (components1.count == components2.count) {
        return 0;
    }
    else if (components1.count < components2.count)
    {
        return -1;
    }
    return 1;
}

+ (NSString *)URLEncodeString:(NSString *)str
{
    //str为nil时，直接返回@""，否则会崩溃
    if(![str isKindOfClass:[NSString class]]) {
        return @"";
    }
    
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[str UTF8String];
    int sourceLen = (int)strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i)
    {
        const unsigned char thisChar = source[i];
        if (thisChar == ' ')
        {
            [output appendString:@"+"];
        }
        else if
            (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
             (thisChar >= 'a' && thisChar <= 'z') ||
             (thisChar >= 'A' && thisChar <= 'Z') ||
             (thisChar >= '0' && thisChar <= '9')) {
                [output appendFormat:@"%c", thisChar];
            }
        else
        {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}





//从Token中获得值
+ (NSString *)saveToken:(NSString *)token {
    
    if (!token) {
        return @"";
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:token options:0];
    NSString *temp= [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
    NSString *result = [NSStringUtils stringFromHexString:temp];
    return result;
}


//杀死程序（有动画效果）
+ (void)exitApplication {
    UIWindow *window = [RVRootViewTool getCurrentRootWindow];
    [UIView animateWithDuration:1.0f animations:^{
        window.alpha = 0;
        window.frame = CGRectMake(0, window.bounds.size.height / 2, window.bounds.size.width, 0.5);
    } completion:^(BOOL finished) {
        exit(0);
    }];
}


//方法交换
+ (void)swizzlingInClass:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector
{
    Class class = cls;
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    if (!originalMethod) {
        NSLogError(@"originalMethod 为nil Class=%@,originalSelector=%@",NSStringFromClass(class),NSStringFromSelector(originalSelector));
        return;
    }
    if (!swizzledMethod) {
        NSLogError(@"swizzledMethod 为nil Class=%@,swizzledSelector=%@",NSStringFromClass(class),NSStringFromSelector(swizzledSelector));
        return;
    }
   
    
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod)
    {
        //方法注入成功，表明当前类本身没有实现原方法(是父类实现的)。
        //将原方法的IMP替换到新方法中
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    }
    else
    {
        //方法注入失败，表明当前类已经实现了原方法
        //交换两个方法的IMP
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

//方法交换
+ (void)swizzlingInOriginalClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector
{
    if (!originalClass) {
        NSLogError(@"originalClass 为nil");
        return;
    }
    if (!swizzledClass) {
        NSLogError(@"swizzledClass 为nil");
        return;
    }
    
    Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector);
    
    if (!originalMethod) {
        NSLogError(@"originalMethod 为nil Class=%@,originalSelector=%@",NSStringFromClass(originalClass),NSStringFromSelector(originalSelector));
        return;
    }
    if (!swizzledMethod) {
        NSLogError(@"swizzledMethod 为nil Class=%@,swizzledSelector=%@",NSStringFromClass(swizzledClass),NSStringFromSelector(swizzledSelector));
        return;
    }
   
    //将swizzled方法注入到被hook的类中，并更新Method
    class_addMethod(originalClass, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    swizzledMethod = class_getInstanceMethod(originalClass, swizzledSelector);
    
    
    BOOL didAddMethod =
    class_addMethod(originalClass,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod)
    {
        //方法注入成功，表明当前类本身没有实现原方法(是父类实现的)。
        //将原方法的IMP替换到新方法中
        class_replaceMethod(originalClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    }
    else
    {
        //方法注入失败，表明当前类已经实现了原方法
        //交换两个方法的IMP
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}


//hook instance对象所在类的originalSelector方法，如果方法不存在，将会先注入一个方法
+ (void)swizzlingDelegateMethodInOriginalClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector noopSelector:(SEL)noopSelector {
    
    if (!originalClass) {
        NSLogError(@"originalClass不存在");
        return;
    }
    if (!swizzledClass) {
        NSLogError(@"swizzledClass不存在");
        return;
    }
    
    //获取对应的Mehtod
    Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);//被hook的方法
    Method swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector);//我们用来交换的方法
    Method noopMethod = class_getInstanceMethod(swizzledClass, noopSelector);//用来占位的空方法
    
    if (!swizzledMethod) {
        NSLogError(@"swizzledMethod不存在%@",NSStringFromSelector(swizzledSelector));
        return;
    }
    if (!noopMethod) {
        NSLogError(@"noopMethod不存在%@",NSStringFromSelector(noopSelector));
        return;
    }
    
    //如果原方法没有实现，注入一个空方法，并更新Method
    if (!originalMethod) {
        class_addMethod(originalClass, originalSelector, method_getImplementation(noopMethod), method_getTypeEncoding(noopMethod));
        originalMethod = class_getInstanceMethod(originalClass, originalSelector);
    }
    
    //将swizzled方法注入到被hook的类中，并更新Method
    class_addMethod(originalClass, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    swizzledMethod = class_getInstanceMethod(originalClass, swizzledSelector);
    
    //以下为经典的代码，同一个类中的方法交换
    BOOL didAddMethod = class_addMethod(originalClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(originalClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

//方法交换
+ (void)swizzlingClassMehthodInOriginalClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector
{
    if (!originalClass) {
        NSLogError(@"originalClass 为nil");
        return;
    }
    if (!swizzledClass) {
        NSLogError(@"swizzledClass 为nil");
        return;
    }
    
    originalClass = object_getClass(originalClass);
    swizzledClass = object_getClass(swizzledClass);
    
    Method originalMethod = class_getClassMethod(originalClass, originalSelector);
    Method swizzledMethod = class_getClassMethod(swizzledClass, swizzledSelector);
    
    if (!originalMethod) {
        NSLogError(@"originalMethod 为nil Class=%@,originalSelector=%@",NSStringFromClass(originalClass),NSStringFromSelector(originalSelector));
        return;
    }
    if (!swizzledMethod) {
        NSLogError(@"swizzledMethod 为nil Class=%@,swizzledSelector=%@",NSStringFromClass(swizzledClass),NSStringFromSelector(swizzledSelector));
        return;
    }
   
    //将swizzled方法注入到被hook的类中，并更新Method
    class_addMethod(originalClass, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    swizzledMethod = class_getClassMethod(originalClass, swizzledSelector);
    
    
    BOOL didAddMethod =
    class_addMethod(originalClass,
                    originalSelector,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod)
    {
        //方法注入成功，表明当前类本身没有实现原方法(是父类实现的)。
        //将原方法的IMP替换到新方法中
        class_replaceMethod(originalClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    }
    else
    {
        //方法注入失败，表明当前类已经实现了原方法
        //交换两个方法的IMP
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}


//打印是否为测试包
+ (BOOL)isDebugPackage {
    
    //检测embedded.mobileprovision文件是否存在，线上包无这个文件
    NSMutableString *fileName = [[NSMutableString alloc] init];
    [fileName appendString:@"embed"];
    [fileName appendString:@"ded"];
    [fileName appendString:@"."];
    [fileName appendString:@"mobile"];
    [fileName appendString:@"provision"];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    BOOL fileExist = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    
    BOOL isSimulator = [RVDeviceUtils isSimulator];
    
    BOOL isDebug = NO;
    if (fileExist || isSimulator) {
        isDebug = YES;
    }
    return isDebug;
}


//用纯颜色生成image
+ (UIImage *)createImageWithColor:(UIColor *)color
{
    CGRect rect=CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}

//openURL方法封装，兼容iOS10以下版本
+ (void)openURL:(NSURL*)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^ __nullable)(BOOL success))completion {
    
    if (@available(iOS 10.0,*)) {
        
        [[UIApplication sharedApplication] openURL:url options:options completionHandler:completion];
    } else {
        
        [[UIApplication sharedApplication] openURL:url];
        if (completion) completion(YES);
    }
}


// 获取文件或者文件夹大小(单位：B)
+ (unsigned long long)sizeAtPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
        return 0;
    };
    unsigned long long fileSize = 0;
    // directory
    if (isDir) {
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
        while (enumerator.nextObject) {
           // 下面注释掉的代码作用：不递归遍历子文件夹
           // if ([enumerator.fileAttributes.fileType isEqualToString:NSFileTypeDirectory]) {
           //      [enumerator skipDescendants];
           // }
            fileSize += enumerator.fileAttributes.fileSize;
        }
    } else {
        // file
        fileSize = [fm attributesOfItemAtPath:path error:nil].fileSize;
    }
    return fileSize;
}

//可以避免给定的View中多个按钮同时点击
+ (void)setExclusiveTouchForButtons:(UIView *)view
{
    for (UIView *v in [view subviews]) {
        
        if([v isKindOfClass:[UIButton class]]) {
            [((UIButton *)v) setExclusiveTouch:YES];
        } else if ([v isKindOfClass:[UIView class]]){
            [self setExclusiveTouchForButtons:v];
        }
    }
}



// 沙盒路径中 Library/Application Support/RVSDK 路径为SDK文件的主要存储路径
+ (NSString *)getSDKApplicationSupportPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *sdkDir = [baseDir stringByAppendingPathComponent:@"RVSDK"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:sdkDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:sdkDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return sdkDir;
}

@end
