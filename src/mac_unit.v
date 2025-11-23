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
	input wire clk, 

	input wire           step_i, 
	
	input wire [W-1:0]   data_i, //right side input data
	input wire [W-1:0]   data_top_i, // top input data

	input wire           wr_weight_v_i,	
	input wire [W-1:0]   weight_i, 

	input wire  [1:0]    jtag_ureg_addr_i, 
	output logic [W-1:0] jtag_ureg_data_o, 

	output wire [W-1:0]  data_o, // left side output data, will become the right side input data of the next unit leftwards
	output wire [W-1:0]  res_o // result, become the top input data for the next unit bellow
); 
localparam MAX_DATA = {1'b0, {W-1{1'b1}}};
localparam MIN_DATA = {1'b1, {W-1{1'b0}}};

reg  [W-1:0]  data_q, add_q;
reg  [W-1:0]  weight_q;

wire [2*W-1:0] mul;
wire           mul_sign; 

wire [2*W-1:0] add_extended; 
wire [W-1:0]   trunc_add; // truncated addition 
wire [W-1:0]   remain_add; 
wire           unused_carry;
wire           overflow, underflow; 

wire [2*W:0]   debug_mul; 
wire [2*W-1:0] debug_add; 

always @(posedge clk) 
	if (step_i) data_q <= data_i;

always @(posedge clk) 
	if (step_i) add_q <= data_top_i; // critical path end 

always @(posedge clk) 
	if (wr_weight_v_i) weight_q <= weight_i;

booth_randix4_mul m_mul(
	.data_i(data_q),
	.w_i(weight_q),
	.res_o(mul),
	.res_sign_o(mul_sign)
);

// Conforming to user expectations of having a soft max to round out
// numbers and not let the results overflow and simply be sliced.
// Forced the need for a costly 16b addition though.
assign add_extended = {{W{add_q[W-1]}}, add_q};
assign {unused_carry, remain_add, trunc_add } = mul + add_extended;

assign debug_mul = {mul_sign, mul}; 
assign debug_add = {remain_add[W-1:0], trunc_add}; 

// soft max 
assign overflow  = ~remain_add[W-1] ? |{remain_add, trunc_add[W-1]} : 0; 
assign underflow = remain_add[W-1] ? ~&{remain_add, trunc_add[W-1]} : 0; 
assign res_o = overflow ? MAX_DATA : underflow ? MIN_DATA : trunc_add;  

assign data_o = data_q;

// jtag user register interface, expected to be used when mac clock is stalled
always @(*) begin
	case(jtag_ureg_addr_i) 
		2'b00: jtag_ureg_data_o = weight_q; 
		2'b01: jtag_ureg_data_o = data_q; 
		2'b10: jtag_ureg_data_o = add_q; 
		2'b11: jtag_ureg_data_o = remain_add;
	endcase 
end
endmodule
