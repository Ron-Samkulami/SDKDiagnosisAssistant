// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2020, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <sys/xattr.h>

#import "VVFileLogger+Internal.h"

// We probably shouldn't be using VVLog() statements within the VVLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#ifndef VV_NSLOG_LEVEL
    #define VV_NSLOG_LEVEL 2
#endif

//忽略实现了过时方法的警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmacro-redefined"

#define NSLogError(frmt, ...)    do{ if(VV_NSLOG_LEVEL >= 1) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(VV_NSLOG_LEVEL >= 2) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(VV_NSLOG_LEVEL >= 3) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogDebug(frmt, ...)    do{ if(VV_NSLOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(VV_NSLOG_LEVEL >= 5) NSLog((frmt), ##__VA_ARGS__); } while(0)

//忽略实现了过时方法的警告
#pragma clang diagnostic pop

#if TARGET_OS_IPHONE
BOOL vvdoesAppRunInBackground(void);
#endif

unsigned long long const kVVDefaultLogMaxFileSize      = 1024 * 1024;      // 1 MB
NSTimeInterval     const kVVDefaultLogRollingFrequency = 60 * 60 * 24;     // 24 Hours
NSUInteger         const kVVDefaultLogMaxNumLogFiles   = 5;                // 5 Files
unsigned long long const kVVDefaultLogFilesDiskQuota   = 20 * 1024 * 1024; // 20 MB

NSTimeInterval     const kVVRollingLeeway              = 1.0;              // 1s

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface VVLogFileManagerDefault () {
    NSDateFormatter *_fileDateFormatter;
    NSUInteger _maximumNumberOfLogFiles;
    unsigned long long _logFilesDiskQuota;
    NSString *_logsDirectory;
#if TARGET_OS_IPHONE
    NSFileProtectionType _defaultFileProtectionLevel;
#endif
}

@end

@implementation VVLogFileManagerDefault

@synthesize maximumNumberOfLogFiles = _maximumNumberOfLogFiles;
@synthesize logFilesDiskQuota = _logFilesDiskQuota;

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
    if ([theKey isEqualToString:@"maximumNumberOfLogFiles"] || [theKey isEqualToString:@"logFilesDiskQuota"]) {
        return NO;
    } else {
        return [super automaticallyNotifiesObserversForKey:theKey];
    }
}

- (instancetype)init {
    return [self initWithLogsDirectory:nil];
}

- (instancetype)initWithLogsDirectory:(nullable NSString *)aLogsDirectory {
    if ((self = [super init])) {
        _maximumNumberOfLogFiles = kVVDefaultLogMaxNumLogFiles;
        _logFilesDiskQuota = kVVDefaultLogFilesDiskQuota;

        _fileDateFormatter = [[NSDateFormatter alloc] init];
        [_fileDateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [_fileDateFormatter setDateFormat: @"yyyy'-'MM'-'dd'--'HH'-'mm'-'ss'-'SSS'"];
        [_fileDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

        if (aLogsDirectory.length > 0) {
            _logsDirectory = [aLogsDirectory copy];
        } else {
            _logsDirectory = [[self defaultLogsDirectory] copy];
        }

        NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;

        [self addObserver:self forKeyPath:NSStringFromSelector(@selector(maximumNumberOfLogFiles)) options:kvoOptions context:nil];
        [self addObserver:self forKeyPath:NSStringFromSelector(@selector(logFilesDiskQuota)) options:kvoOptions context:nil];

        NSLogVerbose(@"VVFileLogManagerDefault: logsDirectory:\n%@", [self logsDirectory]);
        NSLogVerbose(@"VVFileLogManagerDefault: sortedLogFileNames:\n%@", [self sortedLogFileNames]);
    }

    return self;
}

#if TARGET_OS_IPHONE
- (instancetype)initWithLogsDirectory:(NSString *)logsDirectory
           defaultFileProtectionLevel:(NSFileProtectionType)fileProtectionLevel {

    if ((self = [self initWithLogsDirectory:logsDirectory])) {
        if ([fileProtectionLevel isEqualToString:NSFileProtectionNone] ||
            [fileProtectionLevel isEqualToString:NSFileProtectionComplete] ||
            [fileProtectionLevel isEqualToString:NSFileProtectionCompleteUnlessOpen] ||
            [fileProtectionLevel isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication]) {
            _defaultFileProtectionLevel = fileProtectionLevel;
        }
    }

    return self;
}

#endif

- (void)dealloc {
    // try-catch because the observer might be removed or never added. In this case, removeObserver throws and exception
    @try {
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(maximumNumberOfLogFiles))];
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(logFilesDiskQuota))];
    } @catch (NSException *exception) {
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(__unused id)object
                        change:(NSDictionary *)change
                       context:(__unused void *)context {
    NSNumber *old = change[NSKeyValueChangeOldKey];
    NSNumber *new = change[NSKeyValueChangeNewKey];

    if ([old isEqual:new]) {
        return;
    }

    if ([keyPath isEqualToString:NSStringFromSelector(@selector(maximumNumberOfLogFiles))] ||
        [keyPath isEqualToString:NSStringFromSelector(@selector(logFilesDiskQuota))]) {
        NSLogInfo(@"VVFileLogManagerDefault: Responding to configuration change: %@", keyPath);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                // See method header for queue reasoning.
                [self deleteOldLogFiles];
            }
        });
    }
}

