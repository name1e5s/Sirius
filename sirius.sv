`timescale 1ns / 1ps

// The pipeline
module sirius(
        input                   clk,
        input                   rst,
        
        // Interupt channel
        input [5:0]             interrupt,
        // Inst channel
        output logic            inst_en,
        output logic [31:0]     inst_addr,
        input                   inst_ok,
        input                   inst_ok_1,
        input                   inst_ok_2,
        input [31:0]            inst_data_1,
        input [31:0]            inst_data_2,

        // Data channel
        output logic            data_en,
        output logic [3:0]      data_wen,
        output logic [31:0]     data_addr,
        output logic [31:0]     data_wdata,
        input                   data_ok,
        input [31:0]            data_data
);

    wire        if_en, if_id_en, id_ex_en, ex_mem_en, mem_wb_en;

    // IF SIGNALS
    wire [31:0] if_pc_address;
    wire [31:0] if_pc_slave_address = if_pc_address + 32'd4;

    // ID SIGNALS
    wire                id_branch_taken;
    wire [31:0]         id_branch_address;
    // ID -- master
    wire [5:0]          id_opcode, id_funct;
    wire [4:0]          id_rs, id_rt, id_rd, id_shamt;
    wire [15:0]         id_immediate;
    wire [25:0]         id_instr_index;
    wire [2:0]          id_branch_type;
    wire                id_is_branch_instr;
    wire                id_is_branch_link;
    wire                id_is_hilo_accessed;

    wire                id_undefined_inst;
    wire [5:0]	        id_alu_op;
    wire [1:0]          id_alu_src;
    wire                id_alu_imm_src;
    wire [1:0]          id_mem_type;
    wire [2:0]          id_mem_size;
    wire [4:0]          id_wb_reg_dest;
    wire                id_wb_reg_en;
    wire                id_unsigned_flag;
    wire                id_priv_inst;
    // ID -- SLAVE
    wire [5:0]          id_opcode_slave, id_funct_slave;
    wire [4:0]          id_rs_slave, id_rt_slave, id_rd_slave, id_shamt_slave;
    wire [15:0]         id_immediate_slave;
    wire [25:0]         id_instr_index_slave;
    wire [2:0]          id_branch_type_slave;
    wire                id_is_branch_instr_slave;
    wire                id_is_branch_link_slave;
    wire                id_is_hilo_accessed_slave;

    wire                id_undefined_inst_slave;
    wire [5:0]	        id_alu_op_slave;
    wire [1:0]          id_alu_src_slave;
    wire                id_alu_imm_src_slave;
    wire [1:0]          id_mem_type_slave;
    wire [2:0]          id_mem_size_slave;
    wire [4:0]          id_wb_reg_dest_slave;
    wire                id_wb_reg_en_slave;
    wire                id_unsigned_flag_slave;
    wire                id_priv_inst_slave;

    // MEM SIGNALS
    wire                mem_exception_taken;
    wire [31:0]         mem_exception_address;

    // IF-ID SIGNALS
    wire [31:0]         if_id_pc_address;
    wire [31:0]         if_id_pc_address_slave;
    wire [31:0]         if_id_instruction;
    wire [31:0]         if_id_instruction_slave;

    pc pc_0(
        .clk                    (clk),
        .rst                    (rst),
        .pc_en                  (if_en),
        .inst_ok_1              (inst_ok_1),
        .inst_ok_2              (inst_ok_2),
        .branch_taken           (id_branch_taken),
        .branch_address         (id_branch_address),
        .exception_taken        (mem_exception_taken),
        .exception_address      (mem_exception_address),
        .pc_address             (if_pc_address)
    );

    // IF-ID ... no registers!
    instruction_fifo(
        .clk                    (clk),
        .rst                    (rst),
        .read_en1               (), // TODO: provided by id-stage
        .read_en2               (),
        .write_en1              (inst_ok && inst_ok_1),
        .write_en2              (inst_ok && inst_ok_2),
        .write_data_1           (inst_data_1),
        .write_data_2           (inst_data_2),
        .write_address_1        (if_pc_address),
        .write_address_2        (if_pc_slave_address),
        .data_out1              (if_id_instruction),
        .data_out2              (if_id_instruction_slave),
        .address_out1           (if_id_pc_address),
        .address_out2           (if_id_pc_address_slave),
        .empty                  (),
        .almost_empty           (),
        .full                   ()
    );

    decoder_alpha decoder_master(
        .instruction            (if_id_instruction),
        .opcode                 (id_opcode),
        .rs                     (id_rs),
        .rt                     (id_rt),
        .rd                     (id_rd),
        .shamt                  (id_shamt),
        .funct                  (id_funct),
        .immediate              (id_immediate),
        .instr_index            (id_instr_index),
        .branch_type            (id_branch_type),
        .is_branch_instr        (id_is_branch_instr),
        .is_branch_link         (id_is_branch_link),
        .is_hilo_accessed       (id_is_hilo_accessed)
    );

    decoder_crtl conrtol_master(
        .instruction            (if_id_instruction),
        .opcode                 (id_opcode),
        .rt                     (id_rt),
        .rd                     (id_rd),
        .funct                  (id_funct),
        .is_branch              (id_is_branch_instr),
        .is_branch_al           (id_is_branch_link),
        .undefined_inst         (id_undefined_inst),
        .alu_op                 (id_alu_op),
        .alu_src                (id_alu_src),
        .alu_imm_src            (id_alu_imm_src),
        .mem_type               (id_mem_type),
        .mem_size               (id_mem_size),
        .wb_reg_dest            (id_wb_reg_dest),
        .wb_reg_en              (id_wb_reg_en),
        .unsigned_flag          (id_unsigned_flag),
        .priv_inst              (id_priv_inst)
    );

    decoder_alpha decoder_slave(
        .instruction            (if_id_instruction),
        .opcode                 (id_opcode_slave),
        .rs                     (id_rs_slave),
        .rt                     (id_rt_slave),
        .rd                     (id_rd_slave),
        .shamt                  (id_shamt_slave),
        .funct                  (id_funct_slave),
        .immediate              (id_immediate_slave),
        .instr_index            (id_instr_index_slave),
        .branch_type            (id_branch_type_slave),
        .is_branch_instr        (id_is_branch_instr_slave),
        .is_branch_link         (id_is_branch_link_slave),
        .is_hilo_accessed       (id_is_hilo_accessed_slave)
    );

    decoder_crtl conrtol_slave(
        .instruction            (if_id_instruction),
        .opcode                 (id_opcode_slave),
        .rt                     (id_rt_slave),
        .rd                     (id_rd_slave),
        .funct                  (id_funct_slave),
        .is_branch              (id_is_branch_instr_slave),
        .is_branch_al           (id_is_branch_link_slave),
        .undefined_inst         (id_undefined_inst_slave),
        .alu_op                 (id_alu_op_slave),
        .alu_src                (id_alu_src_slave),
        .alu_imm_src            (id_alu_imm_src_slave),
        .mem_type               (id_mem_type_slave),
        .mem_size               (id_mem_size_slave),
        .wb_reg_dest            (id_wb_reg_dest_slave),
        .wb_reg_en              (id_wb_reg_en_slave),
        .unsigned_flag          (id_unsigned_flag_slave),
        .priv_inst              (id_priv_inst_slave)
    );

endmodule