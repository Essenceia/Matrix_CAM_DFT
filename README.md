# Multiply and accumulate matrix multiplier ASIC with design for test infracture

ASIC design for a 2x2 systolic matrix multiplier supporting multiply and accumulate
operations on int8 data alongside a design for test infrastructure to help debug
both usage and diagnose design issues in silicon. 


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
[ unused 7:4 ][ mac unit 3:1 ][ register id 1:0 ] 
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

