`timescale 1ns / 1ps
// A four-stage pipeline multiplier.
// However, pipeline feature is disabled in
// our design.
// OP: 10 as signed operation
//     01 as unsigned operation
//     00 as invalid.
module multplier(
        input                       clk,
        input                       rst,

		input [ 1:0]                op,
		input [31:0]                a,
		input [31:0]                b,
		output logic [63:0]         c,
		output logic                done
        );

    reg [31:0]   _a, _b;
    reg [63:0]   _c;
    reg          sign;
    reg [2:0]    counter;

    assign c    = sign? -_c : _c;
    assign done = counter == 3'b000;

    // Unsigned multplier IP core from xilinx, configured with pipeline stages as 4.
    mult_gen_0 mult(
        .CLK    (clk),
        .SCLR   (rst),
        .A      (_a),
        .B      (_b),
        .P      (_c)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            _a <= 32'd0;
            _b <= 32'd0;
            counter <= 3'd0;
            sign <= 1'b0;
        end
        else begin
            if(!done) begin
                counter <= counter - 1;
            end
            else if(op == 2'b01) begin
                sign <= 0;
                _a <= a;
                _b <= b;
                counter <= 3'd4;
            end
            else if(op == 2'b10) begin
                sign <= a[31] ^ b[31];
                _a <= a[31]? ~a + 1 : a;
                _b <= b[31]? ~b + 1 : b;
                counter <= 3'd4;
            end
            else begin
            end
        end
    end

endmodule
