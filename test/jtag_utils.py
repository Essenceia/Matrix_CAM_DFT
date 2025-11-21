# JTAG testing utils library 
#
# Julia Desmazes, 2025, human made code

import cocotb
from cocotb.triggers import ClockCycles
import random 

IDCODE = 1
IR_L = 3 

def get_cmd(tms=False, tdi=False):
    ret = 0
    if (tms):
        ret |= 1 << 5
    if (tdi):
        ret |= 1 << 4
    return ret 

# jtag tap is placed in rst after at least 5 TMS transitions
# then transition the fsm to idle
async def rst_jtag_tap(dut):
    x = random.randint(5, 20)
    for _ in range(0,x):
        dut.uio_in.value = get_cmd(tms=True)
        await ClockCycles(dut.tck, 1)
    
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)
   
   
# assumes we are starting our command from the idle position
async def set_ir(dut, ir, irl):
    # idle 
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
   
    # dr select
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
 
    # ir select 
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)
    
    # capture ir
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)
   
    # shift ir
    for i in range(0, irl):
        tdi = (ir >> i) & 0x1
        dut.uio_in.value = get_cmd(tms=(i == irl-1), tdi=(tdi == 1))
        await ClockCycles(dut.tck, 1)
    
    # exit 1r
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
    
    # update ir
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)

    # got back to idle
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)

# starting from idle, read the data register of length drl
async def read_dr(dut, drl):
    ret = 0
    
    # idle 
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
   
    # dr select
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)
 
    # capture dr
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)
   
    # shift dr
    for i in range(0, drl):
        tdo = dut.uio_out.value[6]
        ret |= int(tdo) << i
        dut.uio_in.value = get_cmd(tms=(i == drl-1), tdi=(tdi == 1))
        await ClockCycles(dut.tck, 1)
    
    # exit 1r
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
    
    # update dr
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)

    # got back to idle
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)
 
async def get_idcode(dut):
    await set_ir(dut, IDCODE, IR_L)
    return await read_dr(dut, 32)
