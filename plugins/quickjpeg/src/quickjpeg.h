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

/**
 * Initializes the turbojpeg library
 */
FFI_PLUGIN_EXPORT int init();

/**
 * Compresses separate YUV planes (YUV420) directly with turbojpeg
 */
FFI_PLUGIN_EXPORT struct Span
compress_image(uint8_t *y, size_t y_len, int y_stride, uint8_t *u, size_t u_len,
               int u_stride, uint8_t *v, size_t v_len, int v_stride, int width,
               int height);

/**
 * Compresses separate YUV planes by first converting them to ARGB with libyuv
 * and then compressing them as ARGB
 */
FFI_PLUGIN_EXPORT Span compress_image_libyuv(uint8_t *y, size_t y_len,
                                             int y_stride, uint8_t *u,
                                             size_t u_len, int u_stride,
                                             uint8_t *v, size_t v_len,
                                             int v_stride, int width,
                                             int height);

/**
 * Compresses weird YUV planes output by the camera plugin by first converting
 * them manually to ARGB
 */
FFI_PLUGIN_EXPORT struct Span compress_image_manual(
    uint8_t *y, size_t y_len, int y_stride, int y_pixel_stride, uint8_t *u,
    size_t u_len, int u_stride, int u_pixel_stride, uint8_t *v, size_t v_len,
    int v_stride, int v_pixel_stride, int width, int height);

/**
 * Converts NV12 to XRGB and compresses that
 */
FFI_PLUGIN_EXPORT Span compress_nv12(uint8_t *dest, int dest_stride, uint8_t *y,
                                     size_t y_len, int y_stride, uint8_t *uv,
                                     size_t uv_len, int uv_stride, int width,
                                     int height);

/**
 * Compresses RGB images (without alpha)
 */
FFI_PLUGIN_EXPORT Span compress_rgb(uint8_t *src, int src_stride, int width,
                                    int height);

FFI_PLUGIN_EXPORT int convert(
    uint8_t *y_buffer, size_t y_len, int y_stride, int y_pixel_stride, uint8_t *cb_buffer,
    size_t u_len, int u_stride, int u_pixel_stride, uint8_t *cr_buffer, size_t v_len,
    int v_stride, int v_pixel_stride, int width, int height);