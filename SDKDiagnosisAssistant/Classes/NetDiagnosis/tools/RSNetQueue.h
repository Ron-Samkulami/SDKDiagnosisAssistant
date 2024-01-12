//
//  RSNetQueue.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSNetQueue : NSObject

+ (void)rs_net_ping_async:(dispatch_block_t)block;
+ (void)rs_net_trace_async:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
