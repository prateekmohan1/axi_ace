module mux_sel_cache_line #(
	parameter DATA_SIZE = 128,
	parameter NUM_MASTERS = 8
)
(
	input logic [DATA_SIZE-1:0] cache_line_m0,
	input logic [DATA_SIZE-1:0] cache_line_m1,
	input logic [DATA_SIZE-1:0] cache_line_m2,
	input logic [DATA_SIZE-1:0] cache_line_m3,
	input logic [DATA_SIZE-1:0] cache_line_m4,
	input logic [DATA_SIZE-1:0] cache_line_m5,
	input logic [DATA_SIZE-1:0] cache_line_m6,
	input logic [DATA_SIZE-1:0] cache_line_m7,
	input logic [7:0] mux_sel, 
	output logic [DATA_SIZE-1:0] cache_line_out
);

	assign cache_line_out = (mux_sel == 8'd0)  		? cache_line_m0 :
													(mux_sel == 8'd2)  		? cache_line_m1 :
													(mux_sel == 8'd4)  		? cache_line_m2 :
													(mux_sel == 8'd8)  		? cache_line_m3 :
													(mux_sel == 8'd16)  	? cache_line_m4 :
													(mux_sel == 8'd32)  	? cache_line_m5 :
													(mux_sel == 8'd64)  	? cache_line_m6 :
													(mux_sel == 8'd128)  	? cache_line_m7 :
																									cache_line_m0;

endmodule
