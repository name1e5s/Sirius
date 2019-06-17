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
    // EX SIGNALS

    // MEM SIGNALS
    wire                mem_exception_taken;
    wire [31:0]         mem_exception_address;

    // IF-ID SIGNALS
    reg [31:0]          if_id_pc_address;
    reg [31:0]          if_id_instruction;
    reg                 if_id_is_instruction;
    reg                 if_id_in_delay_slot;

    pc pc_0(
        .clk                    (clk),
        .rst                    (rst),
        .pc_en                  (if_en),
        .inst_ok_1              (inst_ok_1),
        .inst_ok_2              (1'b0),
        .branch_taken           (id_branch_taken),
        .branch_address         (id_branch_address),
        .exception_taken        (mem_exception_taken),
        .exception_address      (mem_exception_address),
        .pc_address             (if_pc_address)
    );

    always_ff @(posedge clk) begin : if_id_registers
        if(rst || (id_ex_en && !if_id_en) || flush) begin
            if_id_pc_address    <= 32'd0;
            if_id_instruction   <= 32'd0;
            if_id_is_instruction<= 1'b0;
            if_id_in_delay_slot <= 1'b0;
        end
        else if(if_id_en) begin
            if_id_pc_address    <= if_pc_address;
            if_id_instruction   <= inst_data_1;
            if_id_is_instruction<= 1'b1;
            if_id_in_delay_slot <= id_is_branch_instr;
        end
    end

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

    forwarding_unit forwarding_rs(
        .slave_ex_reg_en    (ex_reg_en),
        .slave_ex_addr      (ex_addr),
        .slave_ex_data      (ex_data),
        .master_ex_reg_en   (master_ex_reg_en),
        .master_ex_addr     (master_ex_addr),
        .master_ex_data     (master_ex_data),
        .slave_mem_reg_en   (mem_reg_en),
        .slave_mem_addr     (mem_addr),
        .slave_mem_data     (mem_data),
        .master_mem_reg_en  (master_mem_reg_en),
        .master_mem_addr    (master_mem_addr),
        .master_mem_data    (master_mem_data),
        .reg_addr           (decoder_rs),
        .reg_data           (raddr2_a),
        .result_data        (rs_value)
    );

    forwarding_unit forwarding_rt(
        .slave_ex_reg_en    (ex_reg_en),
        .slave_ex_addr      (ex_addr),
        .slave_ex_data      (ex_data),
        .master_ex_reg_en   (master_ex_reg_en),
        .master_ex_addr     (master_ex_addr),
        .master_ex_data     (master_ex_data),
        .slave_mem_reg_en   (mem_reg_en),
        .slave_mem_addr     (mem_addr),
        .slave_mem_data     (mem_data),
        .master_mem_reg_en  (master_mem_reg_en),
        .master_mem_addr    (master_mem_addr),
        .master_mem_data    (master_mem_data),
        .reg_addr           (decoder_rt),
        .reg_data           (raddr2_b),
        .result_data        (rt_value)
    );

    logic [31:0] id_alu_src_a, id_alu_src_b;
    // Get alu sources
    always_comb begin : get_alu_src_a
        if(id_alu_src == `SRC_SFT)
            id_alu_src_a = { 27'd0 ,id_shamt};
        else if(id_alu_src == `SRC_PCA)
            id_alu_src_a = if_id_pc_address + 32'd8;
        else
            id_alu_src_a = rs_value;
    end

    always_comb begin: get_alu_src_b
        unique case(id_alu_src)
            `SRC_IMM: begin
            if(id_alu_imm_src)
                id_alu_src_b = { 16'd0, id_immediate };
            else
                id_alu_src_b = { {16{id_immediate[15]}}, id_immediate};
            end
            default:
                id_alu_src_b = rt_value;
        endcase
    end

    branch branch_unit(
        .en                 (if_id_en),
        .pc_address         (if_id_pc_address),
        .instruction        (if_id_instruction),
        .is_branch_instr    (id_is_branch_instr),
        .branch_type        (id_branch_type),
        .data_rs            (rs_value),
        .data_rt            (rt_value),
        .branch_taken       (id_branch_taken),
        .branch_address     (id_branch_address)
    );

    // ID-EX SIGNALS
    // MASTER
    reg [31:0]  id_ex_pc_address;
    reg [31:0]  id_ex_instruction;
    reg [31:0]  id_ex_rs_value;
    reg [31:0]  id_ex_rt_value;
    reg [31:0]  id_ex_alu_src_a;
    reg [31:0]  id_ex_alu_src_b;
    reg [ 1:0]  id_ex_mem_type;
    reg [ 2:0]  id_ex_mem_size;
    reg         id_ex_mem_unsigned_flag;
    reg [ 4:0]  id_ex_wb_reg_dest;
    reg         id_ex_wb_reg_en;
    reg [ 4:0]  id_ex_rd_addr;
    reg [ 2:0]  id_ex_sel;
    reg         id_ex_is_branch_link;
    reg [ 5:0]  id_ex_alu_op;
    reg [ 4:0]  id_ex_rt_addr;
    reg         id_ex_undefined_inst;
    reg         id_ex_is_inst;
    reg         id_ex_in_delay_slot;

    always_ff @(posedge clk) begin
        if(rst || (!id_ex_en && ex_mem_en) || flush) begin
            id_ex_pc_address        <= 32'd0;
            id_ex_instruction       <= 32'd0;
            id_ex_rs_value          <= 32'd0;
            id_ex_rt_value          <= 32'd0;
            id_ex_alu_src_a         <= 32'd0;
            id_ex_alu_src_b         <= 32'd0;
            id_ex_mem_type          <= `MEM_NOOP;
            id_ex_mem_size          <= `SZ_FULL;
            id_ex_mem_unsigned_flag <= 1'b0;
            id_ex_wb_reg_dest       <= 5'd0;
            id_ex_wb_reg_en         <= 1'd0;
            id_ex_rd_addr           <= 5'd0;
            id_ex_sel               <= 3'd0;
            id_ex_is_branch_link    <= 1'b0;
            id_ex_alu_op            <= 6'd0;
            id_ex_rt_addr           <= 5'd0;
            id_ex_undefined_inst    <= 1'd0;
            id_ex_is_inst           <= 1'd0;
            id_ex_in_delay_slot     <= 1'd0;
        end
        else if(id_ex_en) begin 
            id_ex_pc_address        <= if_pc_address;
            id_ex_instruction       <= if_id_instruction;
            id_ex_rs_value          <= rs_value;
            id_ex_rt_value          <= rt_value;
            id_ex_alu_src_a         <= id_alu_src_a;
            id_ex_alu_src_b         <= id_alu_src_b;
            id_ex_mem_type          <= id_mem_type;
            id_ex_mem_size          <= id_mem_size;
            id_ex_mem_unsigned_flag <= id_unsigned_flag;
            id_ex_wb_reg_dest       <= id_wb_reg_dest;
            id_ex_wb_reg_en         <= id_wb_reg_en;
            id_ex_rd_addr           <= id_rd;
            id_ex_sel               <= if_id_instruction[2:0];
            id_ex_is_branch_link    <= id_is_branch_link;
            id_ex_alu_op            <= id_alu_op;
            id_ex_rt_addr           <= id_rt;
            id_ex_undefined_inst    <= id_undefined_inst;
            id_ex_is_inst           <= if_id_is_instruction;
            id_ex_in_delay_slot     <= if_id_in_delay_slot;
        end
    end

endmodule