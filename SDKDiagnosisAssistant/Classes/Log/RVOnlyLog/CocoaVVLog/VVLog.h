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

#import <Foundation/Foundation.h>

// The Swift Package integration has no support for the legacy macros.
#if __has_include("VVLegacyMacros.h")
    // Enable 1.9.x legacy macros if imported directly and it's not a swift package build.
    #ifndef VV_LEGACY_MACROS
        #define VV_LEGACY_MACROS 1
    #endif
    // VV_LEGACY_MACROS is checked in the file itself
    #import "VVLegacyMacros.h"
#endif

// Names of loggers.
#import "VVLoggerNames.h"

#if OS_OBJECT_USE_OBJC
    #define DISPATCH_QUEUE_REFERENCE_TYPE strong
#else
    #define DISPATCH_QUEUE_REFERENCE_TYPE assign
#endif

@class VVLogMessage;
@class VVLoggerInformation;
@protocol VVLogger;
@protocol VVLogFormatter;

NS_ASSUME_NONNULL_BEGIN

/**
 * Define the standard options.
 *
 * We default to only 4 levels because it makes it easier for beginners
 * to make the transition to a logging framework.
 *
 * More advanced users may choose to completely customize the levels (and level names) to suite their needs.
 * For more information on this see the "Custom Log Levels" page:
 * Documentation/CustomLogLevels.md
 *
 * Advanced users may also notice that we're using a bitmask.
 * This is to allow for custom fine grained logging:
 * Documentation/FineGrainedLogging.md
 *
 * -- Flags --
 *
 * Typically you will use the LOG_LEVELS (see below), but the flags may be used directly in certain situations.
 * For example, say you have a lot of warning log messages, and you wanted to disable them.
 * However, you still needed to see your error and info log messages.
 * You could accomplish that with the following:
 *
 * static const VVLogLevel vvLogLevel = VVLogFlagError | VVLogFlagInfo;
 *
 * When LOG_LEVEL_DEF is defined as vvLogLevel.
 *
 * Flags may also be consulted when writing custom log formatters,
 * as the VVLogMessage class captures the individual flag that caused the log message to fire.
 *
 * -- Levels --
 *
 * Log levels are simply the proper bitmask of the flags.
 *
 * -- Booleans --
 *
 * The booleans may be used when your logging code involves more than one line.
 * For example:
 *
 * if (LOG_VERBOSE) {
 *     for (id sprocket in sprockets)
 *         VVLogVerbose(@"sprocket: %@", [sprocket description])
 * }
 *
 * -- Async --
 *
 * Defines the default asynchronous options.
 * The default philosophy for asynchronous logging is very simple:
 *
 * Log messages with errors should be executed synchronously.
 *     After all, an error just occurred. The application could be unstable.
 *
 * All other log messages, such as debug output, are executed asynchronously.
 *     After all, if it wasn't an error, then it was just informational output,
 *     or something the application was easily able to recover from.
 *
 * -- Changes --
 *
 * You are strongly discouraged from modifying this file.
 * If you do, you make it more difficult on yourself to merge future bug fixes and improvements from the project.
 * Instead, create your own MyLogging.h or ApplicationNameLogging.h or CompanyLogging.h
 *
 * For an example of customizing your logging experience, see the "Custom Log Levels" page:
 * Documentation/CustomLogLevels.md
 **/

/**
 *  Flags accompany each log. They are used together with levels to filter out logs.
 */
typedef NS_OPTIONS(NSUInteger, VVLogFlag){
    /**
     *  0...00001 VVLogFlagError
     */
    VVLogFlagError      = (1 << 0),

    /**
     *  0...00010 VVLogFlagWarning
     */
    VVLogFlagWarning    = (1 << 1),

    /**
     *  0...00100 VVLogFlagInfo
     */
    VVLogFlagInfo       = (1 << 2),

    /**
     *  0...01000 VVLogFlagDebug
     */
    VVLogFlagDebug      = (1 << 3),

    /**
     *  0...10000 VVLogFlagVerbose
     */
    VVLogFlagVerbose    = (1 << 4)
};

/**
 *  Log levels are used to filter out logs. Used together with flags.
 */
