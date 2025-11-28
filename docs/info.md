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
- $i_{(t,y)}$ is a value from the $y$ row of the $I$ matrix that is circulated per timestep $t$ though a row of the matrix.
- $c_{(t-1,x,y-1)}$ is the result at the previous timestep $t-1$ of the mac unit above this MAC unit, circulated downwards per collum.
```math
c_{(t,x,y)} = i_{(t,y)} \times w_{(x,y)} + c_{(t-1,x,y-1)}
```

Given this accelerator was designed to operate on signed 8-bit integers, 
but that the successive application of the 8-bit multiplication and addition 
pushes the resulting value up to 17 bits, in order to prevent the size of the base datatype 
from increasing with each sucessive MAC operation, we need to clamp it down back within the 8-bit range.

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

This data streaming allows such designs to make more efficient use of data, re-using it multiple times as the data circulates through the array, contributing to the final results without spending time on expensive data accesses, allowing us to dedicate more of our silicon area and cycle to compute.

## Usage 

The typical sequence to outsource matrix operations to the accelerator would go as follows:
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

Given we are not sending an index alongside each data transfer to indicate which weight/data corrdinates ( index ) each data corresponds to, 
the MAC accelerator keeps track of the next index internaly. As such, if due to external reasons a partial transfer occures, it becomes necessary 
to reset this index using the reset sequence described bellow. 

The weights streaming indexes and the data streaming indexes can be reset independantly, each requires a single data
transfer cycle during which : 
- `data_v_i` is set to `1`
- `data_mode_i` is set to `0` if we are resetting the `weights` indexes, `0` to reset the data indexes
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

In this example we are configuring the the weigth matrix $W$ to : 
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
for {set u 0} {$u <= $USER_REG_UNIT_MAX} {incr u} {
    puts "read internal register $u : 0x[read_user_reg $_CHIPNAME $u 0] - [print_reg_id $r]"  
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
W = 
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
- `res_o[7:0]` contains to result of the MAC operating for a single matrix coordinate

#### Example

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

