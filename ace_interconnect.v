module ace_interconnect #(
	parameter NUM_MASTERS = 8,
	parameter LEN_SIZE = 8,
	parameter ID_SIZE = 8,
	parameter ADDR_SIZE = 32,
	parameter DATA_SIZE = 128,
	parameter STRB_SIZE = DATA_SIZE/8,
	parameter NUM_DATA_SIZE_CACHELINE = 4     //This indicates how many data_size elements are in one cache line
)
(
	// CLK and Reset
	input logic ACLK,
	input logic ARESETn,

	//Write Address Signals
	input logic [NUM_MASTERS*ID_SIZE-1:0] AWID,
	input logic [NUM_MASTERS*ADDR_SIZE-1:0] AWADDR,
	input logic [NUM_MASTERS*LEN_SIZE-1:0] AWLEN,
	input logic [NUM_MASTERS*2-1:0] AWBURST,
	input logic [NUM_MASTERS-1:0] AWVALID,
	output logic [NUM_MASTERS-1:0] AWREADY,

	//Write Data Signals
	input logic [NUM_MASTERS*DATA_SIZE-1:0] WDATA,
	input logic [NUM_MASTERS*STRB_SIZE-1:0] WSTRB,
	input logic [NUM_MASTERS-1:0] WLAST,
	input logic [NUM_MASTERS-1:0] WUSER,
	input logic [NUM_MASTERS-1:0] WVALID,
	output logic [NUM_MASTERS-1:0] WREADY,

	//Write Response signals
	output logic [NUM_MASTERS*ID_SIZE-1:0] BID,
	output logic [NUM_MASTERS*3-1:0] BRESP,
	output logic [NUM_MASTERS-1:0] BVALID,
	input logic [NUM_MASTERS-1:0] BREADY,

	//Read Address Signals
	input logic [NUM_MASTERS*ID_SIZE-1:0] ARID,
	input logic [NUM_MASTERS*ADDR_SIZE-1:0] ARADDR,
	input logic [NUM_MASTERS*LEN_SIZE-1:0] ARLEN,
	input logic [NUM_MASTERS*2-1:0] ARBURST,
	input logic [NUM_MASTERS-1:0] ARVALID,
	output logic [NUM_MASTERS-1:0] ARREADY,

	//Read Data Signals
	output logic [NUM_MASTERS*ID_SIZE-1:0] RID,
	output logic [NUM_MASTERS*DATA_SIZE-1:0] RDATA,
	output logic [NUM_MASTERS-1:0] RLAST,
	output logic [NUM_MASTERS*4-1:0] RRESP,
  output logic [NUM_MASTERS-1:0] RVALID,
	input logic [NUM_MASTERS-1:0] RREADY,

  //Coherence Signals
	input logic [NUM_MASTERS*4-1:0] ARSNOOP,
	input logic [NUM_MASTERS*2-1:0] ARDOMAIN,
	input logic [NUM_MASTERS*2-1:0] ARBAR,
	input logic [NUM_MASTERS*4-1:0] AWSNOOP,
	input logic [NUM_MASTERS*2-1:0] AWDOMAIN,
	input logic [NUM_MASTERS*2-1:0] AWBAR,

	//Snoop Signals
	output logic [NUM_MASTERS-1:0] ACVALID,
	input logic [NUM_MASTERS-1:0] ACREADY,
	output logic [NUM_MASTERS*ADDR_SIZE-1:0] ACADDR,
	output logic [NUM_MASTERS*4-1:0] ACSNOOP,
	output logic [NUM_MASTERS*3-1:0] ACPROT,

	//Snoop Response
	input logic [NUM_MASTERS-1:0] CRVALID,
	output logic [NUM_MASTERS-1:0] CRREADY,
	input logic [NUM_MASTERS*5-1:0] CRRESP,

	//Snoop Data
	input logic [NUM_MASTERS-1:0] CDVALID,
	output logic [NUM_MASTERS-1:0] CDREADY,
	input logic [NUM_MASTERS*DATA_SIZE-1:0] CDDATA,
	input logic [NUM_MASTERS-1:0] CDLAST,

	//Snoop ACK
	input logic [NUM_MASTERS-1:0] RACK,
	input logic [NUM_MASTERS-1:0] WACK
);

	logic [NUM_MASTERS-1:0] ar_trans_to_arb_vld;
	logic [NUM_MASTERS-1:0] aw_trans_to_arb_vld;
	logic [NUM_MASTERS-1:0] w_direct_mem;
	logic [NUM_MASTERS-1:0] r_direct_mem;

	logic [15:0] bids_from_masters;
	logic [15:0] wins_from_masters;
	logic get_next_win;

	logic any_bids;
	logic intercon_busy;
	logic [ADDR_SIZE*NUM_MASTERS-1:0] ACADDR_int;
	logic [4*NUM_MASTERS-1:0] ACSNOOP_int;
	logic [3*NUM_MASTERS-1:0] ACPROT_int;
	logic [ADDR_SIZE-1:0] ACADDR_from_master;
	logic [3:0] ACSNOOP_from_master;
	logic [2:0] ACPROT_from_master;

	logic [NUM_MASTERS-1:0] masters_trans_vld;
	logic [NUM_MASTERS-1:0] snoop_logic_trans_vld;
	logic [NUM_MASTERS-1:0] intercon_busy_from_masters;
	logic [NUM_MASTERS-1:0] done_data_from_masters;
	logic [NUM_MASTERS-1:0] start_from_cache_line_aggr;
	logic [NUM_MASTERS-1:0] stop_from_cache_line_aggr;
	logic [NUM_MASTERS*DATA_SIZE-1:0] cache_line_out_from_masters;
	logic [NUM_MASTERS*5-1:0] crresp_out_from_masters;
	logic [NUM_MASTERS-1:0] crresp_vld_from_masters;
	logic [DATA_SIZE-1:0] cache_line_from_mux;

	genvar i;

	generate
		for (i = 0 ; i < NUM_MASTERS; i = i + 1) begin
			axi_addr_logic inst_master(
			.ACLK						(ACLK),
			.ARESETn				(ARESETn),
			//Write Address Signals
			.AWID						(AWID[ID_SIZE*i+ID_SIZE-1:i*ID_SIZE]),
			.AWADDR					(AWADDR[ADDR_SIZE*i+ADDR_SIZE-1:i*ADDR_SIZE]),
			.AWLEN					(AWLEN[LEN_SIZE*i+LEN_SIZE-1:i*LEN_SIZE]),
			.AWBURST				(AWBURST[2*i+2-1:i*2]),
			.AWVALID				(AWVALID[i]),
			.AWREADY				(AWREADY[i]),
			//Read Address Signals
			.ARID						(ARID[ID_SIZE*i+ID_SIZE-1:i*ID_SIZE]),
			.ARADDR					(ARADDR[ADDR_SIZE*i+ADDR_SIZE-1:i*ADDR_SIZE]),
			.ARLEN					(ARLEN[LEN_SIZE*i+LEN_SIZE-1:i*LEN_SIZE]),
			.ARBURST				(ARBURST[2*i+2-1:i*2]),
			.ARVALID				(ARVALID[i]),
			.ARREADY				(ARREADY[i]),
			//Coherence Signals
			.ARSNOOP				(ARSNOOP[4*i+4-1:i*4]),
			.ARDOMAIN				(ARDOMAIN[2*i+2-1:i*2]),
			.ARBAR					(ARBAR[2*i+2-1:i*2]),
			.AWSNOOP				(AWSNOOP[4*i+4-1:i*4]),
			.AWDOMAIN				(AWDOMAIN[2*i+2-1:i*2]),
			.AWBAR					(AWBAR[2*i+2-1:i*2]),
			//Snoop Signals
			.ACADDR					(ACADDR_int[ADDR_SIZE*i+ADDR_SIZE-1:i*ADDR_SIZE]),
			.ACSNOOP				(ACSNOOP_int[4*i+4-1:i*4]),
			.ACPROT					(ACPROT_int[3*i+3-1:3*i]),
			//Signals to Arbiter
			.ar_trans_to_arb_vld		(ar_trans_to_arb_vld[i]),
			.aw_trans_to_arb_vld		(aw_trans_to_arb_vld[i]),
			.w_direct_mem						(w_direct_mem[i]),
			.r_direct_mem						(r_direct_mem[i])
			);
		end
	endgenerate

	// Note that the arbiter has 16 slots, so you can only have
	// a max of 8 masters (each master occupies two slots, the
	// one for ar_trans and one for aw_trans)
	// The design is partitioned so that the lower bits are 
	// all the ar_trans and the higher ones are all aw_trans

	//TODO: Note that the intercon_busy needs to only be released after the 
	//      initiating master has finished its transaction - currently it is
	//      set so that it only depends on intercon_busy_from_masters which
	//      is dependent on the snooped masters not the initiating master
	assign intercon_busy = |intercon_busy_from_masters;
	assign bids_from_masters = {aw_trans_to_arb_vld, ar_trans_to_arb_vld};
	assign any_bids = |bids_from_masters;
	assign get_next_win = any_bids && !intercon_busy;
	assign snoop_logic_trans_vld = !masters_trans_vld;

	fairArb inst_arbiter (
		.bids 				(bids_from_masters),
		.wins 				(wins_from_masters),
		.get_next_win	(get_next_win),
		.clk 					(ACLK),
		.rst 					(ARESETn)
	);

	or_glogic_wins inst_or_glogic_wins (
		.data_in(wins_from_masters),
		.data_out(masters_trans_vld)
	);

	mux_sel_AC_sigs inst_sel_AC_sigs(
		.AC_sigs_m0({ACADDR_int[31:0]   ,ACSNOOP_int[3:0]  ,ACPROT_int[2:0]}),
		.AC_sigs_m1({ACADDR_int[63:32]  ,ACSNOOP_int[7:4]  ,ACPROT_int[5:3]}),
		.AC_sigs_m2({ACADDR_int[95:64]  ,ACSNOOP_int[11:8] ,ACPROT_int[8:6]}),
		.AC_sigs_m3({ACADDR_int[127:96] ,ACSNOOP_int[15:12],ACPROT_int[11:9]}),
		.AC_sigs_m4({ACADDR_int[159:128],ACSNOOP_int[19:16],ACPROT_int[14:12]}),
		.AC_sigs_m5({ACADDR_int[191:160],ACSNOOP_int[23:20],ACPROT_int[17:15]}),
		.AC_sigs_m6({ACADDR_int[223:192],ACSNOOP_int[27:24],ACPROT_int[20:18]}),
		.AC_sigs_m7({ACADDR_int[255:224],ACSNOOP_int[31:28],ACPROT_int[23:21]}),
		.mux_sel(wins_from_masters),
		.ACADDR_out(ACADDR_from_master),
		.ACSNOOP_out(ACSNOOP_from_master),
		.ACPROT_out(ACPROT_from_master)
	);

	generate
		for (i = 0 ; i < NUM_MASTERS; i = i + 1) begin
			axi_snoop_logic inst_axi_snoop_logic (
				.ACLK          			(ACLK),
				.ARESETn          	(ARESETn),
				.ACVALID          	(ACVALID[i]),
				.ACREADY          	(ACREADY[i]),
				.ACADDR          		(ACADDR[ADDR_SIZE*i+ADDR_SIZE-1:i*ADDR_SIZE]),
				.ACSNOOP          	(ACSNOOP[4*i+4-1:i*4]),
				.ACPROT          		(ACPROT[3*i+3-1:i*3]),
				.CRVALID          	(CRVALID[i]),
				.CRREADY          	(CRREADY[i]),
				.CRRESP          		(CRRESP[5*i+5-1:i*5]),
				.CDVALID          	(CDVALID[i]),
				.CDREADY          	(CDREADY[i]),
				.CDDATA          		(CDDATA[DATA_SIZE*i+DATA_SIZE-1:i*DATA_SIZE]),
				.CDLAST          		(CDLAST[i]),
				.ACADDR_intercon  	(ACADDR_from_master),
				.ACSNOOP_intercon 	(ACSNOOP_from_master),
				.ACPROT_intercon  	(ACPROT_from_master),
				.trans_vld        	(snoop_logic_trans_vld[i]),
				.intercon_busy    	(intercon_busy_from_masters[i]),
				.done_data_out    	(done_data_from_masters[i]),
				.start            	(start_from_cache_line_aggr[i]),
				.stop             	(stop_from_cache_line_aggr[i]),
				.cache_line_section (cache_line_out_from_masters[DATA_SIZE*i+DATA_SIZE-1:i*DATA_SIZE]),
				.cache_line_out   	(),
				.CRRESP_OUT       	(crresp_out_from_masters[5*i+5-1:i*5]),
				.crresp_vld					(crresp_vld_from_masters[i])
			);
		end
	endgenerate

	mux_sel_cache_line  inst_mux_cache_line(
		.cache_line_m0		(cache_line_out_from_masters[127:0]),
		.cache_line_m1		(cache_line_out_from_masters[255:128]),
		.cache_line_m2		(cache_line_out_from_masters[383:256]),
		.cache_line_m3		(cache_line_out_from_masters[511:384]),
		.cache_line_m4		(cache_line_out_from_masters[639:512]),
		.cache_line_m5		(cache_line_out_from_masters[767:640]),
		.cache_line_m6		(cache_line_out_from_masters[895:768]),
		.cache_line_m7		(cache_line_out_from_masters[1023:896]),
		.mux_sel					(start_from_cache_line_aggr),
		.cache_line_out		(cache_line_from_mux)
	);


	cache_line_aggr inst_cache_line_aggregator (
		.ACLK							(ACLK),
		.ARESETn					(ARESETn),
		.cache_line_in		(cache_line_from_mux),    
		.crresp_vld				(crresp_vld_from_masters),				
		.crresp_in				(crresp_out_from_masters),
		.done_data_in			(done_data_from_masters),
		.start						(start_from_cache_line_aggr),
		.stop							(stop_from_cache_line_aggr),
		.cache_line_out		(),
		.crresp_out				(),
		.data_rdy					(),
		.no_data					()
	);


endmodule
