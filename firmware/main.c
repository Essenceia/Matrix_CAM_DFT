#include "pico/stdlib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pinout.h" 

#include "hardware/clocks.h"

#include "led.pio.h"
#include "bus_clk.pio.h"
#include "pio_utils.h" 

#define DELAY_MS 1000

#define PIO_N    2 // number of PIO SM used
#define PIO_LED  0
#define PIO_CLK  1
#define macro_str(x) #x

#define PICO_SYS_CLK_HW              200000000   // 200 MHz
#define BUS_PIO_CLK_FREQ_HZ  (float)  80000000.0 //  80 MHz
#define LED_PIO_CLK_FREQ_HZ  (float)  80000000.0 //  80 MHz

#define _DMA_BASE (uint32_t) 0x50000000
#define TC_OFF   (uint32_t) 0x008
#define TRANSFER_COUNT_ADDR (_DMA_BASE + TC_OFF)


#define log_init(PIO_IDX) printf(#PIO_IDX " init sucess %d:{%d:%d}", s, sm[PIO_IDX], offset[PIO_IDX]);
int main() {
	PIO pio[PIO_N];
	uint sm[PIO_N];
	uint offset[PIO_N];
	float clk_div; 
	uint led = 1;
	pinout_t *p;
	bool s = true;

	// set system clk
	set_sys_clock_hz(PICO_SYS_CLK_HW, true);
	
	stdio_init_all();
	
	/* bus clk */
	s &= pio_claim_free_sm_and_add_program_for_gpio_range(
		&bus_clk_program, 
		&pio[PIO_CLK], &sm[PIO_CLK], &offset[PIO_CLK],
		BUS_CLK_PIN, 1, true);
	log_init(PIO_CLK);
	hard_assert(s);
	clk_div = (float)clock_get_hz(clk_sys) / (BUS_PIO_CLK_FREQ_HZ); 
	bus_clk_program_init(pio[PIO_CLK], sm[PIO_CLK], offset[PIO_CLK], BUS_CLK_PIN, clk_div);

	/* led - explicitlt place on PIO0 to prevent overwritting of GPIO25 by `pull noblock` on data_wr*/
	s = allocate_prog_pio(0, &pio[PIO_LED], &sm[PIO_LED], &offset[PIO_LED], &led_program);
	log_init(PIO_LED);
	hard_assert(s);
	led_program_init(pio[PIO_LED], sm[PIO_LED], offset[PIO_LED], PICO_DEFAULT_LED_PIN, clk_div);	

	while (true) {
		sleep_ms(DELAY_MS);
		pio_sm_put_blocking(pio[PIO_LED], sm[PIO_LED], led);
		led = led ? 0:1;
    }
}
