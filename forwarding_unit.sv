`timescale 1ns / 1ps

module forwarding_unit(
    input                   slave_ex_reg_en,
    input [ 4:0]            slave_ex_addr,
    input [31:0]            slave_ex_data,
    input                   master_ex_reg_en,
    input [ 4:0]            master_ex_addr,
    input [31:0]            master_ex_data,
    input                   slave_mem_reg_en,
    input [ 4:0]            slave_mem_addr,
    input [31:0]            slave_mem_data,
    input                   master_mem_reg_en,
    input [ 4:0]            master_mem_addr,
    input [31:0]            master_mem_data,
    input [ 4:0]            reg_addr,
    input [31:0]            reg_data,
    output logic [31:0]     result_data
);

    always_comb begin : get_result
        if(reg_addr != 32'd0) begin
            if(slave_ex_reg_en && slave_ex_addr == reg_addr)
                result_data = slave_ex_data;
            else if(master_ex_reg_en && master_ex_addr == reg_addr)
                result_data = master_ex_data;
            else if(slave_mem_reg_en && slave_mem_addr == reg_addr)
                result_data = slave_mem_data;
            else if(master_mem_reg_en && master_mem_addr == reg_addr)
                result_data = master_mem_data;
            else
                result_data = reg_data;
        end
        else begin
            result_data = 32'd0;
        end
    end

endmodule