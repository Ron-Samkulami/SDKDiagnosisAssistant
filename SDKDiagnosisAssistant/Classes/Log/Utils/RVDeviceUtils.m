//
//  RVDeviceUtils.m
//  RVSDK
//
//  Created by 黄雄荣 on 2022/8/19.
//  Copyright © 2022 SDK. All rights reserved.
//

#import "RVDeviceUtils.h"

#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#import <sys/utsname.h>
#import <ifaddrs.h>

@implementation RVDeviceUtils

/// 获取手机Mac地址(iOS7开始会固定返回020000000000)
+ (NSString *) macaddress
{
    int mib[6];
    size_t len;
    char *buf;
    unsigned char *ptr;
    struct if_msghdr *ifm;
    struct sockaddr_dl *sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    
    if ((mib[5] = if_nametoindex("en0")) == 0) {
        printf("Error: if_nametoindex error/n");
        return NULL;
    }
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 1/n");
        return NULL;
    }
    
    if ((buf = malloc(len)) == NULL) {
        printf("Could not allocate memory. error!/n");
        return NULL;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 2");
        return NULL;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    NSString *outstring = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    free(buf);
    return [outstring uppercaseString];
}

/// 获取设备原始型号
+ (NSString *)getOriginalDeviceType
{
    //需要导入头文件：#import <sys/utsname.h>
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *originalDeviceType = [NSString stringWithCString: systemInfo.machine encoding:NSASCIIStringEncoding];
    return originalDeviceType;
}

