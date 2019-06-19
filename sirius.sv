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

    wire                if_en, if_id_en, id_ex_en, ex_mem_en, mem_wb_en;
    wire                flush;

    wire                fifo_full;
    assign              if_en = !fifo_full;

    // IF SIGNALS
    wire [31:0]         if_pc_address;
    wire [31:0]         if_pc_slave_address = if_pc_address + 32'd4;

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
    wire [31:0]         reg_rs_data, reg_rt_data;
    wire [31:0]         rs_value, rt_value;

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

    // ID -- slave
    wire [5:0]          id_opcode_slave, id_funct_slave;
    wire [4:0]          id_rs_slave, id_rt_slave, id_rd_slave, id_shamt_slave;
    wire [15:0]         id_immediate_slave;
    wire [25:0]         id_instr_index_slave;
    wire [2:0]          id_branch_type_slave;
    wire                id_is_branch_instr_slave;
    wire                id_is_branch_link_slave;
    wire                id_is_hilo_accessed_slave;
    wire [31:0]         reg_rs_data_slave, reg_rt_data_slave;
    wire [31:0]         rs_value_slave, rt_value_slave;

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

    wire                id_enable_slave;
    // EX SIGNALS
    wire [7:0]          ex_cop0_addr;
    wire                ex_cop0_wen;
    wire [31:0]         ex_cop0_data;
    wire                ex_exp_overflow;
    wire                ex_exp_eret;
    wire                ex_exp_syscal;
    wire                ex_exp_break;
    wire [31:0]         ex_result;
    wire                ex_stall_o;

    wire                ex_exp_overflow_slave;
    wire [31:0]         ex_result_slave;

    // MEM SIGNALS
    wire                mem_exception_taken = flush;
    wire [31:0]         mem_exception_address;
    wire                mem_cp0_exp_en;
    wire                mem_cp0_exp_badvaddr_en;
    wire [31:0]         mem_cp0_exp_badvaddr;
    wire                mem_cp0_exp_bd;
    wire [4:0]          mem_cp0_exp_code;
    wire [31:0]         mem_cp0_exp_epc;
    wire                mem_cp0_exl_clean;
    wire [31:0]         mem_cp0_epc_address;
    wire                mem_cp0_allow_interrupt;
    wire [7:0]          mem_cp0_interrupt_flag;
    wire [31:0]         mem_result;
    wire                mem_addr_error;

    // WB SIGNALS
    wire                wb_reg_write_en;
    wire [4:0]          wb_reg_write_dest;
    wire [31:0]         wb_reg_write_data;

    wire                wb_reg_write_en_slave;
    wire [4:0]          wb_reg_write_dest_slave;
    wire [31:0]         wb_reg_write_data_slave;

    // IF-ID SIGNALS
    wire [31:0]          if_id_pc_address;
    wire [31:0]          if_id_instruction;
    wire                 if_id_in_delay_slot;
    wire [31:0]          if_id_pc_address_slave;
    wire [31:0]          if_id_instruction_slave;
    wire                 if_id_in_delay_slot_slave;
    wire                 if_id_fifo_empty;
    wire                 if_id_fifo_almost_empty;

    // ID-EX SIGNALS
    // MASTER
    reg [31:0]      id_ex_pc_address;
    reg [31:0]      id_ex_instruction;
    reg [31:0]      id_ex_rs_value;
    reg [31:0]      id_ex_rt_value;
    reg [31:0]      id_ex_alu_src_a;
    reg [31:0]      id_ex_alu_src_b;
    reg [ 1:0]      id_ex_mem_type;
    reg [ 2:0]      id_ex_mem_size;
    reg             id_ex_mem_unsigned_flag;
    reg [ 4:0]      id_ex_wb_reg_dest;
    reg             id_ex_wb_reg_en;
    reg [ 4:0]      id_ex_rd_addr;
    reg [ 2:0]      id_ex_sel;
    reg             id_ex_is_branch_link;
    reg [ 5:0]      id_ex_alu_op;
    reg [ 4:0]      id_ex_rt_addr;
    reg             id_ex_undefined_inst;
    reg             id_ex_is_inst;
    reg             id_ex_is_branch;
    reg             id_ex_in_delay_slot;

    // SLAVE
    reg [31:0]      id_ex_pc_address_slave;
    reg [31:0]      id_ex_alu_src_a_slave;
    reg [31:0]      id_ex_alu_src_b_slave;
    reg [ 4:0]      id_ex_wb_reg_dest_slave;
    reg             id_ex_wb_reg_en_slave;
    reg [ 5:0]      id_ex_alu_op_slave;

    // EX_MEM SIGNALS
    // MASTER
    reg 	        ex_mem_cp0_wen;
    reg [7:0]       ex_mem_cp0_waddr;
    reg [31:0]      ex_mem_cp0_wdata;
    reg [31:0]      ex_mem_result;
    reg [31:0]      ex_mem_rt_value;
    reg [2:0]       ex_mem_size;
    reg 	        ex_mem_unsigned_flag;
    reg             ex_mem_is_inst;    
    reg 	        ex_mem_invalid_instruction;
    reg 	        ex_mem_syscall;
    reg 	        ex_mem_break_;
    reg 	        ex_mem_eret;
    reg 	        ex_mem_overflow;
    reg 	        ex_mem_wen;
    reg 	        ex_mem_in_delay_slot;
    reg [31:0]      ex_mem_pc_address;
    reg [31:0]      ex_mem_mem_address;
    reg [4:0]       ex_mem_wb_reg_dest;
    reg             ex_mem_wb_reg_en;
    reg 	        ex_mem_branch_link;
    reg             ex_mem_is_branch;
    reg [1:0]       ex_mem_type;
    reg [2:0]       ex_mem_size;

    // SLAVE
    reg [31:0]      ex_mem_pc_address_slave;
    reg [31:0]      ex_mem_result_slave;
    reg [ 4:0]      ex_mem_wb_reg_dest_slave;
    reg             ex_mem_wb_reg_en_slave;
    reg             ex_mem_overflow_slave;

    // MEM_WB SIGNALS
    reg [31:0]      mem_wb_result, mem_wb_pc_address;
    reg [4:0]       mem_wb_reg_dest;
    reg             mem_wb_reg_write_en;
    reg             mem_wb_branch_link;

    // SLAVE
    reg [31:0]      mem_wb_pc_address_slave;
    reg [31:0]      mem_wb_result_slave;
    reg [ 4:0]      mem_wb_reg_dest_slave;
    reg             mem_wb_reg_en_slave;

    // Global components
    pipe_ctrl pipe_ctrl0(
        .ex_stall               (ex_stall_o),
        .mem_stall              (data_en & ~data_ok),
        .id_ex_alu_op           (id_ex_alu_op),
        .id_ex_mem_type         (id_ex_mem_type),
        .id_ex_mem_wb_reg_dest  (id_ex_wb_reg_dest),
        .ex_mem_cp0_wen         (ex_mem_cp0_wen),
        .ex_mem_mem_type        (ex_mem_type),
        .ex_mem_mem_wb_reg_dest (ex_mem_wb_reg_dest),
        .id_rs                  (id_rs),
        .id_rt                  (id_rt),
        .en_if_id               (if_id_en),
        .en_id_ex               (id_ex_en),
        .en_ex_mem              (ex_mem_en),
        .en_mem_wb              (mem_wb_en)
    );

    register reg_file(
        .clk                    (clk),
        .rst                    (rst),
        .raddr1_a               (id_rs),
        .rdata1_a               (reg_rs_data),
        .raddr1_b               (id_rt),
        .rdata1_b               (reg_rt_data),
        .wen1_a                 (wb_reg_write_en),
        .waddr1_a               (wb_reg_write_dest),
        .wdata1_a               (wb_reg_write_data),
        .raddr2_a               (id_rs_slave),
        .rdata2_a               (reg_rs_data_slave),
        .raddr2_b               (id_rt_slave),
        .rdata2_b               (reg_rt_data_slave),
        .wen2_a                 (wb_reg_write_en_slave),
        .waddr2_a               (wb_reg_write_dest_slave),
        .wdata2_a               (wb_reg_write_data_slave)
    );

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

    instruction_fifo instruction_fifo_0(
        .clk                    (clk),
        .rst                    (rst || flush || branch_taken),
        .rst_with_delay         (branch_taken && ~id_enable_slave),
        .read_en1               (if_id_en),
        .read_en2               (id_enable_slave),
        .write_en1              (inst_ok & inst_ok_1),
        .write_en2              (inst_ok & inst_ok_2),
        .write_data1            (inst_data_1),
        .write_address1         (if_pc_address),
        .write_data2            (inst_data_2),
        .write_address2         (if_pc_address + 32'd4),
        .data_out1              (if_id_instruction),
        .data_out2              (if_id_instruction_slave),
        .address_out1           (if_id_pc_address),
        .address_out2           (if_id_pc_address_slave),
        .delay_slot_out1        (if_id_in_delay_slot),
        .empty                  (if_id_fifo_empty),
        .almost_empty           (if_id_fifo_almost_empty),
        .full                   (fifo_full)
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
        .instruction            (if_id_instruction_slave),
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
        .instruction            (if_id_instruction_slave),
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

    forwarding_unit forwarding_rs(
        .slave_ex_reg_en    (id_ex_wb_reg_en_slave),
        .slave_ex_addr      (id_ex_wb_reg_dest_slave),
        .slave_ex_data      (ex_data),
        .master_ex_reg_en   (id_ex_wb_reg_en),
        .master_ex_addr     (id_ex_wb_reg_dest),
        .master_ex_data     (ex_result_slave),
        .slave_mem_reg_en   (ex_mem_wb_reg_en_slave),
        .slave_mem_addr     (ex_mem_wb_reg_dest_slave),
        .slave_mem_data     (ex_mem_result_slave),
        .master_mem_reg_en  (ex_mem_wb_reg_en),
        .master_mem_addr    (ex_mem_wb_reg_dest),
        .master_mem_data    (mem_result),
        .reg_addr           (id_rs),
        .reg_data           (reg_rs_data),
        .result_data        (rs_value)
    );

    forwarding_unit forwarding_rt(
        .slave_ex_reg_en    (id_ex_wb_reg_en_slave),
        .slave_ex_addr      (id_ex_wb_reg_dest_slave),
        .slave_ex_data      (ex_data),
        .master_ex_reg_en   (id_ex_wb_reg_en),
        .master_ex_addr     (id_ex_wb_reg_dest),
        .master_ex_data     (ex_result_slave),
        .slave_mem_reg_en   (ex_mem_wb_reg_en_slave),
        .slave_mem_addr     (ex_mem_wb_reg_dest_slave),
        .slave_mem_data     (ex_mem_result_slave),
        .master_mem_reg_en  (ex_mem_wb_reg_en),
        .master_mem_addr    (ex_mem_wb_reg_dest),
        .master_mem_data    (mem_result),
        .reg_addr           (id_rt),
        .reg_data           (reg_rt_data),
        .result_data        (rt_value)
    );

    forwarding_unit forwarding_rs_slave(
        .slave_ex_reg_en    (id_ex_wb_reg_en_slave),
        .slave_ex_addr      (id_ex_wb_reg_dest_slave),
        .slave_ex_data      (ex_data),
        .master_ex_reg_en   (id_ex_wb_reg_en),
        .master_ex_addr     (id_ex_wb_reg_dest),
        .master_ex_data     (ex_result_slave),
        .slave_mem_reg_en   (ex_mem_wb_reg_en_slave),
        .slave_mem_addr     (ex_mem_wb_reg_dest_slave),
        .slave_mem_data     (ex_mem_result_slave),
        .master_mem_reg_en  (ex_mem_wb_reg_en),
        .master_mem_addr    (ex_mem_wb_reg_dest),
        .master_mem_data    (mem_result),
        .reg_addr           (id_rs_slave),
        .reg_data           (reg_rs_data_slave),
        .result_data        (rs_value_slave)
    );

    forwarding_unit forwarding_rt_slave(
        .slave_ex_reg_en    (id_ex_wb_reg_en_slave),
        .slave_ex_addr      (id_ex_wb_reg_dest_slave),
        .slave_ex_data      (ex_data),
        .master_ex_reg_en   (id_ex_wb_reg_en),
        .master_ex_addr     (id_ex_wb_reg_dest),
        .master_ex_data     (ex_result_slave),
        .slave_mem_reg_en   (ex_mem_wb_reg_en_slave),
        .slave_mem_addr     (ex_mem_wb_reg_dest_slave),
        .slave_mem_data     (ex_mem_result_slave),
        .master_mem_reg_en  (ex_mem_wb_reg_en),
        .master_mem_addr    (ex_mem_wb_reg_dest),
        .master_mem_data    (mem_result),
        .reg_addr           (id_rt_slave),
        .reg_data           (reg_rt_data_slave),
        .result_data        (rt_value_slave)
    );

    dual_engine dual_engine_0(
        .id_priv_inst_master        (id_priv_inst),
        .id_wb_reg_dest_master      (id_wb_reg_dest),
        .id_wb_reg_en_master        (id_wb_reg_en),
        .id_opcode_slave            (id_opcode_slave),
        .id_rs_slave                (id_rs_slave),
        .id_rt_slave                (id_rt_slave),
        .id_mem_type_slave          (id_mem_type_slave),
        .id_is_branch_instr_slave   (id_is_branch_instr_slave),
        .id_priv_inst_slave         (id_priv_inst_slave),
        .fifo_empty                 (if_id_fifo_empty),
        .fifo_almost_empty          (if_id_fifo_almost_empty),
        .enable_master              (if_id_en),
        .enable_slave               (id_enable_slave)
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

    logic [31:0] id_alu_src_a_slave, id_alu_src_b_slave;
    always_comb begin : get_alu_src_a_slave
        if(id_alu_src_slave == `SRC_SFT)
            id_alu_src_a_slave = { 27'd0 ,id_shamt};
        else if(id_alu_src == `SRC_PCA)
            id_alu_src_a_slave = if_id_pc_address + 32'd8;
        else
            id_alu_src_a_slave = rs_value_slave;
    end

    always_comb begin: get_alu_src_b_slave
        unique case(id_alu_src_slave)
            `SRC_IMM: begin
            if(id_alu_imm_src_slave)
                id_alu_src_b_slave = { 16'd0, id_immediate_slave };
            else
                id_alu_src_b_slave = { {16{id_immediate_slave[15]}}, id_immediate_slave};
            end
            default:
                id_alu_src_b_slave = rt_value_slave;
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
            id_ex_is_branch         <= 1'd0;
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
            id_ex_is_branch         <= id_is_branch_instr;
        end
    end

    always_ff @(posedge clk) begin
        if(rst || (!id_ex_en && ex_mem_en) || flush || !id_enable_slave) begin
            id_ex_pc_address_slave  <= 32'd0;
            id_ex_alu_src_a_slave   <= 32'd0;
            id_ex_alu_src_b_slave   <= 32'd0;
            id_ex_wb_reg_dest_slave <= 5'd0;
            id_ex_wb_reg_en_slave   <= 1'd0;
            id_ex_alu_op_slave      <= 6'd0;
        end
        else if(id_ex_en) begin
            id_ex_pc_address_slave  <= if_id_pc_address_slave;
            id_ex_alu_src_a_slave   <= id_alu_src_a_slave;
            id_ex_alu_src_b_slave   <= id_alu_src_b_slave;
            id_ex_wb_reg_dest_slave <= id_wb_reg_dest_slave;
            id_ex_wb_reg_en_slave   <= id_wb_reg_en_slave;
            id_ex_alu_op_slave      <= id_alu_op_slave;
        end
    end

    alu_alpha alu_alpha(
        .clk                (clk),
        .rst                (rst),
        .flush_i            (flush),
        .hilo_accessed      (id_is_hilo_accessed),
        .alu_op             (id_ex_alu_op),
        .src_a              (id_ex_alu_src_a),
        .src_b              (id_ex_alu_src_b),
        .rd                 (id_ex_rd_addr),
        .sel                (id_ex_sel),
        .cop0_addr          (ex_cop0_addr),
        .cop0_data          (ex_cop0_data),
        .cop0_wen           (ex_cop0_wen),
        .exp_overflow       (ex_exp_overflow),
        .exp_eret           (ex_exp_eret),
        .exp_syscal         (ex_exp_syscal),
        .exp_break          (ex_exp_break),
        .result             (ex_result),
        .stall_o            (ex_stall_o)
    );

    alu_beta alu_beta(
        .clk                (clk),
        .rst                (rst),
        .alu_op             (id_ex_alu_op_slave),
        .src_a              (id_ex_alu_src_a_slave),
        .src_b              (id_ex_alu_src_b_slave),
        .exp_overflow       (ex_exp_overflow_slave),
        .result             (ex_result_slave)
    );

    always_ff @(posedge clk) begin
        if(rst || (!ex_mem_en && mem_wb_en) || flush) begin
            ex_mem_cp0_wen              <= 1'b0;
            ex_mem_cp0_waddr            <= 8'b0;
            ex_mem_cp0_wdata            <= 32'd0;
            ex_mem_result               <= 32'd0;
            ex_mem_rt_value             <= 32'd0;
            ex_mem_type                 <= 2'd0;
            ex_mem_size                 <= 3'd0;
            ex_mem_unsigned_flag        <= 1'b0;
            ex_mem_invalid_instruction  <= 1'd0;
            ex_mem_syscall              <= 1'd0;
            ex_mem_break_               <= 1'd0;
            ex_mem_eret                 <= 1'd0;
            ex_mem_overflow             <= 1'd0;
            ex_mem_wen                  <= 1'd0;
            ex_mem_in_delay_slot        <= 1'd0;
            ex_mem_pc_address           <= 32'd0;
            ex_mem_mem_address          <= 32'd0;
            ex_mem_wb_reg_dest          <= 5'd0;
            ex_mem_wb_reg_en            <= 1'b0;
            ex_mem_branch_link          <= 1'd0;
            ex_mem_is_inst              <= 1'd0;
            ex_mem_is_branch            <= 1'd0;
        end
        else if(ex_mem_en) begin 
            ex_mem_cp0_wen              <= ex_cop0_wen;
            ex_mem_cp0_waddr            <= ex_cop0_addr;
            ex_mem_cp0_wdata            <= id_ex_rt_value;
            ex_mem_result               <= ex_result;
            ex_mem_rt_value             <= id_ex_rt_value;
            ex_mem_type                 <= id_ex_mem_type;
            ex_mem_size                 <= id_ex_mem_size;
            ex_mem_unsigned_flag        <= id_ex_mem_unsigned_flag;
            ex_mem_invalid_instruction  <= id_ex_undefined_inst;
            ex_mem_syscall              <= ex_exp_syscal;
            ex_mem_break_               <= ex_exp_break;
            ex_mem_eret                 <= ex_exp_eret;
            ex_mem_overflow             <= ex_exp_overflow;
            ex_mem_wen                  <= id_ex_mem_type == `MEM_STOR;
            ex_mem_in_delay_slot        <= id_ex_in_delay_slot;
            ex_mem_pc_address           <= id_ex_pc_address;
            ex_mem_mem_address          <= ex_result;
            ex_mem_wb_reg_dest          <= id_ex_wb_reg_dest;
            ex_mem_wb_reg_en            <= id_ex_wb_reg_en;
            ex_mem_branch_link          <= id_ex_is_branch_link;
            ex_mem_is_inst              <= id_ex_is_inst;
            ex_mem_is_branch            <= id_ex_is_branch;
        end
    end

    always_ff @(posedge clk) begin
        if(rst || (!ex_mem_en && mem_wb_en) || flush) begin
            ex_mem_pc_address_slave <= 32'd0;
            ex_mem_result_slave     <= 32'd0;
            ex_mem_wb_reg_dest_slave<= 5'd0;
            ex_mem_wb_reg_en_slave  <= 1'd0;
            ex_mem_overflow_slave   <= 1'd0;
        end
        else if(ex_mem_en) begin
            ex_mem_pc_address_slave <= id_ex_pc_address_slave;
            ex_mem_result_slave     <= ex_result_slave;
            ex_mem_wb_reg_dest_slave<= id_ex_wb_reg_dest_slave;
            ex_mem_wb_reg_en_slave  <= id_ex_wb_reg_en_slave;
            ex_mem_overflow_slave   <= ex_exp_overflow_slave;
        end
    end 


    memory memory_0(
        .clk                        (clk),
        .rst                        (rst),
        .address                    (ex_mem_mem_address),
        .rt_value                   (ex_mem_rt_value),
        .mem_type                   (ex_mem_type),
        .mem_size                   (ex_mem_size),
        .mem_signed                 (ex_mem_unsigned_flag),
        .mem_en                     (data_en),
        .mem_wen                    (data_wen),
        .mem_addr                   (data_addr),
        .mem_wdata                  (data_wdata),
        .mem_rdata                  (data_data),
        .result                     (mem_result),
        .address_error              (mem_addr_error)
    );

    exception_alpha exception(
        .clk                        (clk),
        .rst                        (rst),
        .iaddr_alignment_error      (|ex_mem_pc_address[1:0]),
        .daddr_alignment_error      (mem_addr_error),
        .invalid_instruction        (ex_mem_invalid_instruction),
        .priv_instruction           (1'b0),
        .syscall                    (ex_mem_syscall),
        .break_                     (ex_mem_break),
        .eret                       (ex_mem_eret),
        .overflow                   (ex_mem_overflow),
        .mem_wen                    (ex_mem_wen),
        .is_branch_instruction      (ex_mem_is_branch),
        .is_branch_slot             (ex_mem_in_delay_slot),
        .pc_address                 (ex_mem_pc_address),
        .mem_address                (data_addr),
        .epc_address                (mem_cp0_epc_address),
        .allow_interrupt            (mem_cp0_allow_interrupt),
        .interrupt_flag             (mem_cp0_interrupt_flag),
        .is_inst                    (ex_mem_is_inst),
        .slave_exp_undefined_inst   (1'b0),
        .slave_exp_overflow         (ex_exp_overflow_slave),
        .exp_detect                 (flush),
        .cp0_exp_en                 (mem_cp0_exp_en),
        .cp0_exl_clean              (mem_cp0_exl_clean),
        .cp0_exp_epc                (mem_cp0_exp_epc),
        .cp0_exp_code               (mem_cp0_exp_code),
        .cp0_exp_bad_vaddr          (mem_cp0_exp_badvaddr),
        .cp0_exp_bad_vaddr_wen      (mem_cp0_exp_badvaddr_en),
        .exp_pc_address             (mem_exception_address),
        .cp0_exp_bd                 (mem_cp0_exp_bd)
    );

    cp0 coprocessor(
        .clk                    (clk),
        .rst                    (rst),
        .hint                   (interrupt),
        .raddr                  (ex_cop0_addr),
        .rdata                  (ex_cop0_data),
        .wen                    (ex_mem_cp0_wen),
        .waddr                  (ex_mem_cp0_waddr),
        .wdata                  (ex_mem_cp0_wdata),
        .exp_en                 (mem_cp0_exp_en,
        .exp_badvaddr_en        (mem_cp0_exp_badvaddr_en),
        .exp_badvaddr           (mem_cp0_exp_badvaddr),
        .exp_bd                 (mem_cp0_exp_bd),
        .exp_code               (mem_cp0_exp_code),
        .exp_epc                (mem_cp0_exp_epc),
        .exl_clean              (mem_cp0_exl_clean),
        .epc_address            (mem_cp0_epc_address),
        .allow_interrupt        (mem_cp0_allow_interrupt),
        .interrupt_flag         (mem_cp0_interrupt_flag)
    );

    always_ff @(posedge clk) begin
        if(rst || !mem_wb_en || flush) begin
            mem_wb_result <= 32'd0;
            mem_wb_pc_address <= 32'd0;
            mem_wb_reg_dest <= 5'd0;
            mem_wb_reg_write_en <= 1'd0;
            mem_wb_branch_link <= 1'd0;
        end
        else begin
            mem_wb_result <= mem_result;
            mem_wb_pc_address <= ex_mem_pc_address;
            mem_wb_reg_dest <= ex_mem_wb_reg_dest;
            mem_wb_reg_write_en <= ex_mem_wb_reg_en;
            mem_wb_branch_link <= ex_mem_branch_link;
        end
    end

    always_ff @(posedge clk) begin
        if(rst || !mem_wb_en || flush) begin
            mem_wb_result_slave <= 32'd0;
            mem_wb_pc_address_slave <= 32'd0;
            mem_wb_reg_dest_slave <= 5'd0;
            mem_wb_reg_en_slave <= 1'd0;
        end
        else begin
            mem_wb_result_slave <= ex_mem_result_slave;
            mem_wb_pc_address_slave <= ex_mem_pc_address_slave;
            mem_wb_reg_dest_slave <= ex_mem_wb_reg_dest_slave;
            mem_wb_reg_en_slave <= ex_mem_wb_reg_en_slave;
        end
    end

    writeback_alpha writeback_0(
        .clk                    (clk),
        .rst                    (rst),
        .result                 (mem_wb_result),
        .pc_address             (mem_wb_pc_address),
        .reg_dest               (mem_wb_reg_dest),
        .write_en               (mem_wb_reg_write_en),
        .branch_link            (mem_wb_branch_link),
        .reg_write_en           (wb_reg_write_en),
        .reg_write_dest         (wb_reg_write_dest),
        .reg_write_data         (wb_reg_write_data)
    );

    writeback_beta writeback_1(
        .result                 (mem_wb_result_slave),
        .reg_dest               (mem_wb_reg_dest_slave),
        .write_en               (mem_wb_reg_en_slave),
        .reg_write_en           (wb_reg_write_en_slave),
        .reg_write_dest         (wb_reg_write_dest_slave),
        .reg_write_data         (wb_reg_write_data_slave)
    );

endmodule