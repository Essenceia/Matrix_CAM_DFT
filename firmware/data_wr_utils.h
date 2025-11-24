#ifndef _DATA_WR_UTILS
#define _DATA_WR_UTILS

#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "pinout.h"

// TPU matrix dimentions
#define N 2
#define NN 4

typedef struct __attribute__((packed)) {
	uint8_t data[NN];
} data_t;

void send_data_rst(pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm);

void send_data(data_t *data, bool is_weight, pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm);

// conversion functions
void data_to_pinout(data_t *c, bool is_weight, pinout_t *p, size_t pl);

// init dma
uint init_wr_dma_channel(PIO pio, uint sm);

// start transfer
void start_wr_dma_pinout_stream(pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm);

#endif // _DATA_WR_UTILS

