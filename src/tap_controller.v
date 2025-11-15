/* 
 * JTAG TAP Controller
 *
 * Julia Desmazes, 25, human made code
 */

`timescale 1ns / 1ps

module tap_contolle #(
	parameter IR_W,
	parameter [3:0]  VERSION_NUM,
	parameter [15:0] PART_NUM,
	parameter [10:0] MANIFACTURE_ID
	)(
	input  ena_i, 

	input  tck_i, 
	input  tms_i, 
	input  tdi_i,
	input  trst_i, // optional, adding to guaranty FSM is in reset to help reduce power 
	output tdo_o,

	output dr_shift_o,
	output dr_capture_o,
	output dr_update_o
);
/* supported instruction opcodes
 * some instructions opcodes can be implementation defined, this isn't
 * the case for the following two instructions : 
 * EXTEST - 0
 * BYPASS - max (all ones)  */
localparam [IR_W-1:0] EXTEST = {IR_W-1{1'b0}};// 0 - spec defined
localparam [IR_W-1:0] IDCODE = {{IR_W-2{1'b0}}, 1'b1}; // 1
localparam [IR_W-1:0] SAMPLE_PRELOAD = {IR_W-1{1'b0}}; // 0
localparam [IR_W-1:0] BYPASS = {IR_W-1{1'b1}};         // max

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

reg [3:0] fsm_q;

/* fsm is reset though the RESET TAP */
always @(posedge tck_i or posedge trst_i) begin
	if (trst_i) begin 
		fsm_q <= RESET;
	end else if (ena_i) begin // block isn't going to be power gatted
		case(fsq_q)
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
wire [IR_W-1:0] ir; 
wire ir_tdo;
ir #(.W(IR_W), .RESET_OPCODE(IDCODE)) m_ir(
	.rst_tap(trst_i),

	.tck_i(tck_i),
	.tdi_i(tdi_i),
	.tdo_o(ir_tdo),

	.capture_i(fsm_q == IR_CAPTURE),
	.shift_i(fsm_q == IR_SELECT),
	.update_i(fsm_q == IR_UPDATE),

	.inst_o(ir)
);
/* DR */ 
wire dr_tdo;

assign dr_shift_o   = fsm_q == DR_SHIFT;
assign dr_capture_o = fsm_q == DR_CAPTURE; 
assign dr_update_o  = fsm_q == DR_UPDATE; 

/* TDO mux */
assign tdo_o = (fsm_q == IR_SHIFT)? ir_tdo: 
			   (fsm_q == DR_SHIFT)? dr_tdo:
			   1'b0;
		
endmodule
