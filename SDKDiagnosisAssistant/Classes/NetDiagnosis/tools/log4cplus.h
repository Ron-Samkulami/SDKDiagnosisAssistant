#ifndef _LOG4CPLUS_H_
#define _LOG4CPLUS_H_
#endif

#if (defined (_MSC_VER) && _MSC_VER >= 1900) || (defined(__cplusplus) && __cplusplus>= 201103L)
#define __STDC_FORMAT_MACROS
#include <cinttypes>
#endif

#ifdef RSNetDiagnosis_Log
#include <syslog.h>

extern int NET_DIAGNOSIS_LOG_LEVEL;
extern int NET_DIAGNOSIS_FLAG_FATAL;
extern int NET_DIAGNOSIS_FLAG_ERROR;
extern int NET_DIAGNOSIS_FLAG_WARN;
extern int NET_DIAGNOSIS_FLAG_INFO;
extern int NET_DIAGNOSIS_FLAG_DEBUG;

#define log4cplus_fatal(category, logFmt, ...) \
do { \
    if(NET_DIAGNOSIS_LOG_LEVEL & NET_DIAGNOSIS_FLAG_FATAL) \
        syslog(LOG_CRIT, "%s:" logFmt, #category,##__VA_ARGS__); \
}while(0)

#define log4cplus_error(category, logFmt, ...) \
do { \
    if(NET_DIAGNOSIS_LOG_LEVEL & NET_DIAGNOSIS_FLAG_ERROR) \
        syslog(LOG_ERR, "%s:" logFmt, #category,##__VA_ARGS__); \
}while(0)

#define log4cplus_warn(category, logFmt, ...) \
do { \
    if(NET_DIAGNOSIS_LOG_LEVEL & NET_DIAGNOSIS_FLAG_WARN) \
        syslog(LOG_WARNING, "%s:" logFmt, #category,##__VA_ARGS__); \
}while(0)

#define log4cplus_info(category, logFmt, ...) \
do { \
    if(NET_DIAGNOSIS_LOG_LEVEL & NET_DIAGNOSIS_FLAG_INFO) \
        syslog(LOG_WARNING, "%s:" logFmt, #category,##__VA_ARGS__); \
}while(0)

#define log4cplus_debug(category, logFmt, ...) \
do { \
    if(NET_DIAGNOSIS_LOG_LEVEL & NET_DIAGNOSIS_FLAG_DEBUG) \
        syslog(LOG_WARNING, "%s:" logFmt, #category,##__VA_ARGS__); \
}while(0)


#endif

