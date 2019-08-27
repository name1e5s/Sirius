`timescale 1ns / 1ps
// A simple divider module.
// Takes 34 cycles to get result.
// DIVIDEND \div DIVISOR = QOUTIENT ...... REMAINDER
module divider(
        input                       clk,
        input                       rst,

        input [ 1:0]                div_op,
        input [31:0]                divisor,
        input [31:0]                dividend,

        output [63:0]               result,
        output                      done
);
    logic [5:0]      counter;
    logic [31:0]     _divisor, _dividend;
    logic            sign;
    logic            dividend_sign;

    reg [63:0]       _result;
   
    wire [31:0]      quotient    = sign? (~_result[63:32] + 32'd1) :  _result[63:32];
    wire [31:0]      remainder   = dividend_sign? (~_result[31:0] + 32'd1) : _result[31:0];

    assign done     = counter == 6'd0;
    assign result   = { remainder, quotient };

    always_ff @(posedge clk) begin : get_operands
        if(rst) begin
            counter <= 6'd0;
            _divisor <= 32'd0;
            _dividend <= 32'd0;
            sign <= 1'b0;
        end
        else begin
            if(!done)
                counter <= counter - 1;
            else begin
                if(div_op == 2'b10) begin
                    sign            <= divisor[31] ^ dividend[31];
                    _divisor        <= divisor[31]? ~divisor + 1 : divisor;
                    _dividend       <= dividend[31]? ~dividend + 1 : dividend;
                    dividend_sign   <= dividend[31];
                    counter         <= 6'd34;
                end
                else if(div_op == 2'b01) begin
                    sign            <= 1'b0;
                    _divisor        <= divisor;
                    _dividend       <= dividend;
                    dividend_sign   <= 1'b0;
                    counter         <= 6'd34;
                end
                else begin
                end
            end
        end
    end

    div_gen_0 div(
        .aclk                   (clk),
        .s_axis_divisor_tdata   (_divisor),
        .s_axis_divisor_tvalid  (1'd1),
        .s_axis_dividend_tdata  (_dividend),
        .s_axis_dividend_tvalid (1'd1),
        .m_axis_dout_tdata      (_result)
    );

endmodule
