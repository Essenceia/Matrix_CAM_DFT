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
        dut.uio_in.value = get_cmd(tms=(i == drl-1))
        await ClockCycles(dut.tck, 1)
        tdo = dut.uio_out.value[6]
        ret |= int(tdo) << i 
    # exit 1r
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
    
    # update dr
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)

    # got back to idle
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)

    return ret

# decode and pretty print idcode format 
# { version 4b, part_num 16b, manifacturer_id 11b, 1'b1 }
#
def decode_idcode(idcode):
    assert(idcode & 0x1)
    idcode = idcode >> 1
    manif = idcode & 0x7ff
    idcode = idcode >> 11
    part = idcode & 0xffff
    idcode = idcode >> 16
    v = idcode & 0xf
    return v, part, manif

def pretty_print_idcode(v, part, manif):
    cocotb.log.info("idcode: { version %s, part num %s, manifacturer id %s}", hex(v), hex(part), hex(manif))

async def get_idcode(dut):
    await set_ir(dut, IDCODE, IR_L)
    cocotb.log.info("start read dr")
    idcode = await read_dr(dut, 32)
    v, p, m = decode_idcode(idcode)
    pretty_print_idcode(v,p,m)
    return v,p, m
