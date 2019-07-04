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
        
        output logic                data_ok,
        output logic [31:0]         data_data,

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
        CACHED_RSHAKE   = 4'b0001,
        CACHED_RWAIT    = 4'b0100,
        CACHED_REFILL   = 4'b0010,
        CACHED_WWAIT    = 4'b0111,
        UNCACHED_SHAKE  = 4'b1001,
        UNCACHED_WWAIT  = 4'b1100,
        UNCACHED_RETURN = 4'b1010
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
    end

    always_ff @(posedge clk) begin : update_dirty_info
        if(rst) begin
            dcache_dirty <= 128'd0;
        end
        else if(cstate == CACHED_REFILL) begin
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

        for(int i = 0; i < 16; i++) begin
            ram_buffer[i] = dcache_return_data[i];
        end

        unique case(cstate)
        IDLE: begin
            if(rst || !den) begin
                // Make vivado happy
            end
            else if(daddr_type) begin // Uncached access
                mmu_running = 1'd1;
                if(dwen) begin
                    write_required  = 1'd1;
                    nstate          = UNCACHED_WWAIT;
                end
                else begin // Read
                    daddr_req       = daddr_psy;
                    read_en         = 1'd1;
                    read_type       = 1'd1;
                    if(daddr_req_ok) begin
                        nstate  = UNCACHED_RETURN;
                    end
                    else begin
                        nstate  = UNCACHED_SHAKE;
                    end
                end
            end
            else if(dcache_valid[data_index] && dcache_return_tag == data_tag) begin
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
                daddr_req   = {daddr_psy[31:6], 6'd0};
                mmu_running = 1'd1;
                read_en     = 1'd1;
                read_type   = 1'd0;
                write_required = dcache_dirty[data_index];
                if(daddr_req_ok) begin
                    nstate  = CACHED_RWAIT;
                end
                else begin
                    nstate  = CACHED_RSHAKE;
                end
            end
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
            if(ddata_rlast) begin
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
            if(ddata_rlast && wcstate == WIDLE) begin
                nstate  = CACHED_REFILL;
            end
            else if(ddata_rlast) begin
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

        wnstate          = WIDLE;
        case(wcstate)
        WIDLE: begin
            if(write_required && daddr_type) begin // Uncached write
                daddr_wreq      = daddr_psy;
                write_en        = 1'd1;
                write_type      = 1'd1;
                write_byte_en   = dwen;
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
            daddr_wreq      = daddr_psy;
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
            write_byte_en   = dwen;
            dwdata          = wdata;
            dwvalid         = 1'd1;
            dwlast          = 1'd1;
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
