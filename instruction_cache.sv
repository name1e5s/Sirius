`timescale 1ns / 1ps
// The instruction cache.
// Format:
// | Tag[18:0] | data... 64Bytes | * 128
// Address format:
// addr[31:13] as Tag
// addr[12:6] as Index
// addr[5:2] as Offset
// addr[1:0] is unused in i$

module instruction_cache(
        input                       clk,
        input                       rst,
        
        input                       inst_en,
        input  [31:0]               inst_addr, // Physics address, please
        
        // To CPU
        output logic[31:0]          inst_data,
        output logic                inst_ok,
        
        // To MMU
        output logic[31:0]          inst_addr_mmu,
        output logic                inst_read_req,
        input                       inst_addr_ok,
        input  [31:0]               inst_read_data,
        input                       mmu_valid,
        input                       mmu_last
);
    parameter [1:0] // ICache FSM
        IDLE = 2'b01, // In IDLE state, read from cache is OKAY.
        WIAT = 2'b10, // In WIAT state, the data is transformed into cache.
        COMM = 2'b11; 

    reg [127:0]     icache_valid;
    reg [  1:0]     icache_curr;
    reg [  1:0]     icache_next;

    reg  [31:0]     waiting_address;
    wire [18:0]     waiting_tag     = waiting_address[31:13];
    wire [ 6:0]     waiting_index   = waiting_address[12: 6];
    wire [ 3:0]     waiting_offset  = waiting_address[ 5: 2];

    reg [  3:0]     receive_counter;
    reg [ 31:0]     receive_buffer[0:15];
    
    wire [530:0]    icache_return; // Connect to output channel of ram.
    wire [ 31:0]    icache_return_data[0:15];
    wire [ 18:0]    inst_tag    = inst_addr[31:13];
    wire [  6:0]    inst_index  = inst_addr[12: 6];
    wire [  3:0]    inst_offset = inst_addr[5: 2];
    
    wire [  6:0]    ram_dpra    = inst_index;
    wire [  6:0]    ram_a       = waiting_index;
    wire [530:0]    ram_d;
    logic           ram_we;
    
    wire [18:0]icache_return_tag  = icache_return[18:0];
    assign icache_return_data[0]  = icache_return[50:19];
    assign icache_return_data[1]  = icache_return[82:51];
    assign icache_return_data[2]  = icache_return[114:83];
    assign icache_return_data[3]  = icache_return[146:115];
    assign icache_return_data[4]  = icache_return[178:147];
    assign icache_return_data[5]  = icache_return[210:179];
    assign icache_return_data[6]  = icache_return[242:211];
    assign icache_return_data[7]  = icache_return[274:243];
    assign icache_return_data[8]  = icache_return[306:275];
    assign icache_return_data[9]  = icache_return[338:307];
    assign icache_return_data[10] = icache_return[370:339];
    assign icache_return_data[11] = icache_return[402:371];
    assign icache_return_data[12] = icache_return[434:403];
    assign icache_return_data[13] = icache_return[466:435];
    assign icache_return_data[14] = icache_return[498:467];
    assign icache_return_data[15] = icache_return[530:499];

    assign ram_d[18:0]      = inst_tag;
    assign ram_d[50:19]     = receive_buffer[0];
    assign ram_d[82:51]     = receive_buffer[1];
    assign ram_d[114:83]    = receive_buffer[2];
    assign ram_d[146:115]   = receive_buffer[3];
    assign ram_d[178:147]   = receive_buffer[4];
    assign ram_d[210:179]   = receive_buffer[5];
    assign ram_d[242:211]   = receive_buffer[6];
    assign ram_d[274:243]   = receive_buffer[7];
    assign ram_d[306:275]   = receive_buffer[8];
    assign ram_d[338:307]   = receive_buffer[9];
    assign ram_d[370:339]   = receive_buffer[10];
    assign ram_d[402:371]   = receive_buffer[11];
    assign ram_d[434:403]   = receive_buffer[12];
    assign ram_d[466:435]   = receive_buffer[13];
    assign ram_d[498:467]   = receive_buffer[14];
    assign ram_d[530:499]   = receive_buffer[15];

    always_ff @(posedge clk) begin : update_status
        if(rst)
            icache_curr <= IDLE;
        else
            icache_curr <= icache_next;
    end

    always_ff @(posedge clk) begin : update_valid_info
        if(rst)
            icache_valid <= 128'd0;
        else if(icache_curr == COMM)
            icache_valid[waiting_index] <= 1'b1;
        else
            icache_valid <= icache_valid;
    end

    always_ff @(posedge clk) begin : update_receive_counter
        if(rst || (icache_curr == IDLE && icache_next == WIAT))
            receive_counter <= 4'd0;
        else if(icache_curr == WIAT && mmu_valid)
            receive_counter <= receive_counter + 4'd1;
        else
            receive_counter <= receive_counter;
    end

    always_ff @(posedge clk) begin : update_waiting_address
        if(rst)
            waiting_address <= 32'd0;
        else if(icache_curr == IDLE && icache_next == WIAT)
            waiting_address <= inst_addr;
        else
            waiting_address <= waiting_address;
    end

    always_ff @(posedge clk) begin : update_receive_buffer
        if(rst) begin
            for(int i = 0; i < 16; i++)
                receive_buffer[i] <= 32'd0;
        end
        else if(icache_curr == WIAT && mmu_valid)
            receive_buffer[receive_counter] <= inst_read_data;
    end

    always_comb begin : update_icache_next
        ram_we          = 1'b0;
        inst_ok         = 1'b0;
        inst_data       = 32'd0;
        inst_addr_mmu   = 32'd0;
        inst_read_req   = 1'b0;
        icache_next     = IDLE;
        case(icache_curr)
        COMM: begin
            ram_we = 1'b1;
            inst_ok = 1'b1;
            inst_data = receive_buffer[waiting_offset];
        end
        WIAT: begin
            if(mmu_last) begin
                icache_next = COMM;
            end
            else
                icache_next = WIAT;
        end
        default: begin // IDLE
            if(!inst_en) begin
                // We do nothing
            end
            else if(icache_valid[inst_index] && icache_return_tag == inst_tag) begin // Cache hit!
                inst_ok     = 1'b1;
                inst_data   = icache_return_data[inst_offset];
            end
            else begin // Cache miss
                inst_ok         = 1'b0;
                inst_addr_mmu   = {inst_addr[31:6], 6'd0};
                inst_read_req   = 1'b1;
                if(inst_addr_ok)
                    icache_next = WIAT;
                else
                    icache_next = IDLE;
            end
        end
        endcase
    end

    dist_mem_gen_icache icache_ram(
        .clk            (clk),
        .dpra           (ram_dpra),
        .a              (ram_a),
        .d              (ram_d),
        .we             (ram_we),
        .dpo            (icache_return)
    );
endmodule
