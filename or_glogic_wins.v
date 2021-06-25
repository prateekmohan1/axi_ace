module or_glogic_wins(
	input logic [15:0] data_in,
	output logic [7:0] data_out
);

	assign data_out[0] = data_in[0] | data_in[8];
	assign data_out[1] = data_in[1] | data_in[9];
	assign data_out[2] = data_in[2] | data_in[10];
	assign data_out[3] = data_in[3] | data_in[11];
	assign data_out[4] = data_in[4] | data_in[12];
	assign data_out[5] = data_in[5] | data_in[13];
	assign data_out[6] = data_in[6] | data_in[14];
	assign data_out[7] = data_in[7] | data_in[15];

endmodule
