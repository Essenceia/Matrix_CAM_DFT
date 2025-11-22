# Cocotb testbench for testing the MAC and JTAG functions of this ASIC design
#
# Julia Desmazes, 2025, human made code

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

import random 
import mac_utils
import jtag_utils
import asyncio
from array import array 

N = 2 # matrix dimention 

# cover full range of i8
MIN_W = -128
MAX_W =  127
MIN_I = -128
MAX_I =  127

def start_clk(dut):
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start()) #runs the clock "in the background" 

def start_jtag_clk(dut):
    jtag_clk = Clock(dut.tck, 77, unit="us")
    cocotb.start_soon(jtag_clk.start())

# Reset sequence
async def rst(dut, ena=1, start_jtag=False):
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
    res = array('b', [0,0,0,0])
    assert(len(W) == N*N)
    assert(len(I) == N*N)
    for x in range(0,N):
        for y in range(0,N):
            for ix in range(0,N):
                tmp = res[y*N+x] + I[y*N+ix]*W[ix*N+x] 
                if (tmp >= 127):
                    tmp = 127
                if (tmp <= -128):
                    tmp = -128
                res[y*N+x] = tmp
    return res

async def read_res(dut):
    res = array('b')
       
    while (len(res) != N*N):
        if (dut.result_v.value == 1):
            x = dut.uo_out.value.to_signed()
            res.append(x)
        await ClockCycles(dut.clk, 1)
    
    return res 

async def compare_res(dut, W, I):
    expected = mac(W,I)
    res = await read_res(dut) 

    cocotb.log.info("expected vs got :")
    cocotb.log.info(' '.join(map(str, expected)))
    cocotb.log.info(' '.join(map(str, res)))
    
    assert(res == expected) 

# MAC tests 

@cocotb.test()
async def simple_mac_test(dut):
    await rst(dut) 
    W = array('b', [0, 1, 2, 3]) 
    I = array('b', [4, 5, 6, 7])

    await mac_utils.rst_data_addr(dut)

    # send weights 
    await mac_utils.write_config(dut, W, weight=True)

    # res can start comming in before all the data has been finished being written 
    comp_task = cocotb.start_soon(compare_res(dut, W, I))
        
    # send data
    write_task = cocotb.start_soon(mac_utils.write_config(dut, I , weight=False))
   
    await write_task
    await comp_task 
        
    await ClockCycles(dut.clk, 10)

@cocotb.test()
async def random_mac_test(dut):
    await rst(dut)
    await mac_utils.rst_data_addr(dut)
    for _ in range(0, 500): 
        W = array('b')
        I = array('b')
        for _ in range(0,4):
            W.append(mac_utils.biased_random(MIN_W,MAX_W))
            I.append(mac_utils.biased_random(MIN_I,MAX_I))


        # send weights 
        await mac_utils.write_config(dut, W, weight=True)
    
        # check result - results can start streaming before all the 
        # data has been written 
        comp_task = cocotb.start_soon(compare_res(dut, W, I))
        
        # send data
        write_task = cocotb.start_soon(mac_utils.write_config(dut, I , weight=False))
   
        await write_task
        await comp_task 

@cocotb.test()
async def random_mac_reuse_weights_test(dut):
    await rst(dut)
    await mac_utils.rst_data_addr(dut)
    for _ in range(0, 20): 
        W = array('b')
        for _ in range(0,4):
            W.append(mac_utils.biased_random(MIN_W,MAX_W))
        await mac_utils.write_config(dut, W, weight=True)

        for _ in range(0, 50): 
            I = array('b')
            for _ in range(0,4):
                I.append(mac_utils.biased_random(MIN_I,MAX_I))
    
            # check result - results can start streaming before all the 
            # data has been written 
            comp_task = cocotb.start_soon(compare_res(dut, W, I))
            # write data
            write_task = cocotb.start_soon(mac_utils.write_config(dut, I , weight=False))
   
            await write_task
            await comp_task 


# JTAG tests
# read out idcode 
async def jtag_read_idcode(dut):
    v, p, m = await jtag_utils.get_idcode(dut)
    assert(v == 1)
    assert(p == 0xbeef) 
    assert(m == 0x6b)

# test bypass mode ( required by spec ) 
async def jtag_test_bypass(dut):
    await jtag_utils.test_bypass(dut)

# test extest: bounday scan :) ( required by spec ) 
async def jtag_extest(dut):
    await jtag_utils.test_bsc(dut, extest=True)

# test sample preload: bounday scan :) ( also required by spec ) 
async def jtag_sample_preload(dut):
    await jtag_utils.test_bsc(dut, extest=False)

@cocotb.test()
async def jtag_simple_test(dut):
    await rst(dut, start_jtag=True)
    await jtag_utils.rst_jtag_tap(dut)
    await jtag_test_bypass(dut) # jtag ir is set to idcode by default, start with bypass test to increase verification coverage
    await jtag_read_idcode(dut)
    await jtag_extest(dut)
    await jtag_sample_preload(dut)

@cocotb.test()
async def jtag_random_test(dut):
    await rst(dut, start_jtag=True)
    await jtag_utils.rst_jtag_tap(dut)
    for _ in range(0, 100):
        ir = random.randint(0,3)
        match ir: 
            case 0:
                await jtag_test_bypass(dut) # jtag ir is set to idcode by default, start with bypass test to increase verification coverage
            case 1:
                await jtag_read_idcode(dut)
            case 2:
                await jtag_extest(dut)
            case 3:
                await jtag_sample_preload(dut)


@cocotb.test()
async def jtag_user_reg_test(dut):
    await rst(dut, start_jtag=True)
    await jtag_utils.rst_jtag_tap(dut)

    for _ in range(0, 20):
        W = array('b')
        I = array('b')
        for _ in range(0,4):
            W.append(mac_utils.biased_random(MIN_W,MAX_W))
            I.append(mac_utils.biased_random(MIN_I,MAX_I))

        # send weights 
        await mac_utils.write_config(dut, W, weight=True)
       
        for _ in range(0, 10): 
            first = True
            unit_next = random.randint(0,3)
             
            read_reg = await jtag_utils.scan_user_reg(dut, unit_next , 0, first)
            if not(first):
                cocotb.log.debug("read reg %s / %s", read_reg, W[0])
                assert(read_reg == W[unit])

            unit = unit_next
            first = False

