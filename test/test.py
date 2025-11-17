import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import utils

def start_clk(dut):
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start()) #runs the clock "in the background" 

def start_jtag_clk(dut):
    jtag_clk = Clock(dut.dut.tck, 100, unit="us")
    cocotb.start_soon(jtag_clk.start())

# Reset sequence
async def rst(dut, ena=1, start_jtag=0):
    dut.rst_n.value = 0
    start_clk(dut)
    if start_jtag:
        start_jtag_clk(dut)
    await ClockCycles(dut.clk, 2)
    # set default io
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.ena.value = ena
    await ClockCycles(dut.clk,10)

# utils 

# send weights to cam array 

@cocotb.test()
async def simple_cam_test(dut):
    await rst(dut) 

    await utils.rst_data_addr(dut)

    # send weights 
    await utils.write_config(dut, bytearray([0, 1, 2,3]), weight=True)
    # send data
    await utils.write_config(dut, bytearray([4, 5, 6, 7]), weight=False)

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 100)

