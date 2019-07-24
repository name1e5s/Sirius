`timescale 1ns / 1ps
`include "alu_op.vh"
// Slave ALU, thie ALU doesn't handle HILO operations and
// priv instructions.
module alu_beta(
        input                       clk,
        input                       rst,

        input [5:0]                 alu_op,
        input [31:0]                src_a,
        input [31:0]                src_b,

        output logic                ex_reg_en,
        output logic                exp_overflow,
        output logic [31:0]         result
);

    wire [31:0] 			     add_result = src_a + src_b;
    wire [31:0] 			     sub_result = src_a - src_b;
    logic [5:0]                  clo_result, clz_result;

    // Regular operation.
    always_comb begin : alu_operation
        unique case(alu_op)
            `ALU_ADD, `ALU_ADDU:
                result = add_result;
            `ALU_SUB, `ALU_SUBU:
                result = sub_result;
            `ALU_SLT:
                result = $signed(src_a) < $signed(src_b) ? 32'd1 : 32'd0;
            `ALU_SLTU:
                result = src_a < src_b? 32'd1 : 32'd0;
            `ALU_AND:
                result = src_a & src_b;
            `ALU_LUI:
                result = { src_b[15:0], 16'h0000 };
            `ALU_NOR:
                result = ~(src_a | src_b);
            `ALU_OR:
                result = src_a | src_b;
            `ALU_XOR:
                result = src_a ^ src_b;
            `ALU_SLL:
                result = src_b << src_a[4:0];
            `ALU_SRA:
                result = $signed(src_b) >>> src_a[4:0];
            `ALU_SRL:
                result = src_b >> src_a[4:0];
            `ALU_OUTA, `ALU_MOVN, `ALU_MOVZ:
                result = src_a;
            `ALU_OUTB:
                result = src_b;
            `ALU_CLO:
                result = {26'd0,clo_result};
            `ALU_CLZ:
                result = {26'd0,clz_result};
            default:
                result = 32'h0000_0000;
        endcase
    end

    always_comb begin : set_reg_en
        unique case(alu_op)
        `ALU_MOVN:
            ex_reg_en = (src_b != 32'd0);
        `ALU_MOVZ:
            ex_reg_en = (src_b == 32'd0);
        default:
            ex_reg_en = 1'd1;
        endcase
    end

    always_comb begin : set_overflow
        unique case (alu_op)
            `ALU_ADD:
                exp_overflow = ((src_a[31] ~^ src_b[31]) & (src_a[31] ^ add_result[31]));
            `ALU_SUB:
                exp_overflow = ((src_a[31]  ^ src_b[31]) & (src_a[31] ^ sub_result[31]));
            default:
                exp_overflow = 1'b0;
        endcase
    end

    always_comb begin
        casex (src_a)
            32'b0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd0;
            32'b10xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd1;
            32'b110xxxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd2;
            32'b1110xxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd3;
            32'b11110xxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd4;
            32'b111110xxxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd5;
            32'b1111110xxxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd6;
            32'b11111110xxxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd7;
            32'b111111110xxxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd8;
            32'b1111111110xxxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd9;
            32'b11111111110xxxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd10;
            32'b111111111110xxxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd11;
            32'b1111111111110xxxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd12;
            32'b11111111111110xxxxxxxxxxxxxxxxxx:
                clo_result <= 6'd13;
            32'b111111111111110xxxxxxxxxxxxxxxxx:
                clo_result <= 6'd14;
            32'b1111111111111110xxxxxxxxxxxxxxxx:
                clo_result <= 6'd15;
            32'b11111111111111110xxxxxxxxxxxxxxx:
                clo_result <= 6'd16;
            32'b111111111111111110xxxxxxxxxxxxxx:
                clo_result <= 6'd17;
            32'b1111111111111111110xxxxxxxxxxxxx:
                clo_result <= 6'd18;
            32'b11111111111111111110xxxxxxxxxxxx:
                clo_result <= 6'd19;
            32'b111111111111111111110xxxxxxxxxxx:
                clo_result <= 6'd20;
            32'b1111111111111111111110xxxxxxxxxx:
                clo_result <= 6'd21;
            32'b11111111111111111111110xxxxxxxxx:
                clo_result <= 6'd22;
            32'b111111111111111111111110xxxxxxxx:
                clo_result <= 6'd23;
            32'b1111111111111111111111110xxxxxxx:
                clo_result <= 6'd24;
            32'b11111111111111111111111110xxxxxx:
                clo_result <= 6'd25;
            32'b111111111111111111111111110xxxxx:
                clo_result <= 6'd26;
            32'b1111111111111111111111111110xxxx:
                clo_result <= 6'd27;
            32'b11111111111111111111111111110xxx:
                clo_result <= 6'd28;
            32'b111111111111111111111111111110xx:
                clo_result <= 6'd29;
            32'b1111111111111111111111111111110x:
                clo_result <= 6'd30;
            32'b11111111111111111111111111111110:
                clo_result <= 6'd31;
            32'b11111111111111111111111111111111:
                clo_result <= 6'd32;
            default:
                clo_result <= 6'd0;
        endcase
    end

    always_comb begin
        casex (src_a)
            32'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd0;
            32'b01xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd1;
            32'b001xxxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd2;
            32'b0001xxxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd3;
            32'b00001xxxxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd4;
            32'b000001xxxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd5;
            32'b0000001xxxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd6;
            32'b00000001xxxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd7;
            32'b000000001xxxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd8;
            32'b0000000001xxxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd9;
            32'b00000000001xxxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd10;
            32'b000000000001xxxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd11;
            32'b0000000000001xxxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd12;
            32'b00000000000001xxxxxxxxxxxxxxxxxx:
                clz_result <= 6'd13;
            32'b000000000000001xxxxxxxxxxxxxxxxx:
                clz_result <= 6'd14;
            32'b0000000000000001xxxxxxxxxxxxxxxx:
                clz_result <= 6'd15;
            32'b00000000000000001xxxxxxxxxxxxxxx:
                clz_result <= 6'd16;
            32'b000000000000000001xxxxxxxxxxxxxx:
                clz_result <= 6'd17;
            32'b0000000000000000001xxxxxxxxxxxxx:
                clz_result <= 6'd18;
            32'b00000000000000000001xxxxxxxxxxxx:
                clz_result <= 6'd19;
            32'b000000000000000000001xxxxxxxxxxx:
                clz_result <= 6'd20;
            32'b0000000000000000000001xxxxxxxxxx:
                clz_result <= 6'd21;
            32'b00000000000000000000001xxxxxxxxx:
                clz_result <= 6'd22;
            32'b000000000000000000000001xxxxxxxx:
                clz_result <= 6'd23;
            32'b0000000000000000000000001xxxxxxx:
                clz_result <= 6'd24;
            32'b00000000000000000000000001xxxxxx:
                clz_result <= 6'd25;
            32'b000000000000000000000000001xxxxx:
                clz_result <= 6'd26;
            32'b0000000000000000000000000001xxxx:
                clz_result <= 6'd27;
            32'b00000000000000000000000000001xxx:
                clz_result <= 6'd28;
            32'b000000000000000000000000000001xx:
                clz_result <= 6'd29;
            32'b0000000000000000000000000000001x:
                clz_result <= 6'd30;
            32'b00000000000000000000000000000001:
                clz_result <= 6'd31;
            32'b00000000000000000000000000000000:
                clz_result <= 6'd32;
            default:
                clz_result <= 6'd0;
        endcase
    end
endmodule