#if TARGET_OS_IPHONE
- (NSFileProtectionType)logFileProtection {
    if (_defaultFileProtectionLevel.length > 0) {
        return _defaultFileProtectionLevel;
    } else if (vvdoesAppRunInBackground()) {
        return NSFileProtectionCompleteUntilFirstUserAuthentication;
    } else {
        return NSFileProtectionCompleteUnlessOpen;
    }
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Deleting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Deletes archived log files that exceed the maximumNumberOfLogFiles or logFilesDiskQuota configuration values.
 * Method may take a while to execute since we're performing IO. It's not critical that this is synchronized with
 * log output, since the files we're deleting are all archived and not in use, therefore this method is called on a
 * background queue.
 **/
- (void)deleteOldLogFiles {
    NSLogVerbose(@"VVLogFileManagerDefault: deleteOldLogFiles");

    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
    NSUInteger firstIndexToDelete = NSNotFound;

    const unsigned long long diskQuota = self.logFilesDiskQuota;
    const NSUInteger maxNumLogFiles = self.maximumNumberOfLogFiles;

    if (diskQuota) {
        unsigned long long used = 0;

        for (NSUInteger i = 0; i < sortedLogFileInfos.count; i++) {
            VVLogFileInfo *info = sortedLogFileInfos[i];
            used += info.fileSize;

            if (used > diskQuota) {
                firstIndexToDelete = i;
                break;
            }
        }
    }

    if (maxNumLogFiles) {
        if (firstIndexToDelete == NSNotFound) {
            firstIndexToDelete = maxNumLogFiles;
        } else {
            firstIndexToDelete = MIN(firstIndexToDelete, maxNumLogFiles);
        }
    }

    if (firstIndexToDelete == 0) {
        // Do we consider the first file?
        // We are only supposed to be deleting archived files.
        // In most cases, the first file is likely the log file that is currently being written to.
        // So in most cases, we do not want to consider this file for deletion.

        if (sortedLogFileInfos.count > 0) {
            VVLogFileInfo *logFileInfo = sortedLogFileInfos[0];

            if (!logFileInfo.isArchived) {
                // Don't delete active file.
                ++firstIndexToDelete;
            }
        }
    }

    if (firstIndexToDelete != NSNotFound) {
        // removing all log files starting with firstIndexToDelete

        for (NSUInteger i = firstIndexToDelete; i < sortedLogFileInfos.count; i++) {
            VVLogFileInfo *logFileInfo = sortedLogFileInfos[i];

            NSError *error = nil;
            BOOL success = [[NSFileManager defaultManager] removeItemAtPath:logFileInfo.filePath error:&error];
            if (success) {
                NSLogInfo(@"VVLogFileManagerDefault: Deleting file: %@", logFileInfo.fileName);
            } else {
                NSLogError(@"VVLogFileManagerDefault: Error deleting file %@", error);
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Log Files
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the path to the default logs directory.
 * If the logs directory doesn't exist, this method automatically creates it.
 **/
- (NSString *)defaultLogsDirectory {

#if TARGET_OS_IPHONE
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"Logs"];
#else
    NSString *appName = [[NSProcessInfo processInfo] processName];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
    NSString *logsDirectory = [[basePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:appName];
#endif

    return logsDirectory;
}

- (NSString *)logsDirectory {
    // We could do this check once, during initialization, and not bother again.
    // But this way the code continues to work if the directory gets deleted while the code is running.

    NSAssert(_logsDirectory.length > 0, @"Directory must be set.");

    NSError *err = nil;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:_logsDirectory
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:&err];
    if (success == NO) {
        NSLogError(@"VVFileLogManagerDefault: Error creating logsDirectory: %@", err);
    }

    return _logsDirectory;
}

- (BOOL)isLogFile:(NSString *)fileName {
    NSString *appName = [self applicationName];

    // We need to add a space to the name as otherwise we could match applications that have the name prefix.
    BOOL hasProperPrefix = [fileName hasPrefix:[appName stringByAppendingString:@" "]];
    BOOL hasProperSuffix = [fileName hasSuffix:@".log"];

    return (hasProperPrefix && hasProperSuffix);
}

// if you change formatter, then change sortedLogFileInfos method also accordingly
- (NSDateFormatter *)logFileDateFormatter {
    return _fileDateFormatter;
}

- (NSArray *)unsortedLogFilePaths {
    NSString *logsDirectory = [self logsDirectory];
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory error:nil];

    NSMutableArray *unsortedLogFilePaths = [NSMutableArray arrayWithCapacity:[fileNames count]];

    for (NSString *fileName in fileNames) {
        // Filter out any files that aren't log files. (Just for extra safety)

#if TARGET_IPHONE_SIMULATOR
        // This is only used on the iPhone simulator for backward compatibility reason.
        //
        // In case of iPhone simulator there can be 'archived' extension. isLogFile:
        // method knows nothing about it. Thus removing it for this method.
        NSString *theFileName = [fileName stringByReplacingOccurrencesOfString:@".archived"
                                                                    withString:@""];

        if ([self isLogFile:theFileName])
#else

        if ([self isLogFile:fileName])
#endif
        {
            NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];

            [unsortedLogFilePaths addObject:filePath];
        }
    }

    return unsortedLogFilePaths;
}

- (NSArray *)unsortedLogFileNames {
    NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];

    NSMutableArray *unsortedLogFileNames = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];

    for (NSString *filePath in unsortedLogFilePaths) {
        [unsortedLogFileNames addObject:[filePath lastPathComponent]];
    }

    return unsortedLogFileNames;
}

- (NSArray *)unsortedLogFileInfos {
    NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];

    NSMutableArray *unsortedLogFileInfos = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];

    for (NSString *filePath in unsortedLogFilePaths) {
        VVLogFileInfo *logFileInfo = [[VVLogFileInfo alloc] initWithFilePath:filePath];

        [unsortedLogFileInfos addObject:logFileInfo];
    }

    return unsortedLogFileInfos;
}

- (NSArray *)sortedLogFilePaths {
    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];

    NSMutableArray *sortedLogFilePaths = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];

    for (VVLogFileInfo *logFileInfo in sortedLogFileInfos) {
        [sortedLogFilePaths addObject:[logFileInfo filePath]];
    }

    return sortedLogFilePaths;
}

- (NSArray *)sortedLogFileNames {
    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];

    NSMutableArray *sortedLogFileNames = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];

    for (VVLogFileInfo *logFileInfo in sortedLogFileInfos) {
        [sortedLogFileNames addObject:[logFileInfo fileName]];
    }

    return sortedLogFileNames;
}

