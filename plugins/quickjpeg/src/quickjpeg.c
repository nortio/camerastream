#include "quickjpeg.h"
#include "libyuv.h"
#include "libyuv/basic_types.h"
#include "libyuv/convert_argb.h"
#include "libyuv/convert_from_argb.h"
#include "log.h"
#include "turbojpeg.h"
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#define NULL_SPAN (Span){.data = NULL, .len = 0}

tjhandle jhandle;

// TODO: use a proper dynamic array
typedef struct Box {
    uint8_t *buffer;
    size_t capacity;
} Box;

static inline void box_init(Box *box) {
    box->buffer = NULL;
    box->capacity = 0;
}

static inline void box_reserve(Box *box, size_t amount) {
    if (amount < box->capacity) {
        return;
    }
    box->buffer = realloc(box->buffer, amount);
    box->capacity = amount;
}

Box android_rgba_buffer;
uint8_t *buffer = NULL;

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

static inline int clamp(int a) {
    a = MIN(a, 255);
    return MAX(a, 0);
}

FFI_PLUGIN_EXPORT struct Span
compress_image_manual(uint8_t *y_buffer, size_t y_len, int y_stride,
                      int y_pixel_stride, uint8_t *cb_buffer, size_t u_len,
                      int u_stride, int u_pixel_stride, uint8_t *cr_buffer,
                      size_t v_len, int v_stride, int v_pixel_stride, int width,
                      int height) {

    if (u_pixel_stride != v_pixel_stride) {
        LOG_WARN("U Pixel Stride and V Pixel Stride are not equal (%d != %d)",
                 u_pixel_stride, v_pixel_stride);
    }
    int uv_pixel_stride = MIN(u_pixel_stride, v_pixel_stride);
    LOG_DEBUG("UV Pixel stride %d", uv_pixel_stride);

    if (u_stride != v_stride) {
        LOG_WARN("U Stride and V Stride are not equal (%d != %d)", u_stride,
                 v_stride);
    }
    int uv_stride = MIN(u_stride, v_stride);

    box_reserve(&android_rgba_buffer, width * height * 4);

    if (Android420ToABGR(y_buffer, y_stride, cb_buffer, u_stride, cr_buffer,
                         v_stride, uv_pixel_stride, android_rgba_buffer.buffer,
                         width * 4, width, height)) {
        LOG_ERROR("Failed to convert Android YUV420 to ARGB");
        return NULL_SPAN;
    }

    // TODO: start reusing buffers instead of allocating new ones for each jpeg frame
    uint8_t *out = NULL;
    size_t out_size = 0;

    if (tj3Compress8(jhandle, android_rgba_buffer.buffer, width, width * 4,
                     height, TJPF_RGBA, &out, &out_size) < 0) {
        LOG_ERROR("Failed to encode YUV (to ARGB manual) image to JPEG: %s",
                  tj3GetErrorStr(jhandle));
        return NULL_SPAN;
    }

    LOG_DEBUG("Output size: %lu", out_size);

    return (Span){.data = out, .len = out_size};
}

/**
 * Unused, this is old conversion code (replaced by Android420ToABGR, provided by libyuv)
 */
static int convert(uint8_t *y_buffer, size_t y_len, int y_stride,
                              int y_pixel_stride, uint8_t *cb_buffer,
                              size_t u_len, int u_stride, int u_pixel_stride,
                              uint8_t *cr_buffer, size_t v_len, int v_stride,
                              int v_pixel_stride, int width, int height) {

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

            // BT.601
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
 * Also unused, might be useful
 */
static Span compress_rgb(uint8_t *src, int src_stride, int width,
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
    box_init(&android_rgba_buffer);
    box_reserve(&android_rgba_buffer, 720 * 480 * 4);

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
