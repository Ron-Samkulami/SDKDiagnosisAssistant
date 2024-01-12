//
//  RSJsonUtils.h
//  SDKDiagnosisAssistant_Example
//
//  Created by 黄雄荣 on 2024/1/5.
//  Copyright © 2024 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSJsonUtils : NSObject

/// dictonary转JSON字符串(JSON带格式)
+ (NSString *)jsonStringFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
