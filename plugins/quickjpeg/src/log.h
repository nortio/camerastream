#ifndef __SRC_LOG_H_
#define __SRC_LOG_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h> // IWYU pragma: keep
#include <errno.h>
#include "defines.h"

typedef enum LogLevel {
    LOGTRACE,
    LOGDEBUG,
    LOGINFO,
    LOGWARN,
    LOGERROR
} LogLevel;

#ifdef _MSC_VER
#define __FILE_NAME__ __FILE__
#endif

int parlo_log_init(LogLevel level);
void parlo_log(LogLevel level, const char* srcfile, int line, const char *fmt, ...);
#define LOG_PRINT(...) parlo_log(LOGTRACE, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define LOG_INFO(...) parlo_log(LOGINFO, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define LOG_ERROR(...) parlo_log(LOGERROR, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define LOG_DEBUG(...) parlo_log(LOGDEBUG, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define LOG_TRACE(...) parlo_log(LOGTRACE, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define LOG_WARN(...) parlo_log(LOGWARN, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define LOG_PERROR(str) parlo_log(LOGERROR, __FILE_NAME__, __LINE__, str ": %s", strerror(errno))

int parlo_log_destroy();
int parlo_log_set_level(LogLevel level);
void print_buf(const unsigned char *buf, size_t buf_len);
void print_buf_with_title(const char *title, const unsigned char *buf,
                          size_t buf_len);

#ifdef PARLO_ANDROID

#include <android/log.h>
#define TAG "parlo_native"

#define PRINT(...)

#elif defined(PARLO_LINUX)


#define PRINT__INT(fmt, ...) fprintf(stderr, "" fmt "%s", __VA_ARGS__);
#define PRINT(...) PRINT__INT(__VA_ARGS__, "");

#elif defined(PARLO_WIN32)

#ifdef _MSC_VER

#define PRINT__INT(fmt, ...) printf(fmt, __VA_ARGS__);
#define PRINT(...) PRINT__INT(__VA_ARGS__, "");

#else

#define PRINT__INT(fmt, ...) printf("" fmt "%s", __VA_ARGS__);
#define PRINT(...) PRINT__INT(__VA_ARGS__, "");

#endif

#else

#warning "Undefined platform (using printf)"

#define PRINT__INT(fmt, ...) printf("" fmt "%s", __VA_ARGS__);
#define PRINT(...) PRINT__INT(__VA_ARGS__, "");

#endif

#ifdef __cplusplus
}
#endif
#endif // __SRC_LOG_H_