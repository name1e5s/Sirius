`timescale 1ns / 1ps
`include "common.vh"

module decoder_alpha(
        input [31:0]                instruction,

        output logic [5:0]          opcode,
        output logic [4:0]          rs,
        output logic [4:0]          rt,
        output logic [4:0]          rd,
        output logic [4:0]          shamt,
        output logic [5:0]          funct,
        output logic [15:0]         immediate,
        output logic [25:0]         instr_index,

        output logic [2:0]          branch_type,
        output logic                is_branch_instr,
        output logic                is_branch_link,
        output logic                is_hilo_accessed
);

    assign opcode = instruction[31:26];
    assign rs = instruction[25:21];
    assign rt = instruction[20:16];
    assign rd = instruction[15:11];
    assign shamt = instruction[10:6];
    assign funct = instruction[5:0];
    assign immediate = instruction[15:0];
    assign instr_index = instruction[25:0];

    // Check if the instruction is a branch/jump function
    always_comb begin
        //BEQ, BNE, BLEZ and BGTZ live here
        if(opcode[5:2] == 4'b0001) begin
            is_branch_instr = 1'b1;
            branch_type = `B_EQNE;
            is_branch_link = 1'b0;
        // BLTZ, BGEZ, BLTZL, BGEZL lives here, but we
        // don't care those branch-likely instructions
        end
        else if(opcode == 6'b000001 && rt[3:1] == 3'b000) begin
            is_branch_instr = 1'b1;
            branch_type = `B_LTGE;
            is_branch_link = rt[4];
        // J, JAL is here
        end
        else if(opcode[5:1] == 5'b00001) begin
            is_branch_instr = 1'b1;
            branch_type = `B_JUMP;
            is_branch_link = opcode[0];
        //  JR, JALR is here
        end
        else if(opcode == 6'b000000 && funct[5:1] == 5'b00100) begin
            is_branch_instr = 1'b1;
            branch_type = `B_JREG;
            is_branch_link = funct[0];
        end
        else begin
            is_branch_instr = 1'b0;
            branch_type = `B_INVA;
            is_branch_link = 1'b0;
        end
    end

    // Check if the instruction needs HILO register(s)
    // Note: the multplier and divier requires more than one cycle to
    // complete the operation and they write their results to inner
    // ``hilo'' register(s). Hence we can perform those operations
    // without stalling the whole pipeline when the result in the hilo
    // is not needed.
    always_comb begin
        if(instruction[31:26] == 6'b000000 &&
            (instruction[5:2] == 4'b0100 || instruction[5:2] == 4'b0110))
            is_hilo_accessed = 1'b1;
        else if(instruction[31:26] == 6'b011100 && (instruction[5:3] == 3'b000))
            case(instruction[2:0])
                3'b000, 3'b001, 3'b010, 3'b100, 3'b101:
                    is_hilo_accessed = 1'b1;
                default:
                    is_hilo_accessed = 1'b0;
            endcase
        else
            is_hilo_accessed = 1'b0;
    end
endmodule