- (NSArray *)sortedLogFileInfos {
    return [[self unsortedLogFileInfos] sortedArrayUsingComparator:^NSComparisonResult(VVLogFileInfo *obj1,
                                                                                       VVLogFileInfo *obj2) {
        NSDate *date1 = [NSDate new];
        NSDate *date2 = [NSDate new];

        NSArray<NSString *> *arrayComponent = [[obj1 fileName] componentsSeparatedByString:@" "];
        if (arrayComponent.count > 0) {
            NSString *stringDate = arrayComponent.lastObject;
            stringDate = [stringDate stringByReplacingOccurrencesOfString:@".log" withString:@""];
#if TARGET_IPHONE_SIMULATOR
            // This is only used on the iPhone simulator for backward compatibility reason.
            stringDate = [stringDate stringByReplacingOccurrencesOfString:@".archived" withString:@""];
#endif
            date1 = [[self logFileDateFormatter] dateFromString:stringDate] ?: [obj1 creationDate];
        }

        arrayComponent = [[obj2 fileName] componentsSeparatedByString:@" "];
        if (arrayComponent.count > 0) {
            NSString *stringDate = arrayComponent.lastObject;
            stringDate = [stringDate stringByReplacingOccurrencesOfString:@".log" withString:@""];
#if TARGET_IPHONE_SIMULATOR
            // This is only used on the iPhone simulator for backward compatibility reason.
            stringDate = [stringDate stringByReplacingOccurrencesOfString:@".archived" withString:@""];
#endif
            date2 = [[self logFileDateFormatter] dateFromString:stringDate] ?: [obj2 creationDate];
        }

        return [date2 compare:date1 ?: [NSDate new]];
    }];

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//if you change newLogFileName , then  change isLogFile method also accordingly
- (NSString *)newLogFileName {
    NSString *appName = [self applicationName];

    NSDateFormatter *dateFormatter = [self logFileDateFormatter];
    NSString *formattedDate = [dateFormatter stringFromDate:[NSDate date]];

    return [NSString stringWithFormat:@"%@ %@.log", appName, formattedDate];
}

- (nullable NSString *)logFileHeader {
    return nil;
}

- (NSData *)logFileHeaderData {
    NSString *fileHeaderStr = [self logFileHeader];

    if (fileHeaderStr.length == 0) {
        return nil;
    }

    if (![fileHeaderStr hasSuffix:@"\n"]) {
        fileHeaderStr = [fileHeaderStr stringByAppendingString:@"\n"];
    }

    return [fileHeaderStr dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)createNewLogFileWithError:(NSError *__autoreleasing  _Nullable *)error {
    static NSUInteger MAX_ALLOWED_ERROR = 5;

    NSString *fileName = [self newLogFileName];
    NSString *logsDirectory = [self logsDirectory];
    NSData *fileHeader = [self logFileHeaderData];
    if (fileHeader == nil) {
        fileHeader = [NSData new];
    }

    NSUInteger attempt = 1;
    NSUInteger criticalErrors = 0;
    NSError *lastCriticalError;

    do {
        if (criticalErrors >= MAX_ALLOWED_ERROR) {
            NSLogError(@"VVLogFileManagerDefault: Bailing file creation, encountered %ld errors.",
                        (unsigned long)criticalErrors);
            *error = lastCriticalError;
            return nil;
        }

        NSString *actualFileName = fileName;
        if (attempt > 1) {
            NSString *extension = [actualFileName pathExtension];

            actualFileName = [actualFileName stringByDeletingPathExtension];
            actualFileName = [actualFileName stringByAppendingFormat:@" %lu", (unsigned long)attempt];

            if (extension.length) {
                actualFileName = [actualFileName stringByAppendingPathExtension:extension];
            }
        }

        NSString *filePath = [logsDirectory stringByAppendingPathComponent:actualFileName];

        NSError *currentError = nil;
        BOOL success = [fileHeader writeToFile:filePath options:NSDataWritingAtomic error:&currentError];

#if TARGET_OS_IPHONE
        if (success) {
            // When creating log file on iOS we're setting NSFileProtectionKey attribute to NSFileProtectionCompleteUnlessOpen.
            //
            // But in case if app is able to launch from background we need to have an ability to open log file any time we
            // want (even if device is locked). Thats why that attribute have to be changed to
            // NSFileProtectionCompleteUntilFirstUserAuthentication.
            NSDictionary *attributes = @{NSFileProtectionKey: [self logFileProtection]};
            success = [[NSFileManager defaultManager] setAttributes:attributes
                                                       ofItemAtPath:filePath
                                                              error:&currentError];
        }
#endif

        if (success) {
            NSLogVerbose(@"VVLogFileManagerDefault: Created new log file: %@", actualFileName);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // Since we just created a new log file, we may need to delete some old log files
                [self deleteOldLogFiles];
            });
            return filePath;
        } else if (currentError.code == NSFileWriteFileExistsError) {
            attempt++;
            continue;
        } else {
            NSLogError(@"VVLogFileManagerDefault: Critical error while creating log file: %@", currentError);
            criticalErrors++;
            lastCriticalError = currentError;
            continue;
        }

        return filePath;
    } while (YES);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)applicationName {
    static NSString *_appName;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];

        if (_appName.length == 0) {
            _appName = [[NSProcessInfo processInfo] processName];
        }

        if (_appName.length == 0) {
            _appName = @"";
        }
    });

    return _appName;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface VVLogFileFormatterDefault () {
    NSDateFormatter *_dateFormatter;
}

@end

@implementation VVLogFileFormatterDefault

- (instancetype)init {
    return [self initWithDateFormatter:nil];
}

