`timescale 1ns / 1ps
// The COP0
module cp0(
        input                       clk,
        input                       rst,

        input [5:0]                 hint,
        input [7:0]                 raddr,
        output logic [31:0]         rdata,

        input                       wen,
        input [7:0]                 waddr,
        input [31:0]                wdata,

        // Exceptions
        input                       exp_en,
        input                       exp_badvaddr_en,
        input [31:0]                exp_badvaddr,
        input                       exp_bd,
        input [4:0]                 exp_code,
        input [31:0]                exp_epc,
        input                       exl_clean,

        // TLB...
        input                       miss_probe,
        input [3:0]                 matched_index_probe,
        output logic                user_mode,
        output logic                cp0_kseg0_uncached,
        output logic [7:0]          curr_ASID,
        output logic [3:0]          cp0_index,
        output logic [3:0]          cp0_random,
        output logic [85:0]         cp0_tlb_conf_out,
        input [85:0]                cp0_tlb_conf_in         

        output logic [31:0]         epc_address,
        output logic                allow_interrupt,
        output logic [7:0]          interrupt_flag
);
   
    // Control register definition
    reg [31:0] 		        BadVAddr;
    reg [32:0] 		        Count;
    reg [31:0] 		        Status;
    reg [31:0] 		        Cause;
    reg [31:0] 		        EPC;
    reg [31:0]              EntryHi;
    reg [31:0]              EntryLo0;
    reg [31:0]              EntryLo1;
    reg [31:0]              Index;

    assign epc_address       = EPC;
    assign allow_interrupt   = Status[2:0] == 3'b001;
    assign interrupt_flag    = Status[15:8] & Cause[15:8];
    assign curr_ASID         = EntryHi[7:0];
    assign cp0_index         = Index[3:0];
    assign cp0_random        = 4'd4; // Chosen by fair dice roll
                                     // guaranteed to be random
    assign user_mode = Status[4:1]==4'b1000;
    assign cp0_tlb_conf_out = { EntryHi[31:13], EntryLo0[0] && EntryLo0[1], EntryHi[7:0], EntryLo0[29:1], EntryLo1[29:1]};

    always_comb begin : cop0_data_read
        unique case(raddr)
            { 5'd8, 3'd0 }:
                rdata = BadVAddr;
            { 5'd9, 3'd0 }:
                rdata = Count[32:1];
            { 5'd12, 3'd0 }:
                rdata = Status;
            { 5'd13, 3'd0 }:
                rdata = Cause;
            { 5'd14, 3'd0 }:
                rdata = EPC;
            // SiriusG begin
            { 5'd10, 3'd0 }:
                rdata = EntryHi;
            { 5'd2, 3'd0 }:
                rdata = EntryLo0;
            { 5'd3, 3'd0 }:
                rdata = EntryLo1;
            { 5'd0, 5'd0 }:
                rdata = Index;
            // SiriusG end
            default:
                rdata = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin : cop0_data_update
        if(rst) begin
            Count <= 32'd0;
            Status[31:23] <= 9'd0;
            Status[22] <= 1'b1;
            Status[21:16] <= 6'd0;
            Status[7:2] <= 6'd0;
            Status[1:0] <= 2'b0;
            Cause <= 32'd0;
            EntryHi <= 32'd0;
            EntryLo0[31:30] <= 2'd0;
            EntryLo1[31:30] <= 2'd0;
            Index <= 32'd0;
        end
        else begin
            Cause[15:10] <= hint;
            Count <= Count + 33'd1;
            if(wen) begin
                unique case(waddr)
                    { 5'd9, 3'd0 }:
                        Count <= {wdata, 1'b0};
                    { 5'd12, 3'd0}: begin
                        Status[15:8] <= wdata[15:8];
                        Status[1:0] <= wdata[1:0];
                    end
                    { 5'd13 , 3'd0 }:
                        Cause[9:8] <= wdata[9:8];
                    { 5'd14 , 3'd0 }:
                        EPC <= wdata;
                    { 5'd10, 3'd0}: begin
                        EntryHi[31:13]  <= wdata[31:13];
                        EntryHi[7:0]    <= wdata[7:0];
                    end
                    { 5'd2 , 3'd0 }:
                        EntryLo0[29:0] <= wdata[29:0];
                    { 5'd3 , 3'd0 }:
                        EntryLo1[29:0] <= wdata[29:0];
                    { 5'd0, 5'd0 }:
                        Index[3:0] <= wdata[3:0]; // Only 16 entries here...
                    default: begin
                        // Make vivado happy. :)
                    end
                endcase
            end
            if(exp_en) begin
                if(exp_badvaddr_en)
                    BadVAddr <= exp_badvaddr;
                Status[1] <= ~exl_clean;
                Cause[31] <= exp_bd;
                Cause[6:2] <= exp_code;
                EPC <= exp_epc;
                Index[31] <= exp_probe_failure;
            end
        end
    end
endmodule