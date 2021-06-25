module axi_init_master_response #(
	parameter LEN_SIZE = 8,
	parameter ID_SIZE = 8,
	parameter ADDR_SIZE = 32,
	parameter DATA_SIZE = 128,
	parameter STRB_SIZE = DATA_SIZE/8,
	parameter NUM_MASTERS = 8
)
(
	// clk and reset
	input logic ACLK,
	input logic ARESETn,

	// Logic coming in from cache_line_aggr
	input logic [DATA_SIZE-1:0] cache_line_in,
	input logic [3:0] crresp_in,
	input logic data_rdy,
	input logic no_data,

	// Logic coming in from winning master
	input logic [3:0] ACSNOOP,
	input logic [ADDR_SIZE-1:0] ACADDR,
	input logic [2:0] ACPROT,

	// Logic coming in winning master (AXI)
	input logic RREADY,
	output logic [ID_SIZE-1:0] RID,
	output logic [DATA_SIZE-1:0] RDATA,
	output logic RLAST,
	output logic [3:0] RRESP,
	output logic RVALID,

	// Logic to write and read to memory
	input logic [DATA_SIZE*4-1:0] mem_rddata
	output logic [DATA_SIZE*4-1:0] mem_wrdata,
	output logic [ADDR_SIZE-1:0] mem_addr,
	output logic wr_en,
	output logic rd_en
);

	logic [2:0] axi_init_fsm_cs, axi_init_fsm_ns;
	logic [1:0] stall_cycles_Q;
	logic [DATA_SIZE*4-1:0] cache_line_Q;

	logic [3:0] ACSNOOP_Q;
	logic [ADDR_SIZE-1:0] ACADDR_Q;
	logic [ADDR_SIZE-1:0] ACPROT_Q;
	logic [DATA_SIZE*4-1:0] mem_wdata_Q;
	logic [ADDR_SIZE-1:0] mem_addr_Q;
	logic wr_en_Q;
	logic rd_en_Q;
	logic RRESP

	//Parameters for ACSNOOP
	localparam  AC_READONCE_7						= 4'b0000;
	localparam	AC_READSHARED_6					= 4'b0001;
	localparam	AC_READCLEAN_4					= 4'b0010;
	localparam	AC_READNOTSHAREDDIRTY_5 = 4'b0011;
	localparam	AC_READUNIQUE_1					= 4'b0111;
	localparam	AC_CLEANSHARED_14				= 4'b1000;
	localparam	AC_CLEANVALID_15				= 4'b1001;
	localparam	AC_MAKEINVALID_16				= 4'b1101;

	// Assign statements
	assign ACSNOOP = ACSNOOP_Q;
	assign ACADDR = ACADDR_Q;
	assign ACPROT = ACPROT_Q;
	assign mem_data = mem_data_Q;
	assign mem_addr = mem_addr_Q;
	assign wr_en = wr_en_Q;
	assign rd_en = rd_en_Q;

	always @ (*) begin
		axi_init_fsm_ns = axi_init_fsm_cs;
		mux_sel_cache_line = 0;
		case (axi_init_fsm_cs) 
			3'd0: begin
				// This is the beginning state, you will stay
				// in this state and wait for data_rdy
				if (data_rdy) 		axi_init_fsm_ns = 3'd1;
				else if (no_data) axi_init_fsm_ns = 3'd2;
				else							axi_init_fsm_ns = 3'd0;
			end
			3'd1: begin
				// If you are in this state, you have received
				// a data_rdy and from this point you need
				// to capture the data for 4 cycles
				if (stall_cycles_Q == 3) 	axi_init_fsm_ns = 3'd3;
				else 											axi_init_fsm_ns = 3'd1;
			end
			3'd2: begin
				// Here you have received the no_data signal so
				// you are reading from memory
				if (stall_cycles_Q == 2) 	axi_init_fsm_ns = 3'd4;
				else											axi_init_fsm_ns = 3'd2;
			end
			3'd3: begin
				// In this state, you have received the data from
				// the cache_line_aggr and you might need to write
				// to memory if needed


			end
			3'd4: begin

			end


		endcase
	end
	

	always @ (posedge ACLK) begin
		if (~ARESETn) begin
			stall_cycles_Q <= 0;
			ACSNOOP_Q <= 0;
			ACADDR_Q <= 0;
			ACPROT_Q <= 0;
			mem_data_Q <= 0;
			mem_addr_Q <= 0;
			wr_en_Q <= 0;
			rd_en_Q <= 0;
			cache_line_Q <= 0;
		end
		else begin
			stall_cycles_Q <= stall_cycles_Q;
			cache_line_Q <= cache_line_Q;
			ACSNOOP_Q <= ACSNOOP_Q;
			ACADDR_Q <= ACADDR_Q;
			ACPROT_Q <= ACPROT_Q;
			mem_data_Q <= mem_data_Q;
			mem_addr_Q <= mem_addr_Q;
			wr_en_Q <= wr_en_Q;
			rd_en_Q <= rd_en_Q;
			case (fsm_aggr_cs) 
				3'd0: begin
					stall_cycles_Q <= 0;
					ACSNOOP_Q <= ACSNOOP;
					ACADDR_Q <= ACADDR;
					ACPROT_Q <= ACPROT;
					mem_wdata_Q <= 0;
					mem_addr_Q <= 0;
					wr_en_Q <= 0;
					rd_en_Q <= 0;					
				end
				3'd1: begin
					// In this state, you need to increment
					// the stall_cycles_Q register and capture 
					// in the data 
					case(stall_cycles_Q)
						2'd0: begin
							cache_line_Q[DATA_SIZE*(0+1)-1:DATA_SIZE*0] <= cache_line_in;
							stall_cycles_Q <= stall_cycles_Q + 1;
						end                                                             
						2'd1: begin                                                     
							cache_line_Q[DATA_SIZE*(1+1)-1:DATA_SIZE*1]<= cache_line_in;
							stall_cycles_Q <= stall_cycles_Q + 1;
						end                                                             
						2'd2: begin                                                     
							cache_line_Q[DATA_SIZE*(2+1)-1:DATA_SIZE*2]<= cache_line_in;
							stall_cycles_Q <= stall_cycles_Q + 1;
						end                                                             
						2'd3: begin                                                     
							cache_line_Q[DATA_SIZE*(3+1)-1:DATA_SIZE*3] <= cache_line_in;
							stall_cycles_Q <= 0;
						end
					endcase					
				end
				3'd2: begin
					// In this state, you have received a 
					// no_data signal so you need to read from
					// the memory depending on the ACSNOOP
					if (stall_cycles_Q == 2) begin
						cache_line_out_Q <= mem_rddata;
					end
					case (ACSNOOP_Q)
						AC_READONCE_7: begin
							rd_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READCLEAN_4 begin
							rd_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READNOTSHAREDDIRTY_5: begin
							rd_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READSHARED_6: begin
							rd_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READUNIQUE_1: begin
							rd_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						default: begin
							rd_en_Q <= 0;
							mem_addr_Q <= 0;
						end
					endcase
					stall_cycles_Q <= stall_cycles_Q + 1;
				end
				3'd3: begin
					// In this state, you are writing to memory depending
					// on the ACSNOOP
					case (ACSNOOP_Q)
						AC_READONCE_7: begin
							wr_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
							mem_data_Q <= cache_line_Q;
							
						end
						AC_READCLEAN_4 begin
							wr_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READNOTSHAREDDIRTY_5: begin
							wr_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READSHARED_6: begin
							wr_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_READUNIQUE_1: begin
							wr_en_Q <= 1;
							mem_addr_Q <= ACADDR_Q;
						end
						AC_CLEANSHARED_14: begin
							wr_en_Q <= 1;


						end
						AC_CLEANVALID_15: begin
							wr_en_Q <= 1;

						end
						AC_MAKEINVALID_16: begin
							wr_en_Q <= 1;

						end
						default: begin
							wr_en_Q <= 0;
						end
					endcase


				end
			endcase
		end
	end




	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			axi_init_fsm_cs <= 0;
		end
		else begin
			axi_init_fsm_cs <= axi_init_fsm_ns;
		end
	end




endmodule
