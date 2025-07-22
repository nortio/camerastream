#include "log.h"
#include "quickjpeg.h"
#include "turbojpeg.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define NULL_SPAN (Span){.data = NULL, .len = 0}

struct Span read_file(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        perror("Failed to open file");
        return NULL_SPAN;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        perror("Failed to seek file");
        fclose(file);
        return NULL_SPAN;
    }

    long res = ftell(file);
    if (res < 0) {
        perror("Failed to tell file size");
        fclose(file);
        return NULL_SPAN;
    }
    rewind(file);

    size_t length = (size_t)res;

    uint8_t *buffer = (uint8_t *)malloc(length + 1);
    if (!buffer) {
        perror("Failed to allocate buffer");
        fclose(file);
        return NULL_SPAN;
    }

    size_t read_size = fread(buffer, 1, length, file);
    if (read_size != (size_t)length) {
        perror("Failed to read entire file");
        free(buffer);
        fclose(file);
        return NULL_SPAN;
    }

    fclose(file);
    return (struct Span){.data = buffer, .len = length};
}
typedef struct Span Span;
int main(int argc, char **argv) {
    //assert(parlo_log_init(LOGTRACE) == 0);
    assert(argc >= 5);

    Span info = read_file(argv[1]);
    assert(info.data != NULL);
    Span y = read_file(argv[2]);
    assert(y.data != NULL);
    Span u = read_file(argv[3]);
    assert(u.data != NULL);
    Span v = read_file(argv[4]);
    assert(v.data != NULL);

    // print_buf_with_title("U Raw plane", u.data, u.len);

    int width = 0, height = 0, y_stride = 0, u_stride = 0, v_stride = 0;
    // TODO: can't be bothered to fix this garbage
    info.data[info.len] = '\0';
    sscanf((char *)info.data, "%dx%d \n %d \n %d \n %d \n", &width, &height,
           &y_stride, &u_stride, &v_stride);
    LOG_INFO("Image %dx%d, Y: %lu (stride: %d), U: %lu (stride: %d), V: %lu "
             "(stride: %d)",
             width, height, y.len, y_stride, u.len, u_stride, v.len, v_stride);
    init();
    parlo_log_set_level(LOGTRACE);
    Span res =
        compress_image_manual(y.data, y.len, y_stride, 1, u.data, u.len, u_stride, 2,
                              v.data, v.len, v_stride, 2, width, height);
    int dest_stride = width * 4 * sizeof(uint8_t);
    uint8_t *dest = malloc(dest_stride * height);
    // Span res = compress_nv12(dest, dest_stride, y.data, y.len, 720, u.data,
    // u.len,360, width, height);

    tjhandle handle = tj3Init(TJINIT_COMPRESS);

    if (tj3SaveImage8(handle, "../test/rawimage", dest, width, dest_stride,
                      height, TJPF_XRGB) < 0) {
        LOG_ERROR("Could not save raw image: %s", tj3GetErrorStr(handle));
    }
    LOG_INFO("JPEG output size: %lu", res.len);

    FILE *out = fopen("../test/out.jpeg", "wb");

    fwrite(res.data, sizeof(uint8_t), res.len, out);

    (void)system("xdg-open ../test/out.jpeg");
    return 0;
}