`define ALU_ADD     6'd0
`define ALU_ADDU    6'd1
`define ALU_SUB     6'd2
`define ALU_SUBU    6'd3
`define ALU_SLT     6'd4
`define ALU_SLTU    6'd5
`define ALU_DIV     6'd6
`define ALU_DIVU    6'd7
`define ALU_MULT    6'd8
`define ALU_MULTU   6'd9
`define ALU_AND     6'd10
`define ALU_LUI     6'd11
`define ALU_NOR     6'd12
`define ALU_OR      6'd13
`define ALU_XOR     6'd14
`define ALU_SLL     6'd15
`define ALU_SRA     6'd16
`define ALU_SRL     6'd17
`define ALU_MFHI    6'd18
`define ALU_MFLO    6'd19
`define ALU_MTHI    6'd20
`define ALU_MTLO    6'd21
// FAKE ALU OP
`define ALU_OUTA    6'd22
`define ALU_OUTB    6'd23
// C0
`define ALU_MFC0    6'd24
`define ALU_MTC0    6'd25
`define ALU_ERET    6'd26
`define ALU_SYSC    6'd27
`define ALU_BREK    6'd28

// MIPS32r2
`define ALU_MUL     6'd29
`define ALU_CLO     6'd30 
`define ALU_CLZ     6'd31
`define ALU_MADD    6'd32
`define ALU_MADDU   6'd33
`define ALU_MSUB    6'd34
`define ALU_MSUBU   6'd35
`define ALU_MOVN    6'd36
`define ALU_MOVZ    6'd37
`define ALU_TLBWI   6'd38
`define ALU_TLBWR   6'd39
`define ALU_TLBR    6'd40
`define ALU_TLBP    6'd41