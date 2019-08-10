`timescale 1ns/1ps

module pc(
        input                   clk,
        input                   rst,
        input                   pc_en,
        input                   inst_ok_1,
        input                   inst_ok_2,
        input                   fifo_full,

        input                   branch_en,

        input                   branch_taken,
        input [31:0]            branch_address,
        input                   exception_taken,
        input [31:0]            exception_address,

        output logic [31:0]     pc_address_next_bran,
        input  [31:0]           pc_address_psy_next_bran,
        input                   pc_tlb_miss_bran,
        input                   pc_tlb_illegal_bran,
        input                   pc_tlb_invalid_bran,
        input                   pc_tlb_uncached_bran,

        output logic [31:0]     pc_address_next_seq0,
        input  [31:0]           pc_address_psy_next_seq0,
        input                   pc_tlb_miss_seq0,
        input                   pc_tlb_illegal_seq0,
        input                   pc_tlb_invalid_seq0,
        input                   pc_tlb_uncached_seq0,

        output logic [31:0]     pc_address_next_seq1,
        input  [31:0]           pc_address_psy_next_seq1,
        input                   pc_tlb_miss_seq1,
        input                   pc_tlb_illegal_seq1,
        input                   pc_tlb_invalid_seq1,
        input                   pc_tlb_uncached_seq1,

        output logic [31:0]     pc_address,
        output logic [31:0]     pc_address_psy,
        output logic            tlb_miss,
        output logic            tlb_illegal,
        output logic            tlb_invalid,
        output logic            tlb_uncached
);

    reg     [31:0] real_pc_address;
    logic   [31:0] pc_address_next;
    logic          pc_tlb_miss_next;
    logic          pc_tlb_illegal_next;
    logic          pc_tlb_invalid_next;
    logic          pc_tlb_uncached_next;
    logic   [31:0] pc_address_psy_next;
    
    assign pc_address           = real_pc_address;
    assign pc_address_next_bran = branch_address;
    assign pc_address_next_seq0 = pc_address + 32'd4;
    assign pc_address_next_seq1 = pc_address + 32'd8;
    
    always_ff @(posedge clk) begin
        pc_address_psy  <= pc_address_psy_next;
        tlb_miss        <= pc_tlb_miss_next;
        tlb_illegal     <= pc_tlb_illegal_next;
        tlb_invalid     <= pc_tlb_invalid_next;
        tlb_uncached    <= pc_tlb_uncached_next;
    end

    always_comb begin : compute_next_pc_address
        if(rst) begin
            pc_address_next     = 32'hbfc0_0000; // Initial value
            pc_address_psy_next = 32'h1fc0_0000;
            pc_tlb_miss_next    = 1'd0;
            pc_tlb_illegal_next = 1'd0;
            pc_tlb_invalid_next = 1'd0;
            pc_tlb_uncached_next= 1'd1;
        end
        else if(pc_en) begin
            if(exception_taken) begin
                pc_address_next     = exception_address;
                pc_address_psy_next = { 3'd0, exception_address[28:0] };
                pc_tlb_miss_next    = 1'd0;
                pc_tlb_illegal_next = 1'd0;
                pc_tlb_invalid_next = 1'd0;
                pc_tlb_uncached_next= exception_address[29];
            end
            else if(branch_en && branch_taken) begin
                pc_address_next     = branch_address;
                pc_address_psy_next = pc_address_psy_next_bran;
                pc_tlb_miss_next    = pc_tlb_miss_bran;
                pc_tlb_illegal_next = pc_tlb_illegal_bran;
                pc_tlb_invalid_next = pc_tlb_invalid_bran;
                pc_tlb_uncached_next= pc_tlb_uncached_bran;
            end
            else if(fifo_full) begin
                pc_address_next     = pc_address;
                pc_address_psy_next = pc_address_psy;
                pc_tlb_miss_next    = tlb_miss;
                pc_tlb_illegal_next = tlb_illegal;
                pc_tlb_invalid_next = tlb_invalid;
                pc_tlb_uncached_next= tlb_uncached;
            end
            else if(inst_ok_1 && inst_ok_2) begin
                pc_address_next     = pc_address + 32'd8;
                pc_address_psy_next = pc_address_psy_next_seq1;
                pc_tlb_miss_next    = pc_tlb_miss_seq1;
                pc_tlb_illegal_next = pc_tlb_illegal_seq1;
                pc_tlb_invalid_next = pc_tlb_invalid_seq1;
                pc_tlb_uncached_next= pc_tlb_uncached_seq1;
            end
            else if(inst_ok_1) begin
                pc_address_next = pc_address + 32'd4;
                pc_address_psy_next = pc_address_psy_next_seq0;
                pc_tlb_miss_next    = pc_tlb_miss_seq0;
                pc_tlb_illegal_next = pc_tlb_illegal_seq0;
                pc_tlb_invalid_next = pc_tlb_invalid_seq0;
                pc_tlb_uncached_next= pc_tlb_uncached_seq0;
            end
            else begin
                pc_address_next     = pc_address;
                pc_address_psy_next = pc_address_psy;
                pc_tlb_miss_next    = tlb_miss;
                pc_tlb_illegal_next = tlb_illegal;
                pc_tlb_invalid_next = tlb_invalid;
                pc_tlb_uncached_next= tlb_uncached;
            end
        end
        else begin
            pc_address_next     = pc_address; 
            pc_address_psy_next = pc_address_psy;
            pc_tlb_miss_next    = tlb_miss;
            pc_tlb_illegal_next = tlb_illegal;
            pc_tlb_invalid_next = tlb_invalid;
            pc_tlb_uncached_next= tlb_uncached;
        end
    end

    always_ff @(posedge clk) begin
        real_pc_address <= pc_address_next;
    end
    
endmodule