`timescale 1ns / 1ps

module mmu_top(
        input                   clk,
        input                   rst,
        // Inst channel
        input                   inst_en,
        input [31:0]            inst_addr,
        output logic            inst_ok,
        output logic            inst_ok_1,
        output logic            inst_ok_2,
        output logic [31:0]     inst_data_1,
        output logic [31:0]     inst_data_2,
        // Data channel
        input                   data_en,
        input [3:0]             data_wen,
        input [31:0]            data_addr,
        input [31:0]            data_wdata,
        output logic            data_ok,
        output logic [31:0]     data_data,

        // AXI
        //ar
        output [3 :0]           arid,
        output [31:0]           araddr,
        output [7 :0]           arlen,
        output [2 :0]           arsize,
        output [1 :0]           arburst,
        output [1 :0]           arlock,
        output [3 :0]           arcache,
        output [2 :0]           arprot,
        output                  arvalid,
        input                   arready,
        //r           
        input  [3 :0]           rid,
        input  [31:0]           rdata,
        input  [1 :0]           rresp,
        input                   rlast,
        input                   rvalid,
        output                  rready,
        //aw          
        output [3 :0]           awid,
        output [31:0]           awaddr,
        output [7 :0]           awlen,
        output [2 :0]           awsize,
        output [1 :0]           awburst,
        output [1 :0]           awlock,
        output [3 :0]           awcache,
        output [2 :0]           awprot,
        output                  awvalid,
        input                   awready,
        //w          
        output [3 :0]           wid,
        output [31:0]           wdata,
        output [3 :0]           wstrb,
        output                  wlast,
        output                  wvalid,
        input                   wready,
        //b           
        input  [3 :0]           bid,
        input  [1 :0]           bresp,
        input                   bvalid,
        output                  bready       
);

endmodule