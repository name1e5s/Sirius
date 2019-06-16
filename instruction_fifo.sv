`timescale 1ns / 1ps

module instruction_fifo(
        input                       clk,
        input                       rst,

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
        output logic                empty,
        output logic                almost_empty,
        output logic                full
);

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
    assign data_out1 = data[read_pointer];
    assign data_out2 = data[read_pointer + 4'd1];
    assign address_out1 = address[read_pointer];
    assign address_out2 = address[read_pointer + 4'd1];

    always_ff @(posedge clk) begin : update_write_pointer
        if(rst)
            write_pointer <= 4'd0;
        else if(write_en1 && write_en2)
            write_pointer <= write_pointer + 4'd2;
        else if(write_en1)
            write_pointer <= write_pointer + 4'd1;
        else
            write_pointer <= write_pointer;
    end

    always_ff @(posedge clk) begin : update_read_pointer
        if(rst)
            read_pointer <= 4'd0;
        else if(read_en1 && read_en2)
            read_pointer <= read_pointer + 4'd2;
        else if(read_en1)
            read_pointer <= read_pointer + 4'd1;
        else
            read_pointer <= read_pointer;
    end

    always_ff @(posedge clk) begin : update_counter
        if(rst)
            data_count <= 4'd0;
        else if((write_en1 && (!read_en1) && (!read_en2)) &&
                (write_en1 && write_en2 && read_en1 && (!read_en2)))
            data_count <= data_count + 4'd1;
        else if(write_en1 && write_en2 && (!read_en1) && (!read_en2))
            data_count <= data_count + 4'd2;
        else if((read_en1 && (!write_en1) && (!write_en2)) &&
                (read_en1 && read_en2 && (write_en1) && (!write_en2)))
            data_count <= data_count - 4'd1;
        else if(read_en1 && read_en2 && (!write_en1) && (!write_en2))
            data_count <= data_count - 4'd2;
    end

    always_ff @(posedge clk iff rst == 1'd0) begin : write_data 
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