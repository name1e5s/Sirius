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
        output logic [31:0]     data_data
);

endmodule