//
//  RSAsyncTaskQueue.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSAsyncTaskQueue.h"

@interface RSAsyncTaskQueue ()

@property(strong, nonatomic) NSMutableArray<AsyncTask> *tasks;

@property(assign, nonatomic) BOOL isRunning;

@property(strong, nonatomic) dispatch_queue_t queue ;

@end


@implementation RSAsyncTaskQueue

- (instancetype)init
{
    self = [super init];
    if (self) {
        _tasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)initWithIdentifier:(const char *_Nullable )identifier {
    if ([self init]) {
        _queue = dispatch_queue_create(identifier, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)addTask:(AsyncTask)asyncTask {
    if (_isRunning == YES) {
        NSLog(@"Can't add task to a running queue, please add task before calling -[RVAsyncTaskQueue engage]!");
        NSException *ex = [[NSException alloc] initWithName:@"RVAsyncTaskQueueError" reason:@"Can't add task to a running queue, please add task before calling -[RVAsyncTaskQueue engage]!" userInfo:nil];
        [ex raise];
//        return;
    }
    [_tasks addObject:asyncTask];
}


- (void)engage {
    _isRunning = YES;
    
    // Working on specific dispatch_queue_t
    dispatch_async(_queue, ^{
        
        // Add tasks by sequence
        for (int idx = 0; idx < self->_tasks.count; idx++) {
            
            // Create semaphore to lock thread
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            // Every task must call taskFinished() to unlock thread, so the next task could be engaged
            void(^taskFinished)(void) = ^() {
                // Signal sema to unlock thread
                dispatch_semaphore_signal(sema);
            };
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self->_tasks[idx]) {
                    self->_tasks[idx](taskFinished);
                }
            });

            // Lock thread until current task done
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        
        
        // Call completeHandler after all task done
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_completeHandler) self->_completeHandler();
        });
        
    });
    
}

@end
