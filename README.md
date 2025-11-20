# Multiply and accumulate matrix multiplier ASIC with design for test infracture

ASIC design for a 2x2 systolic matrix multiplier supporting multiply and accumulate
operations on int8 data alongside a design for test infrastructure to help debug
both usage and diagnose design issues in silicon. 


## Using JTAG 

When using the `USER_REG` custom JTAG TAP instruction the MAC logic is expected to be
temporarily halted, as in no weigth or data  update operations and no matrix compute is expected
to be ongoing. 
To this effect, there is no CDC protection when transfering data between the JTAG clock
domain and the MAC domain. If the MAC isn't halted the resulting metastability risks
corrupting the sampled data.

This also applies when doing a boundary scan. 
