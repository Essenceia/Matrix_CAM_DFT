<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Multiply and accumulate matrix multiplier ASIC with design for test infracture

ASIC design for a 2x2 systolic matrix multiplier supporting multiply and accumulate
operations on int8 data alongside a design for test infrastructure to help debug
both usage and diagnose design issues in silicon.

# MAC 

For faster multiplication we are using the booth radix4 algorythme with wallace trees. 

If the result of the MAC operation `w*i + a` exeeds the ranges of the int8, they will be
clamped to `int8_min` and `int8_max`.

