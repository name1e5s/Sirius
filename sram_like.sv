`timescale 1ns / 1ps

module sram_like(
        input                       clk,
		input                       rstn,
		input                       flush,
		//inst sram-like 
		output logic                inst_req ,
		output logic                inst_wr ,
		output logic [1 :0]         inst_size ,
		output logic [31:0]         inst_addr ,
		output logic [31:0]         inst_wdata ,
		input [31:0]                inst_rdata ,
		input                       inst_addr_ok ,
		input                       inst_data_ok ,

		//data sram-like 
		output logic                data_req ,
		output logic                data_wr ,
		output logic [1 :0]         data_size ,
		output logic [31:0]         data_addr ,
		output logic [31:0]         data_wdata ,
		input [31:0]                data_rdata ,
		input                       data_addr_ok ,
		input                       data_data_ok ,

		// From/To CPU
		input                       ien,
		input [31:0]                iaddr_i,
		output logic [31:0]         idata_i,
		output logic                inst_ok,

		// To data
		input                       den,
		input [3:0]                 dwen, // Which byte is write enabled?
		input [31:0]                daddr_i,
		input [31:0]                dwdata_i,
		output logic [31:0]         drdata_i,
		output logic                data_ok
);
   
   wire rst = ~rstn;
   
    parameter [1:0] // One hot FSM
        IDLE = 2'b01,
        WIAT = 2'b10,
        PCCH = 2'b11;
   
   reg [1:0]    icurr;
   logic [1:0]  inext;

    always_ff @(posedge clk) begin : update_icurr
        if(rst) begin
            icurr <= IDLE;
        end
        else begin
            icurr <= inext;
        end
    end
   
    always_comb begin : select_next_icurr
        case(icurr)
        WIAT: begin
            inst_req = 1'b0;
            inst_addr = 32'd0;
            idata_i = inst_rdata;
            inst_ok = inst_data_ok;
            if(inst_data_ok) begin
                inst_req = ien;
                inst_addr = iaddr_i;
                if(inst_req && inst_addr_ok)
                    inext = WIAT;
                else
                    inext = IDLE;
            end
            else
                inext = WIAT;
        end
        default: begin // IDLE
            inst_req = ien;
            inst_addr = iaddr_i;
            idata_i = 32'd0;
            inst_ok = 1'd0;
            if(inst_req && inst_addr_ok)
                inext = WIAT;
            else
                inext = IDLE;
        end
        endcase
    end
   
   
   logic [1:0]  dsize;
   logic [31:0] daddr;
   
    always_comb begin : get_dsize_daddr
        case(dwen)
        4'b0001, 4'b0010, 4'b0100, 4'b1000: begin
            dsize = 2'b00;
            daddr = daddr_i;
        end
        4'b0011, 4'b1100: begin
            dsize = 2'b01;
            daddr = daddr_i;
        end
        4'b1111: begin
            dsize = 2'b10;
            daddr = daddr_i;
        end
        default: begin // read
            dsize = 2'b10;
            daddr = {daddr_i[31:2], 2'd0 };
        end
        endcase
    end
   
   reg [1:0]    dcurr;
   logic [1:0]  dnext;
   
    always_ff @(posedge clk) begin : update_dcurr
        if(rst) begin
            dcurr <= IDLE;
        end
        else begin
            dcurr <= dnext;
        end
    end
   
    always_comb begin : select_next_dcurr
        data_size = dsize;
        data_addr = daddr;
        case(dcurr)
        WIAT: begin
            data_req = 1'b0;
            data_wr = 1'b0;
            data_wdata = 32'd0;
            drdata_i = data_rdata;
            data_ok = data_data_ok;
            if(data_data_ok)
                dnext = IDLE;
            else
                dnext = WIAT;
        end
        default: begin // IDLE
            data_req = den;
            data_wr = |dwen;
            data_wdata = dwdata_i;
            drdata_i = 32'd0;
            data_ok = 1'b0;
            if(data_req && data_addr_ok)
                dnext = WIAT;
            else
                dnext = IDLE;
        end
        endcase
    end
   
    assign inst_wr      = 1'b0;
    assign inst_size    = 2'b10;
    assign inst_wdata   = 32'd0;
endmodule
