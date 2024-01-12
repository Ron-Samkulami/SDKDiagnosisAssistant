//
//  RVNetUtils.h
//  SDKDiagnosisAssistant
//
//  Created by 黄雄荣 on 2024/1/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RVNetUtils : NSObject

/// MD5加密
+ (NSString *)md5HexDigest:(NSString *)originalStr;

/// 获取当前时间戳
+ (NSString *)getCurrentTimeStamp;

/// 对象转JSON字符串
+ (id)convertObjToJsonStringIfValid:(id)object;
@end

NS_ASSUME_NONNULL_END
