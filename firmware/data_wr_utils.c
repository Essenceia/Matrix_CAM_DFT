#include "data_wr_utils.h" 
#include "hardware/dma.h"
#include <string.h> 
#include <stdlib.h>

void send_data_rst(pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm){
	const size_t rl = 2;
	hard_assert(p);
	hard_assert(pl >= rl );
	memset(p, 0, sizeof(pinout_t)*rl);
	for(uint i=0; i < rl; i++){
		p[i].valid_i = 1; 
		p[i].data_mode_i = i;
		p[i].data_rst_addr_i = 1;
	} 
	start_wr_dma_pinout_stream(p, rl, dma_chan, pio, sm);
}


size_t data_to_pinout(data_t *c, bool is_weight, pinout_t *p, size_t pl)
{
	hard_assert(p);
	hard_assert(pl >= NN);
	memset(p, 0, sizeof(pinout_t)*NN);
	for(uint i=0; i < NN; i++)
	{
		p[i].data_i = c->data[i];
		p[i].valid_i = 1; 
		p[i].data_mode_i = is_weight? CTRL_DATA_MODE_WEIGHT: CTRL_DATA_MODE_DATA;
	}
	return NN; 
}

void send_data(data_t *data, bool is_weight,  pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm)
{
	hard_assert(data);
	size_t tcnt = data_to_pinout(data, is_weight, p, pl); 

	start_wr_dma_pinout_stream(p, tcnt, dma_chan, pio, sm);
}


/* setup dma channel for writing 32b bursts to the PIO TX FIFO 
 * ! not configuring : 
 * - read address 
 * - transder count 
 *   returns : configured dma channel*/
uint init_wr_dma_channel(PIO pio, uint sm)
{
   	uint dma_chan = dma_claim_unused_channel(true);
	dma_channel_config c = dma_channel_get_default_config(dma_chan);
	channel_config_set_read_increment(&c, true); // incremnet the addr we read to on each transfer
	channel_config_set_write_increment(&c, false); // allways write to TX FIFO of the same PIO	
	channel_config_set_dreq(&c, pio_get_dreq(pio, sm, true)); // trigger dreq when there is an empty entry in the TX FIFO
	channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
	dma_channel_set_write_addr(dma_chan, &pio->txf[sm], false);
	dma_channel_set_config(dma_chan, &c, false);
	return dma_chan; 
}
/* set up dma stream of data to pio
 * assumption: the pinout array is allocated continiously in memory */
void start_wr_dma_pinout_stream(pinout_t *p, size_t pl, uint dma_chan, PIO pio, uint sm)
{
	// stall until current dma transfer stream is finished
	dma_channel_wait_for_finish_blocking(dma_chan);
	while(pio_sm_get_tx_fifo_level(pio, sm)!=0){}	

	dma_channel_set_read_addr(dma_chan, p, false);
	dma_channel_set_transfer_count(dma_chan, pl, true);	
}
