`timescale 1ns / 1ps

module hilo(
        input                   clk,
        input                   rst,

        input                   hilo_wen_wb,
        input [63:0]            hilo_result_wb,

        input                   hilo_wen_mem,
        input [63:0]            hilo_result_mem,
        
        output logic [63:0]     hilo_value
);

    reg [63:0] hilo_register;

    always_ff @(posedge clk) begin : write_to_hilo
        if(rst)
            hilo_register <= 64'd0;
        else if(hilo_wen_wb)
            hilo_register <= hilo_result_wb;
    end

    always_comb begin : select_output
        if(hilo_wen_mem)
            hilo_value = hilo_result_mem;
        else if(hilo_wen_wb)
            hilo_value = hilo_result_wb;
        else
            hilo_value = hilo_register;
    end

endmodule