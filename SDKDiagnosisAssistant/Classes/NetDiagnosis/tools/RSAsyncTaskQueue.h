//
//  RSAsyncTaskQueue.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ TaskFinished )(void);
typedef void (^ AsyncTask)(TaskFinished taskFinished);
typedef void (^ CompleteHandler )(void);

@interface RSAsyncTaskQueue : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 @brief Initialize a new queue
 
 @discussion Must initialize with an identifier

 @param identifier queue identifier
 @return `RSAsyncTaskQueue` instance
 */
- (instancetype)initWithIdentifier:(const char *_Nullable )identifier;

/**
 @brief Add an async task
 
 @discussion Must call  `taskFinished()` when current task complete.
 
 @param asyncTask The thing you want to do.
 */
- (void)addTask:(AsyncTask)asyncTask;


/**
 @brief Start the task queue.
 */
- (void)engage;


/// Completion
@property(strong, nonatomic) CompleteHandler completeHandler;

@end

NS_ASSUME_NONNULL_END