- (instancetype)initWithDateFormatter:(nullable NSDateFormatter *)aDateFormatter {
    if ((self = [super init])) {
        if (aDateFormatter) {
            _dateFormatter = aDateFormatter;
        } else {
            _dateFormatter = [[NSDateFormatter alloc] init];
            [_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4]; // 10.4+ style
            [_dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
        }
    }

    return self;
}

- (NSString *)formatLogMessage:(VVLogMessage *)logMessage {
    NSString *dateAndTime = [_dateFormatter stringFromDate:(logMessage->_timestamp)];

    return [NSString stringWithFormat:@"%@  %@", dateAndTime, logMessage->_message];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface VVFileLogger () {
    id <VVLogFileManager> _logFileManager;

    VVLogFileInfo *_currentLogFileInfo;
    NSFileHandle *_currentLogFileHandle;

    dispatch_source_t _currentLogFileVnode;

    NSTimeInterval _rollingFrequency;
    dispatch_source_t _rollingTimer;

    unsigned long long _maximumFileSize;

    dispatch_queue_t _completionQueue;
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation VVFileLogger
#pragma clang diagnostic pop

- (instancetype)init {
    VVLogFileManagerDefault *defaultLogFileManager = [[VVLogFileManagerDefault alloc] init];
    return [self initWithLogFileManager:defaultLogFileManager completionQueue:nil];
}

- (instancetype)initWithLogFileManager:(id<VVLogFileManager>)logFileManager {
    return [self initWithLogFileManager:logFileManager completionQueue:nil];
}

- (instancetype)initWithLogFileManager:(id <VVLogFileManager>)aLogFileManager
                       completionQueue:(nullable dispatch_queue_t)dispatchQueue {
    if ((self = [super init])) {
        _completionQueue = dispatchQueue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        _maximumFileSize = kVVDefaultLogMaxFileSize;
        _rollingFrequency = kVVDefaultLogRollingFrequency;
        _automaticallyAppendNewlineForCustomFormatters = YES;

        _logFileManager = aLogFileManager;
        _logFormatter = [VVLogFileFormatterDefault new];
    }

    return self;
}

- (void)lt_cleanup {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    [_currentLogFileHandle synchronizeFile];
    [_currentLogFileHandle closeFile];

    if (_currentLogFileVnode) {
        dispatch_source_cancel(_currentLogFileVnode);
        _currentLogFileVnode = NULL;
    }

    if (_rollingTimer) {
        dispatch_source_cancel(_rollingTimer);
        _rollingTimer = NULL;
    }
}

- (void)dealloc {
    if (self.isOnInternalLoggerQueue) {
        [self lt_cleanup];
    } else {
        dispatch_sync(self.loggerQueue, ^{
            [self lt_cleanup];
        });
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (unsigned long long)maximumFileSize {
    __block unsigned long long result;

    dispatch_block_t block = ^{
        result = self->_maximumFileSize;
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    // Note: The internal implementation MUST access the maximumFileSize variable directly,
    // This method is designed explicitly for external access.
    //
    // Using "self." syntax to go through this method will cause immediate deadlock.
    // This is the intended result. Fix it by accessing the ivar directly.
    // Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];

    dispatch_sync(globalLoggingQueue, ^{
        dispatch_sync(self.loggerQueue, block);
    });

    return result;
}

- (void)setMaximumFileSize:(unsigned long long)newMaximumFileSize {
    dispatch_block_t block = ^{
        @autoreleasepool {
            self->_maximumFileSize = newMaximumFileSize;
            [self lt_maybeRollLogFileDueToSize];
        }
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    // Note: The internal implementation MUST access the maximumFileSize variable directly,
    // This method is designed explicitly for external access.
    //
    // Using "self." syntax to go through this method will cause immediate deadlock.
    // This is the intended result. Fix it by accessing the ivar directly.
    // Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];

    dispatch_async(globalLoggingQueue, ^{
        dispatch_async(self.loggerQueue, block);
    });
}

- (NSTimeInterval)rollingFrequency {
    __block NSTimeInterval result;

    dispatch_block_t block = ^{
        result = self->_rollingFrequency;
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    // Note: The internal implementation should access the rollingFrequency variable directly,
    // This method is designed explicitly for external access.
    //
    // Using "self." syntax to go through this method will cause immediate deadlock.
    // This is the intended result. Fix it by accessing the ivar directly.
    // Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];

    dispatch_sync(globalLoggingQueue, ^{
        dispatch_sync(self.loggerQueue, block);
    });

    return result;
}

- (void)setRollingFrequency:(NSTimeInterval)newRollingFrequency {
    dispatch_block_t block = ^{
        @autoreleasepool {
            self->_rollingFrequency = newRollingFrequency;
            [self lt_maybeRollLogFileDueToAge];
        }
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    // Note: The internal implementation should access the rollingFrequency variable directly,
    // This method is designed explicitly for external access.
    //
    // Using "self." syntax to go through this method will cause immediate deadlock.
    // This is the intended result. Fix it by accessing the ivar directly.
    // Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];

    dispatch_async(globalLoggingQueue, ^{
        dispatch_async(self.loggerQueue, block);
    });
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Rolling
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)lt_scheduleTimerToRollLogFileDueToAge {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    if (_rollingTimer) {
        dispatch_source_cancel(_rollingTimer);
        _rollingTimer = NULL;
    }

    if (_currentLogFileInfo == nil || _rollingFrequency <= 0.0) {
        return;
    }

    NSDate *logFileCreationDate = [_currentLogFileInfo creationDate];
    NSTimeInterval frequency = MIN(_rollingFrequency, DBL_MAX - [logFileCreationDate timeIntervalSinceReferenceDate]);
    NSDate *logFileRollingDate = [logFileCreationDate dateByAddingTimeInterval:frequency];

    NSLogVerbose(@"VVFileLogger: scheduleTimerToRollLogFileDueToAge");
    NSLogVerbose(@"VVFileLogger: logFileCreationDate    : %@", logFileCreationDate);
    NSLogVerbose(@"VVFileLogger: actual rollingFrequency: %f", frequency);
    NSLogVerbose(@"VVFileLogger: logFileRollingDate     : %@", logFileRollingDate);

    _rollingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _loggerQueue);

    __weak __auto_type weakSelf = self;
    dispatch_source_set_event_handler(_rollingTimer, ^{ @autoreleasepool {
        [weakSelf lt_maybeRollLogFileDueToAge];
    } });

    #if !OS_OBJECT_USE_OBJC
    dispatch_source_t theRollingTimer = _rollingTimer;
    dispatch_source_set_cancel_handler(_rollingTimer, ^{
        dispatch_release(theRollingTimer);
    });
    #endif

    static NSTimeInterval const kVVMaxTimerDelay = LLONG_MAX / NSEC_PER_SEC;
    int64_t delay = (int64_t)(MIN([logFileRollingDate timeIntervalSinceNow], kVVMaxTimerDelay) * (NSTimeInterval) NSEC_PER_SEC);
    dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, delay);

    dispatch_source_set_timer(_rollingTimer, fireTime, DISPATCH_TIME_FOREVER, (uint64_t)kVVRollingLeeway * NSEC_PER_SEC);

    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *))
        dispatch_activate(_rollingTimer);
    else
        dispatch_resume(_rollingTimer);
}

- (void)rollLogFile {
    [self rollLogFileWithCompletionBlock:nil];
}

- (void)rollLogFileWithCompletionBlock:(nullable void (^)(void))completionBlock {
    // This method is public.
    // We need to execute the rolling on our logging thread/queue.

    dispatch_block_t block = ^{
        @autoreleasepool {
            [self lt_rollLogFileNow];

            if (completionBlock) {
                dispatch_async(self->_completionQueue, ^{
                    completionBlock();
                });
            }
        }
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(self.loggerQueue, block);
        });
    }
}

- (void)lt_rollLogFileNow {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");
    NSLogVerbose(@"VVFileLogger: rollLogFileNow");

    if (_currentLogFileHandle == nil) {
        return;
    }

    [_currentLogFileHandle synchronizeFile];
    [_currentLogFileHandle closeFile];
    _currentLogFileHandle = nil;

    _currentLogFileInfo.isArchived = YES;
    BOOL logFileManagerRespondsToSelector = [_logFileManager respondsToSelector:@selector(didRollAndArchiveLogFile:)];
    NSString *archivedFilePath = (logFileManagerRespondsToSelector) ? [_currentLogFileInfo.filePath copy] : nil;
    _currentLogFileInfo = nil;

    if (logFileManagerRespondsToSelector) {
        dispatch_async(_completionQueue, ^{
            [self->_logFileManager didRollAndArchiveLogFile:archivedFilePath];
        });
    }

    if (_currentLogFileVnode) {
        dispatch_source_cancel(_currentLogFileVnode);
        _currentLogFileVnode = nil;
    }

    if (_rollingTimer) {
        dispatch_source_cancel(_rollingTimer);
        _rollingTimer = nil;
    }
}

- (void)lt_maybeRollLogFileDueToAge {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    if (_rollingFrequency > 0.0 && (_currentLogFileInfo.age + kVVRollingLeeway) >= _rollingFrequency) {
        NSLogVerbose(@"VVFileLogger: Rolling log file due to age...");
        [self lt_rollLogFileNow];
    } else {
        [self lt_scheduleTimerToRollLogFileDueToAge];
    }
}

- (void)lt_maybeRollLogFileDueToSize {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    // This method is called from logMessage.
    // Keep it FAST.

    // Note: Use direct access to maximumFileSize variable.
    // We specifically wrote our own getter/setter method to allow us to do this (for performance reasons).

    if (_maximumFileSize > 0) {
        unsigned long long fileSize = [_currentLogFileHandle offsetInFile];

        if (fileSize >= _maximumFileSize) {
            NSLogVerbose(@"VVFileLogger: Rolling log file due to size (%qu)...", fileSize);

            [self lt_rollLogFileNow];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)lt_shouldLogFileBeArchived:(VVLogFileInfo *)mostRecentLogFileInfo {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    if (mostRecentLogFileInfo.isArchived) {
        return NO;
    } else if ([self shouldArchiveRecentLogFileInfo:mostRecentLogFileInfo]) {
        return YES;
    } else if (_maximumFileSize > 0 && mostRecentLogFileInfo.fileSize >= _maximumFileSize) {
        return YES;
    } else if (_rollingFrequency > 0.0 && mostRecentLogFileInfo.age >= _rollingFrequency) {
        return YES;
    }

#if TARGET_OS_IPHONE
    // When creating log file on iOS we're setting NSFileProtectionKey attribute to NSFileProtectionCompleteUnlessOpen.
    //
    // But in case if app is able to launch from background we need to have an ability to open log file any time we
    // want (even if device is locked). Thats why that attribute have to be changed to
    // NSFileProtectionCompleteUntilFirstUserAuthentication.
    //
    // If previous log was created when app wasn't running in background, but now it is - we archive it and create
    // a new one.
    //
    // If user has overwritten to NSFileProtectionNone there is no neeed to create a new one.
    if (vvdoesAppRunInBackground()) {
        NSFileProtectionType key = mostRecentLogFileInfo.fileAttributes[NSFileProtectionKey];
        BOOL isUntilFirstAuth = [key isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication];
        BOOL isNone = [key isEqualToString:NSFileProtectionNone];

        if (key != nil && !isUntilFirstAuth && !isNone) {
            return YES;
        }
    }
#endif

    return NO;
}

/**
 * Returns the log file that should be used.
 * If there is an existing log file that is suitable, within the
 * constraints of maximumFileSize and rollingFrequency, then it is returned.
 *
 * Otherwise a new file is created and returned.
 **/
- (VVLogFileInfo *)currentLogFileInfo {
    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.
    // Do not access this method on any Lumberjack queue, will deadlock.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    __block VVLogFileInfo *info = nil;
    dispatch_block_t block = ^{
        info = [self lt_currentLogFileInfo];
    };

    dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];

    dispatch_sync(globalLoggingQueue, ^{
        dispatch_sync(self->_loggerQueue, block);
    });

    return info;
}

- (VVLogFileInfo *)lt_currentLogFileInfo {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    // Get the current log file info ivar (might be nil).
    VVLogFileInfo *newCurrentLogFile = _currentLogFileInfo;

    // Check if we're resuming and if so, get the first of the sorted log file infos.
    BOOL isResuming = newCurrentLogFile == nil;
    if (isResuming) {
        NSArray *sortedLogFileInfos = [_logFileManager sortedLogFileInfos];
        newCurrentLogFile = sortedLogFileInfos.firstObject;
    }

    // Check if the file we've found is still valid. Otherwise create a new one.
    if (newCurrentLogFile != nil && [self lt_shouldUseLogFile:newCurrentLogFile isResuming:isResuming]) {
        if (isResuming) {
            NSLogVerbose(@"VVFileLogger: Resuming logging with file %@", newCurrentLogFile.fileName);
        }
        _currentLogFileInfo = newCurrentLogFile;
    } else {
        NSString *currentLogFilePath;
        if ([_logFileManager respondsToSelector:@selector(createNewLogFileWithError:)]) {
            __autoreleasing NSError *error;
            currentLogFilePath = [_logFileManager createNewLogFileWithError:&error];
            if (!currentLogFilePath) {
                NSLogError(@"VVFileLogger: Failed to create new log file: %@", error);
            }
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSAssert([_logFileManager respondsToSelector:@selector(createNewLogFile)],
                     @"Invalid log file manager! Responds neither to `-createNewLogFileWithError:` nor `-createNewLogFile`!");
            currentLogFilePath = [_logFileManager createNewLogFile];
            #pragma clang diagnostic pop
        }
        // Use static factory method here, since it checks for nil (and is unavailable to Swift).
        _currentLogFileInfo = [VVLogFileInfo logFileWithPath:currentLogFilePath];
    }

    return _currentLogFileInfo;
}

- (BOOL)lt_shouldUseLogFile:(nonnull VVLogFileInfo *)logFileInfo isResuming:(BOOL)isResuming {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");
    NSParameterAssert(logFileInfo);

    // Check if the log file is archived. We must not use archived log files.
    if (logFileInfo.isArchived) {
        return NO;
    }

    // If we're resuming, we need to check if the log file is allowed for reuse or needs to be archived.
    if (isResuming && (_doNotReuseLogFiles || [self lt_shouldLogFileBeArchived:logFileInfo])) {
        logFileInfo.isArchived = YES;

        if ([_logFileManager respondsToSelector:@selector(didArchiveLogFile:)]) {
            NSString *archivedFilePath = [logFileInfo.filePath copy];
            dispatch_async(_completionQueue, ^{
                [self->_logFileManager didArchiveLogFile:archivedFilePath];
            });
        }

        return NO;
    }

    // All checks have passed. It's valid.
    return YES;
}

- (void)lt_monitorCurrentLogFileForExternalChanges {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");
    NSAssert(_currentLogFileHandle, @"Can not monitor without handle.");

    dispatch_source_vnode_flags_t flags = DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE;
    _currentLogFileVnode = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                        (uintptr_t)[_currentLogFileHandle fileDescriptor],
                                                        flags,
                                                        _loggerQueue);

    __weak __auto_type weakSelf = self;
    dispatch_source_set_event_handler(_currentLogFileVnode, ^{ @autoreleasepool {
        NSLogInfo(@"VVFileLogger: Current logfile was moved. Rolling it and creating a new one");
        [weakSelf lt_rollLogFileNow];
    } });

#if !OS_OBJECT_USE_OBJC
    dispatch_source_t vnode = _currentLogFileVnode;
    dispatch_source_set_cancel_handler(_currentLogFileVnode, ^{
        dispatch_release(vnode);
    });
#endif

    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *))
        dispatch_activate(_currentLogFileVnode);
    else
        dispatch_resume(_currentLogFileVnode);
}

- (NSFileHandle *)lt_currentLogFileHandle {
    NSAssert([self isOnInternalLoggerQueue], @"lt_ methods should be on logger queue.");

    if (!_currentLogFileHandle) {
        NSString *logFilePath = [[self lt_currentLogFileInfo] filePath];
        _currentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        [_currentLogFileHandle seekToEndOfFile];

        if (_currentLogFileHandle) {
            [self lt_scheduleTimerToRollLogFileDueToAge];
            [self lt_monitorCurrentLogFileForExternalChanges];
        }
    }

    return _currentLogFileHandle;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark VVLogger Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static int exception_count = 0;

- (void)logMessage:(VVLogMessage *)logMessage {
    // Don't need to check for isOnInternalLoggerQueue, -lt_dataForMessage: will do it for us.
    NSData *data = [self lt_dataForMessage:logMessage];

    if (data.length == 0) {
        return;
    }

    [self lt_logData:data];
}

- (void)willLogMessage:(VVLogFileInfo *)logFileInfo {

}

- (void)didLogMessage:(VVLogFileInfo *)logFileInfo {
    [self lt_maybeRollLogFileDueToSize];
}

- (BOOL)shouldArchiveRecentLogFileInfo:(__unused VVLogFileInfo *)recentLogFileInfo {
    return NO;
}

- (void)willRemoveLogger {
    [self lt_rollLogFileNow];
}

- (void)flush {
    // This method is public.
    // We need to execute the rolling on our logging thread/queue.

    dispatch_block_t block = ^{
        @autoreleasepool {
            [self lt_flush];
        }
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_sync(globalLoggingQueue, ^{
            dispatch_sync(self.loggerQueue, block);
        });
    }
}

- (void)lt_flush {
    NSAssert([self isOnInternalLoggerQueue], @"flush should only be executed on internal queue.");
    [_currentLogFileHandle synchronizeFile];
}

- (VVLoggerName)loggerName {
    return VVLoggerNameFile;
}

@end

@implementation VVFileLogger (Internal)

- (void)logData:(NSData *)data {
    // This method is public.
    // We need to execute the rolling on our logging thread/queue.

    dispatch_block_t block = ^{
        @autoreleasepool {
            [self lt_logData:data];
        }
    };

    // The design of this method is taken from the VVAbstractLogger implementation.
    // For extensive documentation please refer to the VVAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [VVLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_sync(globalLoggingQueue, ^{
            dispatch_sync(self.loggerQueue, block);
        });
    }
}

