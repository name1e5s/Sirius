`timescale 1ns / 1ps

// daddr_psy should not be changed when pipeline stall
// now the mmu_data shares the same structure with mmu_inst
// FUCK VERILOG!!!
module mmu_data(
        input                       clk,
        input                       rst,

        // From/to sirius
        input                       den,
        input [3:0]                 dwen,
        input [31:0]                daddr_psy,
        input [31:0]                wdata,
        input                       daddr_type, // 0 as cacahe...
        input [2:0]                 data_size_in,
        output logic [2:0]          data_size_out,
        
        output logic                data_ok,
        output logic [31:0]         data_data,

        // Cache control
        input                       data_hit_writeback,
        input                       index_invalidate,

        // From/to MMU
        output logic                mmu_running,
        // read channel
        output logic [31:0]         daddr_req,
        output logic                read_en,
        output logic                read_type, // o as cache refill, 1 as uncached
        input                       daddr_req_ok,
        input [31:0]                ddata_rdata,
        input                       ddata_rvalid,
        input                       ddata_rlast,
        // write channel
        output logic [31:0]         daddr_wreq,
        output logic                write_en,
        output logic                write_type,
        output logic [3:0]          write_byte_en,
        output logic                dwvalid,
        output logic [31:0]         dwdata,
        output logic                dwlast,
        input                       daddr_wreq_ok,
        input                       ddata_wready,
        input                       ddata_bvalid
);

    enum logic [3:0] {
        IDLE            = 4'b0000,
        FIFO_WAIT       = 4'b0101,
        CACHED_RSHAKE   = 4'b0001,
        CACHED_RWAIT    = 4'b0100,
        CACHED_REFILL   = 4'b0010,
        CACHED_WWAIT    = 4'b0111,
        UNCACHED_SHAKE  = 4'b1001,
        UNCACHED_WWAIT  = 4'b1100,
        UNCACHED_RETURN = 4'b1010,
        CACHECTRL_WAIT  = 4'b1111
    } cstate, nstate;

    enum logic [2:0] {
        WIDLE            = 3'b000,
        UNCACHED_WSHAKE = 3'b001,
        UNCACHED_WWRITE = 3'b011,
        UNCACHED_WRESULT= 3'b010,
        CACHED_WSHAKE   = 3'b101,
        CACHED_WWRITE   = 3'b110,
        CACHED_WRESULT  = 3'b111
    } wcstate, wnstate;

    reg  [127:0]    dcache_valid;
    reg  [127:0]    dcache_dirty;

    wire [ 18:0]    data_tag    = daddr_psy[31:13];
    wire [  6:0]    data_index  = daddr_psy[12:6];
    wire [  3:0]    data_offset = daddr_psy[5:2];
    wire [  6:0]    ram_dpra    = data_index;
    wire [  6:0]    ram_a       = data_index;
    logic[530:0]    _ram_d, ram_d, ram_d_buffer;
    logic           ram_we;

    wire [530:0]    dcache_return; // Connect to output channel of ram.
    wire [ 31:0]    dcache_return_data[0:15];

    reg [ 31:0]     receive_buffer[0:15];
    logic[ 31:0]    ram_buffer[0:15];
    
    logic write_required;
    logic writeback_required;
    logic valid_change;

    wire [18:0]dcache_return_tag  = dcache_return[18:0];
    assign dcache_return_data[0]  = dcache_return[50:19];
    assign dcache_return_data[1]  = dcache_return[82:51];
    assign dcache_return_data[2]  = dcache_return[114:83];
    assign dcache_return_data[3]  = dcache_return[146:115];
    assign dcache_return_data[4]  = dcache_return[178:147];
    assign dcache_return_data[5]  = dcache_return[210:179];
    assign dcache_return_data[6]  = dcache_return[242:211];
    assign dcache_return_data[7]  = dcache_return[274:243];
    assign dcache_return_data[8]  = dcache_return[306:275];
    assign dcache_return_data[9]  = dcache_return[338:307];
    assign dcache_return_data[10] = dcache_return[370:339];
    assign dcache_return_data[11] = dcache_return[402:371];
    assign dcache_return_data[12] = dcache_return[434:403];
    assign dcache_return_data[13] = dcache_return[466:435];
    assign dcache_return_data[14] = dcache_return[498:467];
    assign dcache_return_data[15] = dcache_return[530:499];

    assign _ram_d[18:0]      = data_tag;
    assign _ram_d[50:19]     = receive_buffer[0];
    assign _ram_d[82:51]     = receive_buffer[1];
    assign _ram_d[114:83]    = receive_buffer[2];
    assign _ram_d[146:115]   = receive_buffer[3];
    assign _ram_d[178:147]   = receive_buffer[4];
    assign _ram_d[210:179]   = receive_buffer[5];
    assign _ram_d[242:211]   = receive_buffer[6];
    assign _ram_d[274:243]   = receive_buffer[7];
    assign _ram_d[306:275]   = receive_buffer[8];
    assign _ram_d[338:307]   = receive_buffer[9];
    assign _ram_d[370:339]   = receive_buffer[10];
    assign _ram_d[402:371]   = receive_buffer[11];
    assign _ram_d[434:403]   = receive_buffer[12];
    assign _ram_d[466:435]   = receive_buffer[13];
    assign _ram_d[498:467]   = receive_buffer[14];
    assign _ram_d[530:499]   = receive_buffer[15];

    assign ram_d_buffer[18:0]      = data_tag;
    assign ram_d_buffer[50:19]     = ram_buffer[0];
    assign ram_d_buffer[82:51]     = ram_buffer[1];
    assign ram_d_buffer[114:83]    = ram_buffer[2];
    assign ram_d_buffer[146:115]   = ram_buffer[3];
    assign ram_d_buffer[178:147]   = ram_buffer[4];
    assign ram_d_buffer[210:179]   = ram_buffer[5];
    assign ram_d_buffer[242:211]   = ram_buffer[6];
    assign ram_d_buffer[274:243]   = ram_buffer[7];
    assign ram_d_buffer[306:275]   = ram_buffer[8];
    assign ram_d_buffer[338:307]   = ram_buffer[9];
    assign ram_d_buffer[370:339]   = ram_buffer[10];
    assign ram_d_buffer[402:371]   = ram_buffer[11];
    assign ram_d_buffer[434:403]   = ram_buffer[12];
    assign ram_d_buffer[466:435]   = ram_buffer[13];
    assign ram_d_buffer[498:467]   = ram_buffer[14];
    assign ram_d_buffer[530:499]   = ram_buffer[15];
	

    dist_mem_gen_icache dcache_ram(
        .clk            (clk),
        .dpra           (ram_dpra),
        .a              (ram_a),
        .d              (ram_d),
        .we             (ram_we),
        .dpo            (dcache_return)
    );

    logic [31:0] dfifo_addr;
    logic [31:0] dfifo_data;
    logic [3:0]  dfifo_dwen;
    logic        dfifo_read_en;
    logic        dfifo_write_en;
    logic        dfifo_full;
    logic        dfifo_empty;


    data_fifo dfifo(
        .clk            (clk),
        .rst            (rst),
        .size_in        (data_size_in),
        .addr_in        (daddr_psy),
        .data_in        (wdata),
        .dwen_in        (dwen),
        .addr_out       (dfifo_addr),
        .data_out       (dfifo_data),
        .dwen_out       (dfifo_dwen),
        .size_out       (data_size_out),
        .read_en        (dfifo_read_en),
        .write_en       (dfifo_write_en),
        .full           (dfifo_full),
        .empty          (dfifo_empty)
    );

    always_ff @(posedge clk) begin : update_status
        if(rst)
            cstate <= IDLE;
        else
            cstate <= nstate;
    end

    always_ff @(posedge clk) begin : update_wstatus
        if(rst)
            wcstate <= WIDLE;
        else
            wcstate <= wnstate;
    end

    always_ff @(posedge clk) begin : update_valid_info
        if(rst) begin
            dcache_valid <= 128'd0;
        end
        else if(cstate == CACHED_REFILL) begin
            dcache_valid[data_index] <= 1'b1;
        end
        else if(valid_change)
            dcache_valid[data_index] <= 1'b0;
    end

    always_ff @(posedge clk) begin : update_dirty_info
        if(rst) begin
            dcache_dirty <= 128'd0;
        end
        else if(cstate == CACHED_REFILL || valid_change) begin
            dcache_dirty[data_index] <= 1'b0;
        end
        else if(writeback_required) begin
            dcache_dirty[data_index] <= 1'b1;
        end
    end

    reg [3:0] receive_counter;

    always_ff @(posedge clk) begin : update_receive_counter
        if(rst || cstate != CACHED_RWAIT) begin
            receive_counter <= 4'd0;
        end
        else if(cstate == CACHED_RWAIT && ddata_rvalid) begin// receive new data
            receive_counter <= receive_counter + 4'd1;
        end
    end

    always_ff @(posedge clk) begin : write_data_to_buffer
        if(rst) begin // Clear buffer
            for(int i = 0; i < 16; i++)
                receive_buffer[i] <= 32'd0;
        end
        else if(cstate == CACHED_RWAIT && ddata_rvalid) begin
            receive_buffer[receive_counter] <= ddata_rdata;
        end
    end

    reg [3:0] output_counter;

    always_ff @(posedge clk) begin : update_output_counter
        if(rst || wcstate != CACHED_WWRITE) begin
            output_counter <= 4'd0;
        end
        else if(wcstate == CACHED_WWRITE && ddata_wready) begin // receive new data
            output_counter <= output_counter + 4'd1;
        end
    end

    always_comb begin
        if(writeback_required)
            ram_d = ram_d_buffer;
        else
            ram_d = _ram_d;
    end

    // For performance tunning...
    reg [63:0]  cache_hit_counter;
    reg [63:0]  cache_miss_counter;
    reg [63:0]  cache_swap_counter;
    reg [63:0]  uncached_read_counter;
    reg [63:0]  uncached_write_counter;

    logic       cache_hit;
    logic       cache_miss;
    logic       cache_swap;
    logic       uncached_read;
    logic       uncached_write;

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

    always_ff @(posedge clk) begin
        if(rst) begin
            cache_swap_counter <= 64'd0;
        end
        else if(cache_swap) begin
            cache_swap_counter <= cache_swap_counter + 64'd1;
            $display("[DBEUG] Cache swap at index %d for address 0x%08x", data_index, daddr_psy);
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            uncached_read_counter <= 64'd0;
        end
        else if(uncached_read) begin
            uncached_read_counter <= uncached_read_counter + 64'd1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            uncached_write_counter <= 64'd0;
        end
        else if(uncached_write) begin
            uncached_write_counter <= uncached_write_counter + 64'd1;
        end
    end

    wire hit_it = (dcache_valid[data_index] && (dcache_return_tag == data_tag || index_invalidate));

    // Read channel
    always_comb begin
        data_ok         = 1'd0;
        data_data       = 32'd0;

        daddr_req       = 32'd0;
        read_en         = 1'd0;
        read_type       = 1'd0;
        write_required  = 1'd0;
        writeback_required = 1'd0;
        mmu_running     = 1'd0;

        nstate          = IDLE;
        ram_we          = 1'd0;

        // For perf tunning...
        cache_hit   = 1'd0;
        cache_miss  = 1'd0;
        cache_swap  = 1'd0;
        uncached_read = 1'd0;
        uncached_write = 1'd0;

        dfifo_write_en = 1'd0;
        valid_change = 1'd0;


        for(int i = 0; i < 16; i++) begin
            ram_buffer[i] = dcache_return_data[i];
        end

        unique case(cstate)
        IDLE: begin
            if(rst || !den) begin
                // Make vivado happy
            end
            else if(data_hit_writeback) begin
                if(hit_it && dcache_dirty[data_index] && ~(dfifo_empty && wcstate == WIDLE))
                    nstate = FIFO_WAIT;
                valid_change = hit_it;
                write_required = hit_it && dcache_dirty[data_index];
                data_ok = ~hit_it;
                if(hit_it)
                    nstate = CACHECTRL_WAIT;
            end
            else if(daddr_type) begin // Uncached access
                mmu_running = 1'd1;
                if(dwen) begin
                    dfifo_write_en  = ~dfifo_full;
                    data_ok         = ~dfifo_full;
                    nstate          = IDLE;
                    uncached_write  = 1'd1;
                end
                else begin // Read
                    if(dfifo_empty && wcstate == WIDLE) begin
                        daddr_req       = daddr_psy;
                        read_en         = 1'd1;
                        read_type       = 1'd1;
                        uncached_read   = 1'd1;
                        if(daddr_req_ok) begin
                            nstate  = UNCACHED_RETURN;
                        end
                        else begin
                            nstate  = UNCACHED_SHAKE;
                        end
                    end
                    else
                        nstate = FIFO_WAIT;
                end
            end
            else if(hit_it) begin
                cache_hit   = 1'd1;
                if(dwen != 4'd0) begin
                    writeback_required = 1'd1;
                    ram_we      = 1'd1;
                    data_ok     = 1'd1;
                    data_data   = 32'd0;
                    ram_buffer[data_offset] = (dcache_return_data[data_offset] & {{8{~dwen[3]}}, {8{~dwen[2]}}, {8{~dwen[1]}}, {8{~dwen[0]}}}) |  
                                                (wdata  & {{8{dwen[3]}}, {8{dwen[2]}}, {8{dwen[1]}}, {8{dwen[0]}}});
                end
                else begin
                    data_ok     = 1'd1;
                    data_data   = dcache_return_data[data_offset];
                end
                nstate  = IDLE;
            end
            else begin // Cache miss
                cache_miss  = 1'd1;
                if(dcache_dirty[data_index] && ~(dfifo_empty && wcstate == WIDLE)) begin
                    nstate = FIFO_WAIT;
                end
                else begin
                    daddr_req   = {daddr_psy[31:6], 6'd0};
                    mmu_running = 1'd1;
                    read_en     = 1'd1;
                    read_type   = 1'd0;
                    cache_swap  = dcache_valid[data_index];
                    write_required = dcache_dirty[data_index];
                    if(daddr_req_ok) begin
                        nstate  = CACHED_RWAIT;
                    end
                    else begin
                        nstate  = CACHED_RSHAKE;
                    end
                end

            end
        end

        CACHECTRL_WAIT: begin
            if(dfifo_empty && (wcstate == WIDLE)) begin
                nstate = IDLE;
                data_ok = 1'd1;
            end
            else
                nstate = CACHECTRL_WAIT;
        end

        FIFO_WAIT: begin
            if(dfifo_empty && (wcstate == WIDLE))
                nstate = IDLE;
            else
                nstate = FIFO_WAIT;
        end

        UNCACHED_SHAKE: begin
            daddr_req   = daddr_psy;
            read_en     = 1'd1;
            read_type   = 1'd1;
            mmu_running = 1'd1;
            if(daddr_req_ok) begin
                nstate  = UNCACHED_RETURN;
            end
            else begin
                nstate  = UNCACHED_SHAKE;
            end
        end
        UNCACHED_RETURN: begin
            data_ok     = ddata_rvalid;
            data_data   = ddata_rdata;
            mmu_running = 1'd1;
            if(ddata_rvalid && ddata_rlast) begin
                nstate  = IDLE;
            end
            else begin
                nstate  = UNCACHED_RETURN;
            end
        end
        UNCACHED_WWAIT: begin
            mmu_running = 1'd1;
            if(wcstate == UNCACHED_WRESULT && ddata_bvalid) begin
                data_ok = 1'd1;
                nstate = IDLE;
            end
            else
                nstate = UNCACHED_WWAIT;
        end
        CACHED_RSHAKE: begin
            mmu_running = 1'd1;
            daddr_req   = {daddr_psy[31:6], 6'd0};
            read_en     = 1'd1;
            read_type   = 1'd0;
            if(daddr_req_ok) begin
                nstate  = CACHED_RWAIT;
            end
            else begin
                nstate  = CACHED_RSHAKE;
            end
        end
        CACHED_RWAIT: begin
            mmu_running = 1'd1;
            if(ddata_rvalid && ddata_rlast && wcstate == WIDLE) begin
                nstate  = CACHED_REFILL;
            end
            else if(ddata_rvalid && ddata_rlast) begin
                nstate = CACHED_WWAIT;
            end
            else begin
                nstate  = CACHED_RWAIT;
            end
        end
        CACHED_WWAIT: begin
            mmu_running = 1'd1;
            if(wcstate != WIDLE) begin
                nstate  = CACHED_WWAIT;
            end
            else begin
                nstate  = CACHED_REFILL;
            end
        end
        CACHED_REFILL: begin
            mmu_running = 1'd1;
            ram_we      = 1'd1;
            nstate      = IDLE;

            data_ok     = ~(|dwen);
            data_data   = receive_buffer[data_offset];
        end
        default: begin
            // Make vivado happy :)
        end
        endcase
    end

    // Write channel
    always_comb begin
        daddr_wreq      = 32'd0;
        write_en        = 1'd0;
        write_type      = 1'd0;
        write_byte_en   = 4'd0;
        dwvalid         = 1'd0;
        dwdata          = 32'd0;
        dwlast          = 1'd0;

        wnstate         = WIDLE;

        // FIFO default value
        dfifo_read_en   = 1'd0;

        case(wcstate)
        WIDLE: begin
            if(~dfifo_empty) begin // Uncached write
                daddr_wreq      = dfifo_addr;
                write_en        = 1'd1;
                write_type      = 1'd1;
                write_byte_en   = dfifo_dwen;
                if(daddr_wreq_ok) begin
                    wnstate = UNCACHED_WWRITE;
                end
                else begin
                    wnstate = UNCACHED_WSHAKE;
                end
            end
            else if(write_required) begin
                daddr_wreq      = { dcache_return_tag, data_index, 6'd0 };
                write_en        = 1'd1;
                write_type      = 1'd0;
                if(daddr_wreq_ok) begin
                    wnstate = CACHED_WWRITE;
                end
                else begin
                    wnstate = CACHED_WSHAKE;
                end
            end
        end
        UNCACHED_WSHAKE: begin
            daddr_wreq      = dfifo_addr;
            write_en        = 1'd1;
            write_type      = 1'd1;
            if(daddr_wreq_ok) begin
                wnstate = UNCACHED_WWRITE;
            end
            else begin
                wnstate = UNCACHED_WSHAKE;
            end
        end
        UNCACHED_WWRITE: begin
            write_byte_en   = dfifo_dwen;
            dwdata          = dfifo_data;
            dwvalid         = 1'd1;
            dwlast          = 1'd1;
            dfifo_read_en   = ddata_wready;
            if(ddata_wready)
                wnstate = UNCACHED_WRESULT;
            else
                wnstate = UNCACHED_WWRITE;
        end
        UNCACHED_WRESULT: begin
            if(ddata_bvalid)
                wnstate = WIDLE;
            else
                wnstate = UNCACHED_WRESULT;
        end
        CACHED_WSHAKE: begin
            daddr_wreq      = { dcache_return_tag, data_index, 6'd0 };
            write_en        = 1'd1;
            write_type      = 1'd0;
            if(daddr_wreq_ok) begin
                wnstate = CACHED_WWRITE;
            end
            else begin
                wnstate = CACHED_WSHAKE;
            end
        end
        CACHED_WWRITE: begin
            write_byte_en   = 4'b1111;
            dwdata          = dcache_return_data[output_counter];
            dwvalid         = 1'd1;
            dwlast          = &output_counter;
            if(&output_counter && ddata_wready)
                wnstate = CACHED_WRESULT;
            else
                wnstate = CACHED_WWRITE;
        end
        CACHED_WRESULT: begin
            if(ddata_bvalid)
                wnstate = WIDLE;
            else
                wnstate = CACHED_WRESULT;
        end
        default: begin
        // Make vivado happy :)
        end
    endcase
    end

endmodule
