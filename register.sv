`timescale 1ns / 1ps
// The register file.
// Note that when both pipelines try to
// write to the same port, the slave pipeline
// has a higher priority.
module register(
        input                       clk,
        input                       rst,

		input [4:0]					raddr1_a,
		output logic [31:0] 		rdata1_a,

		input [4:0]					raddr1_b,
		output logic [31:0] 		rdata1_b,

		input 						wen1_a,
		input [4:0]					waddr1_a,
		input [31:0]				wdata1_a,

        input [4:0]					raddr2_a,
		output logic [31:0] 		rdata2_a,

		input [4:0]					raddr2_b,
		output logic [31:0] 		rdata2_b,

		input 						wen2_a,
		input [4:0]					waddr2_a,
		input [31:0]				wdata2_a
);

    reg [31:0] _register[0:31];

	always_comb begin : read_data1_a
		if(raddr1_a == 5'b00000)
			rdata1_a = 32'h0000_0000;
        else if(wen2_a && waddr2_a == raddr1_a)
            rdata1_a = wdata2_a;
		else if(wen1_a && waddr1_a == raddr1_a)
			rdata1_a = wdata1_a;
		else
			rdata1_a = _register[raddr1_a];
	end

	always_comb begin : read_data1_b
		if(raddr1_b == 5'b00000)
			rdata1_b = 32'h0000_0000;
        else if(wen2_a && waddr2_a == raddr1_b)
            rdata1_b = wdata2_a;
		else if(wen1_a && waddr1_a == raddr1_b)
			rdata1_b = wdata1_a;
		else
			rdata1_b = _register[raddr1_b];
	end

	always_comb begin : read_data2_a
		if(raddr2_a == 5'b00000)
			rdata2_a = 32'h0000_0000;
        else if(wen2_a && waddr2_a == raddr2_a)
            rdata2_a = wdata2_a;
		else if(wen1_a && waddr1_a == raddr2_a)
			rdata2_a = wdata1_a;
		else
			rdata2_a = _register[raddr2_a];
	end

	always_comb begin : read_data2_b
		if(raddr2_b == 5'b00000)
			rdata2_b = 32'h0000_0000;
        else if(wen2_a && waddr2_a == raddr2_b)
            rdata2_b = wdata2_a;
		else if(wen1_a && waddr1_a == raddr2_b)
			rdata2_b = wdata1_a;
		else
			rdata2_b = _register[raddr2_b];
	end

	always_ff @(posedge clk) begin : write_data
		if(rst) begin
			for(int i = 0; i < 31; i++)
				_register[i] <= 32'h0000_0000;
		end
		else begin
            if(wen1_a && wen2_a && waddr1_a == waddr2_a)
                _register[waddr2_a] <= wdata2_a;
            else begin
                if(wen1_a)
                    _register[waddr1_a] <= wdata1_a;
                if(wen2_a)
                    _register[waddr2_a] <= wdata2_a;
            end
        end
	end
endmodule
