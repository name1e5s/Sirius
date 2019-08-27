`timescale 1ns / 1ps
module exception_alpha(
        input                       clk,
        input                       rst,

        input                       iaddr_alignment_error,
        input                       iaddr_tlb_miss,
        input                       iaddr_tlb_invalid,
        input                       daddr_alignment_error,
        input                       daddr_tlb_miss,
        input                       daddr_tlb_invalid,
        input                       daddr_tlb_dirty,
        input                       invalid_instruction,
        input                       priv_instruction,
        input                       syscall,
        input                       break_,
        input                       eret,
        input                       overflow,
        input                       mem_wen,
        input                       is_branch_instruction,
        input                       is_branch_slot,
        input [31:0]                pc_address,
        input [31:0]                mem_address,
        input [31:0]                epc_address,
        input                       allow_interrupt,
        input [ 7:0]                interrupt_flag,
        input                       is_inst,
        input                       slave_exp_undefined_inst,
        input                       slave_exp_overflow,


        // MIPS32r1
        input [31:0]                cp0_ebase,
        input                       cp0_use_special_iv,
        input                       cp0_use_bootstrap_iv,
        input                       exl_set_if,
        input                       exl_set_mem,
        input [7:0]                 asid_if,
        input [7:0]                 asid_mem,

        output logic                exp_detect,
        output logic                exp_detect_salve,
        output logic                cp0_exp_en,
        output logic                cp0_exl_clean,
        output logic [31:0]         cp0_exp_epc,
        output logic [4:0]          cp0_exp_code,
        output logic [31:0]         cp0_exp_bad_vaddr,
        output logic                cp0_exp_bad_vaddr_wen,
        output logic [31:0]         exp_pc_address,
        output logic                cp0_exp_bd,
        output logic [7:0]          cp0_exp_asid,
        output logic                cp0_exp_asid_en
);
    
    wire [31:0] ebase = cp0_use_bootstrap_iv? 32'hbfc0_0200 : {2'b10, cp0_ebase[29:12], 12'd0};
    always_comb begin : check_exceotion
        exp_pc_address = ebase + 32'h180;
        cp0_exp_en = 1'd1;
        cp0_exl_clean = 1'b0;
        cp0_exp_bad_vaddr_wen = 1'b0;
        cp0_exp_bad_vaddr = 32'd0;
        exp_detect = 1'b1;
        exp_detect_salve = 1'd0;
        cp0_exp_bd = is_branch_slot;
        cp0_exp_epc = is_branch_slot ? pc_address - 32'd4: pc_address;
        cp0_exp_asid = 8'd0;
        cp0_exp_asid_en = 1'd0;
        if(is_inst && allow_interrupt && interrupt_flag != 8'd0) begin
            if(cp0_use_special_iv)
                exp_pc_address = ebase + 32'h200;
            cp0_exp_code = 5'h00;
            $display("[EXP] Interrupt at 0x%x",pc_address);
        end
        else if(iaddr_alignment_error) begin
            cp0_exp_code = 5'h04;
            cp0_exp_bad_vaddr = pc_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
            $display("[EXP] Illegal iaddr at 0x%x",pc_address);
        end
        else if(iaddr_tlb_miss) begin
            if(~exl_set_if)
                exp_pc_address = ebase + 32'h0;
            cp0_exp_asid = asid_if;
            cp0_exp_asid_en = 1'd1;
            cp0_exp_bad_vaddr = pc_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
            cp0_exp_code = 5'h02;
            $display("[EXP] ITLB Miss at 0x%x",pc_address);
        end
        else if(iaddr_tlb_invalid) begin
            cp0_exp_asid = asid_if;
            cp0_exp_asid_en = 1'd1;
            cp0_exp_bad_vaddr = pc_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
            cp0_exp_code = 5'h02;
            $display("[EXP] ITLB Invalid at 0x%x",pc_address);
        end
        else if(syscall) begin
            cp0_exp_code = 5'h08;
            $display("[EXP] System call at 0x%x",pc_address);
        end 
        else if(break_) begin
            cp0_exp_code = 5'h09;
            $display("[EXP] Break point at 0x%x",pc_address);
        end
        else if(invalid_instruction) begin
            cp0_exp_code = 5'h0a;
            $display("[EXP] RI at 0x%x",pc_address);
        end
        else if(priv_instruction) begin
            cp0_exp_code = 5'h0b;
            $display("[EXP] CpU at 0x%x",pc_address);
        end
        else if(overflow) begin
            cp0_exp_code = 5'h0c;
            $display("[EXP] Overflow at 0x%x",pc_address);
        end
        else if(eret) begin
            cp0_exp_code = 5'h00;
            cp0_exp_en = 1'b0;
            cp0_exl_clean = 1'b1;
            exp_pc_address = epc_address;
        end
        else if(daddr_alignment_error) begin
            cp0_exp_code = mem_wen ? 5'h05:5'h04;
            cp0_exp_bad_vaddr = mem_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
        end
        else if(daddr_tlb_miss) begin
            if(~exl_set_mem)
                exp_pc_address = ebase + 32'h0;
            cp0_exp_asid = asid_mem;
            cp0_exp_asid_en = 1'd1;
            cp0_exp_bad_vaddr = mem_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
            cp0_exp_code = mem_wen? 5'h03 : 5'h02;
            $display("[EXP] DTLB Miss at 0x%x",pc_address);
        end
        else if(daddr_tlb_invalid) begin
            cp0_exp_asid = asid_mem;
            cp0_exp_asid_en = 1'd1;
            cp0_exp_bad_vaddr = mem_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
            cp0_exp_code = mem_wen? 5'h03 : 5'h02;
            $display("[EXP] DTLB Invalid at 0x%x",pc_address);
        end
        else if(mem_wen && !daddr_tlb_dirty) begin
            cp0_exp_asid = asid_if;
            cp0_exp_asid_en = 1'd1;
            cp0_exp_bad_vaddr = mem_address;
            cp0_exp_bad_vaddr_wen = 1'b1;
            cp0_exp_code = 5'h01;
            $display("[EXP] DTLB Invalid at 0x%x",pc_address);
        end
        else if(slave_exp_undefined_inst) begin
            cp0_exp_bd = is_branch_instruction;
            cp0_exp_epc = is_branch_instruction? pc_address : pc_address + 32'd4;
            cp0_exp_code = 5'h0a;
            exp_detect_salve = 1'd1;
        end
        else if(slave_exp_overflow) begin
            cp0_exp_bd = is_branch_instruction;
            cp0_exp_epc = is_branch_instruction? pc_address : pc_address + 32'd4;
            cp0_exp_code = 5'h0c;
            exp_detect_salve = 1'd1;
        end
        else begin
            cp0_exp_en = 1'b0;
            exp_detect = 1'b0;
            cp0_exp_code = 5'd0;
        end
    end

endmodule
