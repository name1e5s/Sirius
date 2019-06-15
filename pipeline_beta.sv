`timescale 1ns / 1ps
`include "alu_op.vh"
`include "common.vh"

// The SLAVE pipeline.
// This pipeline can only perform some simple 
// arithmetic and logic operation.
module pipeline_beta(
        input                       clk,
        input                       rst,

        // Clobal control signal
        input                       flush,
        input                       en_id_ex,
        input                       en_ex_mem,
        input                       en_mem_wb,

        // From IF FIFO
        input   [31:0]              instruction,
        input   [31:0]              pc_address,
        input                       is_real_instruction,

        // From register
        input [31:0]				rdata2_a,
        input [31:0]				rdata2_b,

        // From master pipeline
        input                       master_ex_reg_en,
        input [ 4:0]                master_ex_addr,
        input [31:0]                master_ex_data,
        input                       master_mem_reg_en,
        input [ 4:0]                master_mem_addr,
        input [31:0]                master_mem_data,

        // To exception control unit
        output logic                slave_exp_undefined_inst,
        output logic                slave_exp_overflow,

        // To register
        output logic [4:0]			raddr2_a,
        output logic [4:0]			raddr2_b,
        output logic                reg_write_en,
        output logic [4:0]          reg_write_dest,
        output logic [31:0]         reg_write_data,

        // To master pipeline
        output logic                slave_ex_reg_en,
        output logic [ 4:0]         slave_ex_addr,
        output logic [31:0]         slave_ex_data,
        output logic                slave_mem_reg_en,
        output logic [ 4:0]         slave_mem_addr,
        output logic [31:0]         slave_mem_data
);

    // ID  internal signals
    wire [5:0] decoder_opcode;
    wire [4:0] decoder_rs, decoder_rt, decoder_rd;
    wire [4:0] decoder_shamt;
    wire [5:0] decoder_funct;
    wire [5:0] decoder_immediate;
    wire       decoder_undefined_inst;
    wire [5:0] decoder_alu_op;
    wire [1:0] decoder_alu_src;
    wire       decoder_alu_imm_src;
    wire [1:0] decoder_mem_type;
    wire [2:0] decoder_mem_size;
    wire [4:0] decoder_wb_reg_dest;
    wire       decoder_wb_reg_en;
    wire       decoder_unsigned_flag;
    // Compute alu_src
    logic [31:0] id_alu_src_a;
    logic [31:0] id_alu_src_b;

    // EX internal signals
    wire [31:0]     ex_result;
    wire            exp_overflow;

    //! ID-EX SLAVE PIPELINE REGISTERS
    reg [31:0] id_ex_pc_address;
    reg [31:0] id_ex_instruction;
    // For function unit
    reg [5:0]  id_ex_alu_op;
    reg [31:0] id_ex_rs_data, id_ex_rt_data;
    reg [31:0] id_ex_alu_src_a, id_ex_alu_src_b;
    // For MEM stage
    reg [4:0]  id_ex_rt_addr;
    // For CP0
    reg        id_ex_undefined_inst;
    // For wb
    reg 	   id_ex_wb_reg_en;
    reg [4:0]  id_ex_wb_reg_addr;

    //! EX-MEM SLAVE PIPELINE
    // For exception
    reg [31:0] ex_mem_pc_address;
    reg        ex_mem_undefined_inst;
    reg        ex_mem_exp_overflow;
    // For wb
    reg 	   ex_mem_wb_reg_en;
    reg [4:0]  ex_mem_wb_reg_addr;
    reg [31:0] ex_mem_result;
    //! MEM-WB SLAVE PIPELINE
    // For wb
    reg 	   mem_wb_wb_reg_en;
    reg [4:0]  mem_wb_wb_reg_addr;
    reg [31:0] mem_wb_result;
    
    // To exception control unit
    assign slave_exp_undefined_inst = ex_mem_undefined_inst;
    assign slave_exp_overflow       = ex_mem_exp_overflow;

    // To register
    assign raddr2_a = decoder_rs;
    assign raddr2_b = decoder_rt;

    // To master pipeline
    assign slave_ex_reg_en  = id_ex_wb_reg_en;
    assign slave_ex_addr    = id_ex_wb_reg_addr;
    assign slave_ex_data    = ex_result;
    assign slave_mem_reg_en = ex_mem_wb_reg_en;
    assign slave_mem_addr   = ex_mem_wb_reg_addr;
    assign slave_mem_data   = ex_mem_result;

    decoder_beta decoder_1(
        .clk                (clk),
        .rst                (rst),
        .instruction        (instruction),
        .opcode             (decoder_opcode),
        .rs                 (decoder_rs),
        .rt                 (decoder_rt),
        .rd                 (decoder_rd),
        .shamt              (decoder_shamt),
        .funct              (decoder_funct),
        .immediate          (decoder_immediate)
    );

    decoder_ctrl decoder_ctrl_1(
        .instruction        (instruction),
        .opcode             (decoder_opcode),
        .rt                 (decoder_rt),
        .rd                 (decoder_rd),
        .funct              (decoder_funct),
        .is_branch          (1'b0),
        .is_branch_al       (1'b0), // No branch in slave pipeline.
        .undefined_inst     (decoder_undefined_inst),
        .alu_op             (decoder_alu_op),
        .alu_src            (decoder_alu_src),
        .alu_imm_src        (decoder_alu_imm_src),
        .mem_type           (decoder_mem_type),
        .mem_size           (decoder_mem_size),
        .wb_reg_dest        (decoder_wb_reg_dest),
        .wb_reg_en          (decoder_wb_reg_en),
        .unsigned_flag      (decoder_unsigned_flag)
    );

    // Register value forwarding
    wire                   ex_reg_en    = id_ex_wb_reg_en;
    wire [ 4:0]            ex_addr      = id_ex_wb_reg_addr;
    wire [31:0]            ex_data      = ex_result;
    wire                   mem_reg_en   = ex_mem_wb_reg_en;
    wire [ 4:0]            mem_addr     = ex_mem_wb_reg_addr;
    wire [31:0]            mem_data     = ex_mem_result;
    wire [31:0]            rs_value, rt_value;

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

    always_comb begin : get_alu_src_a
        if(id_alu_src == `SRC_SFT)
            id_alu_src_a = { 27'd0 ,decoder_shamt};
        else if(id_alu_src == `SRC_PCA)
            id_alu_src_a = pc_address + 32'd8;
        else
            id_alu_src_a = rs_value;
    end

    always_comb begin: get_alu_src_b
        unique case(id_alu_src)
            `SRC_IMM: begin
            if(decoder_alu_imm_src)
                id_alu_src_b = { 16'd0, decoder_immediate };
            else
                id_alu_src_b = { {16{decoder_immediate[15]}}, decoder_immediate};
            end
            default:
                id_alu_src_b = rt_value;
        endcase
    end

    always_ff @(posedge clk) begin : id_ex_registers
        if(rst || (!en_id_ex && en_ex_mem) || flush) begin
            id_ex_pc_address            <= 32'd0;
            id_ex_instruction           <= 32'd0;
            id_ex_alu_op                <= `ALU_ADDU;
            id_ex_rs_data               <= 32'd0;
            id_ex_rt_data               <= 32'd0;
            id_ex_alu_src_a             <= 32'd0;
            id_ex_alu_src_b             <= 32'd0;
            id_ex_rt_addr               <= 5'd0;
            id_ex_undefined_inst        <= 1'd0;
            id_ex_wb_reg_en             <= 1'd0;
            id_ex_wb_reg_addr           <= 5'd0;
        end
        else if(en_id_ex) begin
            id_ex_pc_address            <= pc_address;
            id_ex_instruction           <= instruction;
            id_ex_alu_op                <= decoder_alu_op;
            id_ex_rs_data               <= rs_value;
            id_ex_rt_data               <= rt_value;
            id_ex_alu_src_a             <= id_alu_src_a;
            id_ex_alu_src_b             <= id_alu_src_b;
            id_ex_rt_addr               <= decoder_rt;
            id_ex_undefined_inst        <= decoder_undefined_inst;
            id_ex_wb_reg_en             <= decoder_wb_reg_en;
            id_ex_wb_reg_addr           <= decoder_wb_reg_dest;
        end
    end

    alu_beta alu_beta_0(
        .clk                (clk),
        .rst                (rst),
        .alu_op             (id_ex_alu_op),
        .src_a              (id_alu_src_a),
        .src_b              (id_alu_src_b),
        .exp_overflow       (exp_overflow),
        .result             (ex_result)
    );

    always_ff @(posedge clk) begin : ex_mem_registers
        if(rst || (!en_ex_mem && en_mem_wb) || flush) begin
            ex_mem_pc_address           <= 32'd0;
            ex_mem_undefined_inst       <= 1'd0;
            ex_mem_exp_overflow         <= 1'd0;
            ex_mem_wb_reg_en            <= 1'd0;
            ex_mem_wb_reg_addr          <= 5'd0;
            ex_mem_result               <= 32'd0;
        end
        else if(en_ex_mem) begin
            ex_mem_pc_address           <= id_ex_pc_address;
            ex_mem_undefined_inst       <= id_ex_undefined_inst;
            ex_mem_exp_overflow         <= exp_overflow;
            ex_mem_wb_reg_en            <= id_ex_wb_reg_en;
            ex_mem_wb_reg_addr          <= id_ex_wb_reg_addr;
            ex_mem_result               <= ex_result;
        end
    end

    always_ff @(posedge clk) begin : mem_wb_registers
        if(rst || !en_mem_wb || flush) begin
            mem_wb_wb_reg_en            <= 1'd0;
            mem_wb_wb_reg_addr          <= 5'd0;
            mem_wb_result               <= 32'd0;
        end
        else begin
            mem_wb_wb_reg_en            <= ex_mem_wb_reg_en;
            mem_wb_wb_reg_addr          <= ex_mem_wb_reg_addr;
            mem_wb_result               <= ex_mem_result;
        end
    end

    writeback_beta writeback_beta_0(
        .result             (mem_wb_result),
        .reg_dest           (mem_wb_wb_reg_addr),
        .write_en           (mem_wb_wb_reg_en),
        .reg_write_en       (reg_write_en),
        .reg_write_dest     (reg_write_dest),
        .reg_write_data     (reg_write_data)
    );
endmodule