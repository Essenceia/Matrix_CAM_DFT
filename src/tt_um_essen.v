`timescale 1ns / 1ps

module tt_um_essen(
	input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
); 
localparam MODE_DATA   = 1'b0;
localparam MODE_WEIGHT = 1'b1;

/* data interface */ 
(* MARK_BSC = "true" *) wire [7:0] data;
(* MARK_BSC = "true" *) wire [7:0] result;
(* MARK_BSC = "true" *) wire       result_v;
(* MARK_BSC = "true" *) wire       data_v;
(* MARK_BSC = "true" *) wire       date_mode; 

assign data       = ui_in;
assign uo_out     = result;
assign data_v     = uio_in[0];
assign data_mode  = uio_in[1];
assign uio_out[7] = result_v;

/* DFT interface */ 
wire tck;
wire tdi;
wire tms; 
wire tdo; 

assign tck        = uio_in[2];
assign tdi        = uio_in[3];
assign tms        = uio_in[4];
assign uio_out[5] = tdo;

assign uio_oe = 8'b1010_0000; 

// input/output interface boundary scan 

// JTAG 

// CAM design
endmodule

