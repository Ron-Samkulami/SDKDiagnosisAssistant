//
//  RVFileStreamSeparation.m
//  uploadFileDemo
//
//  Created by hyjet on 2018/3/9.
//  Copyright © 2018年 uploadFileDemo. All rights reserved.
//

#import "RVFileStream.h"
#import "RVOnlyLog.h"
#pragma mark - RVFileStreamSeparation


@interface RVFileStream ()

@property (nonatomic, strong) NSFileHandle *readFileHandle;//读取处理器

@end

@implementation RVFileStream

- (instancetype)initWithFilePath:(NSString *)path uploadId:(NSString *)uploadId cutFragmenSize:(CGFloat)cutFragmenSize {
    
    if (self = [super init]) {
    
        if (![self getFileInfoAtPath:path]) {
            return nil;
        }
        if (!uploadId) {
            return nil;
        }
        
        _readFileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
        _uploadId = uploadId;
        //分片大小最低128K
        _cutFragmenSize = MAX(cutFragmenSize, 1024*128) ;
        //核心方法，分片
        [self cutFileForFragments];
    }
    return self;
}

//根据文件路径进行设置
- (BOOL)getFileInfoAtPath:(NSString*)path {
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    if (![fileMgr fileExistsAtPath:path]) {
        NSLogInfo(@"文件不存在：%@",path);
        return NO;
    }
    
    _filePath = path;
    
    NSDictionary *attr = [fileMgr attributesOfItemAtPath:path error:nil];
    _fileSize = (NSUInteger)attr.fileSize;

    NSString *fileName = [path lastPathComponent];
    _fileName = fileName;
    
    return YES;
}

//切分文件片段
- (void)cutFileForFragments {
    
    //每一片的大小
    NSUInteger offset = _cutFragmenSize;
    //块数
    NSUInteger chunks = (_fileSize%offset==0)?(_fileSize/offset):(_fileSize/(offset) + 1);
    
    NSMutableArray<RVStreamFragment *> *fragments = [[NSMutableArray alloc] initWithCapacity:chunks];
    for (int i = 0; i < chunks; i ++) {
        //设置每一片fragment
        RVStreamFragment *fragment = [[RVStreamFragment alloc] init];
        fragment.status = NO;
        fragment.fragmentId = [NSString stringWithFormat:@"%d",i+1];
        fragment.offset = i * offset;
        
        if (i != chunks - 1) {
            fragment.size = offset;
        } else {
            //最后一片特殊处理
            fragment.size = _fileSize - fragment.offset;
        }
        [fragments addObject:fragment];
    }
    
    _streamFragments = fragments;
}

//通过分片信息读取对应的片数据
- (NSData *)readDataOfFragment:(RVStreamFragment*)fragment {
    
    NSLogDebug(@"fragment=%@",fragment);
    if (!fragment) {
        if (_readFileHandle) {
            [_readFileHandle closeFile];
        }
        return nil;
    }
    
    if (self.readFileHandle==nil) {
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:_filePath]) {
            NSLogInfo(@"readDataOfFragment _filePath 不存在");
            return nil;
        }
        self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];
    }

    //移动到偏移位置
    [self.readFileHandle seekToFileOffset:fragment.offset];
    //从偏移位置开始，读取fragmentSize大小的数据
    NSData *data = [self.readFileHandle readDataOfLength:fragment.size];
    return data;
}

//通过分片信息读取对应的片数据（适应多线程）
- (NSData *)multiThreadReadDataOfFragment:(RVStreamFragment*)fragment {
    
    NSLogDebug(@"fragment=%@",fragment);
    if (!fragment) {
        return nil;
    }
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:_filePath]) {
        NSLogInfo(@"readDataOfFragment _filePath 不存在");
        return nil;
    }
    
    // 每个线程新建一个NSFileHandle进行操作
    NSFileHandle *readFileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];

    //移动到偏移位置
    [readFileHandle seekToFileOffset:fragment.offset];
    //从偏移位置开始，读取fragmentSize大小的数据
    NSData *data = [readFileHandle readDataOfLength:fragment.size];
    return data;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    
    [aCoder encodeObject:_fileName forKey:@"fileName"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.fileSize] forKey:@"fileSize"];
    [aCoder encodeObject:_filePath forKey:@"filePath"];
    [aCoder encodeObject:_streamFragments forKey:@"streamFragments"];
    [aCoder encodeObject:_uploadId forKey:@"uploadId"];
    [aCoder encodeObject:_uploadType forKey:@"uploadType"];
    [aCoder encodeObject:_uploadRelateId forKey:@"uploadRelateId"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        
        _fileName = [aDecoder decodeObjectForKey:@"fileName"];
        _fileSize = [[aDecoder decodeObjectForKey:@"fileSize"] unsignedIntegerValue];
        _filePath = [aDecoder decodeObjectForKey:@"filePath"];
        _streamFragments = [aDecoder decodeObjectForKey:@"streamFragments"];
        _uploadId = [aDecoder decodeObjectForKey:@"uploadId"];
        _uploadType = [aDecoder decodeObjectForKey:@"uploadType"];
        _uploadRelateId = [aDecoder decodeObjectForKey:@"uploadRelateId"];
    }
    return self;
}


@end


@implementation RVStreamFragment

- (void)encodeWithCoder:(NSCoder *)aCoder {
    
    [aCoder encodeObject:self.fragmentId forKey:@"fragmentId"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.size] forKey:@"size"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.offset] forKey:@"offset"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.status] forKey:@"status"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.fragmentId = [aDecoder decodeObjectForKey:@"fragmentId"];
        self.size = [[aDecoder decodeObjectForKey:@"size"] unsignedIntegerValue];
        self.offset = [[aDecoder decodeObjectForKey:@"offset"] unsignedIntegerValue];
        self.status = [[aDecoder decodeObjectForKey:@"status"] boolValue];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"RVStreamFragment fragmentId=%@,size=%lu,offset=%zd,status=%d",_fragmentId,(unsigned long)_size,_offset,_status];
}

@end
