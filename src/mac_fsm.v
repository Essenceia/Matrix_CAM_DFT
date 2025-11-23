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
	input wire clk, 
	input wire rst_n, 
	input wire ena,

	input wire data_v_i, 
	input wire data_mode_i, 
	input wire data_rst_addr_i,

	output wire [NN-1:0] wr_weight_v_o,
	output wire [N-1:0]  wr_data_v_o,

	output wire mac_step_o, // cam step through 

	output wire [N-1:0] res_rd_o,
	output wire [N-1:0] res_wr_o // output streaming

);
localparam MODE_DATA   = 1'b0;
localparam MODE_WEIGHT = 1'b1;

/* weight write logic */
wire wr_weight_v;
reg [NN-1:0] wr_weight_pos_q;

assign wr_weight_v = data_v_i & (data_mode_i == MODE_WEIGHT) & ~data_rst_addr_i;
always @(posedge clk) 
	if (~rst_n |  data_rst_addr_i ) wr_weight_pos_q <= {{NN-1{1'b0}}, 1'b1};
	else if (wr_weight_v) wr_weight_pos_q <= { wr_weight_pos_q[NN-2:0], wr_weight_pos_q[NN-1]};

assign wr_weight_v_o = {NN{wr_weight_v}} & wr_weight_pos_q;

/* data write logic */
wire        wr_data_v;
reg [N-1:0] wr_data_pos_q;
reg         unused_add_q;

assign wr_data_v = data_v_i & (data_mode_i == MODE_DATA) & ~data_rst_addr_i;
always @(posedge clk) 
	if (~rst_n | data_rst_addr_i ) wr_data_pos_q <= {N{1'b0}};
	else if (wr_data_v) {unused_add_q, wr_data_pos_q} <= wr_data_pos_q + {{N-1{1'b0}}, 1'b1};

/* N dimention dependant logic 
 *
 * MAC steps */
reg last_step_q;
reg mac_step_q;
reg en_q;
always @(posedge clk) 
	en_q <= ena;

assign wr_data_v_o = { wr_data_pos_q[0], ~wr_data_pos_q[0]};
always @(posedge clk) 
	if (~rst_n) last_step_q <= 1'b0;
	else last_step_q <= wr_data_v & (wr_data_pos_q == 2'd3); 

always @(posedge clk) 
	if (en_q)  begin
		mac_step_q <= wr_data_v & wr_data_pos_q != 2'd1 | last_step_q;
	end

assign mac_step_o = mac_step_q;

/* Capture MAC output control */ 
reg [1:0] rd_fsm_q; 
localparam RD_IDLE = 2'd0;
localparam RD_0    = 2'd1; 
localparam RD_1_2  = 2'd2; 
localparam RD_3    = 2'd3;

reg [N-1:0] res_rd_q;

always @(posedge clk) begin
	if (~rst_n | data_v_i & data_rst_addr_i) begin
		rd_fsm_q <= RD_IDLE; 
	end else begin
		case(rd_fsm_q) 
			RD_IDLE: rd_fsm_q <= wr_data_v & wr_data_pos_q == 2'b10 ? RD_0: RD_IDLE; 
			RD_0: begin
			   rd_fsm_q <= mac_step_q ? RD_1_2 : RD_0;
			   res_rd_q <= {1'b0, mac_step_q};
			end
			RD_1_2: begin
				rd_fsm_q <= mac_step_q ? RD_3: RD_1_2;
				res_rd_q <= {mac_step_q, mac_step_q};
			end
			RD_3: begin
				rd_fsm_q <= RD_IDLE;
				res_rd_q <= {mac_step_q, 1'b0};
			end
		endcase
	end
end

assign res_rd_o = res_rd_q; 

/* stream captured output to IO */
reg [N-1:0] res_wr_q;
reg [2:0] wr_fsm_q; 
localparam WR_IDLE = 3'd0;
localparam WR_0    = 3'd1; 
localparam WR_1    = 3'd2; 
localparam WR_2    = 3'd3; 
localparam WR_3    = 3'd4;

always @(posedge clk) begin
	if (~rst_n | data_v_i & data_rst_addr_i) begin
		wr_fsm_q <= WR_IDLE; 
	end else begin
		case(wr_fsm_q) 
			WR_IDLE: begin 
				wr_fsm_q <= (rd_fsm_q == RD_0) ? WR_0: WR_IDLE; 
				res_wr_q <= 2'b00;
			end
			WR_0: begin
			   wr_fsm_q <= (rd_fsm_q == RD_1_2) & mac_step_q ? WR_1 : WR_0;
			   res_wr_q <= res_rd_q; // 2'b01
			end
			WR_1: begin
				wr_fsm_q <= (rd_fsm_q == RD_3) & mac_step_q ? WR_2: WR_1;
				res_wr_q <= {mac_step_q , 1'b0};
			end
			WR_2: begin
				wr_fsm_q <= WR_3;
				res_wr_q <= 2'b01;
			end			
			WR_3: begin
				wr_fsm_q <= WR_IDLE;
				res_wr_q <= 2'b10;
			end
			default: begin 
				wr_fsm_q <= WR_IDLE;
				res_wr_q <= 2'b00;
			end
		endcase
	end
end

assign res_wr_o = res_wr_q; 

endmodule
