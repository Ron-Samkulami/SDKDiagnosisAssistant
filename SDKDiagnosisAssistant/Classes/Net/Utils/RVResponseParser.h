//
//  RVResponseParser.h
//  sqwsdk
//
//  Created by 朱 圣 on 11/5/13.
//  Copyright (c) 2013 37wan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RVResponseParser : NSObject

//初始化方法
- (instancetype)initWithURL:(NSString *)urlString;
//解析
- (void)parseResponseObject:(id)responseObj;


@property (nonatomic, copy, readonly)NSDictionary *dicResult;//返回的结果(全部)

@property (nonatomic, assign, readonly)NSInteger code;//结果码(result)
@property (nonatomic, copy, readonly)NSString *message;//失败提示(msg)
@property (nonatomic, copy, readonly)NSDictionary *resultData;//结果字典(data)
@property (nonatomic, assign, readonly)NSInteger errorCode;//错误码(code/error_code)


@end
