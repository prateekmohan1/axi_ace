module find_ones #(
	parameter NUM_MASTERS = 8
)
(
	input logic [NUM_MASTERS-1:0] ones_chk,
	output logic [4:0] index_pos
);

	assign index_pos = (ones_chk[0]) ? 5'd0 : 
										 (ones_chk[1]) ? 5'd1 :
										 (ones_chk[2]) ? 5'd2 :
										 (ones_chk[3]) ? 5'd3 :
										 (ones_chk[4]) ? 5'd4 :
										 (ones_chk[5]) ? 5'd5 :
										 (ones_chk[6]) ? 5'd6 :
										 (ones_chk[7]) ? 5'd7 ;

endmodule
