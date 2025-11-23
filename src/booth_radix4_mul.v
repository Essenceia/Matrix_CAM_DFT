`timescale 1ns / 1ps
`default_nettype none

module booth_randix4_mul(
	input wire [7:0] data_i, 
	input wire [7:0] w_i, 

	output wire [15:0] res_o, 
	output wire        res_sign_o 
	);

// Parital products  
// PP0
wire [8:0] pp0_enc;
wire       pp0_e, pp0_s;
wire [11:0] pp0;

booth_radix4_enc m_enc0(
	.mul_i({w_i[1:0], 1'b0}),
	.data_i(data_i),

	.res_o(pp0_enc),
	.ext_o(pp0_e),
	.sign_o(pp0_s)
);
assign pp0 = {~pp0_e, {2{pp0_e}}, pp0_enc};

// PP1
wire [8:0]  pp1_enc;
wire        pp1_e, pp1_s;
wire [10:0] pp1;

booth_radix4_enc m_enc1(
	.mul_i(w_i[3:1]),
	.data_i(data_i),

	.res_o(pp1_enc),
	.ext_o(pp1_e),
	.sign_o(pp1_s)
);
assign pp1 = {1'b1, ~pp1_e, pp1_enc};

// PP2
wire [8:0]  pp2_enc;
wire        pp2_e, pp2_s;
wire [10:0] pp2;

booth_radix4_enc m_enc2(
	.mul_i(w_i[5:3]),
	.data_i(data_i),

	.res_o(pp2_enc),
	.ext_o(pp2_e),
	.sign_o(pp2_s)
);
assign pp2 = {1'b1, ~pp2_e, pp2_enc};// PP2

// PP3
wire [8:0]  pp3_enc;
wire        pp3_e, pp3_s;
wire [9:0] pp3;

booth_radix4_enc m_enc3(
	.mul_i(w_i[7:5]),
	.data_i(data_i),

	.res_o(pp3_enc),
	.ext_o(pp3_e),
	.sign_o(pp3_s)
);
assign pp3 = {~pp3_e, pp3_enc};


// Adder tree 
// level 0 
wire [12:0] add0_0; 
wire [13:0] add0_1; 
wire        add0_0_carry;
wire        add0_1_carry;

assign {add0_0_carry, add0_0} = {1'b0, pp0} 
                              + {pp1, 1'b0, pp0_s}
                              + {6'b0, pp3_s, 6'b0}; // adding pp3_s to left tree to balance trees

assign {add0_1_carry, add0_1} = {1'b0, pp2, 1'b0,  pp1_s}
		                	  + {pp3, 1'b0, pp2_s, 2'b0};

// level 1
wire [15:0] add1; 
wire unused_add1_carry; // carry value can be pre-computed

assign {unused_add1_carry, add1 } = {3'b0, add0_0_carry, add0_0}
                                  + {add0_1_carry, add0_1, 2'b0};

assign res_o = add1;

// parallel detmination of final multiplicaion sign
assign res_sign_o = (data_i[7] ^ w_i[7]) & |data_i[7:0] & |w_i[7:0];
 
endmodule 
