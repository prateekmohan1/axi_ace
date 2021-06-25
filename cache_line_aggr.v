module cache_line_aggr #(
	parameter DATA_SIZE = 128,
	parameter NUM_MASTERS = 8
)
(
	input logic ACLK,
	input logic ARESETn,
	// This corresponds to the cache line that is being sent my the master
	input logic [DATA_SIZE-1:0] cache_line_in,    
	// This corresponds to the crresp_vld line from each master. If this is high, 
	// then that means the master has sent a crresp for the snoop transaction
	input logic [NUM_MASTERS-1:0] crresp_vld,				
	// This corresponds to the actual crresp line from each master. If this is high, 
	// then that means the master has sent a crresp for the snoop transaction
	input logic [NUM_MASTERS*5-1:0] crresp_in,
	// This corresponds to a bit from each master to indicate that the data
	// transfer is completed (if a master being snooped is sending back data
	// then this bit means that master has finished sending the data and it
	// is ready for consumption
	input logic [NUM_MASTERS-1:0] done_data_in,

	// This corresponds to the bit that tells the master to start sending the data
	output logic [NUM_MASTERS-1:0] start,
	// This corresponds to the bit that tells the master to stop its processing 
	// because another master has already acknowledged that it has the data
	output logic [NUM_MASTERS-1:0] stop,
	output logic [DATA_SIZE*4-1:0] cache_line_out,
	output logic [3:0] crresp_out,
	output logic data_rdy,
	output logic no_data
);

	logic [NUM_MASTERS-1:0] crresp_isDirty;
	logic [NUM_MASTERS-1:0] crresp_chk;

	logic [2:0] fsm_aggr_cs, fsm_aggr_ns;
	logic [4:0] index_pos, index_pos_Q;
	logic [4:0] index_pos_done_data, index_pos_done_data_Q;
	logic chk_dirty_Q;
	logic [NUM_MASTERS-1:0] done_data_in_Q;

	logic [3:0] mux_sel_cache_line;
	logic [DATA_SIZE*4-1:0] cache_line_out_Q, cache_line_out_int;
	logic [4:0] crresp_int, crresp_out_Q;
	logic data_rdy_Q;

	logic [NUM_MASTERS-1:0] start_Q, stop_Q;
	logic [1:0] stall_cycles_Q;
	logic [1:0] data_cache_line_Q;
	logic [DATA_SIZE*4-1:0] cache_line_Q;	
	
	logic no_data_D, no_data_Q;

	assign no_data = no_data_Q;
	assign start = start_Q;
	assign stop = stop_Q;
	
	genvar i;

	//Here you isolate the isDirty bits from the 
	//crresp coming from all the masters to 
	//have it all in one bus
	generate
		for (i = 0 ; i < NUM_MASTERS; i = i + 1) begin
			assign crresp_isDirty[i] = crresp_in[i*NUM_MASTERS+2];
		end
	endgenerate

	//Here you just check if the chk is valid or not
	assign crresp_chk = crresp_isDirty & crresp_vld;
	assign cache_line_out = cache_line_out_Q;
	assign data_rdy = data_rdy_Q;
	assign crresp_out = crresp_out_Q;


	//Find the first one in the crresp_chk and return
	//the index of that one
	find_ones inst_find_ones_crresp(
		.ones_chk(crresp_chk),
		.index_pos(index_pos)
	);

	find_ones  inst_find_ones_done_data(
		.ones_chk(done_data_in_Q),
		.index_pos(index_pos_done_data)
	);

	mux_crresp inst_mux_crresp (
		.crresp_in   	(crresp_in),
		.mux_sel     	(mux_sel_cache_line),
		.crresp_out 	(crresp_int)
	);

	always @ (*) begin
		fsm_aggr_ns = fsm_aggr_cs;
		mux_sel_cache_line = 0;
		case (fsm_aggr_cs) 
			3'd0: begin
				// Here you have to check if the crresp_chk is 
				// non zero (meaning you have a dirty bit
				// Or also check if you've received data from
				// all masters
				if (crresp_chk != 0) begin
					fsm_aggr_ns = 3'd1;
				end
				else if (crresp_vld == 8'hff) begin
					fsm_aggr_ns = 3'd1;
				end
				else begin
					fsm_aggr_ns = 3'd0;
				end
			end
			3'd1: begin
				// Here, if you have seen a dirty bit then
				// you choose the specific cache line
				// to output
				if (chk_dirty_Q) begin
					// If you are here, then you have a dirty
					// line
					if (done_data_in_Q[index_pos_Q]) begin
						// Select the specific cache line mux
						mux_sel_cache_line = index_pos_Q;
						fsm_aggr_ns = 3'd3;
					end
					else begin
						// Here, you are still waiting for 
						// the data to come back so just wait
						mux_sel_cache_line = 0;
						fsm_aggr_ns = 3'd1;
					end
				end
				else begin
					// If you are here, then there were absolutely
					// no dirty bits found, but data could still
					// be sent
					if (done_data_in_Q != 0) begin
						// Now here, you need to find a specific line
						// to choose and send
						// So for that, you would need to find the
						// first one in the done_data_in_Q line
						mux_sel_cache_line = index_pos_done_data_Q;
						fsm_aggr_ns = 3'd3;
					end
					else begin
						// Here, you have found no cache lines in the 
						// snooped masters at all
						mux_sel_cache_line = 0;
						fsm_aggr_ns = 3'd2;
					end
				end
			end
			3'd2: begin
				// In this state, you have found no cache lines that
				// need to be transmitted 
				fsm_aggr_ns = 3'd2;
			end
			3'd3: begin
				// In this state, you need to set the start
				// and stop output
				// You also stall for 2 cycles because you need
				// the start_Q to be registered 
				if (stall_cycles_Q == 2'd2) begin
					fsm_aggr_ns = 3'd4;
				end
				else begin
					fsm_aggr_ns = 3'd3;
				end
			end
			3'd4: begin
				// In this state you are receiving data now from
				// the master in the input line cache_line_in
				if (data_cache_line_Q == 2'd3)	fsm_aggr_ns = 3'd5;
				else														fsm_aggr_ns = 3'd4;
			end
			3'd5: begin
				// If you are in this state, you have data that is 
				// ready to send to the initiating master so you just
				// go to the next state
				fsm_aggr_ns = 3'd6;
			end
			3'd6: begin
				// Here you are sending the data in the cahce line 
				// to the masters
				fsm_aggr_ns = 3'd6;
			end
		endcase
	end


	always @ (posedge ACLK) begin
		if (~ARESETn) begin
			index_pos_Q <= 0;
			chk_dirty_Q <= 0;
			cache_line_out_Q <= 0;
			data_rdy_Q <= 0;
			no_data_Q <= 0;
			start_Q <= 0;
			stop_Q <= 0;
			stall_cycles_Q <= 0;
			data_cache_line_Q <= 0;
		end
		else begin
			index_pos_Q <= index_pos_Q;
			chk_dirty_Q <= chk_dirty_Q;
			data_rdy_Q <= data_rdy_Q;
			no_data_Q <= no_data_Q;
			start_Q <= start_Q;
			stop_Q <= stop_Q;
			stall_cycles_Q <= stall_cycles_Q;
			data_cache_line_Q <= data_cache_line_Q;
			case (fsm_aggr_cs) 
				3'd0: begin
					// Here, you are setting the chk_dirty_Q if
					// you find a crresp_chk that is non zero
					// which means you have a dirty entry
					no_data_Q <= 0;
					index_pos_done_data_Q <= index_pos_done_data;
					if (crresp_chk != 0) begin
						index_pos_Q <= index_pos;
						chk_dirty_Q <= 1;
					end
					else begin
						index_pos_Q <= index_pos_Q;
						chk_dirty_Q <= 0;
					end
				end
				3'd1: begin
					// Here, you are checking if you have a dirty entry
					// and if you do, choose the appropriate cache line
					// to output and set that the data is ready
					if (chk_dirty_Q) begin
						// If you are here, then one master has responded
						// with a dirty entry, and so you have to 
						// output that cache line out
						// Also, set the no_data_Q to 0, because if you have
						// seen a dirty bit come from a master, data has to 
						// come from some master
						no_data_Q <= 0;
						if (done_data_in_Q[index_pos_Q]) begin
							crresp_out_Q <= crresp_int;
						end
						else begin
							crresp_out_Q <= crresp_int;
							data_rdy_Q <= 0;
						end
					end
					else begin
						// If you are here, there were no dirty bits
						// found, but data could still be sent
						if (done_data_in_Q != 0) begin
							no_data_Q <= 0;
						end
						else begin
							// If you are here then that means no data is
							// possible to be sent, so you have to let the 
							// requesting master know that nothing is in 
							// the cache
							no_data_Q <= 1;
						end
					end
				end
				3'd2: begin
					// If you are in this state, then you have
					// checked all masters, and there is no data
					// that is in them at all
					no_data_Q <= 1;
				end
				3'd3: begin
					// In this state, you are going to send the start
					// and stop bits to all the masters - also, you are
					// going to start the transaction to grab the data 
					// from the master that has said that it has data
					start_Q <= 1'b1 << index_pos_Q;
					stop_Q <= !(1'b1 << index_pos_Q);
					if (stall_cycles_Q == 2'd2) stall_cycles_Q <= 0;
					else												stall_cycles_Q <= stall_cycles_Q + 1;
				end
				3'd4: begin
					//TODO: Can merge this state's logic with State 4
					// In this state, you are receiving data from the axi snoop
					// logic and you are storing it locally
					// TODO: This should not be the case normally
					case(data_cache_line_Q)
						2'd0: begin
							cache_line_Q[DATA_SIZE*(0+1)-1:DATA_SIZE*0] <= cache_line_in;
						end
						2'd1: begin
							cache_line_Q[DATA_SIZE*(1+1)-1:DATA_SIZE*1] <= cache_line_in;
						end
						2'd2: begin
							cache_line_Q[DATA_SIZE*(2+1)-1:DATA_SIZE*2] <= cache_line_in;
						end
						2'd3: begin
							cache_line_Q[DATA_SIZE*(3+1)-1:DATA_SIZE*3] <= cache_line_in;
						end
					endcase
					data_cache_line_Q <= data_cache_line_Q + 1;
				end
				3'd5: begin
					// In this state, we have to set the data_rdy_Q 
					// line to tell the masters that you have data 
					// ready
					data_rdy_Q <= 1;
					data_cache_line_Q <= 0;
				end
				3'd6: begin
					// In this state, we are writing to the output 
					// cache_line_out_Q with the data to send
					case(data_cache_line_Q)
						2'd0: begin
							cache_line_out_Q <= cache_line_Q[DATA_SIZE*(0+1)-1:DATA_SIZE*0];
						end                                                             
						2'd1: begin                                                     
							cache_line_out_Q <= cache_line_Q[DATA_SIZE*(1+1)-1:DATA_SIZE*1];
						end                                                             
						2'd2: begin                                                     
							cache_line_out_Q <= cache_line_Q[DATA_SIZE*(2+1)-1:DATA_SIZE*2];
						end                                                             
						2'd3: begin                                                     
							cache_line_out_Q <= cache_line_Q[DATA_SIZE*(3+1)-1:DATA_SIZE*3];
						end
					endcase
					data_cache_line_Q <= data_cache_line_Q + 1;
				end
			endcase
		end
	end

	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			done_data_in_Q <= 0;
		end
		else begin
			done_data_in_Q <= done_data_in;
		end
	end

	always @ (posedge ACLK) begin
		if (!ARESETn) begin
			fsm_aggr_cs <= 0;
		end
		else begin
			fsm_aggr_cs <= fsm_aggr_ns;
		end
	end


endmodule

module mux_crresp #(
	parameter NUM_MASTERS = 8
)
(
	input logic [NUM_MASTERS*5-1:0] crresp_in,
	input logic [3:0] mux_sel,
	output logic [4:0] crresp_out
);

	assign crresp_out	= (mux_sel == 0)  ? crresp_out[4:0] :
											(mux_sel == 1)  ? crresp_out[9:5] :
											(mux_sel == 2)  ? crresp_out[14:10] :
											(mux_sel == 3)  ? crresp_out[19:15] :
											(mux_sel == 4)  ? crresp_out[24:20] :
											(mux_sel == 5)  ? crresp_out[29:25] :
											(mux_sel == 6)  ? crresp_out[34:30] :
											(mux_sel == 7)  ? crresp_out[39:35] :
																				5'd0;

endmodule


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
										 (ones_chk[7]) ? 5'd7 :
										 								 5'd0 ;

endmodule
