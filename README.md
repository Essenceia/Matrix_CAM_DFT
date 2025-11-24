# Multiply and accumulate matrix multiplier ASIC with design for test infracture

ASIC design for a 2x2 systolic matrix multiplier on GF180 supporting multiply and accumulate
operations on int8 data alongside a design for test infrastructure to help debug
both usage and diagnose design issues in silicon. 

# ASIC 

This accelerator was designed for the GF180nm node using the gf180mcuD PDK. It occupies 1127,83 µm² of 
die area and had an target typical operating volate of 3.3V at 25°C.

This design features two clock trees, one for the MAC and another for the JTAG TAP, the MAC clk targets 
a 50MHz operating frequency, and the JTAG 2MHz.


There are currently no know manifacturability issues. 

Current status: taped-in, in fabrication

# MAC 

This design features 4 MAC units performing a fused multiply and add operation (FMA) on 8 bit signed intergers.

This entire operation is computed in a single cycle at 50 MHz and a single rounding operation is performed on 
the final operation's results. 

## Frequency 

The 50MHz speed was chosen according to the maximum estimated reliable IO switching frequency and going above
this would have not resulted in any additional speedup given the IO data transfer and on chip storage bottlenecks.

## Multiplication

Each unit implements a booth radix4 multiplier. This multiplier design was chosen for it's low logic 
depth and reasonable area cost. Additionally, since we are going signed multiplication, we can remove
a level in wallace tree we are using for the partial product additions given we only have 4 partial 
products, unlike the 5 needed for unsigned operations.   

## Data access

This design stores a single 8 bit signed weight per MAC unit internally. The remaining of the input 
data must be circulated though the input parallel port on every use making IO this design's biggest 
bottleneck for this first generation. 

# DFT 

This design embeddes a JTAG for debugging the accelerators usage by probing into internal 
resisters and helping identify PCB issues using a bounday scan. 

This JTAG tap uses an instruction register lenght of `3`, was designed to operate at `2MHz`, has idcode `0x1beef0d7`,
and implements the following instructions : 

- `EXTEST` opcode `0x0` boundary scan  
- `IDCODE` opcode `0x1` reads jtag tap identifier
- `SAMPLE_PRELOAD` opcode `0x2` boundary scan 
- `USER_REG` opcode `0x3` probe internal registers
- `BYPASS` opcode `0x7` set the tap in bypass mode

All the four standard instructions `EXTEST`, `IDCODE`, `SAMPLE_PRELOAD`, `BYPASS` are conform to the 
standard behavior.


## Quickstart

For quickly getting started use the utilitaries provided `jtag/openocd.cfg`.

Given this default config assumes you are using an `jlink`, and this might not
be the adapter you are using, you may need to update the adapter sourcing your
current probe : 

```source [find interface/jlink.cfg]```

Run :
```
> openocd -f jtag/openocd.cfg
``` 

Expected output:
```
Open On-Chip Debugger 0.12.0+dev-02171-g11dc2a288 (2025-11-23-19:25)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : J-Link V10 compiled Jan 30 2023 11:28:07
Info : Hardware version: 10.10
Info : VTarget = 3.380 V
Info : clock speed 2000 kHz
Info : JTAG tap: tpu.tap tap/device found: 0x1beef0d7 (mfg: 0x06b (Transwitch), part: 0xbeef, ver: 0x1)
Warn : gdb services need one or more targets defined
idcode : 1beef0d7
read internal register 0:0 : 0x00 - weight
read internal register 0:1 : 0x00 - multiplicant ( input data )
read internal register 0:2 : 0x00 - summand ( input data )
...
```

## `USER_REG`

The `USER_REG` state we designed to probe into the data currently used by each of the 4 MAC units. 
The data to be read is specified by loading it's address in the data register during a pervious `DR_SHIFT` 
stage. As such, two sequences of `DR_SHIFTS` might be necessary: 
1. load the address of the next data
2. read the data off tdi

The address and data are both `8` bits wide, though only the bottom 4 bits of the address are used. 

### Address format 

The address uses the following format :
```
[ unused 7:4 ][ mac unit 3:2 ][ register id 1:0 ] 
```

Register id mapping, for this mac unit gives us the current : 
- `0x0` : weight ( multiplier ) 
- `0x1` : multiplicant ( circulated data ) 
- `0x2` : summand ( circulated data ) 
- `0x3` : mac operation overflow bits, used in rounding to the maxium representation range of the `int8_t`, discarded before the next max unit ( internal mac unit data ) 

## Usage 

When using the `USER_REG` custom JTAG TAP instruction the MAC logic is expected to be
temporarily halted, as in no weigth or data  update operations and no matrix compute is expected
to be ongoing. 
To this effect, there is no CDC protection when transfering data between the JTAG clock
domain and the MAC domain. If the MAC isn't halted the resulting metastability risks
corrupting the sampled data.

This also applies when doing a boundary scan. 

