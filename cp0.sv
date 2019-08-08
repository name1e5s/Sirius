`timescale 1ns / 1ps
// The COP0
module cp0(
        input                       clk,
        input                       rst,

        input [4:0]                 hint,
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
        input                       exp_asid_en,
        input [7:0]                 exp_asid,


        // TLB instructions
        input                       tlbr,
        input                       tlbp,

        // TLB...
        input                       miss_probe,
        input [3:0]                 matched_index_probe,
        output logic                user_mode,
        output logic                cp0_kseg0_uncached,
        output logic [7:0]          curr_ASID,
        output logic [3:0]          cp0_index,
        output logic [3:0]          cp0_random,
        output logic [85:0]         cp0_tlb_conf_out,
        input [85:0]                cp0_tlb_conf_in,

        // MIPS32r1
        output logic [31:0]         ebase_address, 
        output logic                use_special_iv,
        output logic                use_bootstrap_iv,
        output logic                exl_set,

        output logic [31:0]         epc_address,
        output logic                allow_interrupt,
        output logic [7:0]          interrupt_flag
);
   
    // Control register definition\
    reg [31:0]              Index;          // 0 0
    reg [31:0]              Random;         // 1 0 -- NEW
    reg [31:0]              EntryLo0;       // 2 0
    reg [31:0]              EntryLo1;       // 3 0
    reg [31:0]              Context;        // 4 0 -- NEW
    reg [31:0]              Wired;          // 6 0 -- NEW
    reg [31:0] 		        BadVAddr;       // 8 0
    reg [32:0] 		        Count;          // 9 0
    reg [31:0]              EntryHi;        // 10 0
    reg [31:0]              Compare;        // 11 0
    reg [31:0] 		        Status;         // 12 0
    reg [31:0] 		        Cause;          // 13 0
    reg [31:0] 		        EPC;            // 14 0
    reg [31:0]              PRId;           // 15 0 -- NEW
    reg [31:0]              EBase;          // 15 1 -- NEW
    reg [31:0]              Config;         // 16 0 -- NEW
    reg [31:0]              Config1;        // 16 1 -- NEW

    assign epc_address       = EPC;
    assign allow_interrupt   = Status[2:0] == 3'b001;
    assign interrupt_flag    = Status[15:8] & Cause[15:8];
    assign curr_ASID         = EntryHi[7:0];
    assign cp0_index         = Index[3:0];
    assign cp0_random        = {28'd0, Random[3:0]};
    assign user_mode = Status[4:1]==4'b1000;
    assign cp0_kseg0_uncached = Config[2:0] == 3'd2;
    assign cp0_tlb_conf_out = { EntryHi[31:13], EntryLo0[0] && EntryLo1[0], EntryHi[7:0], EntryLo0[29:1], EntryLo1[29:1]};
    assign ebase_address = EBase;
    assign use_special_iv = Cause[23];
    assign use_bootstrap_iv = Status[22];
    assign exl_set = Status[1];

    logic timer_int;

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
            { 5'd1, 3'd0 }:
                rdata = {28'd0, Random[3:0]};
            { 5'd2, 3'd0 }:
                rdata = EntryLo0;
            { 5'd3, 3'd0 }:
                rdata = EntryLo1;
            { 5'd0, 3'd0 }:
                rdata = Index;
            { 5'd4, 3'd0 }:
                rdata = Context;
            { 5'd11, 3'd0 }:
                rdata = Compare;
            { 5'd15, 3'd0 }:
                rdata = PRId;
            { 5'd16, 3'd0 }:
                rdata = Config;
            { 5'd16, 3'd1 }:
                rdata = Config1;
            { 5'd6, 3'd0 }:
                rdata = Wired;
            { 5'd15, 3'd1 }:
                rdata = EBase;
            // SiriusG end
            default:
                rdata = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin : cop0_data_update
        if(rst) begin
            Count           <= 32'd0;
            Status          <= 32'h1040_0004;
            Cause           <= 32'd0;
            EntryHi         <= 32'd0;
            EntryLo0[31:30] <= 2'd0;
            EntryLo1[31:30] <= 2'd0;
            EBase           <= 32'h8000_0000;
            Index           <= 32'd0;
            Context         <= 32'd0;
            Compare         <= 32'd0;
            Context         <= 32'd0;
            PRId            <= 32'h0001_8000; // MIPS 4KC
            Config          <= {1'b1, 21'b0, 3'b1, 7'b0}; // MIPS32R1
            Config1         <= {1'd0, 6'd15, 3'd1, 3'd5, 3'd0, 3'd1, 3'd5, 3'd0, 7'd0};
            timer_int       <= 1'd0;
            Wired           <= 32'd0;
            Random          <= 32'd0;
        end
        else begin
            Cause[15:10] <= {timer_int,hint};
            Count <= Count + 33'd1;
            Random <= Wired + Count[31:0];
            if(Compare != 32'd0 && Compare == Count[32:1])
                timer_int <= 1'd1;
            if(wen) begin
                unique case(waddr)
                    { 5'd9, 3'd0 }:
                        Count           <= {wdata, 1'b0};
                    { 5'd12, 3'd0}: begin
                        Status[28]      <= wdata[28];
                        Status[22]      <= wdata[22];
                        Status[15:8]    <= wdata[15:8];
                        Status[4]       <= wdata[4];
                        Status[2:0]     <= wdata[2:0];
                    end
                    { 5'd13 , 3'd0 }: begin
                        Cause[9:8]      <= wdata[9:8];
                        Cause[23]       <= wdata[23];
                    end
                    { 5'd14 , 3'd0 }:
                        EPC <= wdata;
                    { 5'd10, 3'd0}: begin
                        EntryHi[31:13]  <= wdata[31:13];
                        EntryHi[7:0]    <= wdata[7:0];
                    end
                    { 5'd2 , 3'd0 }:
                        EntryLo0[29:0]  <= wdata[29:0];
                    { 5'd3 , 3'd0 }:
                        EntryLo1[29:0]  <= wdata[29:0];
                    { 5'd0, 5'd0 }:
                        Index[3:0]      <= wdata[3:0]; // Only 16 entries here...
                    { 5'd4, 3'd0 }:
                        Context[31:13]  <= wdata[31:13];
                    { 5'd11, 3'd0 }: begin
                        Compare         <= wdata;
                        timer_int       <= 1'd0;
                    end
                    { 5'd16, 3'd1 }: begin
                        Config[2:0]     <= wdata[2:0];
                    end
                    { 5'd6, 3'd0 }: begin
                        Wired[3:0]      <= wdata[3:0];
                    end
                    { 5'd15, 3'd1 }: begin
                        EBase[29:12]    <= wdata[29:12];
                        EBase[9:0]      <= wdata[9:0];
                    end
                    default: begin
                        // Make vivado happy. :)
                    end
                endcase
            end
            if(exp_en) begin
                if(exp_badvaddr_en)
                    BadVAddr            <= exp_badvaddr;
                if(exp_asid_en)
                    EntryHi[7:0]        <= exp_asid;
                Context[22:4]           <= exp_badvaddr[31:13];
                EntryHi[31:13]          <= exp_badvaddr[31:13];
                Status[1]               <= ~exl_clean;
                Cause[31]               <= exp_bd;
                Cause[6:2]              <= exp_code;
                EPC                     <= exp_epc;
            end
            if(tlbr) begin
                EntryHi[31:13] <= cp0_tlb_conf_in[85:67];
                EntryHi[7:0]   <= cp0_tlb_conf_in[65:58];
                EntryLo0       <= {2'd0,cp0_tlb_conf_in[57:29],cp0_tlb_conf_in[66]};
                EntryLo1       <= {2'd0,cp0_tlb_conf_in[28:0],cp0_tlb_conf_in[66]};
            end
            if(tlbp) begin
                Index[3:0]     <= matched_index_probe;
                Index[31]      <= miss_probe;
            end
        end
    end
endmodule