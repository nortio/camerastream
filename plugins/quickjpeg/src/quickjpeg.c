#include "quickjpeg.h"
#include "libyuv.h"
#include "libyuv/basic_types.h"
#include "libyuv/convert_argb.h"
#include "log.h"
#include "turbojpeg.h"
#include <stddef.h>
#include <stdint.h>

#define NULL_SPAN (Span){.data = NULL, .len = 0}

tjhandle jhandle;
// TODO: use a proper dynamic array
uint8_t *buffer = NULL;

FFI_PLUGIN_EXPORT Span compress_image(uint8_t *y, size_t y_len, int y_stride,
                                      uint8_t *u, size_t u_len, int u_stride,
                                      uint8_t *v, size_t v_len, int v_stride,
                                      int width, int height) {
    const uint8_t *planes[3] = {y, u, v};
    const int strides[3] = {y_stride, u_stride, v_stride};
    uint8_t *out = NULL;
    size_t out_size = 0;

    LOG_TRACE("Image size: %dx%d, uvstride: %d", width, height, u_stride);

    size_t y_size = tj3YUVPlaneSize(0, width, y_stride, height, TJSAMP_420);
    if (y_size != y_len) {
        LOG_ERROR("Y Plane size mismatch: expected %lu, got %lu (stride: %d)",
                  y_size, y_len, y_stride);
    }
    size_t u_size = tj3YUVPlaneSize(1, width, u_stride, height, TJSAMP_420);
    if (u_size != u_len) {
        LOG_ERROR("U Plane size mismatch: expected %lu, got %lu (stride: %d)",
                  u_size, u_len, u_stride);
    }
    size_t v_size = tj3YUVPlaneSize(2, width, v_stride, height, TJSAMP_420);
    if (v_size != v_len) {
        LOG_ERROR("V Plane size mismatch: expected %lu, got %lu (stride: %d)",
                  v_size, v_len, v_stride);
    }

    if (tj3CompressFromYUVPlanes8(jhandle, planes, width, strides, height, &out,
                                  &out_size) < 0) {
        LOG_ERROR("Failed to encode YUV image to JPEG: %s",
                  tj3GetErrorStr(jhandle));
        return NULL_SPAN;
    }

    LOG_DEBUG("Output size: %lu", out_size);

    return (Span){.data = out, .len = out_size};
}

FFI_PLUGIN_EXPORT Span compress_image_libyuv(uint8_t *y, size_t y_len,
                                             int y_stride, uint8_t *u,
                                             size_t u_len, int u_stride,
                                             uint8_t *v, size_t v_len,
                                             int v_stride, int width,
                                             int height) {
    const uint8_t *planes[3] = {y, u, v};
    const int strides[3] = {y_stride, u_stride, v_stride};
    uint8_t *out = NULL;
    size_t out_size = 0;

    LOG_TRACE("Image size: %dx%d, uvstride: %d", width, height, u_stride);

    size_t y_size = tj3YUVPlaneSize(0, width, y_stride, height, TJSAMP_420);
    if (y_size != y_len) {
        LOG_ERROR("Y Plane size mismatch: expected %lu, got %lu (stride: %d)",
                  y_size, y_len, y_stride);
    }
    size_t u_size = tj3YUVPlaneSize(1, width, u_stride, height, TJSAMP_420);
    if (u_size != u_len) {
        LOG_ERROR("U Plane size mismatch: expected %lu, got %lu (stride: %d)",
                  u_size, u_len, u_stride);
    }
    size_t v_size = tj3YUVPlaneSize(2, width, v_stride, height, TJSAMP_420);
    if (v_size != v_len) {
        LOG_ERROR("V Plane size mismatch: expected %lu, got %lu (stride: %d)",
                  v_size, v_len, v_stride);
    }

    I420ToARGB(y, y_stride, u, u_stride, v, v_stride, buffer, width * 4, width,
               height);

    if (tj3Compress8(jhandle, buffer, width, width * 4, height, TJPF_ARGB, &out,
                     &out_size) < 0) {
        LOG_ERROR("Failed to encode YUV (to ARGB) image to JPEG: %s",
                  tj3GetErrorStr(jhandle));
        return NULL_SPAN;
    }

    LOG_DEBUG("Output size: %lu", out_size);

    return (Span){.data = out, .len = out_size};
}

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

