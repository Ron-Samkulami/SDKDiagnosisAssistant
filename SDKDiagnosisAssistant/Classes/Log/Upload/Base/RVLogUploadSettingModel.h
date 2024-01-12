//
//  RVLogUploadSettingModel.h
//  RVSDK
//
//  Created by 石学谦 on 2020/7/6.
//  Copyright © 2020 SDK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RVLogUploadConfigModel.h"


NS_ASSUME_NONNULL_BEGIN

@interface RVLogUploadSettingModel : NSObject

@property (nonatomic, copy)NSString *uploadId;//上传ID
@property (nonatomic, assign)BOOL isAllowed;//是否允许上传
@property (nonatomic, copy)NSString *token;//上传token，有时间限制
@property (nonatomic, strong)RVLogUploadConfigModel *config;//配置信息

- (instancetype)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
