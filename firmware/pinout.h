#ifndef _PINNOUT_H
#define _PINNOUT_H

/* define pinnout to FPGA emulation */ 
#define BUS_CLK_PIN 28

#define DATA_W        8
#define DATA_BASE_PIN 0 
#define RES_BASE_PIN  8
#define CTRL_BASE_PIN 16

typedef struct __attribute__((packed)) {
	uint8_t data_i;
	uint8_t res_o;
	uint8_t valid_i : 1;
	uint8_t data_mode_i : 1;
	uint8_t data_rst_addr_i : 1;
	uint8_t ready_o : 1;
	uint8_t unusued : 3;
	uint8_t padding : 3; /* rpi-pico doesn't expose pins in order, after gpio 22 the next pin is gpio 26 */ 
	uint8_t res_valid_o : 1;
	uint8_t padding1 : 5;	
} pinout_t;

_Static_assert(sizeof(pinout_t) == (32/8));

/* data */ 
#define DATA_MASK (uint32_t) 0xFF

/* data ctrl */
#define CTRL_DATA_W 3
#define CTRL_DATA_MASK (uint32_t) 0x7
#define CTRL_DATA_BASE_PIN CTRL_BASE_PIN
#define CTRL_VALID_PIN CTRL_DATA_BASE_PIN 
#define CTRL_MODE_PIN  CTRL_DATA_BASE_PIN+1
#define CTRL_RST_PIN   CTRL_DATA_BASE_PIN+2

#define CTRL_RES_VALID_PIN 26

#define CTRL_DATA_MODE_WEIGHT 0x0
#define CTRL_DATA_MODE_DATA   0x1

#endif //_PINNOUT_H
