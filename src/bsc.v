/* 
 * BSC - Basic Boundary Scan Cell 
 * Used for JTAG boundary scanning 
 *
 * modules 
 * bsc: configurable wrapped for W wide data
 * bsc_inner: bsc implementation, single bit wide data
 *
 * Julia Desmazes, 25, this code is humman made
 */

`timescale 1ns / 1ps

module bsc #(
	parameter W = 1
	)(
	input wire tck,

	input wire  [W-1:0] data_i,
	output wire [W-1:0] data_o,

	input wire  scan_i, 
	output wire scan_o,

	input wire  shift_i,   // Shift DR
	input wire  capture_i, // Capture DR
	input wire  update_i,  // Update DR
	input wire  mode_i
);

wire [W-1:0] chain;
wire [W-1:0] scan_next; 

genvar i;
generate
	for (i=0; i<W; i=i+1) begin: g_bsp_inner
		if ( i == 0 )
			assign chain[i] = scan_i;
		else
			assign chain[i] = scan_next[i-1];

		bsc_inner m_inner(
			.tck(tck),

			.data_i(data_i[i]),
			.data_o(data_o[i]),

			.scan_i(chain[i]),
			.scan_o(scan_next[i]),

			.shift_i(shift_i),
			.capture_i(capture_i),
			.update_i(update_i),
			.mode_i(mode_i)
		);
	end
endgenerate

assign scan_o = scan_next[W-1];

endmodule 

module bsc_inner(
	input wire  tck,

	input wire  data_i, 
	output wire data_o,

	input wire  scan_i, 
	output wire scan_o,
	
	input wire  shift_i,   // Shift DR
	input wire  capture_i, // Capture DR
	input wire  update_i,  // Update DR
	input wire  mode_i
);
wire ff_1_next, ff_2_next;
reg  ff_1_q, ff_2_q;

assign ff_1_next = shift_i ? scan_i: data_i;
assign ff_2_next = ff_1_q;

always @(posedge tck)
	if (capture_i) ff_1_q <= ff_1_next;

always @(posedge tck)
	if (update_i) ff_2_q <= ff_2_next;

assign scan_o = ff_1_q; 
assign data_o = mode_i ? ff_2_q : data_i; 
 
endmodule


