`timescale 1ns/1ps

module pc(
        input                   clk,
        input                   rst,
        input                   pc_en,
        input                   inst_ok_1,
        input                   inst_ok_2,
        input                   fifo_full,

        input                   branch_taken,
        input [31:0]            branch_address,
        input                   exception_taken,
        input [31:0]            exception_address,

        output logic [31:0]     pc_address
);

    reg     [31:0] real_pc_address;
    logic   [31:0] pc_address_next;
    
    assign pc_address = real_pc_address;

    always_comb begin : compute_next_pc_address
        if(rst)
            pc_address_next = 32'hbfc0_0000; // Initial valud
        else if(pc_en) begin
            if(exception_taken)
                pc_address_next = exception_address;
            else if(branch_taken)
                pc_address_next = branch_address;
            else if(fifo_full)
                pc_address_next = pc_address;
            else if(inst_ok_1 && inst_ok_2)
                pc_address_next = pc_address + 32'd8;
            else if(inst_ok_1)
                pc_address_next = pc_address + 32'd4;
            else
                pc_address_next = pc_address;
        end
        else begin
            pc_address_next = pc_address; 
        end
    end

    always_ff @(posedge clk) begin
        real_pc_address <= pc_address_next;
    end
    
endmodule