#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef struct Span {
    uint8_t *data;
    size_t len;
} Span;

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b);

FFI_PLUGIN_EXPORT int init();

/**
* Compresses separate YUV planes (YUV420)
*/
FFI_PLUGIN_EXPORT struct Span compress_image(uint8_t* y, size_t y_len, int y_stride, uint8_t* u, size_t u_len, int u_stride, uint8_t *v, size_t v_len, int v_stride, int width, int height);

/**
* Converts NV12 to XRGB and compresses that
*/
FFI_PLUGIN_EXPORT Span compress_nv12(uint8_t* dest, int dest_stride, uint8_t* y, size_t y_len, int y_stride, uint8_t*uv, size_t uv_len, int uv_stride, int width, int height);

FFI_PLUGIN_EXPORT Span compress_rgb(uint8_t* src, int src_stride, int width, int height);

// A longer lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b);
