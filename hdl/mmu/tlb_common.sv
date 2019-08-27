module tlb_common(
    input                       clk,
    input                       rst,

    input                       tlbwi,
    input                       tlbwr,

    input [7:0]                 curr_ASID,
    input [31:0]                vaddr,
    output logic [31:0]         paddr,

    output logic                miss,
    output logic                valid,
    output logic                dirty,
    output logic                uncached,
    output logic [3:0]          matched_index,

    // Connects to CP0
    input [3:0]                 cp0_index,
    input [3:0]                 cp0_random,
    input [85:0]                cp0_tlb_conf_in,
    output logic [85:0]         cp0_tlb_conf_out
);

    reg [85:0] tlb_data[0:15];
    assign cp0_tlb_conf_out = tlb_data[cp0_index];

    // Cache registers
    // VPN2 19bits      [85:67]
    // G 1bits          66
    // ASID 8bits       [65:58]
    // PFN0 24bits      [57:34]
    // C 3bits          [33:31]
    // D 1bits          30
    // V 1bits          29
    // PFN1 24bits      [28:5]
    // C 3bits          [4:2]
    // D 1bits          1
    // V 1bits          0
    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < 16; i++)
                tlb_data[i] <= 86'd0;
        end
        else if(tlbwi)
            tlb_data[cp0_index] <= cp0_tlb_conf_in;
        else if(tlbwr)
            tlb_data[cp0_random] <= cp0_tlb_conf_in;
    end

    logic [15:0] matched;
    always_comb begin
        for(int i = 0; i < 16; i++)
            matched[i] = (vaddr[31:13] == tlb_data[i][85:67]) && 
                            (tlb_data[i][65:58] == curr_ASID || tlb_data[i][66]);
    end

    always_comb begin
        matched_index = 4'd0;
        for(int i = 0; i < 16; i++) begin
            if(matched[i]) begin
                matched_index = i;
            end
        end
    end

    assign miss     = (matched == 16'd0);
    assign valid    = miss? 1'd1 : (vaddr[12] ? tlb_data[matched_index][0] : tlb_data[matched_index][29]);
    assign dirty    = vaddr[12] ? tlb_data[matched_index][1] : tlb_data[matched_index][30];
    assign uncached = vaddr[12] ? (tlb_data[matched_index][4:2] == 3'd2) : (tlb_data[matched_index][33:31] == 3'd2);
    assign paddr    = vaddr[12] ? {tlb_data[matched_index][24:5], vaddr[11:0]} : {tlb_data[matched_index][53:34],vaddr[11:0]};

endmodule