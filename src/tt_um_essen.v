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
localparam BSC_CHAIN_W = 6; // bsc scan chain length 

/* IO direction */
assign uio_oe = 8'b1100_0000; 

/* unused IO */
wire [1:0] unused_input;
assign     unused_input = uio_in[7:6];
assign     uio_out[5:0] = 6'b0;  

/* I/O interface, marked for boundary scan insertion */ 
(* MARK_BSC = "in"  *) wire       data_v_bsc;
(* MARK_BSC = "in"  *) wire       data_mode_bsc; 
(* MARK_BSC = "in"  *) wire [7:0] data_bsc;
(* MARK_BSC = "out" *) wire       result_v_bsc;
(* MARK_BSC = "out" *) wire [7:0] result_bsc;

wire [BSC_CHAIN_W-1:0] bsp_chain;
wire bsp_tdo;
wire bsp_shift;
wire bsp_capture;
wire bsp_update;
wire bsp_mode; 

wire       data_v;
wire       date_mode; 
wire [7:0] data;
wire       result_v;
wire [7:0] result;

assign data_v_bsc    = uio_in[0];
assign data_mode_bsc = uio_in[1];
assign data_bsc      = ui_in;
assign uio_out[7]    = result_v_bsc;
assign uo_out        = result_bsc;

assign bsp_chain[0] = tdi;
assign bsp_tdo = bsp_chain[BSC_CHAIN_W-1];

bsc #(.W(1)) m_bsc_data_v_in(
	.data_i(data_v_bsc), .data_o(data_v),
	.scan_i(bsp_chain[0]), .scan_o(bsp_chain[1]),
	.shift_i(bsp_shift), .capture_i(bsp_capture), .update_i(bsp_capture), .mode_i(bsp_mode)
	);	

bsc #(.W(1)) m_bsc_data_mode_in(
	.data_i(data_mode_bsc), .data_o(data_mode),
	.scan_i(bsp_chain[1]), .scan_o(bsp_chain[2]),
	.shift_i(bsp_shift), .capture_i(bsp_capture), .update_i(bsp_capture), .mode_i(bsp_mode)
	);

bsc #(.W(8)) m_bsc_data_in(
	.data_i(data_bsc), .data_o(data),
	.scan_i(bsp_chain[2]), .scan_o(bsp_chain[3]),
	.shift_i(bsp_shift), .capture_i(bsp_capture), .update_i(bsp_capture), .mode_i(bsp_mode)
	);

bsc #(.W(1)) m_bsc_result_v_out(
	.data_i(result_v), .data_o(result_v_bsc),
	.scan_i(bsp_chain[3]), .scan_o(bsp_chain[4]),
	.shift_i(bsp_shift), .capture_i(bsp_capture), .update_i(bsp_capture), .mode_i(bsp_mode)
	);

bsc #(.W(8)) m_bsc_result_out(
	.data_i(result), .data_o(result_bsc),
	.scan_i(bsp_chain[4]), .scan_o(bsp_chain[5]),
	.shift_i(bsp_shift), .capture_i(bsp_capture), .update_i(bsp_capture), .mode_i(bsp_mode)
	);


/* DFT interface */ 
wire tck;
wire tdi;
wire tms; 
wire tdo;
wire trst; 

assign tck        = uio_in[2];
assign tdi        = uio_in[3];
assign tms        = uio_in[4];
assign trst       = uio_in[5] | ~rst_n;
assign uio_out[6] = tdo;


// input/output interface boundary scan 

// JTAG 

// CAM design
endmodule

