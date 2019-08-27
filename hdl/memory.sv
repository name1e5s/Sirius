`timescale 1ns / 1ps
`include "common.vh"
module memory(
        input                       clk,
        input                       rst,

        input [31:0] 	            address,
        input [31:0]                ex_result,
        input [31:0] 	            rt_value,
        input [ 4:0]                rt_addr,
        input [ 1:0] 	            mem_type,
        input [ 2:0] 	            mem_size,
        input 		                mem_signed,

        // Exceptions...
        input [ 2:0]                inst_exp,
        input                       data_miss,
        input                       data_illegal,
        input                       data_tlb_invalid,
        input                       data_dirty,

        // Connect to sram.
        output logic 	            mem_en,
        output logic [3:0]          mem_wen,
        output logic [31:0]         mem_addr,
        output logic [31:0]         mem_wdata,
        input logic [31:0]          mem_rdata,
        output logic [2:0]          data_size,

        output logic [31:0]         result,
        // Report error
        output logic                address_error,
        output logic                tlb_modified,

        // Cache operation
        output logic                inst_hit_invalidate,
        output logic                data_hit_writeback,
        output logic                index_invalidate
);

    assign mem_en       = (|mem_type || data_hit_writeback) && (~address_error) && 
                      (~(|inst_exp)) && (~data_miss) && (~data_tlb_invalid) &&
                      ~((~data_dirty && |mem_wen));
    assign mem_addr     = address;
    assign tlb_modified = (data_dirty && |mem_wen);

    assign inst_hit_invalidate = (mem_type == `MEM_CACH) && (rt_addr == 5'b00000 || rt_addr == 5'b10000);
    assign data_hit_writeback = (mem_type == `MEM_CACH) && (rt_addr == 5'b00001 || rt_addr == 5'b10101);
    assign index_invalidate    = (mem_type == `MEM_CACH) && (rt_addr == 5'b00000 || rt_addr == 5'b00001);

    always_comb begin : detect_write_size
        if(mem_size == `SZ_BYTE)
            data_size = 3'd0;
        else if(mem_size == `SZ_HALF)
            data_size = 3'd1;
        else
            data_size = 3'd2;
    end

    always_comb begin : detect_alignment_error
        if(mem_type != `MEM_NOOP) begin
            unique case(mem_size)
            `SZ_HALF:
                address_error = address[0];
            `SZ_FULL:
                address_error = |address[1:0];
            default:
                address_error = 1'b0;
            endcase
        end
        else
            address_error = 1'b0;
    end

    // Read or write
    always_comb begin : memory_control
        result = ex_result;
        mem_wen = 4'b0;
        mem_wdata = rt_value;
        if(address_error) begin
        // We do noting when align error
        end
        else begin
            if(mem_type == `MEM_STOR) begin
                unique case(mem_size)
                `SZ_FULL:
                    mem_wen = 4'b1111;
                `SZ_HALF: begin
                    mem_wdata = {2{rt_value[15:0]}};
                    mem_wen = {address[1],address[1],~address[1],~address[1]};
                end
                `SZ_BYTE: begin
                    mem_wdata = {4{rt_value[7:0]}};
                    unique case(address[1:0])
                    2'd0:
                        mem_wen = 4'b0001;
                    2'd1:
                        mem_wen = 4'b0010;
                    2'd2:
                        mem_wen = 4'b0100;
                    2'd3:
                        mem_wen = 4'b1000;
                    default:
                        mem_wen = 4'b0000;
                    endcase
                end
                `SZ_LEFT: begin
                    unique case(address[1:0])
                    2'd0: begin
                        mem_wen = 4'b0001;
                        mem_wdata = {4{rt_value[31:24]}};
                    end
                    2'd1: begin
                        mem_wen = 4'b0011;
                        mem_wdata = {2{rt_value[31:16]}};
                    end
                    2'd2: begin
                        mem_wen = 4'b0111;
                        mem_wdata = {8'd0,{rt_value[31:8]}};
                    end
                    2'd3: begin
                        mem_wen = 4'b1111;
                        mem_wdata = rt_value;
                    end
                    default:
                        mem_wen = 4'b0000;
                    endcase
                end
                `SZ_RIGH: begin
                    unique case(address[1:0])
                    2'd0: begin
                        mem_wen = 4'b1111;
                        mem_wdata = rt_value;
                    end
                    2'd1: begin
                        mem_wen = 4'b1110;
                        mem_wdata = {rt_value[23:0],8'd0};
                    end
                    2'd2: begin
                        mem_wen = 4'b1100;
                        mem_wdata = {2{rt_value[15:0]}};
                    end
                    2'd3: begin
                        mem_wen = 4'b1000;
                        mem_wdata = {4{rt_value[7:0]}};
                    end
                    default:
                        mem_wen = 4'b0000;
                    endcase
                end
                default:
                    mem_wen = 4'b1111;
                endcase
            end
            else if(mem_type == `MEM_LOAD) begin
                mem_wen = 4'b0;
                unique case(mem_size)
                `SZ_HALF: begin
                    if(address[1])
                    result = mem_signed? { 16'b0 ,mem_rdata[31:16]} :
                                {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                    else
                    result = mem_signed? { 16'b0 ,mem_rdata[15:0]} :
                                {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                end
                `SZ_BYTE: begin
                    unique case(address[1:0])
                    2'b01:
                        result = mem_signed? { 24'b0, mem_rdata[15:8]} :
                                {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                    2'b10:
                        result = mem_signed? { 24'b0, mem_rdata[23:16]} :
                                {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                    2'b11:
                        result = mem_signed? { 24'b0, mem_rdata[31:24]} :
                                {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                    default:
                        result = mem_signed? { 24'b0, mem_rdata[7:0]} :
                                {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                    endcase
                end
                `SZ_LEFT: begin
                    unique case(address[1:0])
                    2'b00:
                        result = {mem_rdata[7:0],rt_value[23:0]};
                    2'b01:
                        result = {mem_rdata[16:0],rt_value[16:0]};
                    2'b10:
                        result = {mem_rdata[23:0],rt_value[7:0]};
                    default:
                        result = mem_rdata;
                    endcase
                end
                `SZ_RIGH: begin
                    unique case(address[1:0])
                    2'b00:
                        result = mem_rdata;
                    2'b01:
                        result = {rt_value[31:24],mem_rdata[31:8]};
                    2'b10:
                        result = {rt_value[31:16],mem_rdata[31:16]};
                    default:
                        result = {rt_value[31:8],mem_rdata[31:24]};
                    endcase
                end
                default:
                    result = mem_rdata;
                endcase
            end
        end
    end
    
endmodule