typedef NS_ENUM(NSUInteger, VVLogLevel){
    /**
     *  No logs
     */
    VVLogLevelOff       = 0,

    /**
     *  Error logs only
     */
    VVLogLevelError     = (VVLogFlagError),

    /**
     *  Error and warning logs
     */
    VVLogLevelWarning   = (VVLogLevelError   | VVLogFlagWarning),

    /**
     *  Error, warning and info logs
     */
    VVLogLevelInfo      = (VVLogLevelWarning | VVLogFlagInfo),

    /**
     *  Error, warning, info and debug logs
     */
    VVLogLevelDebug     = (VVLogLevelInfo    | VVLogFlagDebug),

    /**
     *  Error, warning, info, debug and verbose logs
     */
    VVLogLevelVerbose   = (VVLogLevelDebug   | VVLogFlagVerbose),

    /**
     *  All logs (1...11111)
     */
    VVLogLevelAll       = NSUIntegerMax
};

/**
 *  Extracts just the file name, no path or extension
 *
 *  @param filePath input file path
 *  @param copy     YES if we want the result to be copied
 *
 *  @return the file name
 */
FOUNDATION_EXTERN NSString * __nullable VVExtractFileNameWithoutExtension(const char *filePath, BOOL copy);

/**
 * The THIS_FILE macro gives you an NSString of the file name.
 * For simplicity and clarity, the file name does not include the full path or file extension.
 *
 * For example: VVLogWarn(@"%@: Unable to find thingy", THIS_FILE) -> @"MyViewController: Unable to find thingy"
 **/
#define THIS_FILE         (VVExtractFileNameWithoutExtension(__FILE__, NO))

/**
 * The THIS_METHOD macro gives you the name of the current objective-c method.
 *
 * For example: VVLogWarn(@"%@ - Requires non-nil strings", THIS_METHOD) -> @"setMake:model: requires non-nil strings"
 *
 * Note: This does NOT work in straight C functions (non objective-c).
 * Instead you should use the predefined __FUNCTION__ macro.
 **/
#define THIS_METHOD       NSStringFromSelector(_cmd)


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  The main class, exposes all logging mechanisms, loggers, ...
 *  For most of the users, this class is hidden behind the logging functions like `VVLogInfo`
 */
@interface VVLog : NSObject

/**
 *  Returns the singleton `VVLog`.
 *  The instance is used by `VVLog` class methods.
 */
@property (class, nonatomic, strong, readonly) VVLog *sharedInstance;

/**
 * Provides access to the underlying logging queue.
 * This may be helpful to Logger classes for things like thread synchronization.
 **/
@property (class, nonatomic, DISPATCH_QUEUE_REFERENCE_TYPE, readonly) dispatch_queue_t loggingQueue;

/**
 * Logging Primitive.
 *
 * This method is used by the macros or logging functions.
 * It is suggested you stick with the macros as they're easier to use.
 *
 *  @param asynchronous YES if the logging is done async, NO if you want to force sync
 *  @param level        the log level
 *  @param flag         the log flag
 *  @param context      the context (if any is defined)
 *  @param file         the current file
 *  @param function     the current function
 *  @param line         the current code line
 *  @param tag          potential tag
 *  @param format       the log format
 */
+ (void)log:(BOOL)asynchronous
      level:(VVLogLevel)level
       flag:(VVLogFlag)flag
    context:(NSInteger)context
       file:(const char *)file
   function:(nullable const char *)function
       line:(NSUInteger)line
        tag:(nullable id)tag
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(9,10);

/**
 * Logging Primitive.
 *
 * This method is used by the macros or logging functions.
 * It is suggested you stick with the macros as they're easier to use.
 *
 *  @param asynchronous YES if the logging is done async, NO if you want to force sync
 *  @param level        the log level
 *  @param flag         the log flag
 *  @param context      the context (if any is defined)
 *  @param file         the current file
 *  @param function     the current function
 *  @param line         the current code line
 *  @param tag          potential tag
 *  @param format       the log format
 */
- (void)log:(BOOL)asynchronous
      level:(VVLogLevel)level
       flag:(VVLogFlag)flag
    context:(NSInteger)context
       file:(const char *)file
   function:(nullable const char *)function
       line:(NSUInteger)line
        tag:(nullable id)tag
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(9,10);

