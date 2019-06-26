`timescale 1ns / 1ps

// The instruction cache.
// Format:
// | Tag[18:0] | data... 64Bytes | * 128
// Address format:
// addr[31:13] as Tag
// addr[12:6] as Index
// addr[5:2] as Offset
// addr[1:0] is unused in i$

module icache(
        input                       clk,
        input                       rst,

        input                       enable,
        input [31:0]                addr_psy,

        output logic [31:0]         data,
        output logic [31:0]         data2,
        output logic                data_ok,
        output logic                data1_ok,
        output logic                data2_ok,

        output logic [31:0]         addr_req,
        output logic                read_req,
        input                       req_ok,
        input  [31:0]               read_data,
        input                       read_valid,
        input                       read_last
);

    enum logic [1:0] { IDLE = 2'b00,
                       SHAK = 2'b01,
                       RFIL = 2'b10 } cstate, nstate;

    wire  [18:0] current_tag    = addr_psy[31:13];
    wire  [ 6:0] current_index  = addr_psy[12:6];
    wire  [ 3:0] current_offset = addr_psy[5:2];

    logic [31:0] pending_address;
    wire  [18:0] pending_tag    = pending_address[31:13];
    wire  [ 6:0] pending_index  = pending_address[12:6];
    wire  [ 3:0] pending_offset = pending_address[5:2];
    logic [ 3:0] pending_counter;
    
    logic [127:0] valid_bit;
    logic [ 18:0] tag[0:127];

    logic [10:0]    read_address1, read_address2;
    logic [31:0]    write_data;
    logic           we;
    logic [31:0]    read_data1, read_data2;

    always_ff @(posedge clk) begin
        if(rst)
            cstate <= IDLE;
        else
            cstate <= nstate;
    end

    always_ff @(posedge clk) begin
        if(rst)
            valid_bit <= 128'd0;
        else if(cstate == RFIL && read_valid && read_last)
            valid_bit[pending_index] <= 1'b1;
    end

    always_ff @(posedge clk) begin
        if(cstate == RFIL && read_valid && read_last)
            tag[pending_index] <= pending_tag;
    end

    always_ff @(posedge clk) begin
        if(cstate == RFIL && read_valid)
            pending_counter <= pending_counter + 4'b1;
        else if(cstate != RFIL)
            pending_counter <= 4'd0;
    end

    always_ff @(posedge clk) begin
        if(cstate == IDLE && nstate != IDLE) begin // CACHE MISS
            pending_address <= addr_psy;
        end
    end

    always_comb begin
        addr_req    = 32'd0;
        read_req    = 1'd0;
        nstate      = IDLE;
        data        = read_data1;
        data2       = read_data2;
        data_ok     = 1'd0;
        data1_ok    = 1'd0;
        data2_ok    = 1'd0;
        write_data  = read_data;
        we          = 1'd0;
        read_address1 = {current_index, current_offset};
        read_address2 = read_address1 + 11'd1;
        case(cstate)
            IDLE: begin
                if(!enable || (current_tag == tag[current_index] && valid_bit[current_index])) begin
                    nstate  = IDLE;
                    data    = read_data1;
                    data2   = read_data2;
                    data_ok = 1'd1; // OK
                    data1_ok= 1'd1;
                    data2_ok= ~(&current_offset);
                end else begin
                    data    = 32'd0;
                    data2   = 32'd0;
                    data_ok = 1'd0;
                    data1_ok= 1'd0;
                    data2_ok= 1'd0;
                    // Generate MMU signals
                    addr_req = {current_tag, current_index, 6'd0};
                    read_req = 1'd1;
                    if(req_ok) // hand shake ok
                        nstate = RFIL;
                    else
                        nstate = SHAK;
                end
            end
            SHAK: begin
                addr_req = {pending_tag, pending_index, 6'd0};
                read_req = 1'd1;
                if(req_ok) // hand shake ok
                    nstate = RFIL;
                else
                    nstate = SHAK;
            end
            RFIL: begin
                we = read_valid;
                if(read_last) begin
                    nstate = IDLE;
                end
                else begin
                    nstate = SHAK;
                end
            end
            default: begin
            end
        endcase
    end

    icache_dual_ram ram(
        .clk                    (clk),
        .a                      (read_address1),
        .dpra                   (read_address2),
        .d                      (write_data),
        .spo                    (read_data1),
        .dpo                    (read_data2),
        .we                     (we)
    );

endmodule