module mmu_map_top(
    input                       clk,
    input                       rst,

    input                       tlbwi,
    input                       tlbwr,
    input                       tlbp,

    input [31:0]                iaddr,
    input                       inst_en,
    output logic [31:0]         iaddr_psy,
    output logic                inst_uncached,
    output logic                inst_miss,
    output logic                inst_illegal,
    output logic                inst_tlb_invalid,

    input [31:0]                iaddr_1,
    input                       inst_en_1,
    output logic [31:0]         iaddr_psy_1,
    output logic                inst_uncached_1,
    output logic                inst_miss_1,
    output logic                inst_illegal_1,
    output logic                inst_tlb_invalid_1,

    input [31:0]                iaddr_2,
    input                       inst_en_2,
    output logic [31:0]         iaddr_psy_2,
    output logic                inst_uncached_2,
    output logic                inst_miss_2,
    output logic                inst_illegal_2,
    output logic                inst_tlb_invalid_2,

    input [31:0]                daddr,
    input                       data_en,
    output logic [31:0]         daddr_psy,
    output logic                data_uncached,
    output logic                data_miss,
    output logic                data_illegal,
    output logic                data_tlb_invalid,
    output logic                data_dirty,

    output logic                miss_probe,
    output logic [3:0]          matched_index_probe,

    // From/to CP0
    input                       user_mode,
    input                       cp0_kseg0_uncached,
    input [7:0]                 curr_ASID,
    input [3:0]                 cp0_index,
    input [3:0]                 cp0_random,
    input [85:0]                cp0_tlb_conf_in,
    output logic [85:0]         cp0_tlb_conf_out
);


    wire [31:0] ipaddr_direct;
    wire [31:0] ipaddr_direct_1;
    wire [31:0] ipaddr_direct_2;
    wire [31:0] dpaddr_direct;
    wire [31:0] ipaddr_tlb;
    wire [31:0] ipaddr_tlb_1;
    wire [31:0] ipaddr_tlb_2;
    wire [31:0] dpaddr_tlb;

    wire iaddr_uncached_direct;
    wire iaddr_uncached_direct_1;
    wire iaddr_uncached_direct_2;
    wire daddr_uncached_direct;

    wire iaddr_in_tlb;
    wire iaddr_in_tlb_1;
    wire iaddr_in_tlb_2;
    wire daddr_in_tlb;

    logic                miss_inst;
    logic                valid_inst;
    logic                uncached_inst;
    logic                miss_inst_1;
    logic                valid_inst_1;
    logic                uncached_inst_1;
    logic                miss_inst_2;
    logic                valid_inst_2;
    logic                uncached_inst_2;

    logic                miss_data;
    logic                valid_data;
    logic                dirty_data;
    logic                uncached_data;

    assign iaddr_psy            = iaddr_in_tlb ? ipaddr_tlb : ipaddr_direct;
    assign inst_uncached        = iaddr_in_tlb ? uncached_inst : iaddr_uncached_direct;
    assign inst_miss            = iaddr_in_tlb && miss_inst;
    assign inst_tlb_invalid     = iaddr_in_tlb && ~valid_inst;
    assign iaddr_psy_1          = iaddr_in_tlb_1 ? ipaddr_tlb_1 : ipaddr_direct_1;
    assign inst_uncached_1      = iaddr_in_tlb_1 ? uncached_inst_1 : iaddr_uncached_direct_1;
    assign inst_miss_1          = iaddr_in_tlb_1 && miss_inst_1;
    assign inst_tlb_invalid_1   = iaddr_in_tlb_1 && ~valid_inst_1;
    assign iaddr_psy_2          = iaddr_in_tlb_2 ? ipaddr_tlb_2 : ipaddr_direct_2;
    assign inst_uncached_2      = iaddr_in_tlb_2 ? uncached_inst_2 : iaddr_uncached_direct_2;
    assign inst_miss_2          = iaddr_in_tlb_2 && miss_inst_2;
    assign inst_tlb_invalid_2   = iaddr_in_tlb_2 && ~valid_inst_2;

    assign daddr_psy        = daddr_in_tlb ? dpaddr_tlb : dpaddr_direct;
    assign data_uncached    = daddr_in_tlb ? uncached_data : daddr_uncached_direct;
    assign data_miss        = daddr_in_tlb && miss_data;
    assign data_tlb_invalid = daddr_in_tlb && ~valid_data;
    assign data_dirty       = ~daddr_in_tlb || dirty_data;

    mmu_map mmu_map_inst(
        .clk                    (clk),
        .rst                    (rst),
        .en                     (inst_en),
        .vaddr                  (iaddr),
        .user_mode              (user_mode),
        .cp0_kseg0_uncached     (cp0_kseg0_uncached),
        .paddr                  (ipaddr_direct),
        .addr_invalid           (inst_illegal),
        .addr_uncached          (iaddr_uncached_direct),
        .addr_in_tlb            (iaddr_in_tlb)
    );

    mmu_map mmu_map_inst_1(
        .clk                    (clk),
        .rst                    (rst),
        .en                     (inst_en_1),
        .vaddr                  (iaddr_1),
        .user_mode              (user_mode),
        .cp0_kseg0_uncached     (cp0_kseg0_uncached),
        .paddr                  (ipaddr_direct_1),
        .addr_invalid           (inst_illegal_1),
        .addr_uncached          (iaddr_uncached_direct_1),
        .addr_in_tlb            (iaddr_in_tlb_1)
    );

    mmu_map mmu_map_inst_2(
        .clk                    (clk),
        .rst                    (rst),
        .en                     (inst_en_2),
        .vaddr                  (iaddr_2),
        .user_mode              (user_mode),
        .cp0_kseg0_uncached     (cp0_kseg0_uncached),
        .paddr                  (ipaddr_direct_2),
        .addr_invalid           (inst_illegal_2),
        .addr_uncached          (iaddr_uncached_direct_2),
        .addr_in_tlb            (iaddr_in_tlb_2)
    );

    mmu_map mmu_map_data(
        .clk                    (clk),
        .rst                    (rst),
        .en                     (data_en),
        .vaddr                  (daddr),
        .user_mode              (user_mode),
        .cp0_kseg0_uncached     (cp0_kseg0_uncached),
        .paddr                  (dpaddr_direct),
        .addr_invalid           (data_illegal),
        .addr_uncached          (daddr_uncached_direct),
        .addr_in_tlb            (daddr_in_tlb)
    );

    tlb_top tlb(
        .clk                    (clk),
        .rst                    (rst),
        .tlbwi                  (tlbwi),
        .tlbwr                  (tlbwr),
        .tlbp                   (tlbp),
        .curr_ASID              (curr_ASID),
        .vaddr_inst             (iaddr),
        .paddr_inst             (ipaddr_tlb),
        .miss_inst              (miss_inst),
        .valid_inst             (valid_inst),
        .uncached_inst          (uncached_inst),
        .vaddr_inst_1           (iaddr_1),
        .paddr_inst_1           (ipaddr_tlb_1),
        .miss_inst_1            (miss_inst_1),
        .valid_inst_1           (valid_inst_1),
        .uncached_inst_1        (uncached_inst_1),
        .vaddr_inst_2           (iaddr_2),
        .paddr_inst_2           (ipaddr_tlb_2),
        .miss_inst_2            (miss_inst_2),
        .valid_inst_2           (valid_inst_2),
        .uncached_inst_2        (uncached_inst_2),
        .vaddr_data             (daddr),
        .paddr_data             (dpaddr_tlb),
        .miss_data              (miss_data),
        .valid_data             (valid_data),
        .dirty_data             (dirty_data),
        .uncached_data          (uncached_data),
        .miss_probe             (miss_probe),
        .matched_index_probe    (matched_index_probe),
        .cp0_index              (cp0_index),
        .cp0_random             (cp0_random),
        .cp0_tlb_conf_in        (cp0_tlb_conf_in),
        .cp0_tlb_conf_out       (cp0_tlb_conf_out)
    );

endmodule