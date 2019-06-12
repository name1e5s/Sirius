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
        input                       mem_stall,

        // Exceptions
        input                       exp_en,
        input                       exp_badvaddr_en,
        input [31:0]                exp_badvaddr,
        input                       exp_bd,
        input [4:0]                 exp_code,
        input [31:0]                exp_epc,
        input                       exl_clean,

        output logic [31:0]         epc_address,
        output logic                allow_interrupt,
        output logic [7:0]          interrupt_flag
);
   
    // Control register definition
    reg [31:0] 		       BadVAddr;
    reg [32:0] 		       Count;
    reg [31:0] 		       Status;
    reg [31:0] 		       Cause;
    reg [31:0] 		       EPC;

    assign epc_address       = EPC;
    assign allow_interrupt   = Status[2:0] == 3'b001;
    assign interrupt_flag    = Status[15:8] & Cause[15:8];

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
        end
        else begin
            Cause[15:10] <= hint;
            Count <= Count + 33'd1;
            if(wen && !mem_stall) begin
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
                    default: begin
                        // Make vivado happy. :)
                    end
                endcase
            end
            if(exp_en && !mem_stall) begin
                if(exp_badvaddr_en)
                    BadVAddr <= exp_badvaddr;
                Status[1] <= ~exl_clean;
                Cause[31] <= exp_bd;
                Cause[6:2] <= exp_code;
                EPC <= exp_epc;
            end
        end
    end
endmodule