/* 
 * JTAG TAP Controller
 *
 * Julia Desmazes, 25, human made code
 */

`timescale 1ns / 1ps
`default_nettype none

module jtag #(
	parameter IR_W = 3,
	parameter [3:0]  VERSION_NUM = 4'he,
	parameter [15:0] PART_NUM = 16'hbeef,
	parameter [10:0] MANIFACTURE_ID = 11'hff,
	parameter UREG_ADDR_W = 4, // user register address size
	parameter UREG_DATA_W = 8, // user register size
	parameter UREG_W = (UREG_ADDR_W >= UREG_DATA_W)? UREG_ADDR_W: UREG_DATA_W
	)(
	input wire  rst_n,
	input wire  ena, 

	input wire  tck_i, 
	input wire  tms_i, 
	input wire  tdi_i,
	input wire  trst_i, // optional, adding to guaranty FSM is in reset to help reduce power 
	output wire tdo_o,

	output wire bsc_shift_o,
	output wire bsc_capture_o,
	output wire bsc_update_o,
	output wire bsc_mode_o,

	input wire bsc_tdo_i,

	output wire [UREG_ADDR_W-1:0] ureg_addr_o,
	input wire  [UREG_DATA_W-1:0] ureg_data_i	
);
/* supported instruction opcodes
 * some instructions opcodes can be implementation defined, this isn't
 * the case for the following two instructions : 
 * EXTEST - 0
 * BYPASS - max (all ones)  */
