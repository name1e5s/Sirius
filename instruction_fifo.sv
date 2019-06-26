`timescale 1ns / 1ps

module instruction_fifo(
        input                       clk,
        input                       rst,
        input                       rst_with_delay,

        // Read inputs
        input                       read_en1,
        input                       read_en2,

        // Write inputs
        input                       write_en1,
        input                       write_en2,
        input [31:0]                write_data1,
        input [31:0]                write_address1,
        input [31:0]                write_data2,
        input [31:0]                write_address2,

        // Read outputs
        output logic [31:0]         data_out1,
        output logic [31:0]         data_out2,
        output logic [31:0]         address_out1,
        output logic [31:0]         address_out2,
        output logic                delay_slot_out1,
        output logic                empty,
        output logic                almost_empty,
        output logic                full
);

    // Reset status
    reg         in_delay_slot;
    reg [31:0]  delayed_data;
    reg [31:0]  delayed_pc;
    // Store data here
    reg [31:0]  data[0:15];
    reg [31:0]  address[0:15];

    // Internal variables
    reg [3:0] write_pointer;
    reg [3:0] read_pointer;
    reg [3:0] data_count;

    // Status monitor
    assign full     = &data_count[3:1];
    assign empty    = (data_count == 4'd0);
    assign almost_empty = (data_count == 4'd1);

    // Output data
    wire [31:0] _data_out1 = data[read_pointer];
    wire [31:0] _data_out2 = data[read_pointer + 4'd1];
    wire [31:0] _address_out1 = address[read_pointer];
    wire [31:0] _address_out2 = address[read_pointer + 4'd1];

    always_comb begin : select_output
        if(in_delay_slot) begin
            data_out1       = delayed_data;
            data_out2       = 32'd0;
            address_out1    = delayed_pc;
            address_out2    = 32'd0;
            delay_slot_out1 = 1'd1;
        end
        else if(empty) begin
            data_out1       = 32'd0;
            data_out2       = 32'd0;
            address_out1    = 32'd0;
            address_out2    = 32'd0;
            delay_slot_out1 = 1'd0;
        end
        else if(almost_empty) begin
            data_out1       = _data_out1;
            data_out2       = 32'd0;
            address_out1    = _address_out1;
            address_out2    = 32'd0;
            delay_slot_out1 = 1'd0;
        end 
        else begin
            data_out1       = _data_out1;
            data_out2       = _data_out2;
            address_out1    = _address_out1;
            address_out2    = _address_out2;
            delay_slot_out1 = 1'd0;
        end
    end

    always_ff @(posedge clk) begin : update_delayed
        if(rst && rst_with_delay) begin
            in_delay_slot   <= 1'd1;
            delayed_data    <= read_pointer + 4'd1 == write_pointer? write_data1 : data[read_pointer + 4'd1];;
            delayed_pc      <= read_pointer + 4'd1 == write_pointer? write_address1 : address[read_pointer + 4'd1];;
        end
        else begin
            in_delay_slot   <= 1'd0;
            delayed_data    <= 32'd0;
            delayed_pc      <= 32'd0;
        end
    end

    always_ff @(posedge clk) begin : update_write_pointer
        if(rst)
            write_pointer <= 4'd0;
        else if(write_en1 && write_en2)
            write_pointer <= write_pointer + 4'd2;
        else if(write_en1)
            write_pointer <= write_pointer + 4'd1;
    end

    always_ff @(posedge clk) begin : update_read_pointer
        if(rst)
            read_pointer <= 4'd0;
        else if(empty)
            read_pointer <= read_pointer;
        else if(read_en1 && read_en2)
            read_pointer <= read_pointer + 4'd2;
        else if(read_en1)
            read_pointer <= read_pointer + 4'd1;
    end

    always_ff @(posedge clk) begin : update_counter
        if(rst)
            data_count <= 4'd0;
        else if((write_en1 && (!write_en2) && (((!read_en1) && (!read_en2)) || empty)) ||
                (write_en1 && write_en2 && (read_en1 && (!read_en2))))
            data_count <= data_count + 4'd1;
        else if(write_en1 && write_en2 && (((!read_en1) && (!read_en2)) || empty))
            data_count <= data_count + 4'd2;
        else if(((read_en1 && (!read_en1) && (!write_en1) && (!write_en2)) ||
                (read_en1 && read_en2 && (write_en1) && (!write_en2))) && (!empty))
            data_count <= data_count - 4'd1;
        else if((read_en1 && read_en2 && (!write_en1) && (!write_en2)) && (!empty))
            data_count <= data_count - 4'd2;
    end

    always_ff @(posedge clk) begin : write_data 
        if(write_en1) begin
            data[write_pointer] <= write_data1;
            address[write_pointer] <= write_address1;
        end
        if(write_en2) begin
            data[write_pointer + 4'd1] <= write_data2;
            address[write_pointer + 4'd1] <= write_address2;
        end
    end
    
endmodule