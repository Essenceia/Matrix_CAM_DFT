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

This design has two parts: the 2x2 systolic MAC accelerator and the JTAG TAP allowing for MAC usage debugging,
and diagnosing PCB connection issues. 
 
# MAC 

## Introduction 

The goal of the MAC accelerator is to perform a matrix matrix multiplication between the input data
matric I and the weight matrix W. 
```math
\begin{bmatrix} i_{0,0} & i_{1,0} \\
 i_{0,1} & i_{1,1} 
\end{bmatrix} 

\times 

\begin{pmatrix} e & f \\ g & h \end{pmatrix} = \begin{pmatrix} ae+bg & af+bh \\ ce+dg & cf+dh \end{pmatrix}
```


For faster multiplication we are using a booth radix4 algorythme with wallace trees, allowing us to 
perform both multiplication and addition in a signle cycle. 

If the result of the MAC operation `w*i + a` exeeds the ranges of the int8, they will be
clamped to `int8_min` and `int8_max`.

For data transfers to and from the chip the matrixes are faltened using the following mapping : 
```
    x                                                                                      
    ─────────────────────►                                                                 
y │ ┌──────────┬──────────┐                                                                
  │ │          │          │                                                                
  │ │          │          │                                                                
  │ │   0,0    │    1,0   │                  ┌──────────┬──────────┬──────────┬──────────┐ 
  │ │          │          │                  │          │          │          │          │ 
  │ │          │          │                  │          │          │          │          │ 
  │ ├──────────┼──────────┤     ───────►     │   0,0    │    1,0   │   0,1    │    1,1   │ 
  │ │          │          │                  │          │          │          │          │ 
  │ │          │          │                  │          │          │          │          │ 
  │ │   0,1    │    1,1   │                  └──────────┴──────────┴──────────┴──────────┘ 
  │ │          │          │                   ────────────────────────────────────────────►
  │ │          │          │                   t                                            
  ▼ └──────────┴──────────┘                                                                
```

Notes : 
- All reference to `cycles` bellow are clocked according to the `clk` pin. 
- Empty cycles, as in one of more cycles where `data_v_i` would go to low in the middle of
the transfer of both the input matrix and the weights are supported. 

## Sending data

This design doesn't feature on chip SRAM and has limited on chip memory.

Given weights have high spacial and temporal locallity, this design allows each weight 
to be configured per mac unit. This configuration can be re-used accross multiple matrixes. 

The intput matrix, on the other hand, is expected to be provided on each usage. 

### Configure weights

Configuring the weights takes 4 data transfer cycles, during which : 
- `data_v_i` is set to `1`
- `data_mode_i` is set to `0` indicating we are sending `weights`
- `data_i[7:0]` contains the weights
- `data_rst_addr_i` is set to `0`

### Sending the input matrix

Sending the input matrix takes 4 data transfer cycles, during which : 
- `data_v_i` is set to `1`
- `data_mode_i` is set to `1` indicating we are sending the input matrix
- `data_i[7:0]` contains the input data
- `data_rst_addr_i` is set to `0`

### Receiving result

When receiving a result the asic will drive the following pins during 
4 data transfer cycles : 
- `res_v_o` is set to `1`
- `res_o[7:0]` contains to result of the MAC operating for a single matrix coordinate


