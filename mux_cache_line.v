module mux_cache_line #(
	parameter DATA_SIZE = 128,
	parameter NUM_MASTERS = 8
)
(
	input logic [DATA_SIZE*4-1:0] cache_line_in_m0,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m1,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m2,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m3,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m4,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m5,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m6,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m7,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m8,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m9,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m10,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m11,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m12,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m13,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m14,
	input logic [DATA_SIZE*4-1:0] cache_line_in_m15,
	input logic [3:0] mux_sel, 
	output logic [DATA_SIZE*4-1:0] cache_line_out
);

	assign cache_line_out = (mux_sel == 0)  ? cache_line_in_m0 :
													(mux_sel == 1)  ? cache_line_in_m1 :
													(mux_sel == 2)  ? cache_line_in_m2 :
													(mux_sel == 3)  ? cache_line_in_m3 :
													(mux_sel == 4)  ? cache_line_in_m4 :
													(mux_sel == 5)  ? cache_line_in_m5 :
													(mux_sel == 6)  ? cache_line_in_m6 :
													(mux_sel == 7)  ? cache_line_in_m7 :
													(mux_sel == 8)  ? cache_line_in_m8 :
													(mux_sel == 9)  ? cache_line_in_m9 :
													(mux_sel == 10) ? cache_line_in_m10 :
													(mux_sel == 11) ? cache_line_in_m11 :
													(mux_sel == 12) ? cache_line_in_m12 :
													(mux_sel == 13) ? cache_line_in_m13 :
													(mux_sel == 14) ? cache_line_in_m14 :
													(mux_sel == 15) ? cache_line_in_m15 ;

endmodule

