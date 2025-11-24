`default_nettype none
module emulator #(
	parameter SWITCH_W = 2,
	parameter PMOD_W = 8,
	parameter LED_W = 16
)
(
    // PmodC
	input wire clk_bus_i, /* 40 MHz for now */
   
	input wire tck_i,
    input wire tdi_i, 
    input wire tms_i,
    output wire tdo_o,

	input wire [SWITCH_W-1:0] switch_i,

	// PmodA	
	input  wire [PMOD_W-1:0]  data_i,  
	
	// Pmod B
	input  wire               data_v_i,
	input  wire               data_mode_i,
	input  wire               data_rst_addr_i,
	
	output wire               res_v_o,
	
	// Pmod D
	output wire [PMOD_W-1:0]  res_o,  
 
	output wire [LED_W-1:0]   led_o,

	output wire [11:0]        unused_o
);
wire clk_ibuf, clk_pll, clk_pll_feedback, clk;
wire pll_lock;
reg  pll_lock_q;
wire ena;
wire rst_async;
reg rst_n_q, rst_n_d1_q;
wire error;
 
wire [7:0] ui_in;
wire [7:0] uio_in; 

wire [7:0] uo_out; 
wire [7:0] uio_out;
wire [7:0] uio_oe;

reg [PMOD_W-1:0] data_bus_q, data_q;
reg  data_mode_bus_q, data_mode_q;
reg  data_v_bus_q, data_v_q;
reg  data_rst_addr_bus_q, data_rst_addr_q;

wire [PMOD_W-1:0] res;
wire res_v;
reg  [PMOD_W-1:0] res_bus_q;
reg              res_v_bus_q;
(* MARK_DEBUG = "true" *)reg [PMOD_W-1:0] res_bus_d2_q;
(* MARK_DEBUG = "true" *)reg              res_v_bus_d2_q;

(* MARK_DEBUG = "true" *) wire tck, tdi, tdo, tms; 

/* clk */
IBUF m_ibuf_clk(
	.I(clk_bus_i),
	.O(clk_ibuf)
);

// Global clock based on bus clock, using the same frequency
// using the inherent jitter filtering capability of the PLL
// and phase locked on bus clokc
PLLE2_BASE #(
   .CLKFBOUT_MULT(25),        
   .CLKIN1_PERIOD(25.0),      
   .CLKOUT0_DIVIDE(25),
   .DIVCLK_DIVIDE(1)
) m_global_clk_pll (
   .CLKFBIN(clk_pll_feedback),
   .CLKFBOUT(clk_pll_feedback),
   .CLKIN1(clk_ibuf),    
   .CLKOUT0(clk_pll),
/* verilator lint_off PINCONNECTEMPTY */
   .CLKOUT1(),
   .CLKOUT2(),
   .CLKOUT3(),
   .CLKOUT4(),
   .CLKOUT5(),
/* verilator lint_on PINCONNECTEMPTY */
   .LOCKED(pll_lock),
   .PWRDWN(1'b0),
   .RST(rst_async) 
);

BUFG m_bufg_clk(
	.I(clk_pll),
	.O(clk)
);

always @(posedge clk) begin
	data_bus_q      <= data_i;
	data_q          <= data_bus_q;

	data_mode_bus_q <= data_mode_i;
	data_mode_q     <= data_mode_bus_q;

	data_rst_addr_bus_q <= data_rst_addr_i;
	data_rst_addr_q     <= data_rst_addr_bus_q;

	data_v_bus_q <= data_v_i;
	data_v_q     <= data_v_bus_q;
end

/* keeping the same timing distortions between both directions */ 
always @(posedge clk) begin
	res_v_bus_q    <= res_v;
	res_v_bus_d2_q <= res_v_bus_q;
	res_bus_q      <= res;
	res_bus_d2_q   <= res_bus_q;
end

assign res_o = res_bus_d2_q;
assign res_v_o = res_v_bus_d2_q;

/* debug leds */
assign led_o[0] = rst_n_d1_q;
assign led_o[1] = ena;
assign led_o[2] = clk_ibuf; 
assign led_o[10:3] = data_q;
assign led_o[11]    = tck;
assign led_o[12]    = tdi;
assign led_o[13]    = tms;
assign led_o[15]    = tdo;

assign unused_o = {4'h0, 1'b1, {7{1'b1}}}; // an, dp, seg

/* rst */
assign rst_async = switch_i[0];

always @(posedge clk or posedge rst_async) begin
	if (rst_async) begin
		pll_lock_q <= 1'b0;
		rst_n_q    <= 1'b0;
		rst_n_d1_q <= 1'b0;
	end else begin
		pll_lock_q <= pll_lock;
		rst_n_q    <= pll_lock_q; 
		rst_n_d1_q <= rst_n_q; 
	end
end

debounce m_switch_debounce(
	.clk(clk),
	.rst_async(rst_async),
	.switch_i(switch_i[1]),
	.switch_o(ena)
);
/* jtag */
assign tck = tck_i;
assign tdi = tdi_i; 
assign tms = tms_i; 
assign tdo_o = tdo; 

/* deisgn top level */ 
assign ui_in = {data_q[6:0] , tck };
assign uio_in = { 2'b0 , tms , tdi , data_rst_addr_q, data_mode_q, data_v_q, data_q[7]};

assign tdo          = uio_out[6];
assign res_v        = uio_out[7];
assign res          = uo_out;

tt_um_essen m_top(
	.ui_in(ui_in),
	.uo_out(uo_out),
	.uio_in(uio_in),
	.uio_out(uio_out),
	.uio_oe(uio_oe),
	.ena(ena),
	.clk(clk),
	.rst_n(rst_n_q)
);

endmodule
