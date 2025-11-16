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
	parameter [10:0] MANIFACTURE_ID,
	parameter UREG_ADDR_W, // user register address size
	parameter UREG_DATA_W, // user register size
	parameter UREG_W = $max(UREG_ADDR_W, UREG_DATA_W)
	)(
	input  ena_i, 

	input  tck_i, 
	input  tms_i, 
	input  tdi_i,
	input  trst_i, // optional, adding to guaranty FSM is in reset to help reduce power 
	output tdo_o,

	output dsc_shift_o,
	output dsc_capture_o,
	output dsc_update_o,
	output dsc_mode_o,

	input dsc_tdo_i,

	output [UREG_W-1:0] ureg_addr_o,
	input  [UREG_W-1:0] ureg_data_i	
);
/* supported instruction opcodes
 * some instructions opcodes can be implementation defined, this isn't
 * the case for the following two instructions : 
 * EXTEST - 0
 * BYPASS - max (all ones)  */
localparam [IR_W-1:0] EXTEST         = {IR_W-1{1'b0}};// 0 - spec defined
localparam [IR_W-1:0] IDCODE         = {{IR_W-2{1'b0}}, 1'b1}; // 1
localparam [IR_W-1:0] SAMPLE_PRELOAD = {{IR_W-3{1'b0}}, 2'b1}; // 2
localparam [IR_W-1:0] USER_REG       = {{IR_W-3{1'b0}}, 2'b1}; // 3
localparam [IR_W-1:0] BYPASS         = {IR_W-1{1'b1}};         // max

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

/* IDCODE */
reg [31:0] idcode_q;
always @(posedge tck_i) begin
	if (fsm_q == DR_CAPTURE)    idcode_q <= PART_ID;
	else if (fsm_q == DR_SHIFT) idcode_q <= {1'b0, idcode_q[31:1]};
end

/* BYPASS */
reg bypass_q;
always @(posedge tck_i) begin
	if (fsm_q == DR_CAPTURE) bypass_q; 
	else if (fsm_q == DR_SHIFT) bypass_q <= tdi_i;	
end

/* USER REGISTER */
reg [UREG_W-1:0] ureg_addr_q, ureg_data_q, ureg_tdi_q;
always @(posedge tck_i) begin
	if (fsm_q == DR_CAPTURE) begin
		ureg_addr_q <= ureg_tdi_q;
		ureg_data_q <= ureg_data_i;
	end else if (fsm_q == DR_SHIFT) begin
		ureg_tdi_q <= {tdi_i, ureg_tdi_q[UREG_W-2:0]};
		ureg_data_q <= {1'b0, ureg_data_q[UREG_W-1:1]};
	end
end

/* DR */ 
wire dr_tdo;

assign dsc_capture_o = (fsm_q == DR_SHIFT | fsm_q == DR_CAPTURE ) & (ir == EXTEST | ir == SAMPLE_PRELOAD); 
assign dsc_shift_o   = fsm_q == DR_SHIFT   & (ir == EXTEST | ir == SAMPLE_PRELOAD);
assign dsc_update_o  = fsm_q == DR_UPDATE  & (ir == EXTEST | ir == SAMPLE_PRELOAD); 
assign dsc_mode_o    = fsm_q == DR_UPDATE  & ir == EXTEST;

/* TDO mux */
assign dr_tdo = (ir == IDCODE) ? idcode_q[0] :
				(ir == BYPASS) ? bypass_q : 
				(ir == SAMPLE_PRELOAD | ir == EXTEST) ? bsc_tdo:
				(ir == USER_REG)? ureg_data_q[0]: 
				1'b0; // TODO custom reg

assign tdo_o = (fsm_q == IR_SHIFT)? ir_tdo: 
			   dr_tdo;
		
endmodule
