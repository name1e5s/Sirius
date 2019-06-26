`timescale 1ns / 1ps
`include "alu_op.vh"
`include "common.vh"

// Pipeline stall control
module pipe_ctrl(
        input               icache_stall,
        input               ex_stall,
        input               mem_stall,
        
        input [5:0]         id_ex_alu_op,
        input [1:0]         id_ex_mem_type,
        input [4:0]         id_ex_mem_wb_reg_dest,
        input               ex_mem_cp0_wen,
        input [1:0]         ex_mem_mem_type,
        input [4:0]         ex_mem_mem_wb_reg_dest,
        input [4:0]         id_rs,
        input [4:0]         id_rt,
        input               id_branch_taken,

        output logic        en_if,
        output logic        en_if_id,
        output logic        en_id_ex,
        output logic        en_ex_mem,
        output logic        en_mem_wb
);

    logic [4:0] en;
    assign { en_if, en_if_id, en_id_ex, en_ex_mem, en_mem_wb } = en;
    
    always_comb begin : set_control_logic
        if(mem_stall)
            en = 5'b00000;
        else if(icache_stall)
            en = 5'b00011;
        else if(ex_stall || (id_ex_alu_op == `ALU_MFC0 && ex_mem_cp0_wen))
            en = 5'b10001;
        else if(id_ex_mem_type == `MEM_LOAD &&
                ((id_ex_mem_wb_reg_dest == id_rs) ||
                (id_ex_mem_wb_reg_dest == id_rt)))
            en = 5'b10011;
        else if(ex_mem_mem_type == `MEM_LOAD &&
                ((ex_mem_mem_wb_reg_dest == id_rs) ||
                (ex_mem_mem_wb_reg_dest == id_rt)))
            en = 5'b10011;
        else
            en = 5'b11111;
    end
    
endmodule