- (void)dummyMethod {}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if (aSelector == @selector(willLogMessage) || aSelector == @selector(didLogMessage)) {
        // Ignore calls to deprecated methods.
        return [self methodSignatureForSelector:@selector(dummyMethod)];
    }

    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if (anInvocation.selector != @selector(dummyMethod)) {
        [super forwardInvocation:anInvocation];
    }
}

- (void)lt_logData:(NSData *)data {
    static BOOL implementsDeprecatedWillLog = NO;
    static BOOL implementsDeprecatedDidLog = NO;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        implementsDeprecatedWillLog = [self respondsToSelector:@selector(willLogMessage)];
        implementsDeprecatedDidLog = [self respondsToSelector:@selector(didLogMessage)];
    });

    NSAssert([self isOnInternalLoggerQueue], @"logMessage should only be executed on internal queue.");

    if (data.length == 0) {
        return;
    }

    @try {
        if (implementsDeprecatedWillLog) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [self willLogMessage];
#pragma clang diagnostic pop
        } else {
            [self willLogMessage:_currentLogFileInfo];
        }

        NSFileHandle *handle = [self lt_currentLogFileHandle];
        [handle seekToEndOfFile];
        [handle writeData:data];

        if (implementsDeprecatedDidLog) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [self didLogMessage];
