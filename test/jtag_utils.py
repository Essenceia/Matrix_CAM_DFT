# JTAG testing utils library 
#
# Julia Desmazes, 2025, human made code

import cocotb
from cocotb.triggers import ClockCycles
import random 

IDCODE = 1
BYPASS = 7
IR_L = 3 

# number of input and output pins
PIN_IN_N = 11
PIN_OUT_N = 9

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
async def set_ir(dut, ir, irl=IR_L):
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

async def test_bypass(dut):
    await set_ir(dut, BYPASS)

    # go to shift dr mode
    
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
    x = random.randint(2, 50)
    tdi_buffer = bytearray(0)
    tdo_buffer = bytearray(0)
    # write tdi in and tdo
    for i in range(0, x):
        tdi = random.randint(0,1)
        if i != x-1:
            tdi_buffer.append(tdi)
        dut.uio_in.value = get_cmd(tms=(i == x-1), tdi=(tdi == 1))
        await ClockCycles(dut.tck, 1)
        tdo = dut.uio_out.value[6]
        if i :
            # lose first byte
            tdo_buffer.append(tdo)
   
    # check bypass results, input should match output
    cocotb.log.info("tdi %s", tdi_buffer)
    cocotb.log.info("tdo %s", tdo_buffer)
    assert(tdi_buffer == tdo_buffer) 
 
     # exit 1r
    dut.uio_in.value = get_cmd(tms=True)
    await ClockCycles(dut.tck, 1)
    
    # update dr
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)

    # got back to idle
    dut.uio_in.value = get_cmd(tms=False)
    await ClockCycles(dut.tck, 1)


def set_random_input_pin_data(dut):
    pin_i = bytearray(PIN_IN_N)
    for i in range(0, PIN_IN_N):
        pin_i.append(random.randint(0,1))
    io_v = 0
    io_v |= (pin_i[2] << 2| pin_i[1]<< 1 | pin_i[0]) << 1
    io_v |= pin_i[3] # data_i[0]
    i_v = 0 
    i_v |= pin_i[10] << 7 | pin_i[9] << 6 |pin_i[8] << 5 |pin_i[7] << 4 | pin_i[6] << 3 | pin_i[5] << 2 | pin_i[4] << 1
    return i_v, io_v 
    
async def test_extest(dut):
    # set data on the input pins to a known state
    ui_in , uio_in = set_random_input_pin_data(dut)
