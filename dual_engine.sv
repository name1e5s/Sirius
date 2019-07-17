`timescale 1ns / 1ps
`include "common.vh"

// Dual issue detect engine.
module dual_engine(
        // Infomation about master pipeline
        input                   id_priv_inst_master,
        input  [4:0]            id_wb_reg_dest_master,
        input                   id_wb_reg_en_master,
        input                   id_is_hilo_accessed_master,

        // For load-use stall detection...
        input [1:0]             id_ex_mem_type,
        input [4:0]             id_ex_mem_wb_reg_dest,

        // Infomation about slave pipeline
        input  [5:0]            id_opcode_slave,
        input  [4:0]            id_rs_slave,
        input  [4:0]            id_rt_slave,
        input  [1:0]            id_mem_type_slave,
        input                   id_is_branch_instr_slave,
        input                   id_priv_inst_slave,
        input                   id_is_hilo_accessed_slave,

        // Info about FIFO
        input                   fifo_empty,
        input                   fifo_almost_empty,

        input                   enable_master,
        output logic            enable_slave
);

    wire fifo = ~(fifo_empty || fifo_almost_empty);
    logic load_use_stall_slave;
    always_comb begin : check_slave_enable
        if((!enable_master) || (id_priv_inst_master) || 
            (id_priv_inst_slave) || (|id_mem_type_slave) ||
            id_is_branch_instr_slave || id_is_hilo_accessed_master || id_is_hilo_accessed_slave)
            enable_slave = 1'b0;
        else begin
            if(id_wb_reg_en_master) begin
                if(id_opcode_slave == 5'd0) begin
                    enable_slave = (~(|id_wb_reg_dest_master)) && (~((id_wb_reg_dest_master == id_rs_slave) || 
                                      (id_wb_reg_dest_master == id_rt_slave))) && fifo && (~load_use_stall_slave);
                end
                else begin
                    enable_slave =  (~(|id_wb_reg_dest_master)) && (~(id_wb_reg_dest_master == id_rs_slave)) && fifo && (~load_use_stall_slave);
                end 
            end
            else begin
                enable_slave = fifo && (~load_use_stall_slave);
            end
        end 
    end

    always_comb begin
        if(id_ex_mem_type == `MEM_LOAD && ((id_ex_mem_wb_reg_dest == id_rs_slave) ||
                (id_ex_mem_wb_reg_dest == id_rt_slave)))
            load_use_stall_slave = 1'd1;
        else  
            load_use_stall_slave = 1'd0;
    end
endmodule