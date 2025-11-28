<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Multiply and accumulate matrix multiplier ASIC with design for test infrastructure

ASIC design for a 2x2 systolic matrix multiplier supporting multiply and accumulate
operations on int8 data alongside a design for test infrastructure to help debug
both usage and diagnose design issues in silicon.


# MAC 

This MAC accelerator operates at up to 50MHz and is capable of reaching up to 100MAC/s or 200MIOP/s.

## Background 

The goal of the MAC accelerator is to perform a matrix matrix multiplication between the input data
matrix $I$ and the weight matrix $W$. 
```math
\begin{gather}
I \times W = R \\
\begin{pmatrix} 
i_{0,0} & i_{1,0} \\
 i_{0,1} & i_{1,1} 
\end{pmatrix} 

\times 

\begin{pmatrix} 
w_{0,0} & w_{1,0} \\ 
w_{0,1} & w_{1,1} 
\end{pmatrix} = 

\begin{pmatrix} 
i_{0,0}w_{0,0}+i_{1,0}w_{0,1} & i_{0,0}w_{1,0}+i_{1,0}w_{1,1}\\ 
i_{0,1}w_{0,0}+i_{1,1}w_{0,1} & i_{0,1}w_{1,0}+i_{1,1}w_{1,1}\end{pmatrix}
\end{gather}
```
This MAC accelerator has 4 units and from this point on, we will refer to each MAC unit according to their unique $(x,y)$ coordinates. 

Each MAC unit calculates the MAC operation $c_{(t,x,y)}$, where :
- $w_{(x,y)}$ is the fixed weight configured for this unit; this value is fixed throughout a set of $I$ and $W$ input matrices.
- $i_{(t,y)}$ is a value from the $y$ row of the $I$ matrix that is circulated per timestep $t$ through a row of the matrix.
- $c_{(t-1,x,y-1)}$ is the result at the previous timestep $t-1$ of the mac unit above this MAC unit, circulated downwards per column.
```math
c_{(t,x,y)} = i_{(t,y)} \times w_{(x,y)} + c_{(t-1,x,y-1)}
```

Given this accelerator was designed to operate on signed 8-bit integers, 
but that the successive application of the 8-bit multiplication and addition 
pushes the resulting value up to 17 bits, in order to prevent the size of the base datatype 
from increasing with each successive MAC operation, we need to clamp it down back within the 8-bit range.

As such, the MAC unit performs an additional clamping function $clamp_{i8}$ that remaps :
```math
clamp_{i8}(c_{(t,x,y)}) = \begin{cases}
   127 &\text{if } c_{(t,x,y}) > 127\\
   c_{(t,x,y)} &\text{if } c_{(t,x,y)} \in [-128,127] \\
    -128 &\text{if } c_{(t,x,y}) < -128\\
\end{cases}
```

Our final full MAC operation is as follows : 
```math
c_{(t,x,y)} = clamp_{i8}(i_{(t,y)} \times w_{(x,y)} + c_{(t-1,x,y-1)})
```

At each MAC timestep $t+1$ :
- the result of a MAC unit $c_{(t,x,y)}$ is shifted downwards on the same column and becomes the input of the MAC unit $(x,y+1)$ below.
- $i_{(t,x)}$ is shifted rightwards and used as input to MAC unit $(x+1,y)$. 

This data streaming allows such designs to make more efficient use of data, re-using it multiple times as the data circulates through the array, contributing to the final results without spending time on expensive data accesses, allowing us to dedicate more of our silicon area and cycles to compute.

## Thoughput

Assuming a pre-configured $W$ weight matrix is being reused and the accelerator is receiving a gapless stream of multiple $I$ input matrices, this MAC accelerator is capable of computing up to 100 MMAC/s or 200 MIOPS/s.

### IO Bottleneck

Accelerator operations are stalled if a MAC operation has a data dependency on data that has yet to arrive. For example, calculating $r_{(0,0)}$ depends on both $i_{(0,0)}$​ and $i_{(1,0)}$​.
In practice, each operation depends on two pieces of input data, yet our input interface being only 8 bits wide allows us to transfer only a single $i_{(x,y)}$​ per cycle.

This limitation means our accelerator is actually operating at half maximum capacity due to this IO bottleneck. If the IO interface were either (a) at least 16 bits wide, or (b) 8 bits wide but operating at 100 MHz, resolving this bottleneck, our maximum throughput would be 200 MMAC/s or 400 MIOPS/s

## Usage 

The typical sequence to offload matrix operations to the accelerator would go as follows:
1. Reset the accelerator (necessary on init)
2. Configure the weights $W$ (can be re-used once configured)
3. Send the input data $I$
4. Read the result $R$

This design doesn't feature on-chip SRAM and has limited on-chip memory.
Given weights have high spatial and temporal locality, this design allows each weight to be configured per MAC unit. This configuration can be reused across multiple matrices.
The input matrix, on the other hand, is expected to be provided on each usage.