#pragma clang diagnostic pop
        } else {
            [self didLogMessage:_currentLogFileInfo];
        }

    } @catch (NSException *exception) {
        exception_count++;

        if (exception_count <= 10) {
            NSLogError(@"VVFileLogger.logMessage: %@", exception);

            if (exception_count == 10) {
                NSLogError(@"VVFileLogger.logMessage: Too many exceptions -- will not log any more of them.");
            }
        }
    }
}

- (NSData *)lt_dataForMessage:(VVLogMessage *)logMessage {
    NSAssert([self isOnInternalLoggerQueue], @"logMessage should only be executed on internal queue.");

    NSString *message = logMessage->_message;
    BOOL isFormatted = NO;

    if (_logFormatter != nil) {
        message = [_logFormatter formatLogMessage:logMessage];
        isFormatted = message != logMessage->_message;
    }

    if (message.length == 0) {
        return nil;
    }

    BOOL shouldFormat = !isFormatted || _automaticallyAppendNewlineForCustomFormatters;
    if (shouldFormat && ![message hasSuffix:@"\n"]) {
        message = [message stringByAppendingString:@"\n"];
    }

    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static NSString * const kVVXAttrArchivedName = @"vvlog.log.archived";

@interface VVLogFileInfo () {
    __strong NSString *_filePath;
    __strong NSString *_fileName;

    __strong NSDictionary *_fileAttributes;

    __strong NSDate *_creationDate;
    __strong NSDate *_modificationDate;

    unsigned long long _fileSize;
}

#if TARGET_IPHONE_SIMULATOR

// Old implementation of extended attributes on the simulator.

- (BOOL)_hasExtensionAttributeWithName:(NSString *)attrName;
- (void)_removeExtensionAttributeWithName:(NSString *)attrName;

#endif

@end


@implementation VVLogFileInfo

@synthesize filePath;

@dynamic fileName;
@dynamic fileAttributes;
@dynamic creationDate;
@dynamic modificationDate;
@dynamic fileSize;
@dynamic age;

@dynamic isArchived;

#pragma mark Lifecycle

+ (instancetype)logFileWithPath:(NSString *)aFilePath {
    if (!aFilePath) return nil;
    return [[self alloc] initWithFilePath:aFilePath];
}

- (instancetype)initWithFilePath:(NSString *)aFilePath {
    NSParameterAssert(aFilePath);
    if ((self = [super init])) {
        filePath = [aFilePath copy];
    }

    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)fileAttributes {
    if (_fileAttributes == nil && filePath != nil) {
        NSError *error = nil;
        _fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];

        if (error) {
            NSLogError(@"VVLogFileInfo: Failed to read file attributes: %@", error);
        }
    }

    return _fileAttributes ?: @{};
}

