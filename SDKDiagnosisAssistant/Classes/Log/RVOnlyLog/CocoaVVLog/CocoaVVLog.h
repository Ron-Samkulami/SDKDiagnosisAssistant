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

/**
 * Welcome to CocoaVVLog!
 *
 * The project page has a wealth of documentation if you have any questions.
 * https://github.com/CocoaVVLog/CocoaVVLog
 *
 * If you're new to the project you may wish to read "Getting Started" at:
 * Documentation/GettingStarted.md
 *
 * Otherwise, here is a quick refresher.
 * There are three steps to using the macros:
 *
 * Step 1:
 * Import the header in your implementation or prefix file:
 *
 * #import "CocoaVVLog.h>
 *
 * Step 2:
 * Define your logging level in your implementation file:
 *
 * // Log levels: off, error, warn, info, verbose
 * static const VVLogLevel vvLogLevel = VVLogLevelVerbose;
 *
 * Step 2 [3rd party frameworks]:
 *
 * Define your LOG_LEVEL_DEF to a different variable/function than vvLogLevel:
 *
 * // #undef LOG_LEVEL_DEF // Undefine first only if needed
 * #define LOG_LEVEL_DEF myLibLogLevel
 *
 * Define your logging level in your implementation file:
 *
 * // Log levels: off, error, warn, info, verbose
 * static const VVLogLevel myLibLogLevel = VVLogLevelVerbose;
 *
 * Step 3:
 * Replace your NSLog statements with VVLog statements according to the severity of the message.
 *
 * NSLog(@"Fatal error, no dohickey found!"); -> VVLogError(@"Fatal error, no dohickey found!");
 *
 * VVLog works exactly the same as NSLog.
 * This means you can pass it multiple variables just like NSLog.
 **/

#import <Foundation/Foundation.h>

//! Project version number for CocoaVVLog.
FOUNDATION_EXPORT double CocoaVVLogVersionNumber;

//! Project version string for CocoaVVLog.
FOUNDATION_EXPORT const unsigned char CocoaVVLogVersionString[];

// Disable legacy macros
#ifndef VV_LEGACY_MACROS
    #define VV_LEGACY_MACROS 0
#endif

// Core
#import "VVLog.h"

// Main macros
#import "VVLogMacros.h"
#import "VVAssertMacros.h"

// Loggers
#import "VVLoggerNames.h"

#import "VVASLLogger.h"
#import "VVFileLogger.h"
#import "VVOSLogger.h"

