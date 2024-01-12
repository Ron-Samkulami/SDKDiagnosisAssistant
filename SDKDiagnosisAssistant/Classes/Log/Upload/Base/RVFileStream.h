//
//  RVFileStreamSeparation.h
//  uploadFileDemo
//
//  Created by hyjet on 2018/3/9.
//  Copyright © 2018年 uploadFileDemo. All rights reserved.
//

#import <Foundation/Foundation.h>

//文件分片的大小，512K
//#define RVStreamFragmentMaxSize         1024 * 512
@import CoreGraphics.CGBase;
@class RVStreamFragment;

/**
 * 文件流操作类
 */
@interface RVFileStream : NSObject<NSCoding>


/// 上传ID，由后台返回，作为一个文件上传时的唯一标识
@property (nonatomic, copy) NSString *uploadId;
/// 上传类型
@property (nonatomic, copy) NSString *uploadType;
/// 上传文件关联的单据ID
@property (nonatomic, copy) NSString *uploadRelateId;

/// 文件所在的文件目录
@property (nonatomic, copy) NSString *filePath;;
/// 包括文件后缀名的文件名
@property (nonatomic, copy, readonly) NSString *fileName;
/// 文件大小
@property (nonatomic, assign, readonly) NSUInteger fileSize;
/// 分片大小
@property (nonatomic, assign, readonly) CGFloat cutFragmenSize;
/// 文件分片数组
@property (nonatomic, strong,readonly) NSArray<RVStreamFragment *> *streamFragments;


/// 初始化方法，根据文件路径和上传ID进行分片等处理
- (instancetype)initWithFilePath:(NSString *)path uploadId:(NSString *)uploadId cutFragmenSize:(CGFloat)cutFragmenSize;

/// 通过分片信息读取对应的片数据
- (NSData *)readDataOfFragment:(RVStreamFragment *)fragment;

/// 通过分片信息读取对应的片数据（适应多线程）
- (NSData *)multiThreadReadDataOfFragment:(RVStreamFragment*)fragment;

@end


#pragma mark - 上传文件片
@interface RVStreamFragment : NSObject<NSCoding>
@property (nonatomic, copy) NSString          *fragmentId;  // 片的唯一标识
@property (nonatomic, assign) NSUInteger      size;         // 片的大小
@property (nonatomic, assign) NSUInteger      offset;       // 片的偏移量
@property (nonatomic, assign) BOOL            status;       // 上传状态 YES上传成功
@end