- (NSString *)fileName {
    if (_fileName == nil) {
        _fileName = [filePath lastPathComponent];
    }

    return _fileName;
}

- (NSDate *)modificationDate {
    if (_modificationDate == nil) {
        _modificationDate = self.fileAttributes[NSFileModificationDate];
    }

    return _modificationDate;
}

- (NSDate *)creationDate {
    if (_creationDate == nil) {
        _creationDate = self.fileAttributes[NSFileCreationDate];
    }

    return _creationDate;
}

- (unsigned long long)fileSize {
    if (_fileSize == 0) {
        _fileSize = [self.fileAttributes[NSFileSize] unsignedLongLongValue];
    }

    return _fileSize;
}

- (NSTimeInterval)age {
    return -[[self creationDate] timeIntervalSinceNow];
}

- (NSString *)description {
    return [@{ @"filePath": self.filePath ? : @"",
               @"fileName": self.fileName ? : @"",
               @"fileAttributes": self.fileAttributes ? : @"",
               @"creationDate": self.creationDate ? : @"",
               @"modificationDate": self.modificationDate ? : @"",
               @"fileSize": @(self.fileSize),
               @"age": @(self.age),
               @"isArchived": @(self.isArchived) } description];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Archiving
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isArchived {
    return [self hasExtendedAttributeWithName:kVVXAttrArchivedName];
}

- (void)setIsArchived:(BOOL)flag {
    if (flag) {
        [self addExtendedAttributeWithName:kVVXAttrArchivedName];
    } else {
        [self removeExtendedAttributeWithName:kVVXAttrArchivedName];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Changes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)reset {
    _fileName = nil;
    _fileAttributes = nil;
    _creationDate = nil;
    _modificationDate = nil;
}

- (void)renameFile:(NSString *)newFileName {
    // This method is only used on the iPhone simulator, where normal extended attributes are broken.
    // See full explanation in the header file.

    if (![newFileName isEqualToString:[self fileName]]) {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSString *fileDir = [filePath stringByDeletingLastPathComponent];
        NSString *newFilePath = [fileDir stringByAppendingPathComponent:newFileName];

        // We only want to assert when we're not using the simulator, as we're "archiving" a log file with this method in the sim
        // (in which case the file might not exist anymore and neither does it parent folder).
#if defined(DEBUG) && (!defined(TARGET_IPHONE_SIMULATOR) || !TARGET_IPHONE_SIMULATOR)
        BOOL directory = NO;
        [fileManager fileExistsAtPath:fileDir isDirectory:&directory];
        NSAssert(directory, @"Containing directory must exist.");
#endif

        NSError *error = nil;

        BOOL success = [fileManager removeItemAtPath:newFilePath error:&error];
        if (!success && error.code != NSFileNoSuchFileError) {
            NSLogError(@"VVLogFileInfo: Error deleting archive (%@): %@", self.fileName, error);
        }

        success = [fileManager moveItemAtPath:filePath toPath:newFilePath error:&error];

        // When a log file is deleted, moved or renamed on the simulator, we attempt to rename it as a
        // result of "archiving" it, but since the file doesn't exist anymore, needless error logs are printed
        // We therefore ignore this error, and assert that the directory we are copying into exists (which
        // is the only other case where this error code can come up).
#if TARGET_IPHONE_SIMULATOR
        if (!success && error.code != NSFileNoSuchFileError)
#else
        if (!success)
#endif
        {
            NSLogError(@"VVLogFileInfo: Error renaming file (%@): %@", self.fileName, error);
        }

        filePath = newFilePath;
        [self reset];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Attribute Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_IPHONE_SIMULATOR

// Old implementation of extended attributes on the simulator.

// Extended attributes were not working properly on the simulator
// due to misuse of setxattr() function.
// Now that this is fixed in the new implementation, we want to keep
// backward compatibility with previous simulator installations.

static NSString * const kVVExtensionSeparator = @".";

static NSString *_xattrToExtensionName(NSString *attrName) {
    static NSDictionary<NSString *, NSString *>* _xattrToExtensionNameMap;
    static dispatch_once_t _token;
    dispatch_once(&_token, ^{
        _xattrToExtensionNameMap = @{ kVVXAttrArchivedName: @"archived" };
    });
    return [_xattrToExtensionNameMap objectForKey:attrName];
}

- (BOOL)_hasExtensionAttributeWithName:(NSString *)attrName {
    // This method is only used on the iPhone simulator for backward compatibility reason.

    // Split the file name into components. File name may have various format, but generally
    // structure is same:
    //
    // <name part>.<extension part> and <name part>.archived.<extension part>
    // or
    // <name part> and <name part>.archived
    //
    // So we want to search for the attrName in the components (ignoring the first array index).

    NSArray *components = [[self fileName] componentsSeparatedByString:kVVExtensionSeparator];

    // Watch out for file names without an extension

    for (NSUInteger i = 1; i < components.count; i++) {
        NSString *attr = components[i];

        if ([attrName isEqualToString:attr]) {
            return YES;
        }
    }

    return NO;
}

- (void)_removeExtensionAttributeWithName:(NSString *)attrName {
    // This method is only used on the iPhone simulator for backward compatibility reason.

    if ([attrName length] == 0) {
        return;
    }

    // Example:
    // attrName = "archived"
    //
    // "mylog.archived.txt" -> "mylog.txt"
    // "mylog.archived"     -> "mylog"

    NSArray *components = [[self fileName] componentsSeparatedByString:kVVExtensionSeparator];

    NSUInteger count = [components count];

    NSUInteger estimatedNewLength = [[self fileName] length];
    NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];

    if (count > 0) {
        [newFileName appendString:components.firstObject];
    }

    BOOL found = NO;

    NSUInteger i;

    for (i = 1; i < count; i++) {
        NSString *attr = components[i];

        if ([attrName isEqualToString:attr]) {
            found = YES;
        } else {
            [newFileName appendString:kVVExtensionSeparator];
            [newFileName appendString:attr];
        }
    }

    if (found) {
        [self renameFile:newFileName];
    }
}

#endif /* if TARGET_IPHONE_SIMULATOR */

- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName {
    const char *path = [filePath fileSystemRepresentation];
    const char *name = [attrName UTF8String];
    BOOL hasExtendedAttribute = NO;
    char buffer[1];

    ssize_t result = getxattr(path, name, buffer, 1, 0, 0);

    // Fast path
    if (result > 0 && buffer[0] == '\1') {
        hasExtendedAttribute = YES;
    }
    // Maintain backward compatibility, but fix it for future checks
    else if (result >= 0) {
        hasExtendedAttribute = YES;

        [self addExtendedAttributeWithName:attrName];
    }
#if TARGET_IPHONE_SIMULATOR
    else if ([self _hasExtensionAttributeWithName:_xattrToExtensionName(attrName)]) {
        hasExtendedAttribute = YES;

        [self addExtendedAttributeWithName:attrName];
    }
#endif

    return hasExtendedAttribute;
}

- (void)addExtendedAttributeWithName:(NSString *)attrName {
    const char *path = [filePath fileSystemRepresentation];
    const char *name = [attrName UTF8String];

    int result = setxattr(path, name, "\1", 1, 0, 0);

    if (result < 0) {
        NSLogError(@"VVLogFileInfo: setxattr(%@, %@): error = %s",
                   attrName,
                   filePath,
                   strerror(errno));
    }
#if TARGET_IPHONE_SIMULATOR
    else {
        [self _removeExtensionAttributeWithName:_xattrToExtensionName(attrName)];
    }
#endif
}

- (void)removeExtendedAttributeWithName:(NSString *)attrName {
    const char *path = [filePath fileSystemRepresentation];
    const char *name = [attrName UTF8String];

    int result = removexattr(path, name, 0);

    if (result < 0 && errno != ENOATTR) {
        NSLogError(@"VVLogFileInfo: removexattr(%@, %@): error = %s",
                   attrName,
                   self.fileName,
                   strerror(errno));
    }

#if TARGET_IPHONE_SIMULATOR
    [self _removeExtensionAttributeWithName:_xattrToExtensionName(attrName)];
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[self class]]) {
        VVLogFileInfo *another = (VVLogFileInfo *)object;

        return [filePath isEqualToString:[another filePath]];
    }

    return NO;
}

- (NSUInteger)hash {
    return [filePath hash];
}

- (NSComparisonResult)reverseCompareByCreationDate:(VVLogFileInfo *)another {
    __auto_type us = [self creationDate];
    __auto_type them = [another creationDate];
    return [them compare:us];
}

- (NSComparisonResult)reverseCompareByModificationDate:(VVLogFileInfo *)another {
    __auto_type us = [self modificationDate];
    __auto_type them = [another modificationDate];
    return [them compare:us];
}

@end

#if TARGET_OS_IPHONE
/**
 * When creating log file on iOS we're setting NSFileProtectionKey attribute to NSFileProtectionCompleteUnlessOpen.
 *
 * But in case if app is able to launch from background we need to have an ability to open log file any time we
 * want (even if device is locked). Thats why that attribute have to be changed to
 * NSFileProtectionCompleteUntilFirstUserAuthentication.
 */
BOOL vvdoesAppRunInBackground() {
    BOOL answer = NO;

    NSArray *backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];

    for (NSString *mode in backgroundModes) {
        if (mode.length > 0) {
            answer = YES;
            break;
        }
    }

    return answer;
}

#endif