Given our input and output data buses are only 8 bits wide, for data transfers to and from the chip the matrices are flattened in the following order:

![flattened](flat.svg)

Notes:
- All references to `cycles` below are clocked according to the `clk` pin.
- Empty cycles, as in one or more cycles where `data_v_i` would go low in the middle of the transfer of both the input matrix and the weights, are supported.
  
### Resetting MAC 

Given we are not sending an index alongside each data transfer to indicate which weight/data coordinates ( index ) each data corresponds to, 
the MAC accelerator keeps track of the next index internally. As such, if due to external reasons a partial transfer occurs, it becomes necessary 
to reset this index using the reset sequence described below. 

The weights streaming indexes and the data streaming indexes can be reset independently, each requires a single data
transfer cycle during which : 
- `data_v_i` is set to `1`
- `data_mode_i` is set to `0` if we are resetting the `weights` indexes, `1` to reset the data indexes
- `data_i[7:0]` is ignored
- `data_rst_addr_i` is set to `1`

#### Example

In this example we are resetting both the data streaming index and the weight index back to back. 

![rst configuration timing diagram](rst_waves.png)

### Configure weights

Configuring the weights takes 4 data transfer cycles, during which : 
- `data_v_i` is set to `1`
- `data_mode_i` is set to `0` indicating we are sending `weights`
- `data_i[7:0]` contains the weights
- `data_rst_addr_i` is set to `0`

#### Example 

In this example we are configuring the the weight matrix $W$ to : 
```math
W = 
\begin{pmatrix} 
0 & 1 \\ 
2 & 3 
\end{pmatrix} 
```
![weights configuration timing diagram](wr_weights_waves.png)

#### Debug

The implemented JTAG TAP can be used to easily debug the weight matrix configuration sequence as it allows the user using the `USER_REG` instruction to 
read the currently configured weights for each MAC unit. 

In the existing openocd helper scripts located at `jtag/openocd.cfg` the `read_user_reg` can we used to read the weights using openocd when used as follows : 
```tcl
set r 0
for {set u 0} {$u <= $USER_REG_UNIT_MAX} {incr u} {
    puts "read internal register $u : 0x[read_user_reg $_CHIPNAME $u $r] - [print_reg_id $r]"  
}
```

For the $W$ weight matrix configured in the example above, the expected output should be : 
```
read internal register 0 : 0x00 - weight
read internal register 1 : 0x01 - weight
read internal register 2 : 0x02 - weight
read internal register 3 : 0x03 - weight
```

### Sending the input matrix

Sending the input matrix takes 4 data transfer cycles, during which : 
- `data_v_i` is set to `1`
- `data_mode_i` is set to `1` indicating we are sending the input matrix
- `data_i[7:0]` contains the input data
- `data_rst_addr_i` is set to `0`

#### Example

In this example we are sending the the input data matrix $I$ : 
```math
I = 
\begin{pmatrix} 
4 & 5 \\ 
6 & 7 
\end{pmatrix} 
```
![data configuration timing diagram](wr_data_waves.png)

### Receiving result

When receiving a result the asic will drive the following pins during 
4 data transfer cycles : 
- `res_v_o` is set to `1`
- `res_o[7:0]` contains the result of the MAC operation for a single matrix coordinate

Internally, the accelerator takes at most 4 cycles to produce a result operate on incomming data, this accounts for incomming data latching and circulating the data though the entire systolic array and output streaming. The accelerator moves the incomming data though the array as soon as it is available. Because of this, and since this accelerator supports gaps in the incomming data if that last data transfer of $i_{(1,1)}$ is delayed by at least 2 cycles, then the accelerator result will start streaming out before all of the input matrix has finished streaming in. 


If the user sends a gapless, uninterupted stream of input data, and re-uses the same weights, this accelerator is capable of up to 100MMAC/s or 200MIOPS/s. 


#### Simlpe example

In this example the $W$ MAC weight matrix is being configured and the $I$ data is being streamed in, following which, the $R$ result starts being sent out. 
```math
R = I \times W = 
\begin{pmatrix} 
4 & 5 \\ 
6 & 7 
\end{pmatrix}
\times
\begin{pmatrix} 
0 & 1 \\ 
2 & 3 
\end{pmatrix}
=
\begin{pmatrix} 
10 & 19 \\ 
14 & 27
\end{pmatrix}
```
![result streamout](rd_res_waves.png)

#### Complex example 

Internally, the accelerator takes at most 4 cycles to produce a result from incoming data. This accounts for incoming data latching, circulating the data through the entire systolic array, and output streaming. The accelerator moves the incoming data through the array as soon as it is available. Because of this, and since this accelerator supports gaps in the incoming data stream, if the last data transfer of $i_{(1,1)}$.

This is why, in the firmware (`firmware/main.c`), we set up the DMA stream to receive the data before we start sending the input matrix, as the gap between sending and getting the result is too small for the controlling MCU to perform any type of compute.

![none trivial read sequence](rd_res_complex_waves.png)
