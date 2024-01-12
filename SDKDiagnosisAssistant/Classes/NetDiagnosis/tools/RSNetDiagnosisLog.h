//
//  RSNetDiagnosisLog.h
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RSNetDiagnosis_Log
#include "log4cplus.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, RSNetDiagnosisLogLevel) {
    RSNetDiagnosisLogLevel_FATAL,
    RSNetDiagnosisLogLevel_ERROR,
    RSNetDiagnosisLogLevel_WARN,
    RSNetDiagnosisLogLevel_INFO,
    RSNetDiagnosisLogLevel_DEBUG
};

@interface RSNetDiagnosisLog : NSObject

+ (void)setLogLevel:(RSNetDiagnosisLogLevel)logLevel;

@end

NS_ASSUME_NONNULL_END