static inline int clamp(int a) {
    a = MIN(a, 255);
    return MAX(a, 0);
}

FFI_PLUGIN_EXPORT struct Span compress_image_manual(
    uint8_t *y_buffer, size_t y_len, int y_stride, int y_pixel_stride, uint8_t *cb_buffer,
    size_t u_len, int u_stride, int u_pixel_stride, uint8_t *cr_buffer, size_t v_len,
    int v_stride, int v_pixel_stride, int width, int height) {

    if (u_stride != v_stride) {
        LOG_WARN("U Stride and V Stride are not equal (%d != %d)", u_stride,
                 v_stride);
    }
    int uv_stride = MIN(u_stride, v_stride);

    if (u_pixel_stride != v_pixel_stride) {
        LOG_WARN("U Pixel Stride and V Pixel Stride are not equal (%d != %d)",
                 u_pixel_stride, v_pixel_stride);
    }
    int uv_pixel_stride = MIN(u_pixel_stride, v_pixel_stride);

    for (int h = 0; h < height; h++) {
        int uvh = h / 2;

        for (int w = 0; w < width; w++) {
            int uvw = w / 2;

            int y_index = (h * y_stride) + (w * y_pixel_stride);
            int uv_index = (uvh * uv_stride) + (uvw * uv_pixel_stride);

            uint8_t y = y_buffer[y_index];
            uint8_t cb = cb_buffer[uv_index];
            uint8_t cr = cr_buffer[uv_index];

            int r = 298.082 / 256.0f * y + 408.583 / 256.0f * cr - 222.921;
            int g = 298.082 / 256.0f * y - 100.291 / 256.0f * cb -
                    208.120 / 256.0f * cr + 135.576;
            int b = 298.082 / 256.0f * y + 516.412 / 256.0f * cb - 276.836;

            r = clamp(r);
            g = clamp(g);
            b = clamp(b);

            int i = (w * 3) + (width * 3) * h;
            buffer[i] = r;
            buffer[i + 1] = g;
            buffer[i + 2] = b;
        }
    }

    uint8_t *out = NULL;
    size_t out_size = 0;

    if (tj3Compress8(jhandle, buffer, width, width * 3, height, TJPF_RGB, &out,
                     &out_size) < 0) {
        LOG_ERROR("Failed to encode YUV (to ARGB manual) image to JPEG: %s",
                  tj3GetErrorStr(jhandle));
        return NULL_SPAN;
    }

    LOG_DEBUG("Output size: %lu", out_size);

    return (Span){.data = out, .len = out_size};
}

