#ifndef __DEFINES_H__
#define __DEFINES_H__

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) || defined(WIN32)
#define PARLO_WIN32
#ifdef _WIN32_WINNT
#if _WIN32_WINNT < 0x0A00
#define DISABLE_CONSOLE_COLORS
#endif
#endif
#elif defined(__ANDROID__)
#define PARLO_ANDROID
#elif defined(__linux__) || defined(__linux)
#define PARLO_LINUX
#endif

#ifdef __cplusplus
}
#endif

#endif // __DEFINES_H__