/**
 * Logging Primitive.
 *
 * This method can be used if you have a prepared va_list.
 * Similar to `log:level:flag:context:file:function:line:tag:format:...`
 *
 *  @param asynchronous YES if the logging is done async, NO if you want to force sync
 *  @param level        the log level
 *  @param flag         the log flag
 *  @param context      the context (if any is defined)
 *  @param file         the current file
 *  @param function     the current function
 *  @param line         the current code line
 *  @param tag          potential tag
 *  @param format       the log format
 *  @param argList      the arguments list as a va_list
 */
+ (void)log:(BOOL)asynchronous
      level:(VVLogLevel)level
       flag:(VVLogFlag)flag
    context:(NSInteger)context
       file:(const char *)file
   function:(nullable const char *)function
       line:(NSUInteger)line
        tag:(nullable id)tag
     format:(NSString *)format
       args:(va_list)argList NS_SWIFT_NAME(log(asynchronous:level:flag:context:file:function:line:tag:format:arguments:));

/**
 * Logging Primitive.
 *
 * This method can be used if you have a prepared va_list.
 * Similar to `log:level:flag:context:file:function:line:tag:format:...`
 *
 *  @param asynchronous YES if the logging is done async, NO if you want to force sync
 *  @param level        the log level
 *  @param flag         the log flag
 *  @param context      the context (if any is defined)
 *  @param file         the current file
 *  @param function     the current function
 *  @param line         the current code line
 *  @param tag          potential tag
 *  @param format       the log format
 *  @param argList      the arguments list as a va_list
 */
- (void)log:(BOOL)asynchronous
      level:(VVLogLevel)level
       flag:(VVLogFlag)flag
    context:(NSInteger)context
       file:(const char *)file
   function:(nullable const char *)function
       line:(NSUInteger)line
        tag:(nullable id)tag
     format:(NSString *)format
       args:(va_list)argList NS_SWIFT_NAME(log(asynchronous:level:flag:context:file:function:line:tag:format:arguments:));

/**
 * Logging Primitive.
 *
 * This method can be used if you manually prepared VVLogMessage.
 *
 *  @param asynchronous YES if the logging is done async, NO if you want to force sync
 *  @param logMessage   the log message stored in a `VVLogMessage` model object
 */
+ (void)log:(BOOL)asynchronous
    message:(VVLogMessage *)logMessage NS_SWIFT_NAME(log(asynchronous:message:));

/**
 * Logging Primitive.
 *
 * This method can be used if you manually prepared VVLogMessage.
 *
 *  @param asynchronous YES if the logging is done async, NO if you want to force sync
 *  @param logMessage   the log message stored in a `VVLogMessage` model object
 */
- (void)log:(BOOL)asynchronous
    message:(VVLogMessage *)logMessage NS_SWIFT_NAME(log(asynchronous:message:));

/**
 * Since logging can be asynchronous, there may be times when you want to flush the logs.
 * The framework invokes this automatically when the application quits.
 **/
+ (void)flushLog;

/**
 * Since logging can be asynchronous, there may be times when you want to flush the logs.
 * The framework invokes this automatically when the application quits.
 **/
- (void)flushLog;

/**
 * Loggers
 *
 * In order for your log statements to go somewhere, you should create and add a logger.
 *
 * You can add multiple loggers in order to direct your log statements to multiple places.
 * And each logger can be configured separately.
 * So you could have, for example, verbose logging to the console, but a concise log file with only warnings & errors.
 **/

/**
 * Adds the logger to the system.
 *
 * This is equivalent to invoking `[VVLog addLogger:logger withLogLevel:VVLogLevelAll]`.
 **/
+ (void)addLogger:(id <VVLogger>)logger;

/**
 * Adds the logger to the system.
 *
 * This is equivalent to invoking `[VVLog addLogger:logger withLogLevel:VVLogLevelAll]`.
 **/
- (void)addLogger:(id <VVLogger>)logger;

