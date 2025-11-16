/* 
 * Multiply accumulate systolic array configuration module
 *
 * This module contains the weight memory, would implement
 * the weight storage in SRAM if there was a proven SRAM MACRO
 * 
 * Julia Desmazes, 2025, this code is human made
 */

`timescale 1ns / 1ps

module mac_conf #(
	parameter W,
	parameter N,
	parameter CNT = N*N, // number of weights
	parameter ADDR = $clog2(CNT)
)(
	input clk, 
	input rst,

	input         wr_weight_v_i,
	input [W-1:0] wr_weight_i,
	input         wr_reset_addr_i, // toggled on data write
	
	input [ADDR-1:0] rd_weight_addr_i,
	output [W-1:0]   rd_weight_o
);
wire [ADDR-1:0] wr_addr;
reg  [ADDR-1:0] wr_addr_q;

reg [W-1:0] weight_q [CNT-1:0];
reg unused_addr_add;

always @(posedge clk) begin
	if (rst | wr_reset_addr_i) wr_addr_q <= {ADDR_W{1'b0}};
	else if (wr_weight_v_i) {unused_addr_add, wr_addr_q} <= wr_addr_q + {{ADDR_W-1{1'b0}}, 1'b1};

always @(posedge clk) begin
	if (wr_weight_v_i) weight_q[wr_addr_q] <= wr_weight_i;

/* read */ 
assign rd_weight_o = weight_q[rd_weight_addr_i]; 

endmodule
