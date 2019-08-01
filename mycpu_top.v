`timescale 1ns / 1ps

module mycpu_top(
		 input [4 :0]  int,
		 input 	       aclk,
		 input 	       aresetn,

		 //axi
		 //ar
		 output [3 :0] arid ,
		 output [31:0] araddr ,
		 output [7 :0] arlen ,
		 output [2 :0] arsize ,
		 output [1 :0] arburst ,
		 output [1 :0] arlock ,
		 output [3 :0] arcache ,
		 output [2 :0] arprot ,
		 output        arvalid ,
		 input 	       arready ,
		 //r           
		 input [3 :0]  rid ,
		 input [31:0]  rdata ,
		 input [1 :0]  rresp ,
		 input 	       rlast ,
		 input 	       rvalid ,
		 output        rready ,
		 //aw          
		 output [3 :0] awid ,
		 output [31:0] awaddr ,
		 output [7 :0] awlen ,
		 output [2 :0] awsize ,
		 output [1 :0] awburst ,
		 output [1 :0] awlock ,
		 output [3 :0] awcache ,
		 output [2 :0] awprot ,
		 output        awvalid ,
		 input 	       awready ,
		 //w          
		 output [3 :0] wid ,
		 output [31:0] wdata ,
		 output [3 :0] wstrb ,
		 output        wlast ,
		 output        wvalid ,
		 input 	       wready ,
		 //b           
		 input [3 :0]  bid ,
		 input [1 :0]  bresp ,
		 input 	       bvalid ,
		 output        bready
		 );

   wire         ien, iok, iok1, iok2, den, dok;
   wire [ 3:0]	dwen;
   wire [31:0]  iaddr_i, idata_i, idata2_i, daddr_i, drdata_i, dwdata_i;
   wire inst_uncached, data_uncached;
   wire inst_hit_invalidate, data_hit_writeback, index_invalidate;
   wire [2:0] data_size;
   mmu_top mmu_0(
			.clk                (aclk),
			.rst                (~aresetn),
            .inst_en            (ien),
            .inst_addr          (iaddr_i),
            .inst_data_1        (idata_i),
            .inst_ok            (iok),
			.inst_ok_1 	      	(iok1),
			.inst_ok_2		  	(iok2),
			.inst_data_2	  	(idata2_i),

            .data_en            (den),
            .data_wen           (dwen),
            .data_addr          (daddr_i),
            .data_wdata         (dwdata_i),
            .data_data          (drdata_i),
            .data_ok            (dok),
			.data_size			(data_size),

			.inst_uncached		(inst_uncached),
			.data_uncached		(data_uncached),
			.inst_hit_invalidate(inst_hit_invalidate),
			.data_hit_writeback	(data_hit_writeback),
			.index_invalidate	(index_invalidate),

			.arid               (arid),
			.araddr             (araddr),
			.arlen              (arlen),
			.arsize             (arsize),
			.arburst            (arburst),
			.arlock             (arlock),
			.arcache            (arcache),
			.arprot             (arprot),
			.arvalid            (arvalid),
			.arready            (arready),
			.rid                (rid),
			.rdata              (rdata),
			.rresp              (rresp),
			.rlast              (rlast),
			.rvalid             (rvalid),
			.rready             (rready),
			.awid               (awid),
			.awaddr             (awaddr),
			.awlen              (awlen),
			.awsize             (awsize),
			.awburst            (awburst),
			.awlock             (awlock),
			.awcache            (awcache),
			.awprot             (awprot),
			.awvalid            (awvalid),
			.awready            (awready),
			.wid                (wid),
			.wdata              (wdata),
			.wstrb              (wstrb),
			.wlast              (wlast),
			.wvalid             (wvalid),
			.wready             (wready),
			.bid                (bid),
			.bresp              (bresp),
			.bvalid             (bvalid),
			.bready             (bready)
			);
			 
   sirius cpu(
              .clk                (aclk),
              .rst                (~aresetn),
              .interrupt          (int),
              .inst_en            (ien),
              .inst_addr          (iaddr_i),
              .inst_data_1        (idata_i),
              .inst_ok            (iok),
			  .inst_ok_1 	      (iok1),
			  .inst_ok_2		  (iok2),
			  .inst_data_2		  (idata2_i),

              .data_en            (den),
              .data_wen           (dwen),
              .data_addr          (daddr_i),
              .data_wdata         (dwdata_i),
              .data_data          (drdata_i),
              .data_ok            (dok),
			  .data_size 		  (data_size),

			  .inst_uncached		(inst_uncached),
			  .data_uncached		(data_uncached),

			.inst_hit_invalidate(inst_hit_invalidate),
			.data_hit_writeback	(data_hit_writeback),
			.index_invalidate	(index_invalidate)
	      );
   
endmodule
