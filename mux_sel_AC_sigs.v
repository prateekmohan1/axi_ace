module mux_sel_AC_sigs #(
	parameter ADDR_SIZE = 32,
	parameter SNOOP_BITSIZE = 4,
	parameter PROT_BITSIZE = 3
)
(
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m0,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m1,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m2,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m3,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m4,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m5,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m6,
	input logic [ADDR_SIZE+SNOOP_BITSIZE+PROT_BITSIZE-1:0] AC_sigs_m7,
	input logic [15:0] mux_sel,
	output logic [ADDR_SIZE-1:0] ACADDR_out,
	output logic [SNOOP_BITSIZE-1:0] ACSNOOP_out,
	output logic [PROT_BITSIZE-1:0] ACPROT_out
);


	assign ACADDR_out = (mux_sel[0] | mux_sel[8]) ?  AC_sigs_m0[38:7] :
											(mux_sel[1] | mux_sel[9]) ?  AC_sigs_m1[38:7] :
											(mux_sel[2] | mux_sel[10]) ? AC_sigs_m2[38:7] :
											(mux_sel[3] | mux_sel[11]) ? AC_sigs_m3[38:7] :
											(mux_sel[4] | mux_sel[12]) ? AC_sigs_m4[38:7] :
											(mux_sel[5] | mux_sel[13]) ? AC_sigs_m5[38:7] :
											(mux_sel[6] | mux_sel[14]) ? AC_sigs_m6[38:7] :
											(mux_sel[7] | mux_sel[15]) ? AC_sigs_m7[38:7] :
																									 32'b0;

	assign ACSNOOP_out = (mux_sel[0] | mux_sel[8]) ?  AC_sigs_m0[6:3] :
                       (mux_sel[1] | mux_sel[9]) ?  AC_sigs_m1[6:3] :
                       (mux_sel[2] | mux_sel[10]) ? AC_sigs_m2[6:3] :
					             (mux_sel[3] | mux_sel[11]) ? AC_sigs_m3[6:3] :
                       (mux_sel[4] | mux_sel[12]) ? AC_sigs_m4[6:3] :
                       (mux_sel[5] | mux_sel[13]) ? AC_sigs_m5[6:3] :
                       (mux_sel[6] | mux_sel[14]) ? AC_sigs_m6[6:3] :
                       (mux_sel[7] | mux_sel[15]) ? AC_sigs_m7[6:3] :
                       														  4'b0;

	assign ACPROT_out =	(mux_sel[0] | mux_sel[8]) ?  AC_sigs_m0[2:0] : 
                     	(mux_sel[1] | mux_sel[9]) ?  AC_sigs_m1[2:0] :
                     	(mux_sel[2] | mux_sel[10]) ? AC_sigs_m2[2:0] :
                     	(mux_sel[3] | mux_sel[11]) ? AC_sigs_m3[2:0] :
                     	(mux_sel[4] | mux_sel[12]) ? AC_sigs_m4[2:0] :
                     	(mux_sel[5] | mux_sel[13]) ? AC_sigs_m5[2:0] :
                     	(mux_sel[6] | mux_sel[14]) ? AC_sigs_m6[2:0] :
                     	(mux_sel[7] | mux_sel[15]) ? AC_sigs_m7[2:0] :
                     															 3'b0;

endmodule
