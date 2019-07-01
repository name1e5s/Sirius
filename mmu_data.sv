`timescale 1ns / 1ps

// daddr_psy should not be changed when pipeline stall
module mmu_data(
        input                       clk,
        input                       rst,

        // From/to sirius
        input                       den,
        input [3:0]                 dwen,
        input [31:0]                daddr_psy,
        input [31:0]                dwdata,
        
        output logic                data_ok,
        output logic                data_data,

        // From/to MMU
        // read channel
        output logic [31:0]         daddr_req,
        output logic                read_en,
        output logic                read_type, // o as cache refill, 1 as uncached
        input                       daddr_req_ok,
        input [31:0]                ddata_rdata,
        input                       ddata_rvalid,
        input                       ddata_rlast,
        // write channel
        output logic [31:0]         daddr_wreq,
        output logic                write_en,
        output logic                write_type,
        output logic [3:0]          write_byte_en,
        output logic                daddr_wreq_ok,
        output logic [31:0]         dwdata,
        output logic                dwlast,
        input                       ddata_wvalid,
        input                       ddata_wok
);

    enum logic [3:0] {
        IDLE            = 4'b0000,
        CACHED_RSHAKE   = 4'b0001,
        CACHED_REFILL   = 4'b0010,
        UNCACHED_SHAKE  = 4'b1001,
        UNCACHED_WWAIT  = 4'b1100,
        UNCACHED_RETURN = 4'b1010
    } cstate, nstate;

    enum logic [2:0] {
        IDLE            = 3'b000,
        UNCACHED_WSHAKE = 3'b001,
        UNCACHED_WRESULT= 3'b010,
        CACHED_WSHAKE   = 3'b101,
        CACHED_WWRITE   = 3'b110
    };

endmodule
