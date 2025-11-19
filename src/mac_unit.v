/* 
 * Multiply accumulate systolic array unit
 * 
 * Julia Desmazes, 2025, this code is human made
 */

`timescale 1ns / 1ps
`default_nettype none 

module mac_unit #(
	parameter W = 8
	)(
	input clk, 

	input         step_i, 
	
	input [W-1:0] data_i, //right side input data
	input [W-1:0] data_top_i, // top input data

	input         wr_weight_v_i,	
	input [W-1:0] weight_i, 

	output [W-1:0] data_o, // left side output data, will become the right side input data of the next unit leftwards
	output [W-1:0] res_o // result, become the top input data for the next unit bellow
); 

reg  [W-1:0] data_q, add_q;
reg  [W-1:0] weight_q;
wire [2*W-1:0] mul;
reg          unused_add;

always @(posedge clk) 
	if (step_i) data_q <= data_i;

always @(posedge clk) 
	if (step_i) add_q <= data_top_i; // critical path end 

always @(posedge clk) 
	if (wr_weight_v_i) weight_q <= weight_i;

booth_randix4_mul m_mul(
	.data_i(data_q),
	.w_i(weight_q),
	.res_o(mul)
);


assign {unused_add, res_o } = mul[W-1:0] + add_q;
assign data_o = data_q;

endmodule
