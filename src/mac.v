/* 
 * Multiply accumulate systolic array top of size NxN
 * 
 * Julia Desmazes, 2025, this code is human made
 */

`timescale 1ns / 1ps

module mac #(
	parameter W, // data and weight width
	parameter N  // matrix dimention
)(
	input clk, 
	
	input data_v_i,
	input data_mode_i,
	input data_reset_addr_i,
	input [W-1:0] data_i, 

	output result_v_o, 
	output [W-1:0] result_o
);
reg  [W-1:0] weight_input_q[N-1:0];
reg  [W-1:0] data_input_q[N-1:0];
wire [W-1:0] data_uint[N-1:0][N-1:0];
wire [W-1:0] res_uint[N-1:0][N-1:0];
wire [W-1:0] data_top_unit[N-1:0][N-1:0];

genvar x,y; 
generate 
	for(y=0; y<N; y=y+1) begin: g_data_unit
		assign data_unit[0][y] = data_input_q[y];
	end

	for(x=0; x < N; x=x+1) begin: g_unit_x
		for(y=0; y < N; y=y+1) begin: g_unit_y
			mac_unit #(.W(W)) m_unit(
				.clk(clk),
				
				.data_i(data_unit[x][y]),
				.data_top_i(),

				.weight_i(),

				.data_o(data_top_unit[x][y]),
				.res_o(res_unit[x][y])
			);		
		end
	end
endgenerate

endmodule