/**
 * Adds the logger to the system.
 *
 * The level that you provide here is a preemptive filter (for performance).
 * That is, the level specified here will be used to filter out logMessages so that
 * the logger is never even invoked for the messages.
 *
 * More information:
 * When you issue a log statement, the logging framework iterates over each logger,
 * and checks to see if it should forward the logMessage to the logger.
 * This check is done using the level parameter passed to this method.
 *
 * For example:
 *
 * `[VVLog addLogger:consoleLogger withLogLevel:VVLogLevelVerbose];`
 * `[VVLog addLogger:fileLogger    withLogLevel:VVLogLevelWarning];`
 *
 * `VVLogError(@"oh no");` => gets forwarded to consoleLogger & fileLogger
 * `VVLogInfo(@"hi");`     => gets forwarded to consoleLogger only
 *
 * It is important to remember that Lumberjack uses a BITMASK.
 * Many developers & third party frameworks may define extra log levels & flags.
 * For example:
 *
 * `#define SOME_FRAMEWORK_LOG_FLAG_TRACE (1 << 6) // 0...1000000`
 *
 * So if you specify `VVLogLevelVerbose` to this method, you won't see the framework's trace messages.
 *
 * `(SOME_FRAMEWORK_LOG_FLAG_TRACE & VVLogLevelVerbose) => (01000000 & 00011111) => NO`
 *
 * Consider passing `VVLogLevelAll` to this method, which has all bits set.
 * You can also use the exclusive-or bitwise operator to get a bitmask that has all flags set,
 * except the ones you explicitly don't want. For example, if you wanted everything except verbose & debug:
 *
 * `((VVLogLevelAll ^ VVLogLevelVerbose) | VVLogLevelInfo)`
 **/
+ (void)addLogger:(id <VVLogger>)logger withLevel:(VVLogLevel)level;

/**
 * Adds the logger to the system.
 *
 * The level that you provide here is a preemptive filter (for performance).
 * That is, the level specified here will be used to filter out logMessages so that
 * the logger is never even invoked for the messages.
 *
 * More information:
 * When you issue a log statement, the logging framework iterates over each logger,
 * and checks to see if it should forward the logMessage to the logger.
 * This check is done using the level parameter passed to this method.
 *
 * For example:
 *
 * `[VVLog addLogger:consoleLogger withLogLevel:VVLogLevelVerbose];`
 * `[VVLog addLogger:fileLogger    withLogLevel:VVLogLevelWarning];`
 *
 * `VVLogError(@"oh no");` => gets forwarded to consoleLogger & fileLogger
 * `VVLogInfo(@"hi");`     => gets forwarded to consoleLogger only
 *
 * It is important to remember that Lumberjack uses a BITMASK.
 * Many developers & third party frameworks may define extra log levels & flags.
 * For example:
 *
 * `#define SOME_FRAMEWORK_LOG_FLAG_TRACE (1 << 6) // 0...1000000`
 *
 * So if you specify `VVLogLevelVerbose` to this method, you won't see the framework's trace messages.
 *
 * `(SOME_FRAMEWORK_LOG_FLAG_TRACE & VVLogLevelVerbose) => (01000000 & 00011111) => NO`
 *
 * Consider passing `VVLogLevelAll` to this method, which has all bits set.
 * You can also use the exclusive-or bitwise operator to get a bitmask that has all flags set,
 * except the ones you explicitly don't want. For example, if you wanted everything except verbose & debug:
 *
 * `((VVLogLevelAll ^ VVLogLevelVerbose) | VVLogLevelInfo)`
 **/
- (void)addLogger:(id <VVLogger>)logger withLevel:(VVLogLevel)level;

/**
 *  Remove the logger from the system
 */
+ (void)removeLogger:(id <VVLogger>)logger;

/**
 *  Remove the logger from the system
 */
- (void)removeLogger:(id <VVLogger>)logger;

/**
 *  Remove all the current loggers
 */
+ (void)removeAllLoggers;

/**
 *  Remove all the current loggers
 */
- (void)removeAllLoggers;

/**
 *  Return all the current loggers
 */
@property (class, nonatomic, copy, readonly) NSArray<id<VVLogger>> *allLoggers;

/**
 *  Return all the current loggers
 */
@property (nonatomic, copy, readonly) NSArray<id<VVLogger>> *allLoggers;

/**
 *  Return all the current loggers with their level (aka VVLoggerInformation).
 */
@property (class, nonatomic, copy, readonly) NSArray<VVLoggerInformation *> *allLoggersWithLevel;

/**
 *  Return all the current loggers with their level (aka VVLoggerInformation).
 */
@property (nonatomic, copy, readonly) NSArray<VVLoggerInformation *> *allLoggersWithLevel;

