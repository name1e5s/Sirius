 `timescale 1ns / 1ps
// I choose to trust xilinx...

// The instruction cache.
// Format:
// | Tag[18:0] | data... 64Bytes | * 128
// Address format:
// addr[31:13] as Tag
// addr[12:6] as Index
// addr[5:2] as Offset
// addr[1:0] is unused in i$

// iaddr_psy should not be changed when pipeline is stalling...
module mmu_inst(
        input                       clk,
        input                       rst,

        // From/to sirius
        input                       ien,
        input [31:0]                iaddr_psy,
        input                       iaddr_type, // 0 as cached, 1 as uncacahed
        
        // Cache control
        input                       inst_hit_invalidate,
        input                       index_invalidate,

        output logic                inst_ok,
        output logic                inst_ok_1,
        output logic                inst_ok_2,
        output logic [31:0]         inst_data_1,
        output logic [31:0]         inst_data_2,
        
        // From/to mmu_top
        output logic                mmu_running,
        output logic [31:0]         iaddr_req,
        output logic                read_en,
        output logic                read_type, // o as cache refill, 1 as uncached
        input                       iaddr_req_ok,
        input [31:0]                idata_rdata,
        input                       idata_rvalid,
        input                       idata_rlast
);

    enum logic [2:0] {
        IDLE            = 3'b000,
        CACHED_SHAKE    = 3'b001,
        CACHED_WAIT     = 3'b010,
        CACHED_REFILL   = 3'b011,
        UNCACHED_SHAKE  = 3'b101,
        UNCACHED_RETURN = 3'b110,
        CACHECTRL_WAIT  = 3'b111
    } cstate, nstate;

    reg  [127:0]    icache_valid;

    wire [ 18:0]    inst_tag    = iaddr_psy[31:13];
    wire [  6:0]    inst_index  = iaddr_psy[12:6];
    wire [  3:0]    inst_offset = iaddr_psy[5:2];
    wire [  6:0]    ram_dpra    = inst_index;
    wire [  6:0]    ram_a       = inst_index;
    wire [530:0]    ram_d;
    logic           ram_we;
    logic           clear_valid;

    wire [530:0]    icache_return; // Connect to output channel of ram.
    wire [ 31:0]    icache_return_data[0:15];
    
    reg [ 31:0]     receive_buffer[0:15];

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

    dist_mem_gen_icache icache_ram(
        .clk            (clk),
        .dpra           (ram_dpra),
        .a              (ram_a),
        .d              (ram_d),
        .we             (ram_we),
        .dpo            (icache_return)
    );

    always_ff @(posedge clk) begin : update_status
        if(rst)
            cstate <= IDLE;
        else
            cstate <= nstate;
    end

    always_ff @(posedge clk) begin : update_valid_info
        if(rst) begin
            icache_valid <= 128'd0;
        end
        else if(cstate == CACHED_REFILL) begin
            icache_valid[inst_index] <= 1'b1;
        end
        else if(clear_valid)
            icache_valid[inst_index] <= 1'b0;
    end

    reg [3:0] receive_counter;

    always_ff @(posedge clk) begin : update_receive_counter
        if(rst || cstate != CACHED_WAIT) begin
            receive_counter <= 4'd0;
        end
        else if(cstate == CACHED_WAIT && idata_rvalid) begin// receive new data
            receive_counter <= receive_counter + 4'd1;
        end
    end

    always_ff @(posedge clk) begin : write_data_to_buffer
        if(rst) begin // Clear buffer
            for(int i = 0; i < 16; i++)
                receive_buffer[i] <= 32'd0;
        end
        else if(cstate == CACHED_WAIT && idata_rvalid) begin
            receive_buffer[receive_counter] <= idata_rdata;
        end
    end
    // For performance tunning...
    reg [63:0]  cache_hit_counter;
    reg [63:0]  cache_miss_counter;

    logic       cache_hit;
    logic       cache_miss;

    always_ff @(posedge clk) begin
        if(rst) begin
            cache_hit_counter   <= 64'd0;
            cache_miss_counter  <= 64'd0;
        end
        else begin
            if(cache_hit)
                cache_hit_counter   <= cache_hit_counter + 64'd1;
            else if(cache_miss)
                cache_miss_counter  <= cache_miss_counter + 64'd1;
        end
    end

    wire hit_it = ((inst_tag == icache_return_tag || index_invalidate) && 
                    icache_valid[inst_index]);

    // WARNING -- COMPLEX COMB LOGIC 
    // "We will still hate the tools."
    always_comb begin : set_all_output
        // Set default signals
        // Output..
        inst_ok     = 1'd0;
        inst_ok_1   = 1'd0;
        inst_ok_2   = 1'd0;
        inst_data_1 = 32'd0;
        inst_data_2 = 32'd0;
        iaddr_req   = 32'd0;
        read_en     = 1'd0;
        read_type   = 1'd0;
        // Internal signals...
        ram_we      = 1'd0;
        mmu_running = 1'd0;

        clear_valid = 1'd0;

        // For perf tunning...
        cache_hit   = 1'd0;
        cache_miss  = 1'd0;

        nstate      = IDLE;
        unique case(cstate)
        IDLE: begin
            if(rst || !ien) begin // We do nothing here.
            end
            else if(inst_hit_invalidate) begin
                clear_valid = hit_it;
                if(hit_it)
                    nstate = CACHECTRL_WAIT;
            end
            else if(iaddr_type) begin// Uncacahed read
                iaddr_req   = iaddr_psy;
                read_en     = 1'd1;
                mmu_running = 1'd1;
                read_type   = 1'd1;
                if(iaddr_req_ok) begin
                    nstate  = UNCACHED_RETURN;
                end
                else begin
                    nstate  = UNCACHED_SHAKE;
                end
            end
            else if(hit_it) begin // Cache hit
                cache_hit   = 1'd1;
                inst_ok     = 1'd1;
                inst_ok_1   = 1'd1;
                inst_ok_2   = ~(&inst_offset);
                inst_data_1 = icache_return_data[inst_offset];
                inst_data_2 = &inst_offset? 32'd0 : icache_return_data[inst_offset + 4'd1];
            end
            else begin // Cache miss
                cache_miss  = 1'd1;
                iaddr_req   = {iaddr_psy[31:6], 6'd0};
                read_en     = 1'd1;
                mmu_running = 1'd1;
                read_type   = 1'd0;
                if(iaddr_req_ok) begin
                    nstate  = CACHED_WAIT;
                end
                else begin
                    nstate  = CACHED_SHAKE;
                end
            end
        end
        CACHECTRL_WAIT: begin
            nstate = IDLE;
        end
        UNCACHED_SHAKE: begin
            iaddr_req   = iaddr_psy;
            read_en     = 1'd1;
            mmu_running = 1'd1;
            read_type   = 1'd1;
            if(iaddr_req_ok) begin
                nstate  = UNCACHED_RETURN;
            end
            else begin
                nstate  = UNCACHED_SHAKE;
            end
        end
        UNCACHED_RETURN: begin
            inst_ok     = idata_rvalid;
            inst_ok_1   = idata_rvalid;
            inst_data_1 = idata_rdata;
            mmu_running = 1'd1;
            if(idata_rvalid && idata_rlast) begin
                nstate  = IDLE;
            end
            else begin
                nstate  = UNCACHED_RETURN;
            end
        end
        CACHED_SHAKE: begin
            iaddr_req   = {iaddr_psy[31:6], 6'd0};
            read_en     = 1'd1;
            read_type   = 1'd0;
            mmu_running = 1'd1;
            if(iaddr_req_ok) begin
                nstate  = CACHED_WAIT;
            end
            else begin
                nstate  = CACHED_SHAKE;
            end
        end
        CACHED_WAIT: begin
            mmu_running = 1'd1;
            if(idata_rvalid && idata_rlast) begin
                nstate  = CACHED_REFILL;
            end
            else begin
                nstate  = CACHED_WAIT;
            end
        end
        CACHED_REFILL: begin
            mmu_running = 1'd1;
            ram_we      = 1'd1;
            nstate      = IDLE;

            inst_ok     = 1'd1;
            inst_ok_1   = 1'd1;
            inst_ok_2   = ~(&inst_offset);
            inst_data_1 = receive_buffer[inst_offset];
            inst_data_2 = &inst_offset? 32'd0 : receive_buffer[inst_offset + 4'd1];
        end
        default: begin // Make vivado happy :)
        end
        endcase
    end

endmodule