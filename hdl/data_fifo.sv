// FIFO used for UNCACHED MEMORY WRITE...
module data_fifo(
    input                   clk,
    input                   rst,

    // Input channel
    input [2:0]             size_in,
    input [31:0]            addr_in,
    input [31:0]            data_in,
    input [3:0]             dwen_in,

    // Output channel
    output wire  [2:0]      size_out,
    output wire  [31:0]     addr_out,
    output wire  [31:0]     data_out,
    output wire  [3:0]      dwen_out,

    // Control channel
    input                   read_en,
    input                   write_en,

    output logic            full,
    output logic            empty
);

    wire [70:0] din;
    wire [70:0] dout;

    assign din          = { size_in, dwen_in, data_in, addr_in };
    assign { size_out, dwen_out, data_out, addr_out } = dout;

/*
    fifo_generator_0 fifo_generator(
        .clk        (clk),
        .srst       (rst),
        .din        (din),
        .dout       (dout),
        .full       (full),
        .empty      (empty),
        .wr_en      (write_en),
        .rd_en      (read_en)
    );
*/

    // Use registers as fifo... Fuck xilinx
    reg [70:0] _fifo[0:63];

    reg [5:0] read_pointer;
    reg [5:0] write_pointer;

    assign full = read_pointer == (write_pointer + 5'd1);
    assign empty = read_pointer == write_pointer;
    assign dout = _fifo[read_pointer];

    always_ff @(posedge clk) begin
        if(rst) begin
            read_pointer <= 6'd0;
        end
        else if(read_en)
            read_pointer <= read_pointer + 6'd1;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            write_pointer <= 6'd0;
        end
        else if(write_en)
            write_pointer <= write_pointer + 6'd1;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < 64; i++)
                _fifo[i] <= 70'd0;
        end
        else if(write_en)
            _fifo[write_pointer] <= din;
    end
    
endmodule