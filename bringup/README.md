# Silicon bringup 

![workbench](bringup.webp)

## JTAG

JTAG TAP just works !? 

Running jtag test script using openOCD: 
```
openocd -f openocd.cfg
```

Output: 
```		
[pitchu](master) ~/rtl/mac_dft/jtag >openocd -f openocd.cfg
Open On-Chip Debugger 0.12.0+dev-02429-ge4c49d860 (2026-03-17-19:44)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : J-Link V10 compiled Jan 30 2023 11:28:07
Info : Hardware version: 10.10
Info : VTarget = 3.303 V
Info : clock speed 2000 kHz
Info : JTAG tap: tpu.tap tap/device found: 0x1beef0d7 (mfg: 0x06b (Transwitch), part: 0xbeef, ver: 0x1)
Warn : gdb services need one or more targets defined
idcode : 1beef0d7
read internal register 0:0 : 0xf1 - weight
read internal register 0:1 : 0xf9 - multiplicant ( input data )
read internal register 0:2 : 0x00 - summand ( input data )
read internal register 0:3 : 0x00 - operation overflow bits
read internal register 1:0 : 0x8a - weight
read internal register 1:1 : 0x00 - multiplicant ( input data )
read internal register 1:2 : 0x00 - summand ( input data )
read internal register 1:3 : 0x00 - operation overflow bits
read internal register 2:0 : 0x27 - weight
read internal register 2:1 : 0x25 - multiplicant ( input data )
read internal register 2:2 : 0x5f - summand ( input data )
read internal register 2:3 : 0x06 - operation overflow bits
read internal register 3:0 : 0x78 - weight
read internal register 3:1 : 0x81 - multiplicant ( input data )
read internal register 3:2 : 0x7f - summand ( input data )
read internal register 3:3 : 0xc4 - operation overflow bits
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
```

