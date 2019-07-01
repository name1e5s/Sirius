`timescale 1ns / 1ps

// iaddr_psy should not be changed when pipeline is stalling...
module mmu_inst(
        input                       clk,
        input                       rst,

        // From/to sirius
        input                       ien,
        input [31:0]                iaddr_psy,
        input                       iaddr_type, // 0 as cached, 1 as uncacahed
        
        output logic                inst_ok,
        output logic                inst_ok_1,
        output logic                inst_ok_2,
        output logic [31:0]         inst_data_1,
        output logic [31:0]         inst_data_2,
        
        // From/to mmu_top
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
        CACHED_REFILL   = 3'b010,
        UNCACHED_SHAKE  = 3'b101,
        UNCACHED_RETURN = 3'b110
    } cstate, nstate;

    // For cache...
    wire [18:0] current_tag     = addr_psy[31:13];
    wire [6:0]  current_index   = addr_psy[12:6];
    wire [3:0]  current_offset  = addr_psy[5:2];

    reg  [3:0]  pending_counter;

    reg [127:0] valid_bit;
    reg [18:0]  tags[0:127];
    
    wire  [31:0]    write_data;
    logic           write_enable;
    logic [31:0]    read_data_1, read_data_2;
    logic           cache_miss;

    wire  [10:0]    read_addr_1, read_addr_2;
    assign          read_addr_1 = { current_index, current_offset };
    assign          read_addr_2 = read_addr_1 + 11'd1;
    assign          write_data  = idata_rdata;

    icache_dual_ram icache_ram(
        .clk                    (clk),
        .a                      (read_addr_1),
        .dpra                   (read_addr_2),
        .d                      (write_data),
        .spo                    (read_data_1),
        .dpo                    (read_data_2),
        .we                     (write_enable)
    );
    
    // Control unit.....
    always_ff @(posedge clk) begin : set_cstate
        if(rst) begin
            cstate <= IDLE;
        end
        else begin
            cstate <= nstate;
        end
    end

    always_ff @(posedge clk) begin : set_valid_bits
        if(rst) begin
            valid_bit <= 128'd0;
        end
        else if(cstate == CACHED_REFILL && idata_rlast) begin
            valid_bit[current_index] <= 1'd1;
        end
    end

    always_ff @(posedge clk) begin : set_tags
        if(cstate == CACHED_REFILL && idata_rlast) begin
            tags[current_index] <= current_tag;
        end
    end

    always_ff @(posedge clk) begin : update_counter
        if(cstate != CACHED_REFILL) begin
            pending_counter <= 4'd0;
        end
        else if(cstate == CACHED_REFILL && idata_rvalid)
            pending_counter <= pending_counter + 1'd1;
    end

    // WARNING -- FUCKING COMPLEX COMB LOGIC
    always_comb begin : all_useful_signals
        // Set Default value
        inst_ok         = 1'd0;
        inst_ok_1       = 1'd0;
        inst_ok_2       = 1'd0;
        inst_data_1     = 32'd0;
        inst_data_2     = 32'd0;
        iaddr_req       = 32'd0;
        read_en         = 1'd0;
        read_type       = 1'd0;
        iaddr_req       = 1'd0;
        read_data_1     = 32'd0;
        read_data_2     = 32'd0;
        cache_miss      = 1'd0;
        unique case(cstate)
        IDLE: begin
            if(!ien) begin
                // We do nothing here...
            end
            else if(iaddr_type) begin // Uncached
                iaddr_req   = iaddr_psy;
                read_en     = 1'd1;
                read_type   = 1'd1;
                if(iaddr_req_ok) begin
                    nstate  = UNCACHED_RETURN;
                end
                else begin
                    nstate  = UNCACHED_SHAKE;
                end
            end
            else if(current_tag == tag[current_index] && valid_bit[current_index]) begin // Cache hit
                nstate      = IDLE;
                inst_ok     = 1'd1;
                inst_ok_1   = 1'd1;
                inst_ok_2   = ~(&current_index); // Cross cache line fetch is invalid.
                inst_data_1 = read_data_1;
                inst_data_2 = read_data_2;
            end
            else begin // Cache miss
                iaddr_req   = { current_tag, current_index, 6'd0 };
                read_en     = 1'd1;
                read_type   = 1'd0;
                if(iaddr_req_ok) begin
                    nstate  = CACHED_REFILL;
                end
                else begin
                    nstate  = CACHED_SHAKE;
                end
            end
        end
        CACHED_SHAKE: begin
            iaddr_req   = { current_tag, current_index, 6'd0 };
            read_en     = 1'd1;
            read_type   = 1'd0;
            if(iaddr_req_ok) begin
                nstate  = CACHED_REFILL;
            end
            else begin
                nstate  = CACHED_SHAKE;
            end
        end
        CACHED_REFILL: begin
            write_enable    = idata_rvalid;
            if(idata_rlast) begin
                nstate      = IDLE;
            end
            else begin
                nstate      = CACHED_REFILL;
            end
        end
        UNCACHED_SHAKE: begin
            iaddr_req   = iaddr_psy;
            read_en     = 1'd1;
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
            if(idata_rlast) begin
                nstate      = IDLE;
            end
            else begin
                nstate      = UNCACHED_RETURN;
            end
        end
        default: begin
            // Make vivado happy :)
        end
        endcase
    end

endmodule