`include "mycpu_head.h"

module stage4_MEM(
    input clk,
    input reset,

    input ws_allow_in,
    output ms_allow_in,

    input es_to_ms_valid,
    output ms_to_ws_valid,

    input [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_MS_TO_DS_BUS-1:0] ms_to_ds_bus,
    
    input [31:0] data_sram_rdata
);

/*-----------------------接收es_to_ms_bus----------------*/
/*
assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_alu_result;
*/

wire [31:0] ms_pc;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [1:0]  unaligned_addr;
wire [2:0]  ms_ld_op;

reg [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            es_to_ms_bus_reg <= 0;
        else if(es_to_ms_valid && ms_allow_in)
            es_to_ms_bus_reg <= es_to_ms_bus;
        else
            es_to_ms_bus_reg <= 0;
    end 

assign {ms_ld_op,unaligned_addr,ms_alu_result, ms_dest, ms_res_from_mem,
        ms_gr_we, ms_pc} = es_to_ms_bus_reg;

/*-------------------------------------------------------*/

/*----------------------发�?�ms_to_ws_bus-----------------*/
wire [31:0] mem_result;
wire [31:0] load_b_res,load_h_res;
assign load_b_res   = (unaligned_addr == 2'h0) ? {{ms_ld_op[2]?{24{data_sram_rdata[7]}}:24'b0} ,data_sram_rdata[7:0]}
        :(unaligned_addr == 2'h1) ? {{ms_ld_op[2]?{24{data_sram_rdata[15]}}:24'b0},data_sram_rdata[15:8]}
        :(unaligned_addr == 2'h2) ? {{ms_ld_op[2]?{24{data_sram_rdata[23]}}:24'b0},data_sram_rdata[23:16]}
        :(unaligned_addr == 2'h3) ? {{ms_ld_op[2]?{24{data_sram_rdata[31]}}:24'b0},data_sram_rdata[31:24]} : 32'b0;
assign load_h_res   = (unaligned_addr[1]) ? {{ms_ld_op[2]?{16{data_sram_rdata[31]}}:16'b0} ,data_sram_rdata[31:16]}
        :{{ms_ld_op[2]?{16{data_sram_rdata[15]}}:16'b0} ,data_sram_rdata[15:0]};
assign mem_result   = ms_ld_op[0] ? load_b_res 
        : ms_ld_op[1] ? load_h_res
        : data_sram_rdata;
wire [31:0] ms_final_result;
assign ms_final_result = ms_res_from_mem? mem_result : ms_alu_result;

assign ms_to_ws_bus[31:0]  = ms_pc;
assign ms_to_ws_bus[32:32] = ms_gr_we;
assign ms_to_ws_bus[37:33] = ms_dest;
assign ms_to_ws_bus[69:38] = ms_final_result;
/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
reg ms_valid;    //valid信号表示这一级流水缓存是否有�??????

wire ms_ready_go;
assign ms_ready_go = 1'b1;
assign ms_allow_in = !ms_valid || ms_ready_go && ws_allow_in;
assign ms_to_ws_valid = ms_valid && ms_ready_go;

always @(posedge clk)
    begin
        if(reset)
            ms_valid <= 1'b0;
        else if(ms_allow_in)
            ms_valid <= es_to_ms_valid;
    end

/*-------------------------------------------------------*/

/*--------------------发�?�ms_to_ds_bus-------------------*/
assign ms_to_ds_bus = {ms_gr_we,ms_dest,ms_final_result};
/*-------------------------------------------------------*/

endmodule