/**
 * Registered Dynamic Logging
 *
 * These methods allow you to obtain a list of classes that are using registered dynamic logging,
 * and also provides methods to get and set their log level during run time.
 **/

/**
 *  Returns an array with the classes that are using registered dynamic logging
 */
@property (class, nonatomic, copy, readonly) NSArray<Class> *registeredClasses;

/**
 *  Returns an array with the classes names that are using registered dynamic logging
 */
@property (class, nonatomic, copy, readonly) NSArray<NSString*> *registeredClassNames;

/**
 *  Returns the current log level for a certain class
 *
 *  @param aClass `Class` param
 */
+ (VVLogLevel)levelForClass:(Class)aClass;

/**
 *  Returns the current log level for a certain class
 *
 *  @param aClassName string param
 */
+ (VVLogLevel)levelForClassWithName:(NSString *)aClassName;

/**
 *  Set the log level for a certain class
 *
 *  @param level  the new level
 *  @param aClass `Class` param
 */
+ (void)setLevel:(VVLogLevel)level forClass:(Class)aClass;

/**
 *  Set the log level for a certain class
 *
 *  @param level      the new level
 *  @param aClassName string param
 */
+ (void)setLevel:(VVLogLevel)level forClassWithName:(NSString *)aClassName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  This protocol describes a basic logger behavior. 
 *  Basically, it can log messages, store a logFormatter plus a bunch of optional behaviors.
 *  (i.e. flush, get its loggerQueue, get its name, ...
 */
@protocol VVLogger <NSObject>

/**
 *  The log message method
 *
 *  @param logMessage the message (model)
 */
- (void)logMessage:(VVLogMessage *)logMessage NS_SWIFT_NAME(log(message:));

/**
 * Formatters may optionally be added to any logger.
 *
 * If no formatter is set, the logger simply logs the message as it is given in logMessage,
 * or it may use its own built in formatting style.
 **/
@property (nonatomic, strong, nullable) id <VVLogFormatter> logFormatter;

@optional

/**
 * Since logging is asynchronous, adding and removing loggers is also asynchronous.
 * In other words, the loggers are added and removed at appropriate times with regards to log messages.
 *
 * - Loggers will not receive log messages that were executed prior to when they were added.
 * - Loggers will not receive log messages that were executed after they were removed.
 *
 * These methods are executed in the logging thread/queue.
 * This is the same thread/queue that will execute every logMessage: invocation.
 * Loggers may use these methods for thread synchronization or other setup/teardown tasks.
 **/
- (void)didAddLogger;

/**
 * Since logging is asynchronous, adding and removing loggers is also asynchronous.
 * In other words, the loggers are added and removed at appropriate times with regards to log messages.
 *
 * - Loggers will not receive log messages that were executed prior to when they were added.
 * - Loggers will not receive log messages that were executed after they were removed.
 *
 * These methods are executed in the logging thread/queue given in parameter.
 * This is the same thread/queue that will execute every logMessage: invocation.
 * Loggers may use the queue parameter to set specific values on the queue with dispatch_set_specific() function.
 **/
- (void)didAddLoggerInQueue:(dispatch_queue_t)queue;

/**
 *  See the above description for `didAddLogger`
 */
- (void)willRemoveLogger;

/**
 * Some loggers may buffer IO for optimization purposes.
 * For example, a database logger may only save occasionally as the disk IO is slow.
 * In such loggers, this method should be implemented to flush any pending IO.
 *
 * This allows invocations of VVLog's flushLog method to be propogated to loggers that need it.
 *
 * Note that VVLog's flushLog method is invoked automatically when the application quits,
 * and it may be also invoked manually by the developer prior to application crashes, or other such reasons.
 **/
- (void)flush;

/**
 * Each logger is executed concurrently with respect to the other loggers.
 * Thus, a dedicated dispatch queue is used for each logger.
 * Logger implementations may optionally choose to provide their own dispatch queue.
 **/
@property (nonatomic, DISPATCH_QUEUE_REFERENCE_TYPE, readonly) dispatch_queue_t loggerQueue;

/**
 * If the logger implementation does not choose to provide its own queue,
 * one will automatically be created for it.
 * The created queue will receive its name from this method.
 * This may be helpful for debugging or profiling reasons.
 **/
@property (copy, nonatomic, readonly) VVLoggerName loggerName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  This protocol describes the behavior of a log formatter
 */
@protocol VVLogFormatter <NSObject>
@required

/**
 * Formatters may optionally be added to any logger.
 * This allows for increased flexibility in the logging environment.
 * For example, log messages for log files may be formatted differently than log messages for the console.
 *
 * For more information about formatters, see the "Custom Formatters" page:
 * Documentation/CustomFormatters.md
 *
 * The formatter may also optionally filter the log message by returning nil,
 * in which case the logger will not log the message.
 **/
- (nullable NSString *)formatLogMessage:(VVLogMessage *)logMessage NS_SWIFT_NAME(format(message:));

@optional

/**
 * A single formatter instance can be added to multiple loggers.
 * These methods provides hooks to notify the formatter of when it's added/removed.
 *
 * This is primarily for thread-safety.
 * If a formatter is explicitly not thread-safe, it may wish to throw an exception if added to multiple loggers.
 * Or if a formatter has potentially thread-unsafe code (e.g. NSDateFormatter with 10.0 behavior),
 * it could possibly use these hooks to switch to thread-safe versions of the code.
 **/
- (void)didAddToLogger:(id <VVLogger>)logger;

/**
 * A single formatter instance can be added to multiple loggers.
 * These methods provides hooks to notify the formatter of when it's added/removed.
 *
 * This is primarily for thread-safety.
 * If a formatter is explicitly not thread-safe, it may wish to throw an exception if added to multiple loggers.
 * Or if a formatter has potentially thread-unsafe code (e.g. NSDateFormatter with 10.0 behavior),
 * it could possibly use these hooks to switch to thread-safe versions of the code or use dispatch_set_specific()
.* to add its own specific values.
 **/
- (void)didAddToLogger:(id <VVLogger>)logger inQueue:(dispatch_queue_t)queue;

/**
 *  See the above description for `didAddToLogger:`
 */
- (void)willRemoveFromLogger:(id <VVLogger>)logger;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  This protocol describes a dynamic logging component
 */
@protocol VVRegisteredDynamicLogging

/**
 * Implement these methods to allow a file's log level to be managed from a central location.
 *
 * This is useful if you'd like to be able to change log levels for various parts
 * of your code from within the running application.
 *
 * Imagine pulling up the settings for your application,
 * and being able to configure the logging level on a per file basis.
 *
 * The implementation can be very straight-forward:
 *
 * ```
 * + (int)vvLogLevel
 * {
 *     return vvLogLevel;
 * }
 *
 * + (void)vvSetLogLevel:(VVLogLevel)level
 * {
 *     vvLogLevel = level;
 * }
 * ```
 **/
@property (class, nonatomic, readwrite, setter=vvSetLogLevel:) VVLogLevel vvLogLevel;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifndef NS_DESIGNATED_INITIALIZER
    #define NS_DESIGNATED_INITIALIZER
#endif

/**
 *  Log message options, allow copying certain log elements
 */
typedef NS_OPTIONS(NSInteger, VVLogMessageOptions){
    /**
     *  Use this to use a copy of the file path
     */
    VVLogMessageCopyFile        = 1 << 0,
    /**
     *  Use this to use a copy of the function name
     */
    VVLogMessageCopyFunction    = 1 << 1,
    /**
     *  Use this to use avoid a copy of the message
     */
    VVLogMessageDontCopyMessage = 1 << 2
};

/**
 * The `VVLogMessage` class encapsulates information about the log message.
 * If you write custom loggers or formatters, you will be dealing with objects of this class.
 **/
@interface VVLogMessage : NSObject <NSCopying>
{
    // Direct accessors to be used only for performance
    @public
    NSString *_message;
    VVLogLevel _level;
    VVLogFlag _flag;
    NSInteger _context;
    NSString *_file;
    NSString *_fileName;
    NSString *_function;
    NSUInteger _line;
    id _tag;
    VVLogMessageOptions _options;
    NSDate * _timestamp;
    NSString *_threadID;
    NSString *_threadName;
    NSString *_queueLabel;
    NSUInteger _qos;
}

/**
 *  Default `init` for empty messages.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 * Standard init method for a log message object.
 * Used by the logging primitives. (And the macros use the logging primitives.)
 *
 * If you find need to manually create logMessage objects, there is one thing you should be aware of:
 *
 * If no flags are passed, the method expects the file and function parameters to be string literals.
 * That is, it expects the given strings to exist for the duration of the object's lifetime,
 * and it expects the given strings to be immutable.
 * In other words, it does not copy these strings, it simply points to them.
 * This is due to the fact that __FILE__ and __FUNCTION__ are usually used to specify these parameters,
 * so it makes sense to optimize and skip the unnecessary allocations.
 * However, if you need them to be copied you may use the options parameter to specify this.
 *
 *  @param message   the message
 *  @param level     the log level
 *  @param flag      the log flag
 *  @param context   the context (if any is defined)
 *  @param file      the current file
 *  @param function  the current function
 *  @param line      the current code line
 *  @param tag       potential tag
 *  @param options   a bitmask which supports VVLogMessageCopyFile and VVLogMessageCopyFunction.
 *  @param timestamp the log timestamp
 *
 *  @return a new instance of a log message model object
 */
- (instancetype)initWithMessage:(NSString *)message
                          level:(VVLogLevel)level
                           flag:(VVLogFlag)flag
                        context:(NSInteger)context
                           file:(NSString *)file
                       function:(nullable NSString *)function
                           line:(NSUInteger)line
                            tag:(nullable id)tag
                        options:(VVLogMessageOptions)options
                      timestamp:(nullable NSDate *)timestamp NS_DESIGNATED_INITIALIZER;

/**
 * Read-only properties
 **/

/**
 *  The log message
 */
@property (readonly, nonatomic) NSString *message;
@property (readonly, nonatomic) VVLogLevel level;
@property (readonly, nonatomic) VVLogFlag flag;
@property (readonly, nonatomic) NSInteger context;
@property (readonly, nonatomic) NSString *file;
@property (readonly, nonatomic) NSString *fileName;
@property (readonly, nonatomic, nullable) NSString * function;
@property (readonly, nonatomic) NSUInteger line;
@property (readonly, nonatomic, nullable) id tag;
@property (readonly, nonatomic) VVLogMessageOptions options;
@property (readonly, nonatomic) NSDate *timestamp;
@property (readonly, nonatomic) NSString *threadID; // ID as it appears in NSLog calculated from the machThreadID
@property (readonly, nonatomic, nullable) NSString *threadName;
@property (readonly, nonatomic) NSString *queueLabel;
@property (readonly, nonatomic) NSUInteger qos API_AVAILABLE(macos(10.10), ios(8.0));

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The `VVLogger` protocol specifies that an optional formatter can be added to a logger.
 * Most (but not all) loggers will want to support formatters.
 *
 * However, writing getters and setters in a thread safe manner,
 * while still maintaining maximum speed for the logging process, is a difficult task.
 *
 * To do it right, the implementation of the getter/setter has strict requirements:
 * - Must NOT require the `logMessage:` method to acquire a lock.
 * - Must NOT require the `logMessage:` method to access an atomic property (also a lock of sorts).
 *
 * To simplify things, an abstract logger is provided that implements the getter and setter.
 *
 * Logger implementations may simply extend this class,
 * and they can ACCESS THE FORMATTER VARIABLE DIRECTLY from within their `logMessage:` method!
 **/
@interface VVAbstractLogger : NSObject <VVLogger>
{
    // Direct accessors to be used only for performance
    @public
    id <VVLogFormatter> _logFormatter;
    dispatch_queue_t _loggerQueue;
}

@property (nonatomic, strong, nullable) id <VVLogFormatter> logFormatter;
@property (nonatomic, DISPATCH_QUEUE_REFERENCE_TYPE) dispatch_queue_t loggerQueue;

// For thread-safety assertions

/**
 *  Return YES if the current logger uses a global queue for logging
 */
@property (nonatomic, readonly, getter=isOnGlobalLoggingQueue)  BOOL onGlobalLoggingQueue;

/**
 *  Return YES if the current logger uses the internal designated queue for logging
 */
@property (nonatomic, readonly, getter=isOnInternalLoggerQueue) BOOL onInternalLoggerQueue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface VVLoggerInformation : NSObject

@property (nonatomic, readonly) id <VVLogger> logger;
@property (nonatomic, readonly) VVLogLevel level;

+ (instancetype)informationWithLogger:(id <VVLogger>)logger
                             andLevel:(VVLogLevel)level;

@end

NS_ASSUME_NONNULL_END
