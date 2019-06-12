`timescale 1ns / 1ps
module exception_alpha(
        input                       clk,
        input                       rst,
        
        input                       ex_mem_stall,
        input                       master_branch_inst;

        input                       daddr_alignment_error,
        input                       invalid_instruction,
        input                       overflow,
        input                       mem_wen,
        input [31:0]                pc_address,
        input [31:0]                mem_address,
        input [31:0]                epc_address,
        input                       is_inst,

        output logic                exp_detect,
        output logic                cp0_exp_en,
        output logic                cp0_exl_clean,
        output logic [31:0]         cp0_exp_epc,
        output logic [4:0]          cp0_exp_code,
        output logic [31:0]         cp0_exp_bad_vaddr,
        output logic                cp0_exp_bad_vaddr_wen,
        output logic [31:0]         exp_pc_address,
        output logic                cp0_exp_bd
);

    assign cp0_exp_bd = master_branch_inst;
    
    always_comb begin : check_exceotion
        exp_pc_address = 32'hbfc00380;
        cp0_exp_en = 1'd1;
        cp0_exl_clean = 1'b0;
        cp0_exp_bad_vaddr_wen = 1'b0;
        exp_detect = 1'b1;
        cp0_exp_epc = is_branch_slot ? pc_address - 32'd4: pc_address;
        
        if(invalid_instruction)
            cp0_exp_code = 5'h0a;
        else if(overflow)
            cp0_exp_code = 5'h0c;
        else if(daddr_alignment_error) begin
            cp0_exp_code = mem_wen ? 5'h05:5'h04;
            cp0_exp_bad_vaddr = mem_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
        end
        else begin
            cp0_exp_en = 1'b0;
            exp_detect = 1'b0;
            cp0_exp_code = 5'd0;
        end
    end

endmodule
