#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum { SAMPLE_RATE = 48000, TONE_MS = 1500, GAP_MS = 400, REPEATS = 2 };

static void put_u16(FILE *file, uint16_t value) {
    fputc(value & 0xff, file);
    fputc((value >> 8) & 0xff, file);
}

static void put_u32(FILE *file, uint32_t value) {
    put_u16(file, value & 0xffff);
    put_u16(file, value >> 16);
}

static void write_frames(FILE *file, unsigned frames, double frequency,
                         int left, int right) {
    for (unsigned i = 0; i < frames; ++i) {
        int16_t sample = (int16_t)(2600.0 * sin(2.0 * M_PI * frequency * i /
                                               SAMPLE_RATE));
        put_u16(file, left ? (uint16_t)sample : 0);
        put_u16(file, right ? (uint16_t)sample : 0);
    }
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s output.wav\n", argv[0]);
        return 2;
    }

    FILE *file = fopen(argv[1], "wb");
    if (!file) {
        perror(argv[1]);
        return 1;
    }

    const unsigned tone_frames = SAMPLE_RATE * TONE_MS / 1000;
    const unsigned gap_frames = SAMPLE_RATE * GAP_MS / 1000;
    const uint32_t data_size = REPEATS *
        (2 * tone_frames + 2 * gap_frames) * 2 * sizeof(int16_t);

    fwrite("RIFF", 1, 4, file);
    put_u32(file, 36 + data_size);
    fwrite("WAVEfmt ", 1, 8, file);
    put_u32(file, 16);
    put_u16(file, 1);
    put_u16(file, 2);
    put_u32(file, SAMPLE_RATE);
    put_u32(file, SAMPLE_RATE * 2 * sizeof(int16_t));
    put_u16(file, 2 * sizeof(int16_t));
    put_u16(file, 16);
    fwrite("data", 1, 4, file);
    put_u32(file, data_size);

    for (int i = 0; i < REPEATS; ++i) {
        write_frames(file, tone_frames, 440.0, 1, 0);
        write_frames(file, gap_frames, 0.0, 0, 0);
        write_frames(file, tone_frames, 880.0, 0, 1);
        write_frames(file, gap_frames, 0.0, 0, 0);
    }

    return fclose(file) == 0 ? 0 : 1;
}
