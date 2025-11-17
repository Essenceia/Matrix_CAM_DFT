# utils.py 
import cocotb
from cocotb.triggers import ClockCycles
import random 

N=2 # CAM array dimention 

# Dissable data transfert for "cycles" cycles.
# Used to simulate realistic conditions where the data transfer
# from the master (microcontroller, FPGA) would be done in bursts.
# Using the RP2040 this might occure when the PIO write sequence is
# stalled due to the DMA transfer no keeping up with the PIO write
# rate and the TX FIFO being empty. 
async def invalid_data(dut, cycles):
    for i in range(0, cycles):
        dut.uio_in.value = 0
        dut.ui_in.value = 0
        await ClockCycles(dut.clk,1)



# Generate data command configuration, sent allong each valid data
# transfer data cycle to convay metadata about the data. 
#
# --- MAC ---
#
# valid - 0 - data transfer contains valid information
#
# mode - 1
# value - meaning
#     0 - cam input data
#     1 - weight
#
# address rst - 2 - rst weight and data addresses
# 
# --- JTAG --- 
# tdi - 4 - input data 
# tms - 5 - fsm transition selection
#
def get_cmd(valid=True, mode=False, rst=False, tdi=False, tms=False):
    ret = 0
    if valid:
        ret |= 1
    if mode:
        ret |= 1 << 1
    if rst:
        ret |= 1 << 2
    if tdi:
        ret |= 1 << 4
    if tms: 
        ret |= 1 << 5

    return ret


# Configure weight values.
#
# In practice it is not necessary for the weight config to be 
# done before each MAC operation, the same weights can be re-used for
# multiple MAC operations.
#
# Data on the other hand must be re-sent for every configuration. If 
# we had more area and the macro we could store it in proximity to the 
# array. Since weights have better temporal locality, the tradeoff was
# made in favor of the weights. 
async def write_config(dut, X, weight=True):
    assert(len(X) == N*N) 
    config = bytearray(0)
    for x in X: 
        assert(x >= -128 and x <= 127)
        config.append(x)

    for i in range(0,N*N):
        if (random.randrange(0,100) > 75):
            await invalid_data(dut, random.randrange(1,5)) 
        dut.uio_in.value = get_cmd(valid=True, mode=weight)
        dut.ui_in.value = config[i]
        await ClockCycles(dut.clk,1)
    dut.uio_in.value = 0

async def rst_data_addr(dut):
    dut.uio_in.value = get_cmd(valid=True, mode=False, rst=True)
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = get_cmd(valid=True, mode=True, rst=True)
    await ClockCycles(dut.clk, 1)
