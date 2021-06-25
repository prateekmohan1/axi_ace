module axi_addr_logic #(
	parameter LEN_SIZE = 8,
	parameter ID_SIZE = 8,
	parameter ADDR_SIZE = 32,
	parameter DATA_SIZE = 128,
	parameter STRB_SIZE = DATA_SIZE/8
)
(
	// CLK and Resetn
	input logic ACLK,
	input logic ARESETn,

	//Write Address Signals
	input logic [ID_SIZE-1:0] AWID,
	input logic [ADDR_SIZE-1:0] AWADDR,
	input logic [LEN_SIZE-1:0] AWLEN,
	input logic [1:0] AWBURST,
	input logic AWVALID,
	output logic AWREADY,

	//Read Address Signals
	input logic [ID_SIZE-1:0] ARID,
	input logic [ADDR_SIZE-1:0] ARADDR,
	input logic [LEN_SIZE-1:0] ARLEN,
	input logic [1:0] ARBURST,
	input logic ARVALID,
	output logic ARREADY,

	//Coherence Signals
	input logic [3:0] ARSNOOP,
	input logic [1:0] ARDOMAIN,
	input logic [1:0] ARBAR,
	input logic [3:0] AWSNOOP,
	input logic [1:0] AWDOMAIN,
	input logic [1:0] AWBAR,

	//Snoop Signals
	output logic [ADDR_SIZE-1:0] ACADDR,
	output logic [3:0] ACSNOOP,
	output logic [2:0] ACPROT,

	//Signals to Arbiter
	output logic ar_trans_to_arb_vld,
	output logic aw_trans_to_arb_vld,
	output logic w_direct_mem,
	output logic r_direct_mem
);

	//Internal Signals for Flops
	logic [ID_SIZE-1:0] AWID_reg;
	logic [ADDR_SIZE-1:0] AWADDR_reg;
	logic [LEN_SIZE-1:0] AWLEN_reg;
	logic [1:0] AWBURST_reg;
	logic AWVALID_reg;
	logic AWREADY_reg;

	logic [ID_SIZE-1:0] ARID_reg;
	logic [ADDR_SIZE-1:0] ARADDR_reg;
	logic [LEN_SIZE-1:0] ARLEN_reg;
	logic [1:0] ARBURST_reg;
	logic ARVALID_reg;
	logic ARREADY_reg;

	logic [3:0] ARSNOOP_reg;
	logic [1:0] ARDOMAIN_reg;
	logic [1:0] ARBAR_reg;
	logic [3:0] AWSNOOP_reg;
	logic [1:0] AWDOMAIN_reg;
	logic [1:0] AWBAR_reg;

	logic [ADDR_SIZE-1:0] ACADDR_reg;
	logic [3:0] ACSNOOP_reg;
	logic [2:0] ACPROT_reg;

	//Internal signals to denote transaction
	logic aw_trans_vld;
	logic ar_trans_vld;

	//Parameters for AWDOMAIN/ARDOMAIN
	localparam 	NON_SHAREABLE 		= 2'b00,
							INNER_SHAREABLE		= 2'b01,
							OUTER_SHAREABLE		= 2'b10,
							SYSTEM						= 2'b11;

	//Parameters for ARSNOOP
	localparam 	READNOSNOOP_17 				= 4'b0001;
	localparam	READONCE_7						= 4'b0000;
	localparam	READSHARED_6					= 4'b0001;
	localparam	READCLEAN_4						= 4'b0010;
	localparam	READNOTSHAREDDIRTY_5 	= 4'b0011;
	localparam	READUNIQUE_1					= 4'b0111;
	localparam	CLEANUNIQUE_3					= 4'b1011;
	localparam	MAKEUNIQUE_2					= 4'b1100;
	localparam	CLEANSHARED_14				= 4'b1000;
	localparam	CLEANINVALID_15				= 4'b1001;
	localparam	MAKEINVALID_16				= 4'b1101;

	//Parameters for AWSNOOP
	localparam	WRITENOSNOOP_21 	= 4'b0000;
	localparam	WRITEUNIQUE_8			= 4'b0000;
	localparam	WRITELINEUNIQUE_9 = 4'b0001;
	localparam	WRITECLEAN_11			= 4'b0010;
	localparam	WRITEBACK_10			= 4'b0011;
	localparam	EVICT_13					= 4'b0100;
	localparam	WRITEEVICT_12			= 4'b0101;

	//Parameters for ACSNOOP
	localparam  AC_READONCE_7						= 4'b0000;
	localparam	AC_READSHARED_6					= 4'b0001;
	localparam	AC_READCLEAN_4					= 4'b0010;
	localparam	AC_READNOTSHAREDDIRTY_5 = 4'b0011;
	localparam	AC_READUNIQUE_1					= 4'b0111;
	localparam	AC_CLEANSHARED_14				= 4'b1000;
	localparam	AC_CLEANVALID_15				= 4'b1001;
	localparam	AC_MAKEINVALID_16				= 4'b1101;

	assign AWREADY = AWREADY_reg;
	assign ARREADY = ARREADY_reg;

	assign ACSNOOP = ACSNOOP_reg;
	assign ACPROT = ACPROT_reg;
	assign ACADDR = ACADDR_reg;

	//Signal capture for the AW input signals
	//If it is seen that there is a AWVALID and
	//AWREADY, capture the inputs - otherwise just
	//retain the old data
	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			AWID_reg <= 0;
			AWADDR_reg <= 0;
			AWLEN_reg <= 0;
			AWBURST_reg <= 0;
			AWSNOOP_reg <= 0;
			AWDOMAIN_reg <= 0;
			AWBAR_reg <= 0;
			aw_trans_vld <= 0;
		end
		else begin
			if (AWVALID && AWREADY) begin
				AWID_reg <= AWID;
				AWADDR_reg <= AWADDR;
				AWLEN_reg <= AWLEN;
				AWBURST_reg <= AWBURST;
				AWSNOOP_reg <= AWSNOOP;
				AWDOMAIN_reg <= AWDOMAIN;
				AWBAR_reg <= AWBAR;
				aw_trans_vld <= 1;
			end
			else begin
				AWID_reg <= AWID_reg;
				AWADDR_reg <= AWADDR_reg;
				AWLEN_reg <= AWLEN_reg;
				AWBURST_reg <= AWBURST_reg;
				AWSNOOP_reg <= AWSNOOP_reg;
				AWDOMAIN_reg <= AWDOMAIN_reg;
				AWBAR_reg <= AWBAR_reg;
				aw_trans_vld <= aw_trans_vld;
			end
		end
	end


	//TODO: There needs to be logic that makes sure
	//      that after a ar_trans_to_arb_vld is set
	//      or aw_trans_to_arb_vld is set then it 
	//      gets deasserted after the transaction is completed
	//			This basically requires the ar_trans_vld
	//      or aw_trans_vld to get deasserted

	//Signal capture for the AR input signals
	//If it is seen that there is a ARVALID and
	//ARREADY, capture the inputs - otherwise just
	//retain the old data
	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			ARID_reg <= 0;
			ARADDR_reg <= 0;
			ARLEN_reg <= 0;
			ARBURST_reg <= 0;
			ARSNOOP_reg <= 0;
			ARDOMAIN_reg <= 0;
			ARBAR_reg <= 0;
			ar_trans_vld <= 0;
		end
		else begin
			if (ARVALID && ARREADY) begin
				ARID_reg <= ARID;
				ARADDR_reg <= ARADDR;
				ARLEN_reg <= ARLEN;
				ARBURST_reg <= ARBURST;
				ARSNOOP_reg <= ARSNOOP;
				ARDOMAIN_reg <= ARDOMAIN;
				ARBAR_reg <= ARBAR;
				ar_trans_vld <= 1;
			end
			else begin
				ARID_reg <= ARID_reg;
				ARADDR_reg <= ARADDR_reg;
				ARLEN_reg <= ARLEN_reg;
				ARBURST_reg <= ARBURST_reg;
				ARSNOOP_reg <= ARSNOOP_reg;
				ARDOMAIN_reg <= ARDOMAIN_reg;
				ARBAR_reg <= ARBAR_reg;
				ar_trans_vld <= ar_trans_vld;
			end
		end
	end


	//Logic for converting an AR/AW
	//transaction to AC snoop transaction
	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			ACSNOOP_reg <= 0;
			ACPROT_reg <= 0;
			ACADDR_reg <= 0;
			ar_trans_to_arb_vld <= 0;
			aw_trans_to_arb_vld <= 0;
			w_direct_mem <= 0;
			r_direct_mem <= 0;
		end
		else begin
			if (ar_trans_vld) begin
				case (ARDOMAIN_reg)
					NON_SHAREABLE: begin
						case (ARSNOOP_reg) 
							READNOSNOOP_17: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								//The ar_trans_to_arb_vld tells the arbiter 
								//if a transaction is ready for snooping
								ar_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= 0;
							end
							CLEANSHARED_14: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANSHARED_14;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							CLEANINVALID_15: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANVALID_15;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							MAKEINVALID_16: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_MAKEINVALID_16;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							default: begin
								//If you are here this is a malformed transaction
								//TODO: Figure out what transaction this should be
							end
						endcase
					end
					INNER_SHAREABLE: begin
						case (ARSNOOP_reg) 
							CLEANSHARED_14: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANSHARED_14;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							CLEANINVALID_15: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANVALID_15;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							MAKEINVALID_16: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_MAKEINVALID_16;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							default: begin
								//If you are here this is a malformed transaction
								//TODO: Figure out what transaction this should be
							end
						endcase
					end
					OUTER_SHAREABLE: begin
						case (ARSNOOP_reg) 
							READONCE_7: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_READONCE_7;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							READSHARED_6: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_READSHARED_6;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							READCLEAN_4: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_READCLEAN_4;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							READNOTSHAREDDIRTY_5: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_READNOTSHAREDDIRTY_5;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							READUNIQUE_1: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_READUNIQUE_1;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							CLEANUNIQUE_3: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANVALID_15;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							MAKEUNIQUE_2: begin
								ar_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_MAKEINVALID_16;
								ACPROT_reg <= 0;
								ACADDR_reg <= ARADDR_reg;
							end
							default: begin
								//If you are here, it is a malformed transaction
								//TODO: Figure out what transaction this should be
							end
						endcase
					end
					SYSTEM: begin
						case (ARSNOOP_reg) 
							READNOSNOOP_17: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								ar_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= 0;
							end
							default: begin
								//If you are here, it is a malformed transaction
								//TODO: Figure out what transaction this should be
							end
						endcase
					end
				endcase
			end
			else if (aw_trans_vld) begin
				case (AWDOMAIN_reg)
					NON_SHAREABLE: begin
						case (AWSNOOP_reg)
							WRITENOSNOOP_21: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= 0;
							end
							WRITECLEAN_11: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= 0;
							end
							WRITEBACK_10: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= 0;
							end
							WRITEEVICT_12: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= 0;
							end
							default: begin
								//If you reached here, there is a malformed transaction
								//TODO: Figure out what transaction this should be
			
							end
						endcase
					end
					INNER_SHAREABLE: begin
						case (AWSNOOP_reg)
							WRITEUNIQUE_8: begin
								aw_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANVALID_15;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITELINEUNIQUE_9: begin
								aw_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_MAKEINVALID_16;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITECLEAN_11: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITEBACK_10: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							EVICT_13: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITEEVICT_12: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
						endcase
					end
					OUTER_SHAREABLE: begin
						case (AWSNOOP_reg)
							WRITEUNIQUE_8: begin
								aw_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_CLEANVALID_15;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITELINEUNIQUE_9: begin
								aw_trans_to_arb_vld <= 1;
								ACSNOOP_reg <= AC_MAKEINVALID_16;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITECLEAN_11: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITEBACK_10: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							EVICT_13: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
							WRITEEVICT_12: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
						endcase
					end
					SYSTEM : begin
						case (AWSNOOP_reg)
							WRITENOSNOOP_21: begin
								//TODO: Need to put a signal that tells arbiter
								//			that this type of transaction needs to 
								//			bypass all other masters, and directly 
								//			access memory
								aw_trans_to_arb_vld <= 0;
								ACSNOOP_reg <= 0;
								ACPROT_reg <= 0;
								ACADDR_reg <= AWADDR_reg;
							end
						endcase
					end
				endcase
			end
			else begin
				//Here, both aw_trans_vld and ar_trans_vld are 0
				ACSNOOP_reg <= 0;
				ACPROT_reg <= 0;
				ACADDR_reg <= 0;
				ar_trans_to_arb_vld <= 0;
				aw_trans_to_arb_vld <= 0;
				w_direct_mem <= 0;
				r_direct_mem <= 0;
			end
		end
	end



	//Default Reset Logic
	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			AWREADY_reg <= 0;
			ARREADY_reg <= 0;
		end
		else begin
			if (AWVALID && !AWREADY_reg) begin
				AWREADY_reg <= 1;
			end
			else begin
				AWREADY_reg <= 0;
			end
			if (ARVALID && !ARREADY_reg) begin
				ARREADY_reg <= 1;
			end
			else begin
				ARREADY_reg <= 0;
			end
		end
	end





endmodule
