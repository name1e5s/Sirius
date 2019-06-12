`timescale 1ns / 1ps
`include "common.vh"

module decoder_beta(
        input                       clk,
        input                       rst,

        input [31:0]                instruction,

        output logic [5:0]          opcode,
        output logic [4:0]          rs,
        output logic [4:0]          rt,
        output logic [4:0]          rd,
        output logic [4:0]          shamt,
        output logic [5:0]          funct,
        output logic [15:0]         immediate
);

    assign opcode = instruction[31:26];
    assign rs = instruction[25:21];
    assign rt = instruction[20:16];
    assign rd = instruction[15:11];
    assign shamt = instruction[10:6];
    assign funct = instruction[5:0];
    assign immediate = instruction[15:0];
    
endmodule