/// 由设备原始型号获取手机型号
+ (NSString *)deviceType:(NSString *)oriDeviceType
{
    //参考自 https://www.theiphonewiki.com/wiki/Models
    //注意后续添加时名字要跟文档保持一致
    if([oriDeviceType isEqualToString:@"iPhone1,1"]) return @"iPhone 2G";
    if([oriDeviceType isEqualToString:@"iPhone1,2"]) return @"iPhone 3G";
    if([oriDeviceType isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS";
    if([oriDeviceType isEqualToString:@"iPhone3,1"]) return @"iPhone 4";
    if([oriDeviceType isEqualToString:@"iPhone3,2"]) return @"iPhone 4";
    if([oriDeviceType isEqualToString:@"iPhone3,3"]) return @"iPhone 4";
    if([oriDeviceType isEqualToString:@"iPhone4,1"]) return @"iPhone 4S";
    if([oriDeviceType isEqualToString:@"iPhone5,1"]) return @"iPhone 5";
    if([oriDeviceType isEqualToString:@"iPhone5,2"]) return @"iPhone 5";
    if([oriDeviceType isEqualToString:@"iPhone5,3"]) return @"iPhone 5c";
    if([oriDeviceType isEqualToString:@"iPhone5,4"]) return @"iPhone 5c";
    if([oriDeviceType isEqualToString:@"iPhone6,1"]) return @"iPhone 5s";
    if([oriDeviceType isEqualToString:@"iPhone6,2"]) return @"iPhone 5s";
    if([oriDeviceType isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus";
    if([oriDeviceType isEqualToString:@"iPhone7,2"]) return @"iPhone 6";
    if([oriDeviceType isEqualToString:@"iPhone8,1"]) return @"iPhone 6s";
    if([oriDeviceType isEqualToString:@"iPhone8,2"]) return @"iPhone 6s Plus";
    if([oriDeviceType isEqualToString:@"iPhone8,4"]) return @"iPhone SE";
    if([oriDeviceType isEqualToString:@"iPhone9,1"]) return @"iPhone 7";
    if([oriDeviceType isEqualToString:@"iPhone9,2"]) return @"iPhone 7 Plus";
    if([oriDeviceType isEqualToString:@"iPhone9,3"]) return @"iPhone 7";
    if([oriDeviceType isEqualToString:@"iPhone9,4"]) return @"iPhone 7 Plus";
    if([oriDeviceType isEqualToString:@"iPhone10,1"]) return @"iPhone 8";
    if([oriDeviceType isEqualToString:@"iPhone10,4"]) return @"iPhone 8";
    if([oriDeviceType isEqualToString:@"iPhone10,2"]) return @"iPhone 8 Plus";
    if([oriDeviceType isEqualToString:@"iPhone10,5"]) return @"iPhone 8 Plus";
    if([oriDeviceType isEqualToString:@"iPhone10,3"]) return @"iPhone X";
    if([oriDeviceType isEqualToString:@"iPhone10,6"]) return @"iPhone X";
    if([oriDeviceType isEqualToString:@"iPhone11,2"]) return @"iPhone XS";
    if([oriDeviceType isEqualToString:@"iPhone11,4"]) return @"iPhone XS Max";
    if([oriDeviceType isEqualToString:@"iPhone11,6"]) return @"iPhone XS Max";
    if([oriDeviceType isEqualToString:@"iPhone11,8"]) return @"iPhone XR";
    if([oriDeviceType isEqualToString:@"iPhone12,1"]) return @"iPhone 11";
    if([oriDeviceType isEqualToString:@"iPhone12,3"]) return @"iPhone 11 Pro";
    if([oriDeviceType isEqualToString:@"iPhone12,5"]) return @"iPhone 11 Pro Max";
    if([oriDeviceType isEqualToString:@"iPhone12,8"]) return @"iPhone SE 2";
    if([oriDeviceType isEqualToString:@"iPhone13,1"]) return @"iPhone 12 mini";
    if([oriDeviceType isEqualToString:@"iPhone13,2"]) return @"iPhone 12";
    if([oriDeviceType isEqualToString:@"iPhone13,3"]) return @"iPhone 12 Pro";
    if([oriDeviceType isEqualToString:@"iPhone13,4"]) return @"iPhone 12 Pro Max";
    if([oriDeviceType isEqualToString:@"iPhone14,2"]) return @"iPhone 13 Pro";
    if([oriDeviceType isEqualToString:@"iPhone14,3"]) return @"iPhone 13 Pro Max";
    if([oriDeviceType isEqualToString:@"iPhone14,4"]) return @"iPhone 13 mini";
    if([oriDeviceType isEqualToString:@"iPhone14,5"]) return @"iPhone 13";
    if([oriDeviceType isEqualToString:@"iPhone14,6"]) return @"iPhone SE 3";
    if([oriDeviceType isEqualToString:@"iPhone14,7"]) return @"iPhone 14";
    if([oriDeviceType isEqualToString:@"iPhone14,8"]) return @"iPhone 14 Plus";
    if([oriDeviceType isEqualToString:@"iPhone15,2"]) return @"iPhone 14 Pro";
    if([oriDeviceType isEqualToString:@"iPhone15,3"]) return @"iPhone 14 Pro Max";
    if([oriDeviceType isEqualToString:@"iPhone15,4"]) return @"iPhone 15";
    if([oriDeviceType isEqualToString:@"iPhone15,5"]) return @"iPhone 15 Plus";
    if([oriDeviceType isEqualToString:@"iPhone16,1"]) return @"iPhone 15 Pro";
    if([oriDeviceType isEqualToString:@"iPhone16,2"]) return @"iPhone 15 Pro Max";
    
    if([oriDeviceType isEqualToString:@"iPod1,1"]) return @"iPod Touch 1";
    if([oriDeviceType isEqualToString:@"iPod2,1"]) return @"iPod Touch 2";
    if([oriDeviceType isEqualToString:@"iPod3,1"]) return @"iPod Touch 3";
    if([oriDeviceType isEqualToString:@"iPod4,1"]) return @"iPod Touch 4";
    if([oriDeviceType isEqualToString:@"iPod5,1"]) return @"iPod Touch 5";
    if([oriDeviceType isEqualToString:@"iPod7,1"]) return @"iPod Touch 6";
    if([oriDeviceType isEqualToString:@"iPod9,1"]) return @"iPod Touch 7";
    
    if([oriDeviceType isEqualToString:@"iPad1,1"]) return @"iPad 1G";
    if([oriDeviceType isEqualToString:@"iPad2,1"]) return @"iPad 2";
    if([oriDeviceType isEqualToString:@"iPad2,2"]) return @"iPad 2";
    if([oriDeviceType isEqualToString:@"iPad2,3"]) return @"iPad 2";
    if([oriDeviceType isEqualToString:@"iPad2,4"]) return @"iPad 2";
    if([oriDeviceType isEqualToString:@"iPad2,5"]) return @"iPad Mini 1G";
    if([oriDeviceType isEqualToString:@"iPad2,6"]) return @"iPad Mini 1G";
    if([oriDeviceType isEqualToString:@"iPad2,7"]) return @"iPad Mini 1G";
    if([oriDeviceType isEqualToString:@"iPad3,1"]) return @"iPad 3";
    if([oriDeviceType isEqualToString:@"iPad3,2"]) return @"iPad 3";
    if([oriDeviceType isEqualToString:@"iPad3,3"]) return @"iPad 3";
    if([oriDeviceType isEqualToString:@"iPad3,4"]) return @"iPad 4";
    if([oriDeviceType isEqualToString:@"iPad3,5"]) return @"iPad 4";
    if([oriDeviceType isEqualToString:@"iPad3,6"]) return @"iPad 4";
    if([oriDeviceType isEqualToString:@"iPad4,1"]) return @"iPad Air";
    if([oriDeviceType isEqualToString:@"iPad4,2"]) return @"iPad Air";
    if([oriDeviceType isEqualToString:@"iPad4,3"]) return @"iPad Air";
    if([oriDeviceType isEqualToString:@"iPad4,4"]) return @"iPad Mini 2G";
    if([oriDeviceType isEqualToString:@"iPad4,5"]) return @"iPad Mini 2G";
    if([oriDeviceType isEqualToString:@"iPad4,6"]) return @"iPad Mini 2G";
    if([oriDeviceType isEqualToString:@"iPad4,7"]) return @"iPad Mini 3";
    if([oriDeviceType isEqualToString:@"iPad4,8"]) return @"iPad Mini 3";
    if([oriDeviceType isEqualToString:@"iPad4,9"]) return @"iPad Mini 3";
    if([oriDeviceType isEqualToString:@"iPad5,1"]) return @"iPad Mini 4";
    if([oriDeviceType isEqualToString:@"iPad5,2"]) return @"iPad Mini 4";
    if([oriDeviceType isEqualToString:@"iPad5,3"]) return @"iPad Air 2";
    if([oriDeviceType isEqualToString:@"iPad5,4"]) return @"iPad Air 2";
    if([oriDeviceType isEqualToString:@"iPad6,3"]) return @"iPad Pro 9.7";
    if([oriDeviceType isEqualToString:@"iPad6,4"]) return @"iPad Pro 9.7";
    if([oriDeviceType isEqualToString:@"iPad6,7"]) return @"iPad Pro 12.9";
    if([oriDeviceType isEqualToString:@"iPad6,8"]) return @"iPad Pro 12.9";
    if([oriDeviceType isEqualToString:@"iPad6,11"]) return @"iPad (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad6,12"]) return @"iPad (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad7,1"]) return @"iPad Pro 12.9 inch 2nd gen";
    if([oriDeviceType isEqualToString:@"iPad7,2"]) return @"iPad Pro 12.9 inch 2nd gen";
    if([oriDeviceType isEqualToString:@"iPad7,3"]) return @"iPad Pro 10.5";
    if([oriDeviceType isEqualToString:@"iPad7,4"]) return @"iPad Pro 10.5";
    if([oriDeviceType isEqualToString:@"iPad7,5"]) return @"iPad 6";
    if([oriDeviceType isEqualToString:@"iPad7,6"]) return @"iPad 6";
    if([oriDeviceType isEqualToString:@"iPad7,11"]) return @"iPad 7";
    if([oriDeviceType isEqualToString:@"iPad7,12"]) return @"iPad 7";
    if([oriDeviceType isEqualToString:@"iPad8,1"]) return @"iPad Pro (11-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,2"]) return @"iPad Pro (11-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,3"]) return @"iPad Pro (11-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,4"]) return @"iPad Pro (11-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,5"]) return @"iPad Pro 3 (12.9-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,6"]) return @"iPad Pro 3 (12.9-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,7"]) return @"iPad Pro 3 (12.9-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,8"]) return @"iPad Pro 3 (12.9-inch)";
    if([oriDeviceType isEqualToString:@"iPad8,9"]) return @"iPad Pro (11-inch) (2nd generation)";
    if([oriDeviceType isEqualToString:@"iPad8,10"]) return @"iPad Pro (11-inch) (2nd generation)";
    if([oriDeviceType isEqualToString:@"iPad8,11"]) return @"iPad Pro (12.9-inch) (4th generation)";
    if([oriDeviceType isEqualToString:@"iPad8,12"]) return @"iPad Pro (12.9-inch) (4th generation)";
    if([oriDeviceType isEqualToString:@"iPad11,1"]) return @"iPad mini 5";
    if([oriDeviceType isEqualToString:@"iPad11,2"]) return @"iPad mini 5";
    if([oriDeviceType isEqualToString:@"iPad11,3"]) return @"iPad Air 3";
    if([oriDeviceType isEqualToString:@"iPad11,4"]) return @"iPad Air 3";
    if([oriDeviceType isEqualToString:@"iPad11,6"]) return @"iPad (8th generation)";
    if([oriDeviceType isEqualToString:@"iPad11,7"]) return @"iPad (8th generation)";
    if([oriDeviceType isEqualToString:@"iPad12,1"]) return @"iPad (9th generation)";
    if([oriDeviceType isEqualToString:@"iPad12,2"]) return @"iPad (9th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,1"]) return @"iPad Air (4th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,2"]) return @"iPad Air (4th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,4"]) return @"iPad Pro (11-inch) (3rd generation)";
    if([oriDeviceType isEqualToString:@"iPad13,5"]) return @"iPad Pro (11-inch) (3rd generation)";
    if([oriDeviceType isEqualToString:@"iPad13,6"]) return @"iPad Pro (11-inch) (3rd generation)";
    if([oriDeviceType isEqualToString:@"iPad13,7"]) return @"iPad Pro (11-inch) (3rd generation)";
    if([oriDeviceType isEqualToString:@"iPad13,8"]) return @"iPad Pro (12.9-inch) (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,9"]) return @"iPad Pro (12.9-inch) (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,10"]) return @"iPad Pro (12.9-inch) (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,11"]) return @"iPad Pro (12.9-inch) (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,16"]) return @"iPad Air (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,17"]) return @"iPad Air (5th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,18"]) return @"iPad (10th generation)";
    if([oriDeviceType isEqualToString:@"iPad13,19"]) return @"iPad (10th generation)";
    if([oriDeviceType isEqualToString:@"iPad14,1"]) return @"iPad mini (6th generation)";
    if([oriDeviceType isEqualToString:@"iPad14,2"]) return @"iPad mini (6th generation)";
    if([oriDeviceType isEqualToString:@"iPad14,3"]) return @"iPad Pro (11-inch) (4rd generation)";
    if([oriDeviceType isEqualToString:@"iPad14,4"]) return @"iPad Pro (11-inch) (4rd generation)";
    if([oriDeviceType isEqualToString:@"iPad14,5"]) return @"iPad Pro (12.9-inch) (6th generation)";
    if([oriDeviceType isEqualToString:@"iPad14,6"]) return @"iPad Pro (12.9-inch) (6th generation)";
    
    if([oriDeviceType isEqualToString:@"i386"]) return @"iPhone Simulator";
    if([oriDeviceType isEqualToString:@"x86_64"]) return @"iPhone Simulator";
    
    return oriDeviceType;
}