FFI_PLUGIN_EXPORT int convert(
    uint8_t *y_buffer, size_t y_len, int y_stride, int y_pixel_stride, uint8_t *cb_buffer,
    size_t u_len, int u_stride, int u_pixel_stride, uint8_t *cr_buffer, size_t v_len,
    int v_stride, int v_pixel_stride, int width, int height) {

    if (u_stride != v_stride) {
        LOG_WARN("U Stride and V Stride are not equal (%d != %d)", u_stride,
                 v_stride);
    }
    int uv_stride = MIN(u_stride, v_stride);

    if (u_pixel_stride != v_pixel_stride) {
        LOG_WARN("U Pixel Stride and V Pixel Stride are not equal (%d != %d)",
                 u_pixel_stride, v_pixel_stride);
    }
    int uv_pixel_stride = MIN(u_pixel_stride, v_pixel_stride);

    for (int h = 0; h < height; h++) {
        int uvh = h / 2;

        for (int w = 0; w < width; w++) {
            int uvw = w / 2;

            int y_index = (h * y_stride) + (w * y_pixel_stride);
            int uv_index = (uvh * uv_stride) + (uvw * uv_pixel_stride);

            uint8_t y = y_buffer[y_index];
            uint8_t cb = cb_buffer[uv_index];
            uint8_t cr = cr_buffer[uv_index];

            int r = 298.082 / 256.0f * y + 408.583 / 256.0f * cr - 222.921;
            int g = 298.082 / 256.0f * y - 100.291 / 256.0f * cb -
                    208.120 / 256.0f * cr + 135.576;
            int b = 298.082 / 256.0f * y + 516.412 / 256.0f * cb - 276.836;

            r = clamp(r);
            g = clamp(g);
            b = clamp(b);

            int i = (w * 3) + (width * 3) * h;
            buffer[i] = r;
            buffer[i + 1] = g;
            buffer[i + 2] = b;
        }
    }
    return 0; 
}

/**
 * Converts NV12 to XRGB and compresses that
 */
FFI_PLUGIN_EXPORT Span compress_nv12(uint8_t *dest, int dest_stride, uint8_t *y,
                                     size_t y_len, int y_stride, uint8_t *uv,
                                     size_t uv_len, int uv_stride, int width,
                                     int height) {
    uint8_t *out = NULL;
    size_t out_size = 0;

    if (NV12ToARGB(y, y_stride, uv, uv_stride, dest, dest_stride, width,
                   height)) {
        LOG_ERROR("NV12 to ARGB conversion failed");
        return NULL_SPAN;
    }

    if (tj3Compress8(jhandle, dest, width, dest_stride, height, TJPF_ARGB, &out,
                     &out_size) < 0) {
        LOG_ERROR("Failed to encode NV12 image to JPEG: %s",
                  tj3GetErrorStr(jhandle));
    }

    return (Span){.data = out, .len = out_size};
}

FFI_PLUGIN_EXPORT Span compress_rgb(uint8_t *src, int src_stride, int width,
                                    int height) {
    uint8_t *out = NULL;
    size_t out_size = 0;

    if (tj3Compress8(jhandle, src, width, src_stride, height, TJPF_RGB, &out,
                     &out_size) < 0) {
        LOG_ERROR("Failed to encode ARGB image to JPEG: %s",
                  tj3GetErrorStr(jhandle));
        return NULL_SPAN;
    }

    return (Span){.data = out, .len = out_size};
}

FFI_PLUGIN_EXPORT int init() {
#define LOG_LEVEL LOGINFO
#ifdef NDEBUG
#define LOG_LEVEL LOGTRACE
#endif
    if (parlo_log_init(LOGINFO)) {
        return 1;
    }

    buffer = malloc(720 * 480 * 4);

    jhandle = tj3Init(TJINIT_COMPRESS);
    if (jhandle == NULL) {
        return 1;
    }

    if (tj3Set(jhandle, TJPARAM_QUALITY, 75) < 0) {
        LOG_ERROR("Error setting quality: %s", tj3GetErrorStr(jhandle));
        return 1;
    }
    if (tj3Set(jhandle, TJPARAM_SUBSAMP, TJSAMP_420) < 0) {
        LOG_ERROR("Error setting chroma subsampling: %s",
                  tj3GetErrorStr(jhandle));
        return 1;
    }
    if (tj3Set(jhandle, TJPARAM_PRECISION, 8) < 0) {
        LOG_WARN("Error setting precision (proceding): %s",
                 tj3GetErrorStr(jhandle));
        // return 1;
    }
    if (tj3Set(jhandle, TJPARAM_COLORSPACE, TJCS_YCbCr) < 0) {
        LOG_ERROR("Error setting color space: %s", tj3GetErrorStr(jhandle));
        return 1;
    }

    LOG_INFO("Quickjpeg successfully initialized");

    return 0;
}
