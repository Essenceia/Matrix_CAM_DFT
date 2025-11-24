`timescale 1ns / 1ps
`default_nettype none 

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

localparam BSC_CHAIN_W = 7; // bsc scan chain length 
localparam UREG_DATA_W = 8;
localparam UREG_ADDR_W = 4;

/* IO direction, 0: input, 1: output */
assign uio_oe = 8'b1100_0000; 

/* unused IO */
wire [1:0] unused_input;
assign     unused_input = uio_in[7:6];
assign     uio_out[5:0] = 6'b0;  

/* I/O interface, marked for boundary scan insertion */ 
(* MARK_BSC = "in" , MARK_DEBUG = "true" *) wire       data_v_bsc;
(* MARK_BSC = "in" , MARK_DEBUG = "true" *) wire       data_mode_bsc; 
(* MARK_BSC = "in" , MARK_DEBUG = "true" *) wire       data_rst_bsc; 
(* MARK_BSC = "in" , MARK_DEBUG = "true" *) wire [7:0] data_bsc;
(* MARK_BSC = "out", MARK_DEBUG = "true" *) wire       result_v_bsc;
(* MARK_BSC = "out", MARK_DEBUG = "true" *) wire [7:0] result_bsc;

wire [BSC_CHAIN_W-1:0] bsc_chain;
wire bsc_tdo;
wire bsc_shift;
wire bsc_capture;
wire bsc_update;
wire bsc_mode; 

(* MARK_DEBUG = "true" *) wire       data_v;
wire       data_mode; 
wire       data_rst; 
wire [7:0] data;
wire       result_v;
wire [7:0] result;

assign data_v_bsc    = uio_in[1];
assign data_mode_bsc = uio_in[2];
assign data_rst_bsc  = uio_in[3];
assign data_bsc      = {uio_in[0], ui_in[7:1]};
assign uio_out[7]    = result_v_bsc;
assign uo_out        = result_bsc;

wire tck;
wire tdi;
wire tms; 
wire tdo;
wire trst; 

assign bsc_chain[0] = tdi;
assign bsc_tdo = bsc_chain[BSC_CHAIN_W-1];

bsc #(.W(1)) m_bsc_data_v_in(
	.tck(tck),
	.data_i(data_v_bsc), .data_o(data_v),
	.scan_i(bsc_chain[0]), .scan_o(bsc_chain[1]),
	.shift_i(bsc_shift), .capture_i(bsc_capture), .update_i(bsc_update), .mode_i(bsc_mode)
	);	

bsc #(.W(1)) m_bsc_data_mode_in(
	.tck(tck),
	.data_i(data_mode_bsc), .data_o(data_mode),
	.scan_i(bsc_chain[1]), .scan_o(bsc_chain[2]),
	.shift_i(bsc_shift), .capture_i(bsc_capture), .update_i(bsc_update), .mode_i(bsc_mode)
	);

bsc #(.W(1)) m_bsc_data_rst_in(
	.tck(tck),
	.data_i(data_rst_bsc), .data_o(data_rst),
	.scan_i(bsc_chain[2]), .scan_o(bsc_chain[3]),
	.shift_i(bsc_shift), .capture_i(bsc_capture), .update_i(bsc_update), .mode_i(bsc_mode)
	);


bsc #(.W(8)) m_bsc_data_in(
	.tck(tck),
	.data_i(data_bsc), .data_o(data),
	.scan_i(bsc_chain[3]), .scan_o(bsc_chain[4]),
	.shift_i(bsc_shift), .capture_i(bsc_capture), .update_i(bsc_update), .mode_i(bsc_mode)
	);

bsc #(.W(1)) m_bsc_result_v_out(
	.tck(tck),
	.data_i(result_v), .data_o(result_v_bsc),
	.scan_i(bsc_chain[4]), .scan_o(bsc_chain[5]),
	.shift_i(bsc_shift), .capture_i(bsc_capture), .update_i(bsc_update), .mode_i(bsc_mode)
	);

bsc #(.W(8)) m_bsc_result_out(
	.tck(tck),
	.data_i(result), .data_o(result_bsc),
	.scan_i(bsc_chain[5]), .scan_o(bsc_chain[6]),
	.shift_i(bsc_shift), .capture_i(bsc_capture), .update_i(bsc_update), .mode_i(bsc_mode)
	);


/* DFT interface */ 
assign tck        = ui_in[0]; // clk's can only be driven from the ui_in pins
assign tdi        = uio_in[4];
assign tms        = uio_in[5];
assign trst       = ~rst_n | ~ena; // there is no power gating, stall the design if not enabled
assign uio_out[6] = tdo;


// JTAG 
wire [UREG_ADDR_W-1:0] ureg_addr;
wire [UREG_DATA_W-1:0] ureg_data;

jtag #(.IR_W(3), 
	.VERSION_NUM(4'h1),
	.PART_NUM(16'hbeef),
	.MANIFACTURE_ID(11'h6b),// <-- do you get the joke ? 
	.UREG_ADDR_W(UREG_ADDR_W),
	.UREG_DATA_W(UREG_DATA_W)
	) m_jtag_tap (
	.rst_n(rst_n),
	.ena(ena), 

	.tck_i(tck),
	.tms_i(tms),
	.tdi_i(tdi),
	.trst_i(trst),
	.tdo_o(tdo),

	.bsc_shift_o(bsc_shift),
	.bsc_capture_o(bsc_capture),
	.bsc_update_o(bsc_update),
	.bsc_mode_o(bsc_mode),

	.bsc_tdo_i(bsc_tdo),

	.ureg_addr_o(ureg_addr),
	.ureg_data_i(ureg_data)
);

// MAC design
mac #(.W(8), .N(2)) m_2x2_systolic_mac(
	.clk(clk),
	.rst_n(rst_n), 
	.ena(ena),

	.data_v_i(data_v),
	.data_mode_i(data_mode),
	.data_rst_addr_i(data_rst),
	.data_i(data),

	.jtag_ureg_addr_i(ureg_addr),
	.jtag_ureg_data_o(ureg_data),

	.result_v_o(result_v),
	.result_o(result)
);

endmodule

