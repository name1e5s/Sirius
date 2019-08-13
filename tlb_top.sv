module tlb_top(
    input                       clk,
    input                       rst,

    input                       tlbwi,
    input                       tlbwr,
    input                       tlbp,

    input [7:0]                 curr_ASID,

    input [31:0]                vaddr_inst,
    output logic [31:0]         paddr_inst,
    output logic                miss_inst,
    output logic                valid_inst,
    output logic                uncached_inst,

    input [31:0]                vaddr_inst_1,
    output logic [31:0]         paddr_inst_1,
    output logic                miss_inst_1,
    output logic                valid_inst_1,
    output logic                uncached_inst_1,

    input [31:0]                vaddr_inst_2,
    output logic [31:0]         paddr_inst_2,
    output logic                miss_inst_2,
    output logic                valid_inst_2,
    output logic                uncached_inst_2,

    input [31:0]                vaddr_inst_3,
    output logic [31:0]         paddr_inst_3,
    output logic                miss_inst_3,
    output logic                valid_inst_3,
    output logic                uncached_inst_3,

    input [31:0]                vaddr_data,
    output logic [31:0]         paddr_data,
    output logic                miss_data,
    output logic                valid_data,
    output logic                dirty_data,
    output logic                uncached_data,

    output logic                miss_probe,
    output logic [2:0]          matched_index_probe,

    // Connects to CP0
    input [2:0]                 cp0_index,
    input [2:0]                 cp0_random,
    input [85:0]                cp0_tlb_conf_in,
    output logic [85:0]         cp0_tlb_conf_out
);

    tlb_common tlb_inst(
        .clk                (clk),
        .rst                (rst),
        .tlbwi              (tlbwi),
        .tlbwr              (tlbwr),
        .curr_ASID          (curr_ASID),
        .vaddr              (vaddr_inst),
        .paddr              (paddr_inst),
        .miss               (miss_inst),
        .valid              (valid_inst),
        .uncached           (uncached_inst),
        .cp0_index          (cp0_index), 
        .cp0_random         (cp0_random),
        .cp0_tlb_conf_in    (cp0_tlb_conf_in),
        .cp0_tlb_conf_out   (cp0_tlb_conf_out)
    );

    tlb_common tlb_inst_1(
        .clk                (clk),
        .rst                (rst),
        .tlbwi              (tlbwi),
        .tlbwr              (tlbwr),
        .curr_ASID          (curr_ASID),
        .vaddr              (vaddr_inst_1),
        .paddr              (paddr_inst_1),
        .miss               (miss_inst_1),
        .valid              (valid_inst_1),
        .uncached           (uncached_inst_1),
        .cp0_index          (cp0_index), 
        .cp0_random         (cp0_random),
        .cp0_tlb_conf_in    (cp0_tlb_conf_in)
    );

    tlb_common tlb_inst_2(
        .clk                (clk),
        .rst                (rst),
        .tlbwi              (tlbwi),
        .tlbwr              (tlbwr),
        .curr_ASID          (curr_ASID),
        .vaddr              (vaddr_inst_2),
        .paddr              (paddr_inst_2),
        .miss               (miss_inst_2),
        .valid              (valid_inst_2),
        .uncached           (uncached_inst_2),
        .cp0_index          (cp0_index), 
        .cp0_random         (cp0_random),
        .cp0_tlb_conf_in    (cp0_tlb_conf_in)
    );

    tlb_common tlb_inst_3(
        .clk                (clk),
        .rst                (rst),
        .tlbwi              (tlbwi),
        .tlbwr              (tlbwr),
        .curr_ASID          (curr_ASID),
        .vaddr              (vaddr_inst_3),
        .paddr              (paddr_inst_3),
        .miss               (miss_inst_3),
        .valid              (valid_inst_3),
        .uncached           (uncached_inst_3),
        .cp0_index          (cp0_index), 
        .cp0_random         (cp0_random),
        .cp0_tlb_conf_in    (cp0_tlb_conf_in)
    );

    tlb_common tlb_data(
        .clk                (clk),
        .rst                (rst),
        .tlbwi              (tlbwi),
        .tlbwr              (tlbwr),
        .curr_ASID          (curr_ASID),
        .vaddr              (vaddr_data),
        .paddr              (paddr_data),
        .miss               (miss_data),
        .valid              (valid_data),
        .dirty              (dirty_data),
        .uncached           (uncached_data),
        .cp0_index          (cp0_index), 
        .cp0_random         (cp0_random),
        .cp0_tlb_conf_in    (cp0_tlb_conf_in)
    );

    tlb_common tlb_probe(
        .clk                (clk),
        .rst                (rst),
        .tlbwi              (tlbwi),
        .tlbwr              (tlbwr),
        .curr_ASID          (curr_ASID),
        .vaddr              ({cp0_tlb_conf_in[85:67],13'd0}),
        .miss               (miss_probe),
        .matched_index      (matched_index_probe),
        .cp0_index          (cp0_index),
        .cp0_random         (cp0_random),
        .cp0_tlb_conf_in    (cp0_tlb_conf_in)
    );

endmodule