/* 
 * Multiply accumulate systolic array unit
 * 
 * Julia Desmazes, 2025, this code is human made
 */

`timescale 1ns / 1ps

module mac_unit #(
	parameter W
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

reg  [W-1:0] data_q;
reg  [W-1:0] weight_q;
wire [W-1:0] unused_mul, mul;
reg          unused_add;

always @(posedge clk) 
	if (step_i) data_q <= data_i;
 
always @(posedge clk) 
	if (wr_weight_v_i) weight_q <= weight_i;

assign {unused_mul, mul} = data_q * weight_q;

assign {unused_add, res_o } = mul + data_top_i;
assign data_o = data_q;

endmodule
