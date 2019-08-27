module mmu_map(
    input                   clk,
    input                   rst,

    input                   en,
    input [31:0]            vaddr,
    input                   user_mode,
    input                   cp0_kseg0_uncached,

    output logic [31:0]     paddr,
    output logic            addr_invalid,
    output logic            addr_uncached,
    output logic            addr_in_tlb
);

    assign addr_invalid = (en && user_mode && vaddr[31]);

    always_comb begin : get_psy_addr_directly
        paddr = 32'd0;
        addr_uncached = 1'd0;
        addr_in_tlb = 1'd0;
        if (en) begin
            unique case(vaddr[31:29])
                3'b100: begin // kseg0
                    addr_uncached = cp0_kseg0_uncached;
                    paddr = { 3'b0, vaddr[28:0]};
                end
                3'b101: begin // kseg1
                    addr_uncached = 1;
                    paddr = { 3'b0, vaddr[28:0]};
                end
                default: begin // kseg2, kseg3 and kuseg
                    addr_in_tlb = 1'b1;
                end
            endcase
        end
    end
endmodule