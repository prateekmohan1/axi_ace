module axi_snoop_logic #(
	parameter ADDR_SIZE = 32,
	parameter DATA_SIZE = 128,
	parameter NUM_DATA_SIZE_CACHELINE = 4
)
(
	input logic ACLK,
	input logic ARESETn,

	// Interface to External Master
	output logic ACVALID,
	input logic  ACREADY,
	output logic [ADDR_SIZE-1:0] ACADDR,
	output logic [3:0] ACSNOOP,
	output logic [2:0] ACPROT,

	// Interface to External Master
	input logic  CRVALID,
	output logic CRREADY,
	input logic [4:0] CRRESP,

	// Interface to External Master
	input logic  CDVALID,
	output logic CDREADY,
	input logic [DATA_SIZE-1:0] CDDATA,
	input logic CDLAST,

	// From Interconnect Logic
	input logic [ADDR_SIZE-1:0] ACADDR_intercon,
	input logic [3:0] ACSNOOP_intercon,
	input logic [2:0] ACPROT_intercon,

	// From the Cache Line Aggregator
	input logic start,
	input logic stop,

	input logic trans_vld,
	output logic intercon_busy,

	output logic done_data_out,
	output logic [DATA_SIZE*NUM_DATA_SIZE_CACHELINE-1:0] cache_line_out,
	output logic [DATA_SIZE-1:0] cache_line_section,
	output logic [4:0] CRRESP_OUT,
	output logic crresp_vld
);

	logic ACVALID_Q;
	logic [ADDR_SIZE-1:0] ACADDR_Q;
	logic [3:0] ACSNOOP_Q;
	logic [2:0] ACPROT_Q;

	logic CRREADY_Q;
	logic [4:0] CRRESP_Q;

	logic CDREADY_Q;
	logic [DATA_SIZE-1:0] CDDATA_Q;
	logic CDLAST_Q;

	logic trans_vld_Q;

	logic [2:0] fsm_snoop_cs, fsm_snoop_ns, fsm_prev_state_D, fsm_prev_state_Q;
	logic intercon_busy_Q, intercon_busy_D;
	logic crresp_vld_D, crresp_vld_Q;
	logic done_data, done_data_Q;

	//Data Retrieved
	logic [DATA_SIZE*4-1:0] cache_line_Q;
	logic [DATA_SIZE-1:0] cache_line_section_Q;
	logic [1:0] index_Q;

	logic start_Q;
	logic stop_Q;

	assign intercon_busy = intercon_busy_Q;
	assign ACVALID = ACVALID_Q;
	assign ACADDR = ACADDR_Q;
	assign ACSNOOP = ACSNOOP_Q;
	assign ACPROT = ACPROT_Q;
	assign CRREADY = CRREADY_Q;
	assign CDREADY = CDREADY_Q;
	assign done_data_out = done_data_Q;
	assign cache_line_out = cache_line_Q;
	assign crresp_vld = crresp_vld_Q;
	assign CRRESP_OUT = CRRESP_Q;
	assign cache_line_section = cache_line_section_Q;

	always @ (*) begin
		intercon_busy_D = intercon_busy_Q;
		fsm_snoop_ns = fsm_snoop_cs;
		fsm_prev_state_D = fsm_prev_state_Q;
		crresp_vld_D = crresp_vld_Q;
		case (fsm_snoop_cs)
			3'd0: begin
				crresp_vld_D = 0;
				if (stop_Q) begin
					fsm_snoop_ns = 3'd6;
					intercon_busy_D = 1;
				end 
				else begin
					if (trans_vld_Q) begin
						fsm_snoop_ns = 3'd1;
						intercon_busy_D = 1;
					end
					else begin
						fsm_snoop_ns = 3'd0;
						intercon_busy_D = 0;
					end
				end
			end
			3'd1: begin
				if (stop_Q) begin
					fsm_snoop_ns = 3'd6;
				end 
				else begin 			
					//In this state, you are checking
					//if the CRVALID has been set
					if (CRVALID && CRREADY_Q) begin
						fsm_snoop_ns = 3'd2;
					end
					else begin
						fsm_snoop_ns = 3'd1;
					end
				end
			end
			3'd2: begin
				if (stop_Q) begin
					fsm_snoop_ns = 3'd6;
					crresp_vld_D = 0;
				end 
				else begin			
					crresp_vld_D = 1;
					//In this state, you have received 
					//the CRRESP and you are flopping it
					if (CRRESP[0]) begin
						fsm_snoop_ns = 3'd3;
					end
					else begin
						fsm_snoop_ns = 3'd5;
						fsm_prev_state_D = 3'd2;
					end
				end
			end
			3'd3: begin
				if (stop_Q) begin
					fsm_snoop_ns = 3'd6;
					crresp_vld_D = 0;
				end 
				else begin						
					//In this state, you know that
					//data transfer will occur
					if (CDVALID && CDREADY_Q) begin
						fsm_snoop_ns = 3'd4;
					end
					else begin
						fsm_snoop_ns = 3'd3;
					end
				end
			end
			3'd4: begin
				if (stop_Q) begin
					fsm_snoop_ns = 3'd6;
				end 
				else begin									
					//In this state you are capturing
					//data and waiting for CDLAST to
					//come
					if (CDLAST) begin
						fsm_snoop_ns = 3'd5;
						fsm_prev_state_D = 3'd4;
					end
					else begin
						fsm_snoop_ns = 3'd4;
					end
				end
			end
			3'd5: begin
				if (stop_Q) begin
					fsm_snoop_ns = 3'd6;
				end 
				else begin												
					//Now here you have captured all
					//the data and you have to wait 
					//here
					if (fsm_prev_state_Q == 3'd2) begin
						done_data = 0;
						fsm_snoop_ns = 3'd6;
						intercon_busy_D = 1'b0;
					end
					else if (fsm_prev_state_Q == 3'd4) begin
						done_data = 1;
						fsm_snoop_ns = 3'd7;
						intercon_busy_D = 1'b1;
					end
				end
			end
			3'd6: begin
				//This is the do_nothing state
				//You would go to this state if 
				//you have received the 'stop'
				//input and you will stay here
				fsm_snoop_ns = 3'd6;
				done_data = 0;
				intercon_busy_D = 1;
			end
			3'd7: begin
				//This is the state where you
				//are sending data (you are going
				//to receive a start)
				if (stop_Q || index_Q == 2'd3) begin
					fsm_snoop_ns = 3'd6;
				end
				else if (start_Q == 1 && index_Q != 2'd3) begin
					fsm_snoop_ns = 3'd7;
				end
				else begin
					fsm_snoop_ns = 3'd7;
				end
			end
		endcase
	end

	always @ (posedge ACLK) begin
		if (~ARESETn) begin
			ACVALID_Q <= 0;
			ACADDR_Q <= 0;
			ACSNOOP_Q <= 0;
			ACPROT_Q <= 0;
			CRREADY_Q <= 0;
			CRRESP_Q <= 0;
			CDREADY_Q <= 0;
			index_Q <= 0;
			cache_line_Q <= 0;
		end
		else begin
			ACVALID_Q <= ACVALID_Q;
			ACADDR_Q <= ACADDR_Q;
			ACSNOOP_Q <= ACSNOOP_Q;
			ACPROT_Q <= ACPROT_Q;
			CRREADY_Q <= CRREADY_Q;
			CRRESP_Q <= CRRESP_Q;
			CDREADY_Q <= CDREADY_Q;
			cache_line_Q <= cache_line_Q;
			index_Q <= index_Q;
			case (fsm_snoop_cs)
				3'd0: begin
					//In this state, you are waiting for
					//the interconnect to tell you that you
					//have data, and if you do have data
					//flop those values
					if (trans_vld_Q) begin
						ACVALID_Q <= 1;
						ACADDR_Q <= ACADDR_intercon;
						ACSNOOP_Q <= ACSNOOP_intercon;
						ACPROT_Q <= ACPROT_intercon;
					end
				end
				3'd1: begin
					//In this state, if ACREADY is set, you
					//deassert the ACVALID and keep it deasserted
					if (ACREADY) ACVALID_Q <= 0;
					else 				 ACVALID_Q <= ACVALID_Q;
					//Also, if you see that CRVALID is ready (the 
					//snooped master has a response) then you can
					//assert the CRREADY
					if (CRVALID && !CRREADY_Q) begin 
						CRREADY_Q <= 1;
					end
					else begin
						CRREADY_Q <= CRREADY_Q;
					end
				end
				3'd2: begin
						//In this cycle, you are capturing the CRRESP
						CRREADY_Q <= 0;
						CRRESP_Q <= CRRESP;
				end
				3'd3: begin
					//In this state, you want to set the CDREADY
					if (CDVALID && !CDREADY_Q) begin
						CDREADY_Q <= 1;
					end
					else begin
						CDREADY_Q <= CDREADY_Q;
					end
				end
				3'd4: begin
					//In this state, you are receiving data
					//from the snooped master
					CDREADY_Q <= 0;

					//Increment index
					index_Q <= index_Q + 1;
					case(index_Q)
						2'd0: begin
							cache_line_Q[DATA_SIZE*(0+1)-1:DATA_SIZE*0] <= CDDATA;
						end
						2'd1: begin
							cache_line_Q[DATA_SIZE*(1+1)-1:DATA_SIZE*1] <= CDDATA;
						end
						2'd2: begin
							cache_line_Q[DATA_SIZE*(2+1)-1:DATA_SIZE*2] <= CDDATA;
						end
						2'd3: begin
							cache_line_Q[DATA_SIZE*(3+1)-1:DATA_SIZE*3] <= CDDATA;
						end
					endcase
				end
				3'd5: begin
					//In this state, you have received all the
					//data and you are telling the 
					//cache line aggregator that you are 
					//done (setting the done_data bit)
					index_Q <= 0;
				end
				3'd6: begin
					//This is the do nothing state
					index_Q <= 0;
				end
				3'd7: begin
					//In this state, you are waiting for 
					//the start_Q and then you will put
					//out the data
					if (start_Q) begin
					case(index_Q)
						2'd0: begin
							cache_line_section_Q <= cache_line_Q[DATA_SIZE*(0+1)-1:DATA_SIZE*0];
						end
						2'd1: begin
							cache_line_section_Q <= cache_line_Q[DATA_SIZE*(1+1)-1:DATA_SIZE*1];
						end
						2'd2: begin
							cache_line_section_Q <= cache_line_Q[DATA_SIZE*(2+1)-1:DATA_SIZE*2];
						end
						2'd3: begin
							cache_line_section_Q <= cache_line_Q[DATA_SIZE*(3+1)-1:DATA_SIZE*3];
						end
					endcase
						index_Q <= index_Q + 1;
					end
					else begin
						cache_line_section_Q <= 0;
						index_Q <= 0;
					end
				end
			endcase
		end
	end

	always @ (posedge ACLK) begin
		if (~ARESETn) begin
			intercon_busy_Q <= 0;
			trans_vld_Q <= 0;
			fsm_prev_state_Q <= 0;
			done_data_Q <= 0;
			start_Q <= 0;
			stop_Q <= 0;
		end
		else begin
			intercon_busy_Q <= intercon_busy_D;
			trans_vld_Q <= trans_vld;
			fsm_prev_state_Q <= fsm_prev_state_D;
			done_data_Q <= done_data;
			start_Q <= start;
			stop_Q <= stop;
		end
	end

	always @ (posedge ACLK) begin
		if (~ARESETn) begin
			fsm_snoop_cs <= 0;
		end
		else begin
			fsm_snoop_cs <= fsm_snoop_ns;
		end
	end




endmodule
