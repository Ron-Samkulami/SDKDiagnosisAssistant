//
//  RSNetDiagnosisLog.m
//  RSNetDiagnosis
//
//  Created by Ron-Samkulami on 12/26/2023.
//  Copyright (c) 2023 Ron-Samkulami. All rights reserved.
//

#import "RSNetDiagnosisLog.h"

/*   define log level  */
int NET_DIAGNOSIS_FLAG_FATAL = 0x10;
int NET_DIAGNOSIS_FLAG_ERROR = 0x08;
int NET_DIAGNOSIS_FLAG_WARN = 0x04;
int NET_DIAGNOSIS_FLAG_INFO = 0x02;
int NET_DIAGNOSIS_FLAG_DEBUG = 0x01;
int NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_FLAG_FATAL|NET_DIAGNOSIS_FLAG_ERROR;

@implementation RSNetDiagnosisLog

+ (void)setLogLevel:(RSNetDiagnosisLogLevel)logLevel
{
    switch (logLevel) {
        case RSNetDiagnosisLogLevel_FATAL:
        {
            NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_FLAG_FATAL;
            log4cplus_fatal("RSNetDiagnosis", "setting UCSDK log level ,NET_DIAGNOSIS_FLAG_FATAL...\n");
        }
            break;
        case RSNetDiagnosisLogLevel_ERROR:
        {
            NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_FLAG_FATAL|NET_DIAGNOSIS_FLAG_ERROR;
            log4cplus_error("RSNetDiagnosis", "setting UCSDK log level ,NET_DIAGNOSIS_FLAG_ERROR...\n");
        }
            break;
        case RSNetDiagnosisLogLevel_WARN:
        {
            NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_FLAG_FATAL|NET_DIAGNOSIS_FLAG_ERROR|NET_DIAGNOSIS_FLAG_WARN;
            log4cplus_warn("RSNetDiagnosis", "setting UCSDK log level ,NET_DIAGNOSIS_FLAG_WARN...\n");
        }
            break;
        case RSNetDiagnosisLogLevel_INFO:
        {
            NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_FLAG_FATAL|NET_DIAGNOSIS_FLAG_ERROR|NET_DIAGNOSIS_FLAG_WARN|NET_DIAGNOSIS_FLAG_INFO;
            log4cplus_info("RSNetDiagnosis", "setting UCSDK log level ,NET_DIAGNOSIS_FLAG_INFO...\n");
        }
            break;
        case RSNetDiagnosisLogLevel_DEBUG:
        {
            NET_DIAGNOSIS_LOG_LEVEL = NET_DIAGNOSIS_FLAG_FATAL|NET_DIAGNOSIS_FLAG_ERROR|NET_DIAGNOSIS_FLAG_WARN|NET_DIAGNOSIS_FLAG_INFO|NET_DIAGNOSIS_FLAG_DEBUG;
            log4cplus_debug("RSNetDiagnosis", "setting UCSDK log level ,UCNetAnalysisSDKLogLevel_DEBUG...\n");
        }
            break;
            
        default:
            break;
    }
}
@end
