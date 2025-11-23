/* 
 * Multiply accumulate systolic array top of size NxN
 * 
 * Julia Desmazes, 2025, this code is human made
 */

`timescale 1ns / 1ps

module mac #(
	parameter W = 8, // data and weight width
	parameter N = 2, // matrix dimention
	parameter UREG_ADDR = 4 
)(
	input wire clk, 
	input wire rst_n,
	input wire ena,
	
	input wire         data_v_i,
	input wire         data_mode_i,
	input wire         data_rst_addr_i,
	input wire [W-1:0] data_i, 

	input wire  [UREG_ADDR-1:0] jtag_ureg_addr_i, 
	output wire [W-1:0]         jtag_ureg_data_o,

	output wire         result_v_o, 
	output wire [W-1:0] result_o
);
localparam NN = N*N;
genvar x,y; 

/* FSM */
logic [NN-1:0] wr_weight_v_flat; // limited support for multidimentional array in the simulator 
logic          wr_weight_v[N-1:0][N-1:0];
logic [N-1:0]  wr_data_v;
reg   [W-1:0]  data_input_q[N-1:0];
logic          mac_step; 
logic [N-1:0]  res_rd, res_wr;

mac_fsm #(.N(N), .NN(NN)) m_fsm(
	.clk(clk),
	.rst_n(rst_n),
	.ena(ena),

	.data_v_i(data_v_i),
	.data_mode_i(data_mode_i),
	.data_rst_addr_i(data_rst_addr_i),

	.wr_weight_v_o(wr_weight_v_flat),
	.wr_data_v_o(wr_data_v),
	
	.mac_step_o(mac_step),

	.res_rd_o(res_rd),
	.res_wr_o(res_wr)
);
generate 
	for(x=0; x<N; x=x+1) begin: g_wr_weight_v_x
		for(y=0; y<N; y=y+1) begin: g_wr_weight_v_y
			assign wr_weight_v[x][y] = wr_weight_v_flat[y*N+x];
		end
	end
	for(y=0; y<N; y=y+1) begin: g_wr_data_y
		always @(posedge clk) 
			if (wr_data_v[y])data_input_q[y] <= data_i;
	end
endgenerate

/* Systolic array */ 

logic [W-1:0] data_unit[N-1:0][N-1:0];
logic [W-1:0] data_flow_right[N-1:0][N-1:0];
logic [W-1:0] data_top_unit[N-1:0][N-1:0];
logic [W-1:0] res_unit[N-1:0][N-1:0];

logic [W-1:0] jtag_ureg_data[NN-1:0];

generate 
	for(y=0; y<N; y=y+1) begin: g_data_unit
		assign data_unit[0][y] = data_input_q[y];
		for(x=1; x<N; x=x+1) begin: g_data_unit_flow
			assign data_unit[x][y] = data_flow_right[x-1][y];
		end
	end

	/* data top */
	for(x=0; x < N; x=x+1) begin: g_data_top_x
		assign data_top_unit[x][0] = {W{1'b0}};
		for(y=1; y < N; y=y+1) begin: g_data_top_y
			assign data_top_unit[x][y] = res_unit[x][y-1];
		end		
	end

	for(x=0; x < N; x=x+1) begin: g_unit_x
		for(y=0; y < N; y=y+1) begin: g_unit_y
			mac_unit #(.W(W)) m_unit(
				.clk(clk),
			
				.step_i(mac_step),
	
				.data_i(data_unit[x][y]),
				.data_top_i(data_top_unit[x][y]),

				.wr_weight_v_i(wr_weight_v[x][y]),	
				.weight_i(data_i),

				.jtag_ureg_addr_i(jtag_ureg_addr_i[1:0]),
				.jtag_ureg_data_o(jtag_ureg_data[y*N+x]),

				.data_o(data_flow_right[x][y]),
				.res_o(res_unit[x][y])
			);		
		end
	end
endgenerate
wire [W-1:0] debug_res0, debug_res1, debug_res2, debug_res3; 
assign debug_res0 = res_unit[0][0]; 
assign debug_res1 = res_unit[1][0]; 
assign debug_res2 = res_unit[0][N-1]; 
assign debug_res3 = res_unit[1][N-1];

// capturing result for streamout
reg [W-1:0] res_stream_q[N-1:0];

// given the res is the critical path, we can't bypass this flop
generate 
	for (x=0; x<N; x=x+1) begin: g_res_capture
		always @(posedge clk) 
			if (res_rd[x])res_stream_q[x] <= res_unit[x][N-1];
	end
endgenerate


// Result output
assign result_v_o = |res_wr;
assign result_o = res_wr[1] ? res_stream_q[1]: res_stream_q[0];


// JTAG user register access
assign jtag_ureg_data_o = jtag_ureg_data[jtag_ureg_addr_i[3:2]]; 
endmodule