localparam [IR_W-1:0] EXTEST         = {IR_W{1'b0}};// 0 - spec defined
localparam [IR_W-1:0] IDCODE         = {{IR_W-1{1'b0}}, 1'b1}; // 1
localparam [IR_W-1:0] SAMPLE_PRELOAD = {{IR_W-2{1'b0}}, 2'd2}; // 2
localparam [IR_W-1:0] USER_REG       = {{IR_W-2{1'b0}}, 2'd3}; // 3
/* verilator lint_off UNUSEDPARAM */
localparam [IR_W-1:0] BYPASS         = {IR_W{1'b1}};         // max
/* verilator lint_on UNUSEDPARAM */

/* part identifier, returned on IDCODE */
localparam [31:0] PART_ID = {VERSION_NUM, PART_NUM, MANIFACTURE_ID, 1'b1};
/* TAP FSM */ 
localparam RESET      = 0;
localparam IDLE       = 1;
localparam DR_SELECT  = 2;
localparam DR_CAPTURE = 3;
localparam DR_SHIFT   = 4;
localparam DR_EXIT_1  = 5;
localparam DR_PAUSE   = 6;
localparam DR_EXIT_2  = 7;
localparam DR_UPDATE  = 8;
localparam IR_SELECT  = 9;
localparam IR_CAPTURE = 10;
localparam IR_SHIFT   = 11;
localparam IR_EXIT_1  = 12;
localparam IR_PAUSE   = 13;
localparam IR_EXIT_2  = 14;
localparam IR_UPDATE  = 15;

(* MARK_DEBUG = "true" *) reg [3:0] fsm_q;
reg  jtag_enabled_q;

/* fsm is reset though the RESET TAP */
always @(posedge tck_i) begin
	if (trst_i | ~ena | ~jtag_enabled_q) begin 
		fsm_q <= RESET;
	end else begin // block isn't going to be power gatted
		case(fsm_q)
			RESET:      fsm_q <= tms_i? RESET: IDLE;
			IDLE:       fsm_q <= tms_i? DR_SELECT: IDLE;
			DR_SELECT:  fsm_q <= tms_i? IR_SELECT: DR_CAPTURE; 
			DR_CAPTURE: fsm_q <= tms_i? DR_EXIT_1: DR_SHIFT; 
			DR_SHIFT:   fsm_q <= tms_i? DR_EXIT_1: DR_SHIFT; 
			DR_EXIT_1:  fsm_q <= tms_i? DR_UPDATE: DR_PAUSE;
			DR_PAUSE:   fsm_q <= tms_i? DR_EXIT_2: DR_PAUSE; 
			DR_EXIT_2:  fsm_q <= tms_i? DR_UPDATE: DR_SHIFT;
			DR_UPDATE:  fsm_q <= tms_i? DR_SELECT: IDLE;
			IR_SELECT:  fsm_q <= tms_i? RESET: IR_CAPTURE; 
			IR_CAPTURE: fsm_q <= tms_i? IR_EXIT_1: IR_SHIFT; 
			IR_SHIFT:   fsm_q <= tms_i? IR_EXIT_1: IR_SHIFT; 
			IR_EXIT_1:  fsm_q <= tms_i? IR_UPDATE: IR_PAUSE;
			IR_PAUSE:   fsm_q <= tms_i? IR_EXIT_2: IR_PAUSE; 
			IR_EXIT_2:  fsm_q <= tms_i? IR_UPDATE: IR_SHIFT;
			IR_UPDATE:  fsm_q <= tms_i? DR_SELECT: IDLE;
		endcase	
	end
end


/* IR register */
(* MARK_DEBUG = "true" *) wire [IR_W-1:0] ir; 
wire ir_tdo;
ir #(.W(IR_W), .RESET_OPCODE(IDCODE)) m_ir(
	.rst_tap(trst_i | ~jtag_enabled_q | (fsm_q == RESET)),

	.tck_i(tck_i),
	.tdi_i(tdi_i),
	.tdo_o(ir_tdo),

	.capture_i(fsm_q == IR_CAPTURE),
	.shift_i(fsm_q == IR_SHIFT),
	.update_i(fsm_q == IR_UPDATE),

	.inst_o(ir)
);

/* IDCODE */
reg [31:0] idcode_q;
always @(posedge tck_i) begin
	if (fsm_q == DR_CAPTURE)    idcode_q <= PART_ID;
	else if (fsm_q == DR_SHIFT) idcode_q <= {tdi_i, idcode_q[31:1]};
end

/* BYPASS */
reg bypass_q;
always @(posedge tck_i) begin
	if (fsm_q == DR_CAPTURE) bypass_q <= 1'b0; 
	else if (fsm_q == DR_SHIFT) bypass_q <= tdi_i;	
end

/* USER REGISTER */
reg [UREG_ADDR_W-1:0]        ureg_addr_q;
reg [UREG_W-UREG_ADDR_W-1:0] unused_ureg_addr_q;
reg [UREG_W-1:0]             ureg_data_q;
reg [UREG_W-1:0]             ureg_tdi_q;

// addr
always @(posedge tck_i) begin
	if (ir == USER_REG) begin
		if (fsm_q == DR_UPDATE) begin
			{ unused_ureg_addr_q , ureg_addr_q } <= ureg_tdi_q;
		end else if (fsm_q == DR_SHIFT) begin
			ureg_tdi_q  <= {tdi_i, ureg_tdi_q[UREG_W-1:1]};
		end
	end
end
// data
always @(posedge tck_i) begin
	if (ir == USER_REG) begin
		if (fsm_q == DR_CAPTURE) begin
			ureg_data_q <= ureg_data_i;
		end else if (fsm_q == DR_SHIFT) begin
			ureg_data_q <= {1'b0, ureg_data_q[UREG_W-1:1]};
		end
	end
end
assign ureg_addr_o = ureg_addr_q; 

/* JTAG dissabled mask */ 
always @(posedge tck_i or negedge rst_n) begin
  if (~rst_n)
    jtag_enabled_q <= 1'b0;  
  else
    jtag_enabled_q <= 1'b1;
end

/* DR */ 
wire dr_tdo;
assign bsc_capture_o = (fsm_q == DR_SHIFT | fsm_q == DR_CAPTURE ) & (ir == EXTEST | ir == SAMPLE_PRELOAD); 
assign bsc_shift_o   = fsm_q == DR_SHIFT   & (ir == EXTEST | ir == SAMPLE_PRELOAD);
assign bsc_update_o  = fsm_q == DR_UPDATE  & (ir == EXTEST | ir == SAMPLE_PRELOAD); 
assign bsc_mode_o    = jtag_enabled_q & ir == EXTEST;

/* TDO mux */
assign dr_tdo = (ir == IDCODE) ? idcode_q[0] :
				(ir == SAMPLE_PRELOAD | ir == EXTEST) ? bsc_tdo_i:
				(ir == USER_REG) ? ureg_data_q[0] :
				bypass_q; 

reg tdo_q;
always @(posedge tck_i) begin
	tdo_q <= (fsm_q == IR_SHIFT)? ir_tdo: 
         	 dr_tdo;

end
assign tdo_o = tdo_q;
endmodule
