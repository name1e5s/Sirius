`timescale 1ns / 1ps
`include "common.vh"
module writeback_beta(
        input [31:0]                result,
        input [4:0]                 reg_dest,
        input                       write_en,

        output logic                reg_write_en,
        output logic [4:0]          reg_write_dest,
        output logic [31:0]         reg_write_data
);

    always_comb begin : generate_output
        reg_write_en = write_en;
        reg_write_dest = reg_dest;
        reg_write_data = result;
    end

endmodule
