module booth_radix4_enc_sel(
	input [2:0] mul_i, // multiplier term

	output neg_o,
	output single_o, 
	output shift2_o
);

// assuming I can do an as good job as the synth simulifying this 
// circiut by hand

assign single_o = (mul_i[0] ^ mul_i[1]);
assign shift_o = ~(mul_i[0] ^ mul_i[1]) & (mul_i[1]^ mul_i[2]);
assign neg_o = mul_i[2];

endmodule

module booth_radix4_enc(
	input [2:0] mul_i, // multiplier term
	input [7:0] data_i,

	output [8:0] res_o,
	output       sign_o
);
wire neg, single, shift2;
wire [8:0] neg_mask; 
wire [7:0] single_mask; 
wire [7:0] shift_mask; 
wire [8:0] post_shift; 

	booth_radix4_enc_sel(
		.mul_i(mul_i),
		.neg_o(neg),
		.single_o(single), 
		.shift2_o(shift2)
	);

assign single_mask = {8{single}};
assign shift_mask = {8{shift2}};
assign neg_mask  = {9{neg}};

assign post_shift = {1'b0, data_i & single_mask} | {data_i & double_mask, 1'b0};
assign res_o = post_shift ^ neg_mask; 
assign sign_o = neg; 

endmodule


