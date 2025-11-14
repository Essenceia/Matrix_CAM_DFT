/* 
 * JTAG TAP Controller
 *
 * Julia Desmazes, 25, human made code
 */

module tap_contoller(
	input  ena_i, 

	input  tck_i, 
	input  tms_i, 
	input  tdi_i, 
	output tdo_i
);
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
always @(posedge tck_i) begin
	if (ena_i) begin // block isn't going to be power gatted
		case(fsq_q) begin
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

endmodule
