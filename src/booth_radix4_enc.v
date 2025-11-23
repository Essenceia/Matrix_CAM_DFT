`timescale 1ns / 1ps
`default_nettype none

module booth_radix4_enc_sel(
	input wire [2:0] mul_i, // multiplier term

	output wire neg_o,
	output wire single_o, 
	output wire shift_o
);

// assuming I can do an as good job as the synth simulifying this 
// circiut by hand

assign single_o = (mul_i[0] ^ mul_i[1]);
assign shift_o = ~(mul_i[0] ^ mul_i[1]) & (mul_i[1]^ mul_i[2]);
assign neg_o = mul_i[2];

endmodule

module booth_radix4_enc(
	input wire [2:0] mul_i, // multiplier term
	input wire [7:0] data_i,

	output wire [8:0] res_o,
	output wire       ext_o, // multiplicat sign extension bit
	output wire       sign_o
);
wire neg, single, shift;
wire [8:0] neg_mask; 
wire [8:0] single_mask; 
wire [7:0] shift_mask; 
wire [8:0] post_shift; 

	booth_radix4_enc_sel m_sel(
		.mul_i(mul_i),
		.neg_o(neg),
		.single_o(single), 
		.shift_o(shift)
	);

assign single_mask = {9{single}};
assign shift_mask = {8{shift}};
assign neg_mask  = {9{neg}};

assign post_shift = {{data_i[7], data_i} & single_mask} | {data_i & shift_mask, 1'b0};
assign res_o = post_shift ^ neg_mask; 
assign sign_o = neg; 
assign ext_o = res_o[8];

endmodule


