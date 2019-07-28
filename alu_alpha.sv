`timescale 1ns / 1ps
`include "alu_op.vh"
// In our design, hilo-related operations and  is handled ONLY by
// alpha pipeline.

// Changelog 2019-06-12: now priv_inst signal is asserted by decoder.
module alu_alpha(
        input                       clk,
        input                       rst,
        input                       flush_i,

        input [5:0]                 alu_op,
        input [31:0]                src_a,
        input [31:0]                src_b,
        input [63:0]                src_hilo,

        // For MFC0/MTC0
        input  [4:0]                rd,
        input  [2:0]                sel,
        output [7:0]                cop0_addr,      // rd || sel
        input  [31:0]               cop0_data,
        output logic                cop0_wen,
        output logic                exp_overflow,
        output logic                exp_eret,
        output logic                exp_syscal,
        output logic                exp_break,
        output logic                tlb_tlbwi,
        output logic                tlb_tlbwr,
        output logic                tlb_tlbr,
        output logic                tlb_tlbp,

        output logic                ex_reg_en,
        output logic                hilo_wen,
        output logic [63:0]         hilo_result,
        output logic [31:0]         result,
        output logic                stall_o        // Stall pipeline when a mdu operation is running and an instruction needs 
                                                    // result in hilo.
);

    wire [63:0] 			     hilo = src_hilo;
    wire [31:0] 			     hi = hilo[63:32];
    wire [31:0] 			     lo = hilo[31:0];
    wire [31:0] 			     add_result = src_a + src_b;
    wire [31:0] 			     sub_result = src_a - src_b;

    logic [5:0]                  clo_result, clz_result;

    // COP0
    assign cop0_addr = {rd, sel};
    assign exp_eret = alu_op == `ALU_ERET;
    assign exp_syscal = alu_op == `ALU_SYSC;
    assign exp_break = alu_op == `ALU_BREK;
    assign tlb_tlbp = alu_op == `ALU_TLBP;
    assign tlb_tlbwi = alu_op == `ALU_TLBWI;
    assign tlb_tlbwr = alu_op == `ALU_TLBWR;
    assign tlb_tlbr = alu_op == `ALU_TLBR;

    always_comb begin : write_c0
        if(alu_op == `ALU_MTC0)
            cop0_wen = 1'b1;
        else
            cop0_wen = 1'b0;
    end

    // For mult/div
    reg             mult_done_prev, div_done_prev;
    logic           mult_done, div_done;
    logic [63:0]    _hilo_mult, _hilo_div;
    // logic [63:0] hilo_mult, hilo_div;
    logic [1:0] 	mult_op, div_op;
    logic           mult_commit, div_commit;
    // Pipeline control.
    wire 	        mdu_running = ~(mult_done & div_done) || mdu_prepare;
    logic 	        mdu_prepare;

    assign stall_o      = flush_i? 0 : (mdu_running);
    assign mult_commit  = mult_done && (mult_done_prev != mult_done);
    assign div_commit   = div_done && (div_done_prev != div_done);

    always_ff @(posedge clk) begin : is_mdu_done
        if(rst) begin
            mult_done_prev <= 1'b0;
            div_done_prev <= 1'b0;
        end
        else begin
            mult_done_prev <= mult_done;
            div_done_prev <= div_done;
        end
    end

    // The mult/div unit.
    always_comb begin : mdu_control
        div_op = 2'd0;
        mult_op = 2'd0;
        mdu_prepare = 1'b0;
        if(!flush_i && (mult_done & div_done) && 
           (mult_done_prev == mult_done) && (div_done_prev == div_done)) begin
            mdu_prepare = 1'b1;
            unique case(alu_op)
            `ALU_DIV:
                div_op = 2'b10;
            `ALU_DIVU:
                div_op = 2'b01;
            `ALU_MULT, `ALU_MADD, `ALU_MSUB, `ALU_MUL:
                mult_op = 2'b10;
            `ALU_MULTU, `ALU_MADDU, `ALU_MSUBU:
                mult_op = 2'b01;
            default: begin
                mdu_prepare = 1'b0;
            end
            endcase
        end
        else begin
            mdu_prepare = 1'b0;
        end
    end

    divider div_alpha(
            .clk        (clk),
            .rst        (rst),
            .div_op     (div_op),
            .divisor    (src_b),
            .dividend   (src_a),
            .result     (_hilo_div),
            .done       (div_done)
        );

    multplier mult_alpha(
			.clk        (clk),
			.rst        (rst),
			.op         (mult_op),
			.a          (src_a),
			.b          (src_b),
			.c          (_hilo_mult),
			.done       (mult_done)
	    );

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
            `ALU_MFHI:
                result = hi;
            `ALU_MFLO:
                result = lo;
            `ALU_OUTA, `ALU_MOVN, `ALU_MOVZ:
                result = src_a;
            `ALU_OUTB:
                result = src_b;
            `ALU_MFC0:
                result = cop0_data;
            `ALU_MTC0:
                result = cop0_addr;
            `ALU_CLO:
                result = {26'd0,clo_result};
            `ALU_CLZ:
                result = {26'd0,clz_result};
            `ALU_MUL:
                result = _hilo_mult[31:0];
            default:
                result = 32'h0000_0000; // Prevent dcache error
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

    // HiLo read/write
    always_comb begin : hilo_read_write
        hilo_wen = 1'd1;
        hilo_result = 64'd0;
        if(div_commit)
            hilo_result = _hilo_div;
        else if(mult_commit) begin
            unique case(alu_op)
                `ALU_MSUB, `ALU_MSUBU:
                    hilo_result = src_hilo - _hilo_mult;
                `ALU_MADD, `ALU_MADDU:
                    hilo_result = _hilo_mult + src_hilo;
                default:
                    hilo_result = _hilo_mult;
            endcase 
        end
        else begin
            unique case(alu_op)
            `ALU_MTHI:
                hilo_result = { src_a, lo };
            `ALU_MTLO:
                hilo_result = { hi, src_a };
            default:
                hilo_wen = 1'd0;
            endcase
        end
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
