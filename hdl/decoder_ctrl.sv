`timescale 1ns / 1ps
`include "common.vh"
`include "alu_op.vh"

// Alpha and Beta shares the same ctrl signal.
module decoder_ctrl(
        input [31:0]				instruction,
        input [5:0]					opcode,
        input [4:0]					rt,
        input [4:0]					rd,
        input [5:0]					funct,
        input						is_branch,
        input						is_branch_al,

        output logic				undefined_inst, // 1 as received a unknown operation.
        output logic [5:0]	 		alu_op, // ALU operation
        output logic [1:0] 			alu_src, // ALU oprand 2 source(0 as rt, 1 as immed)
        output logic       			alu_imm_src, // ALU immediate src - 1 as unsigned, 0 as signed.
        output logic [1:0] 			mem_type, // Memory operation type -- load or store
        output logic [2:0] 			mem_size, // Memory operation size -- B,H,W,WL,WR
        output logic [4:0] 			wb_reg_dest, // Writeback register address
        output logic       			wb_reg_en, // Writeback is enabled
        output logic       			unsigned_flag,   // Is this a unsigned operation in MEM stage.
        output logic                priv_inst   // Is this instruction a priv inst?
);

    // Control logic.
    always_comb begin : decoder
        // To prevent latch...
        undefined_inst  = 1'b0;
        priv_inst       = 1'b0;
        alu_op          = `ALU_ADDU;
        alu_src         = 2'd0;
        alu_imm_src     = 1'd1;
        mem_type        = `MEM_NOOP;
        mem_size        = `SZ_FULL;
        wb_reg_dest     = 5'd0;
        wb_reg_en       = 1'd0;
        unsigned_flag   = 1'd0;
        casex({opcode, funct})
            {6'b000000, 6'b100000}: // ADD
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADD, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001000, 6'bxxxxxx}: // ADDI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADD, `SRC_IMM, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b100001}: // ADDU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001001, 6'bxxxxxx}: // ADDIU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b100010}: // SUB
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SUB, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b100011}: // SUBU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SUBU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b101010}: // SLT
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLT, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001010, 6'bxxxxxx}: // SLTI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLT, `SRC_IMM, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b101011}: // SLTU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLTU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001011, 6'bxxxxxx}: // SLTIU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLTU, `SRC_IMM, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b011010}: // DIV
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_DIV, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b011011}: // DIVU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_DIVU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b011000}: // MULT
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MULT, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b011001}: // MULTU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MULTU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b100100}: // AND
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_AND, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001100, 6'bxxxxxx}: // ANDI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_AND, `SRC_IMM, `ZERO_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b001111, 6'bxxxxxx}: // LUI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_LUI, `SRC_IMM, `ZERO_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b100111}: // NOR
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_NOR, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b100101}: // OR
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_OR, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001101, 6'bxxxxxx}: // ORI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_OR, `SRC_IMM, `ZERO_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b100110}: // XOR
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_XOR, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b001110, 6'bxxxxxx}: // XORI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_XOR, `SRC_IMM, `ZERO_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b000100}: // SLLV
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLL, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b000000}: // SLL
                 {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLL, `SRC_SFT, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b000111}: // SRAV
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SRA, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b000011}: // SRA
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SRA, `SRC_SFT, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b000110}: // SRLV
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SRL, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b000010}: // SRL
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SRL, `SRC_SFT, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b010000}: // MFHI
                  {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MFHI, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b010010}: // MFLO
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MFLO, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b010001}: // MTHI
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MTHI, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b010011}: // MTLO
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MTLO, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b001101}: begin // BREAK
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_BREK, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                priv_inst = 1'b1;
            end
            {6'b000000, 6'b001100}: begin // SYSCALL
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SYSC, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                priv_inst = 1'b1;
            end
            {6'b100000, 6'bxxxxxx}: // LB
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_BYTE, rt, 1'b1, `SIGN_EXTENDED};
            {6'b100100, 6'bxxxxxx}: // LBU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_BYTE, rt, 1'b1, `ZERO_EXTENDED};
            {6'b100001, 6'bxxxxxx}: // LH
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_HALF, rt, 1'b1, `SIGN_EXTENDED};
            {6'b100101, 6'bxxxxxx}: // LHU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_HALF, rt, 1'b1, `ZERO_EXTENDED};
            {6'b100011, 6'bxxxxxx}: // LW
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
            {6'b101000, 6'bxxxxxx}: // SB
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_STOR, `SZ_BYTE, rt, 1'b0, `SIGN_EXTENDED};
            {6'b101001, 6'bxxxxxx}: // SH
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_STOR, `SZ_HALF, rt, 1'b0, `SIGN_EXTENDED};
            {6'b101011, 6'bxxxxxx}: // SW
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_STOR, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
            {6'b010000, 6'bxxxxxx}: begin // PRIV_INST
                priv_inst = 1'b1;
                if(instruction == 32'b01000010000000000000000000011000) // ERET
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_ERET, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                else if(instruction[25:21] == 5'b00000) // MFC0
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_MFC0, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b1, `ZERO_EXTENDED};
                else if(instruction[25:21] == 5'b00100) // MTC0
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_MTC0, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                else if(instruction[25] && instruction[5:0] == 6'b001000) // TLBP
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_TLBP, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                else if(instruction[25] && instruction[5:0] == 6'b000001) // TLBR
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_TLBR, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                else if(instruction[25] && instruction[5:0] == 6'b000010) // TLBWI
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_TLBWI, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                else if(instruction[25] && instruction[5:0] == 6'b000110) // TLBWR
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_TLBWR, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                else
                    undefined_inst = 1'd1;
            end
            // MIPS32r1 begin
            {6'b011100, 6'b100001}: // CLO
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_CLO, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b011100, 6'b100000}: // CLZ
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_CLZ, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b011100, 6'b000000}: // MADD
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MADD, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b011100, 6'b000001}: // MADDU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MADDU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b011100, 6'b000100}: // MSUB
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MSUB, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b011100, 6'b000010}: // MUL
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MUL, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b011100, 6'b000101}: // MSUBU
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MSUBU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b000000, 6'b001011}: // MOVN
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MOVN, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b000000, 6'b001010}: // MOVZ
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_MOVZ, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b1, `ZERO_EXTENDED};
            {6'b110011, 6'bxxxxxx}: begin // PREF -- as NOP
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLL, `SRC_SFT, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
                priv_inst = 1'b1;
            end
            {6'b000000, 6'b001111}: // SYSC -- sa NOP
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLL, `SRC_SFT, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
            {6'b010000, 6'b100000}: begin // WAIT -- as NOP
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_SLL, `SRC_SFT, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rd, 1'b0, `ZERO_EXTENDED};
                priv_inst = 1'b1;
            end
            {6'b101010, 6'bxxxxxx}: // SWL
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_STOR, `SZ_LEFT, rt, 1'b0, `ZERO_EXTENDED};
            {6'b101110, 6'bxxxxxx}: // SWR
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_STOR, `SZ_RIGH, rt, 1'b0, `ZERO_EXTENDED};
            {6'b100010, 6'bxxxxxx}: // LWL
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_LEFT, rt, 1'b1, `ZERO_EXTENDED};
            {6'b100110, 6'bxxxxxx}: // LWR
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_LOAD, `SZ_RIGH, rt, 1'b1, `ZERO_EXTENDED};
            {6'b101111, 6'bxxxxxx}: begin // CACHE
                {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                    {`ALU_ADDU, `SRC_IMM, `SIGN_EXTENDED, `MEM_CACH, `SZ_BYTE, rt, 1'b0, `ZERO_EXTENDED};
                priv_inst = 1'b1;
            end
            // MIPS32r1 end
            default: begin
                if(is_branch && is_branch_al)
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_OUTA, `SRC_PCA, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, 5'd31, 1'b1, `ZERO_EXTENDED};
                else begin
                    undefined_inst = ~is_branch;
                    {alu_op, alu_src, alu_imm_src, mem_type, mem_size, wb_reg_dest, wb_reg_en, unsigned_flag} = 
                        {`ALU_ADDU, `SRC_REG, `SIGN_EXTENDED, `MEM_NOOP, `SZ_FULL, rt, 1'b0, `ZERO_EXTENDED};
                end
            end
        endcase
    end
endmodule