+ (BOOL)isJailBroken
{
    NSArray *jailPaths = @[
        @"/Applications/Cydia.app",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        //                          @"/bin/bash",
        //                          @"/usr/sbin/sshd",
        //                          @"/etc/apt",
        //                          @"/etc/ssh/sshd_config",
        //                          @"/usr/libexec/ssh-keysign"
    ];
    
    for (int i=0; i<jailPaths.count; i++) {
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:jailPaths[i]]) {
            return YES;
        }
    }
    return NO;
}


/// 是否为模拟器
+ (BOOL)isSimulator {
    
    BOOL isSimulator = NO;
    NSString *device = [self getOriginalDeviceType];
    if ([device isEqualToString:@"i386"] || [device isEqualToString:@"x86_64"]) {
        isSimulator = YES;
    }
    return isSimulator;
}

/// 识别是否为VPN状态
+ (BOOL)isVPNOn {
    BOOL flag = NO;
    NSString *version = [UIDevice currentDevice].systemVersion;
    // need two ways to judge this.
    if (version.doubleValue >= 9.0)
    {
        NSDictionary *dict = CFBridgingRelease(CFNetworkCopySystemProxySettings());
        NSArray *keys = [dict[@"__SCOPED__"] allKeys];
        for (NSString *key in keys) {
            if ([key rangeOfString:@"tap"].location != NSNotFound ||
                [key rangeOfString:@"tun"].location != NSNotFound ||
                [key rangeOfString:@"ipsec"].location != NSNotFound ||
                [key rangeOfString:@"ppp"].location != NSNotFound){
                flag = YES;
                break;
            }
        }
    }
    else
    {
        struct ifaddrs *interfaces = NULL;
        struct ifaddrs *temp_addr = NULL;
        int success = 0;
        
        // retrieve the current interfaces - returns 0 on success
        success = getifaddrs(&interfaces);
        if (success == 0)
        {
            // Loop through linked list of interfaces
            temp_addr = interfaces;
            while (temp_addr != NULL)
            {
                NSString *string = [NSString stringWithFormat:@"%s" , temp_addr->ifa_name];
                if ([string rangeOfString:@"tap"].location != NSNotFound ||
                    [string rangeOfString:@"tun"].location != NSNotFound ||
                    [string rangeOfString:@"ipsec"].location != NSNotFound ||
                    [string rangeOfString:@"ppp"].location != NSNotFound)
                {
                    flag = YES;
                    break;
                }
                temp_addr = temp_addr->ifa_next;
            }
        }
        
        // Free memory
        freeifaddrs(interfaces);
    }
    
    return flag;
}
@end
