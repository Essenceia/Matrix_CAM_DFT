import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

import random 
import utils

N = 2 # matrix dimention 

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


def mac(W,I):
    res = bytearray(N*N)
    assert(len(W) == N*N)
    assert(len(I) == N*N)
    for x in range(0,N):
        for y in range(0,N):
            for ix in range(0,N):
                res[y*N+x] += I[y*N+ix]*W[ix*N+x]
    return res

async def read_res(dut):
    res = b''
       
    while (len(res) != N*N):
        if (dut.result_v.value == 1):
            x = dut.uo_out.value.to_unsigned()
            res = res + bytes([x])
        await ClockCycles(dut.clk, 1)
    
    cocotb.log.info("res :")
    cocotb.log.info(' '.join(map(str, res)))
    return res 

async def compare_res(dut, W, I):
    expected = mac(W,I)
    res = await read_res(dut) 
    assert(res == expected) 

@cocotb.test()
async def simple_mac_test(dut):
    await rst(dut) 
    W = bytearray([0, 1, 2, 3]) 
    I = bytearray([4, 5, 6, 7])

    await utils.rst_data_addr(dut)

    # send weights 
    await utils.write_config(dut, W, weight=True)

    # res can start comming in before all the data has been finished being written 
    compare_res(dut, W, I) 

    # send data
    await utils.write_config(dut, I , weight=False)

    await ClockCycles(dut.clk, 10)

@cocotb.test()
async def random_mac_test(dut):
    await rst(dut)
    await utils.rst_data_addr(dut)
    for _ in range(0, 50): 
        W = b''
        I = b''
        for _ in range(0,4):
            W = W + bytes([random.randrange(0,10)])
            I = I + bytes([random.randrange(0,10)])


        # send weights 
        await utils.write_config(dut, W, weight=True)
    
        # check result - results can start streaming before all the 
        # data has been written 
        compare_res(dut, W, I) 
        
        # send data
        await utils.write_config(dut, I , weight=False) 


@cocotb.test()
async def random_mac_reuse_weights_test(dut):
    await rst(dut)
    await utils.rst_data_addr(dut)
    for _ in range(0, 10): 
        W = b''
        for _ in range(0,4):
            W = W + bytes([random.randrange(0,10)])
        await utils.write_config(dut, W, weight=True)

        for _ in range(0, 10): 
            I = b''
            for _ in range(0,4):
                I = I + bytes([random.randrange(0,10)])
    
            # check result - results can start streaming before all the 
            # data has been written 
            compare_res(dut, W, I) 
            
            # send data
            await utils.write_config(dut, I , weight=False) 
