`timescale 1ns / 1ps
`include "alu_op.vh"
`include "common.vh"

// Pipeline stall control
module pipe_ctrl(
        input               clk,
        input               rst,
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
        input               fifo_full,
        input               exp_detect,

        output logic        en_if,
        output logic        en_if_id,
        output logic        en_id_ex,
        output logic        en_ex_mem,
        output logic        en_mem_wb
);

    logic [4:0] en;
    assign { en_if, en_if_id, en_id_ex, en_ex_mem, en_mem_wb } = en;
    
    logic load_use_stall;
    always_comb begin : set_control_logic
        load_use_stall = 1'd0;
        if(rst)
            en = 5'b11111;
        else if(icache_stall) begin
            if(exp_detect || mem_stall)
                en = 5'b00000;
            else begin
                en = 5'b00001;
            end
        end
        else if(mem_stall) begin
            if(id_branch_taken)
                en = 5'b00000;
            else
                en = 5'b10000;
        end
        else if(ex_stall)
            en = 5'b10001;
        else if(id_ex_alu_op == `ALU_MFC0 && ex_mem_cp0_wen)
            en = 5'b10011;
        else if(id_ex_mem_type == `MEM_LOAD &&
                ((id_ex_mem_wb_reg_dest == id_rs) ||
                (id_ex_mem_wb_reg_dest == id_rt))) begin
            en = 5'b10011;
            load_use_stall = 1'd1;
        end
        else
            en = 5'b11111;
    end

    // For perftunning...
    logic [63:0] icache_stall_counter;
    always_ff @(posedge clk) begin
        if(rst)
            icache_stall_counter <= 64'd0;
        else if(icache_stall)
            icache_stall_counter <= icache_stall_counter + 64'd1;
    end

    logic [63:0] mem_stall_counter;
    always_ff @(posedge clk) begin
        if(rst)
            mem_stall_counter <= 64'd0;
        else if(mem_stall)
            mem_stall_counter <= mem_stall_counter + 64'd1;
    end

    logic [63:0] ex_stall_counter;
    always_ff @(posedge clk) begin
        if(rst)
            ex_stall_counter <= 64'd0;
        else if(ex_stall)
            ex_stall_counter <= ex_stall_counter + 64'd1;
    end

    logic [63:0] load_use_stall_counter;
    always_ff @(posedge clk) begin
        if(rst)
            load_use_stall_counter <= 64'd0;
        else if(load_use_stall)
            load_use_stall_counter <= load_use_stall_counter + 64'd1;
    end
    
endmodule