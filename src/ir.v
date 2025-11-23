/* 
 * IR - Instruction Register
 * Part of the JRAG TAP
 * 
 * Julia Desmazes, 2025, human made code
 */

`timescale 1ns / 1ps
`default_nettype none

module ir #(
	parameter          W=2,// IR length
	parameter [W-1:0] RESET_OPCODE = 2'd0// can be IDCODE of BYPASS according to spec
    )(
	input wire  rst_tap,

	input wire  tck_i, 
	input wire  tdi_i,
	output wire tdo_o,
	
	input wire  capture_i,
	input wire  shift_i,
	input wire  update_i,

	output wire [W-1:0] inst_o	
);
reg [W-1:0] shift_q;//shift register
reg [W-1:0] hold_q; //hold register

always @(posedge tck_i)
	if (capture_i)    shift_q <= hold_q;
	else if (shift_i) shift_q <= {tdi_i, shift_q[W-1:1]};

always @(posedge tck_i)
	if (rst_tap) hold_q <= RESET_OPCODE; 
	else if(update_i) hold_q <= shift_q;

assign inst_o = hold_q;
assign tdo_o = shift_q[0];
endmodule
