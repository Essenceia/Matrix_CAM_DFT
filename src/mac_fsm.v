/* 
 * Multiply accumulate systolic array top of size NxN FSM
 * 
 * Orchastrates the MAC behavior
 * 
 * Julia Desmazes, 2025, this code is human made
 */

`timescale 1ns / 1ps

module mac_fsm #(
	parameter N = 2,
	parameter NN = N*N
)(
	input clk, 
	input rst_n, 
	input ena,

	input data_v_i, 
	input data_mode_i, 
	input data_rst_addr_i,

	output [NN-1:0] wr_weight_v_o,
	output [N-1:0]  wr_data_v_o,

	output mac_step_o // cam step through 

);
localparam MODE_DATA   = 1'b0;
localparam MODE_WEIGHT = 1'b1;

/* weight write logic */
wire wr_weight_v;
reg [NN-1:0] wr_weight_pos_q;

assign wr_weight_v = data_v_i & (data_mode_i == MODE_WEIGHT);
always @(posedge clk) 
	if (~rst_n | wr_weight_v & data_rst_addr_i ) wr_weight_pos_q <= {{NN-1{1'b0}}, 1'b1};
	else if (wr_weight_v) wr_weight_pos_q <= { wr_weight_pos_q[NN-2:0], wr_weight_pos_q[NN-1]};

assign wr_weight_v_o = {NN{wr_weight_v}} & wr_weight_pos_q;

/* data write logic */
wire        wr_data_v;
reg [N-1:0] wr_data_pos_q;
reg         unused_add_q;

assign wr_data_v = data_v_i & (data_mode_i == MODE_DATA);
always @(posedge clk) 
	if (~rst_n | wr_data_v & data_rst_addr_i ) wr_data_pos_q <= {N{1'b0}};
	else if (wr_data_v) {unused_add_q, wr_data_pos_q} <= wr_data_pos_q + {{N-1{1'b0}}, 1'b1};

/* N dimention dependant logic */
reg last_step_q;
reg mac_step_q;
reg en_q;
always @(posedge clk) 
	en_q <= ena;

assign wr_data_v_o = { wr_data_pos_q[N-1], ~wr_data_pos_q[N-1]};
always @(posedge clk) 
	if (~rst_n) last_step_q <= 1'b0;
	else last_step_q <= wr_data_v & wr_data_pos_q == NN-1; 

always @(posedge clk) 
	if (en_q)  begin
		mac_step_q <= wr_data_v & wr_data_pos_q != 2'd1 | last_step_q;
	end

assign mac_step_o = mac_step_q;
endmodule
