`timescale 1ns / 1ps

module mmu_top(
        input                   clk,
        input                   rst,
        // Inst channel
        input                   inst_en,
        input [31:0]            inst_addr,
        input                   inst_uncached,
        output logic            inst_ok,
        output logic            inst_ok_1,
        output logic            inst_ok_2,
        output logic [31:0]     inst_data_1,
        output logic [31:0]     inst_data_2,
        // Data channel
        input                   data_en,
        input [3:0]             data_wen,
        input [31:0]            data_addr,
        input                   data_uncached,
        input [31:0]            data_wdata,
        input [2:0]             data_size,
        output logic            data_ok,
        output logic [31:0]     data_data,

        // Cache control
        input                   inst_hit_invalidate,
        input                   data_hit_writeback,
        input                   index_invalidate,

        // AXI
        //ar
        output logic [3 :0]     arid,
        output logic [31:0]     araddr,
        output logic [7 :0]     arlen,
        output logic [2 :0]     arsize,
        output logic [1 :0]     arburst,
        output logic [1 :0]     arlock,
        output logic [3 :0]     arcache,
        output logic [2 :0]     arprot,
        output logic            arvalid,
        input                   arready,
        //r           
        input  [3 :0]           rid,
        input  [31:0]           rdata,
        input  [1 :0]           rresp,
        input                   rlast,
        input                   rvalid,
        output logic            rready,
        //aw          
        output logic [3 :0]     awid,
        output logic [31:0]     awaddr,
        output logic [7 :0]     awlen,
        output logic [2 :0]     awsize,
        output logic [1 :0]     awburst,
        output logic [1 :0]     awlock,
        output logic [3 :0]     awcache,
        output logic [2 :0]     awprot,
        output logic            awvalid,
        input                   awready,
        //w          
        output logic [3 :0]     wid,
        output logic [31:0]     wdata,
        output logic [3 :0]     wstrb,
        output logic            wlast,
        output logic            wvalid,
        input                   wready,
        //b           
        input  [3 :0]           bid,
        input  [1 :0]           bresp,
        input                   bvalid,
        output logic            bready       
);

    // Set default value
    assign  arid    = 4'd0;
    assign  arlock  = 2'd0;
    assign  arcache = 4'd0;
    assign  arprot  = 3'd0;

    assign  rready = 1'b1;

    assign  awid    = 4'd0;
    assign  awlock  = 2'd0;
    assign  awcache = 4'd0;
    assign  awprot  = 3'd0;

    assign  wid     = 4'd0;
    assign  bready  = 1'b1;

    // Addr tran
    logic [31:0]    iaddr_psy, daddr_psy;
    logic           iaddr_type, daddr_type;

    always_comb begin
        iaddr_psy   = inst_addr;
        iaddr_type  = inst_uncached;
        daddr_psy   = data_addr;
        daddr_type  = data_uncached;
    end

    // Inst channel
    wire        inst_running;
    wire [31:0] iaddr_req;
    wire        iread_en;
    wire        iread_type;
    logic       iaddr_req_ok;
    logic[31:0] idata_rdata;
    logic       idata_rvalid;
    logic       idata_rlast;

    mmu_inst inst_ctrl(
        .clk            (clk),
        .rst            (rst),
        .ien            (inst_en),
        .iaddr_psy      (inst_hit_invalidate? daddr_psy : iaddr_psy),
        .iaddr_type     (iaddr_type),
        .inst_ok        (inst_ok),
        .inst_ok_1      (inst_ok_1),
        .inst_ok_2      (inst_ok_2),
        .inst_data_1    (inst_data_1),
        .inst_data_2    (inst_data_2),
        .iaddr_req      (iaddr_req),
        .read_en        (iread_en),
        .read_type      (iread_type),
        .iaddr_req_ok   (iaddr_req_ok),
        .idata_rdata    (idata_rdata),
        .idata_rvalid   (idata_rvalid),
        .idata_rlast    (idata_rlast),
        .mmu_running    (inst_running),
        .inst_hit_invalidate(inst_hit_invalidate),
        .index_invalidate(index_invalidate)
    );

    // Data channel
    wire        data_running;
    wire [31:0] daddr_req;
    wire        dread_en;
    wire        dread_type;
    logic       daddr_req_ok;
    logic[31:0] ddata_rdata;
    logic       ddata_rvalid;
    logic       ddata_rlast;

    wire [31:0] daddr_wreq;
    wire        write_en;
    wire        write_type;
    wire [3:0]  write_byte_en;
    wire        dwvalid;
    wire [31:0] dwdata;
    wire        dwlast;
    logic       daddr_wreq_ok;
    logic       ddata_wready;
    logic       ddata_bvalid;
    logic [2:0] data_size_out;

    mmu_data data_ctrl(
        .clk            (clk),
        .rst            (rst),
        .den            (data_en),
        .dwen           (data_wen),
        .daddr_psy      (daddr_psy),
        .wdata          (data_wdata),
        .daddr_type     (daddr_type),
        .data_ok        (data_ok),
        .data_data      (data_data),
        .daddr_req      (daddr_req),
        .read_en        (dread_en),
        .read_type      (dread_type),
        .daddr_req_ok   (daddr_req_ok),
        .ddata_rdata    (ddata_rdata),
        .ddata_rvalid   (ddata_rvalid),
        .ddata_rlast    (ddata_rlast),
        .daddr_wreq     (daddr_wreq),
        .write_en       (write_en),
        .write_type     (write_type),
        .write_byte_en  (write_byte_en),
        .data_size_in   (data_size),
        .data_size_out  (data_size_out),
        .dwvalid        (dwvalid),
        .dwdata         (dwdata),
        .dwlast         (dwlast),
        .daddr_wreq_ok  (daddr_wreq_ok),
        .ddata_wready   (ddata_wready),
        .ddata_bvalid   (ddata_bvalid),
        .mmu_running    (data_running),
        .data_hit_writeback(data_hit_writeback),
        .index_invalidate(index_invalidate)
    );

    // Read channel 
    always_comb begin
        if((iread_en && inst_running && dread_en && data_running) || (data_running && ~dread_en && inst_running) || (data_running && ~inst_running)) begin // Data first
            araddr          = daddr_req;
            arlen           = dread_type ? 8'd0 : 8'd15;
            arburst         = dread_type ? 2'd0 : 2'd1;
            arvalid         = dread_en;
            daddr_req_ok    = arready;
            ddata_rdata     = rdata;
            ddata_rvalid    = rvalid;
            ddata_rlast     = rlast;
            iaddr_req_ok    = 1'd0;
            idata_rdata     = 32'd0;
            idata_rvalid    = 1'd0;
            idata_rlast     = 1'd0;
            arsize          = dread_type ? data_size : 3'b010;
        end
        else begin
            araddr          = iaddr_req;
            arlen           = iread_type ? 8'd0 : 8'd15;
            arburst         = iread_type ? 2'd0 : 2'd1;
            arsize          = 3'b010;
            arvalid         = iread_en;
            iaddr_req_ok    = arready;
            idata_rdata     = rdata;
            idata_rvalid    = rvalid;
            idata_rlast     = rlast;
            daddr_req_ok    = 1'd0;
            ddata_rdata     = 32'd0;
            ddata_rvalid    = 1'd0;
            ddata_rlast     = 1'd0;
        end
    end

    // Write channel
    always_comb begin
        awaddr          = daddr_wreq;
        awlen           = write_type ? 8'd0 : 8'd15;
        awburst         = write_type ? 2'd0 : 2'd1;
        awvalid         = write_en;
        wstrb           = write_byte_en;
        wdata           = dwdata;
        wvalid          = dwvalid;
        wlast           = dwlast;
        daddr_wreq_ok   = awready;
        ddata_wready    = wready;
        ddata_bvalid    = bvalid;
        awsize          = write_type ? data_size_out : 3'b010;
    end

endmodule