#include "log.h"
#include "stdio.h"
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

#ifdef PARLO_WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

uint32_t orig_codepage = 0;
LogLevel current_level = LOGTRACE;
FILE *log_file = NULL;

int parlo_log_init(LogLevel level) {
#ifdef PARLO_WIN32
    // Set output mode to handle virtual terminal sequences
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hOut == INVALID_HANDLE_VALUE) {
        return GetLastError();
    }

    DWORD dwMode = 0;
    if (!GetConsoleMode(hOut, &dwMode)) {
        return GetLastError();
    }

    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (!SetConsoleMode(hOut, dwMode)) {
        return GetLastError();
    }

    orig_codepage = GetConsoleOutputCP();
    SetConsoleOutputCP(CP_UTF8);

    log_file = fopen("parlo.log", "a");
#endif

    assert(level >= 0 && level <= LOGERROR);

    current_level = level;

    return 0;
}

int parlo_log_destroy() {
#ifdef PARLO_WIN32
    if (orig_codepage) {
        SetConsoleOutputCP(orig_codepage);
    }
#endif
    if (log_file) {
        fclose(log_file);
    }
    return 0;
}

int parlo_log_set_level(LogLevel level) {
    current_level = level;
    return 0;
}

const char *colors[] = {[LOGTRACE] = "\x1b[90m",
                        [LOGDEBUG] = "\x1b[90m",
                        [LOGINFO] = "\x1b[0m",
                        [LOGWARN] = "\x1b[33m",
                        [LOGERROR] = "\x1b[31m"};

const char *tag_colors[] = {[LOGTRACE] = "\x1b[90m",
                            [LOGDEBUG] = "\x1b[90m",
                            [LOGINFO] = "\x1b[32m",
                            [LOGWARN] = "\x1b[33m",
                            [LOGERROR] = "\x1b[31m"};

const char *tags[] = {[LOGTRACE] = "TRACE",
                      [LOGDEBUG] = "DEBUG",
                      [LOGINFO] = " INFO",
                      [LOGWARN] = " WARN",
                      [LOGERROR] = "ERROR"};

#ifdef PARLO_ANDROID
int android_loglevel[] = {[LOGTRACE] = ANDROID_LOG_VERBOSE,
                          [LOGDEBUG] = ANDROID_LOG_DEBUG,
                          [LOGINFO] = ANDROID_LOG_INFO,
                          [LOGWARN] = ANDROID_LOG_WARN,
                          [LOGERROR] = ANDROID_LOG_ERROR};
#endif

void parlo_log(LogLevel level, const char *srcfile, int line, const char *fmt,
               ...) {
    assert(level >= 0 && level <= LOGERROR);

    if (level < current_level) {
        return;
    }

    va_list list;
    va_start(list, fmt);

#ifdef PARLO_ANDROID
    __android_log_vprint(android_loglevel[level], TAG, fmt, list);
#else
    FILE *target = level > LOGINFO ? stderr : stdout;

#ifndef DISABLE_CONSOLE_COLORS
    fprintf(target, "%s%s\x1b[90m %s:%d:%s ", tag_colors[level], tags[level],
            srcfile, line, colors[level]);
    vfprintf(target, fmt, list);
    fprintf(target, "\x1b[0m\n");
#else
    fprintf(target, "[%s] %s:%d: ", tags[level], srcfile, line);
    vfprintf(target, fmt, list);
    fprintf(target, "\n");
#endif

    if (log_file) {
        fprintf(log_file, "[%s] %s:%d: ", tags[level], srcfile, line);
        vfprintf(log_file, fmt, list);
        fprintf(log_file, "\n");
    }

    fflush(target);

#endif

    va_end(list);
}

void print_buf(const unsigned char *buf, size_t buf_len) {
    if (current_level > LOGTRACE) {
        return;
    }
    size_t i = 0;
    for (i = 0; i < buf_len; ++i)
        PRINT("%02X%s", buf[i], (i + 1) % 16 == 0 ? "\r\n" : " ");
}

void print_buf_with_title(const char *title, const unsigned char *buf,
                          size_t buf_len) {
    if (current_level > LOGTRACE) {
        return;
    }
    PRINT("%s\n", title);
    print_buf(buf, buf_len);
    // fprintf(stdout, "\nascii: %s\n", buf);
    PRINT("\x1b[0m\n");
}