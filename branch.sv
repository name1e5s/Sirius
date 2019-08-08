`include "common.vh"
// Branch unit in ex stage.
module branch(
        input                       en,
        input [31:0]                pc_address,
        input [31:0]                instruction,
        input                       is_branch_instr,
        input [2:0]                 branch_type,

        input [31:0]                data_rs,
        input [31:0]                data_rt,

        output logic                branch_taken,
        output logic [31:0]         branch_address
);

   reg [31:0] next_pc;
   reg [31:0] branch_immed;

    always_comb begin : get_target
        next_pc = pc_address + 32'd4;
        branch_immed = pc_address + 32'd4 + {{14{instruction[15]}}, instruction[15:0], 2'b00};
    end

    always_comb begin : take_branch
        branch_address = branch_immed;
        branch_taken = 1'b0;
        if(en && is_branch_instr) begin
            unique case(branch_type)
            `B_EQNE:
                unique case(instruction[27:26])
                2'b00: // BEQ
                    branch_taken = (data_rs == data_rt);
                2'b01: // BNE
                    branch_taken = (data_rs != data_rt);
                2'b10: // BLEZ
                    branch_taken = (data_rs[31] || data_rs==32'b0);
                2'b11: // BGTZ
                    branch_taken = (data_rs[31] == 0 && data_rs);
                default: // Make compiler happy
                    begin
                    end
                endcase
            `B_LTGE:
                unique case(instruction[16])
                1'b0: // BLTZ
                    branch_taken = (data_rs[31] && data_rs);
                1'b1: // BGEZ
                    branch_taken = (data_rs[31] == 0 || data_rs==32'b0);
                default: // Make compiler happy
                    begin
                    end
                endcase
            `B_JUMP: begin
                branch_address = {next_pc[31:28], instruction[25:0], 2'b00};
                branch_taken = 1'b1;
            end
            `B_JREG: begin
                branch_address = data_rs;
                branch_taken = 1'b1;
            end
            default: begin
            end
            endcase
        end
        else begin
        end
    end

endmodule
