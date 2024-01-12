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

NS_ASSUME_NONNULL_BEGIN

typedef NSString *VVLoggerName NS_TYPED_EXTENSIBLE_ENUM;

FOUNDATION_EXPORT VVLoggerName const VVLoggerNameOS NS_SWIFT_NAME(VVLoggerName.os); // VVOSLogger
FOUNDATION_EXPORT VVLoggerName const VVLoggerNameFile NS_SWIFT_NAME(VVLoggerName.file); // VVFileLogger

FOUNDATION_EXPORT VVLoggerName const VVLoggerNameTTY NS_SWIFT_NAME(VVLoggerName.tty); // VVTTYLogger

API_DEPRECATED("Use VVOSLogger instead", macosx(10.4, 10.12), ios(2.0, 10.0), watchos(2.0, 3.0), tvos(9.0, 10.0))
FOUNDATION_EXPORT VVLoggerName const VVLoggerNameASL NS_SWIFT_NAME(VVLoggerName.asl); // VVASLLogger

NS_ASSUME_NONNULL_END
