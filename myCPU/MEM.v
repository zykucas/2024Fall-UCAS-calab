`include "mycpu_head.vh"

module stage4_MEM(
    input clk,
    input reset,

    input ertn_flush,
    input has_int,
    input wb_ex,

    input ws_allow_in,
    output ms_allow_in,

    input es_to_ms_valid,
    output ms_to_ws_valid,

    input [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ws_bus,
    output [`WIDTH_MS_TO_DS_BUS-1:0] ms_to_ds_bus,

    output if_ms_has_int,
    
    input [31:0] data_sram_rdata
);

/*-----------------------接收es_to_ms_bus----------------*/
/*

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_cal_result;
assign es_to_ms_bus[72:71] = es_unaligned_addr;
assign es_to_ms_bus[75:73] = es_ld_op; 
//task12
assign es_to_ms_bus[89:76] = es_csr_num;
assign es_to_ms_bus[121:90] = es_csr_wmask;
assign es_to_ms_bus[122:122] = es_csr_write;
assign es_to_ms_bus[123:123] = es_ertn_flush;
assign es_to_ms_bus[124:124] = es_csr;

wire [31:0] es_csr_wvalue;
assign es_csr_wvalue = es_rkd_value;
assign es_to_ms_bus[156:125] = es_csr_wvalue;
assign es_to_ms_bus[157:157] = es_ex_syscall;
assign es_to_ms_bus[172:158] = es_code;
//exp13
assign es_to_ms_bus[173:173] = es_exc_ADEF;
assign es_to_ms_bus[174:174] = es_exc_INE;
assign es_to_ms_bus[175:175] = es_exc_ALE;
assign es_to_ms_bus[176:176] = es_exc_break;
*/

wire [31:0] ms_pc;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [1:0]  unaligned_addr;
wire [2:0]  ms_ld_op;
//exp12
wire [14:0] ms_code;
wire ms_ex_syscall;
wire [31:0] ms_csr_wvalue;
wire ms_csr;
wire ms_ertn_flush;
wire ms_csr_write;
wire [31:0] ms_csr_wmask;
wire [13:0] ms_csr_num;
wire ms_exc_ADEF;
wire ms_exc_INE;
wire ms_exc_ALE;
wire ms_exc_break;
wire ms_has_int;
wire [31:0] ms_vaddr;

reg [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            es_to_ms_bus_reg <= 0;
        else if(ertn_flush || wb_ex)
            es_to_ms_bus_reg <= 0;
        else if(es_to_ms_valid && ms_allow_in)
            es_to_ms_bus_reg <= es_to_ms_bus;
        else
            es_to_ms_bus_reg <= 0;
    end 

assign {ms_vaddr,ms_has_int,ms_exc_break,ms_exc_ALE,ms_exc_INE,ms_exc_ADEF,
        ms_code, ms_ex_syscall, ms_csr_wvalue, ms_csr, ms_ertn_flush, ms_csr_write, ms_csr_wmask, ms_csr_num,
        ms_ld_op,unaligned_addr,ms_alu_result, ms_dest, ms_res_from_mem,
        ms_gr_we, ms_pc} = es_to_ms_bus_reg;

/*-------------------------------------------------------*/

/*----------------------ms_to_ws_bus-----------------*/
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
//task12
assign ms_to_ws_bus[83:70] = ms_csr_num;
assign ms_to_ws_bus[115:84] = ms_csr_wmask;
assign ms_to_ws_bus[116:116] = ms_csr_write;
assign ms_to_ws_bus[117:117] = ms_ertn_flush;
assign ms_to_ws_bus[118:118] = ms_csr;
assign ms_to_ws_bus[150:119] = ms_csr_wvalue;
assign ms_to_ws_bus[151:151] = ms_ex_syscall;
assign ms_to_ws_bus[166:152] = ms_code;
//exp13
assign ms_to_ws_bus[167:167] = ms_exc_ADEF;
assign ms_to_ws_bus[168:168] = ms_exc_INE;
assign ms_to_ws_bus[169:169] = ms_exc_ALE;
assign ms_to_ws_bus[170:170] = ms_exc_break;
assign ms_to_ws_bus[171:171] = ms_has_int;
assign ms_to_ws_bus[203:172] = ms_vaddr;
/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
reg ms_valid;    
wire ms_ready_go;
assign ms_ready_go = 1'b1;
assign ms_allow_in = !ms_valid || ms_ready_go && ws_allow_in;
assign ms_to_ws_valid = (ms_valid && ms_ready_go) & ~ertn_flush & ~wb_ex;

always @(posedge clk)
    begin
        if(reset)
            ms_valid <= 1'b0;
        else if(ms_allow_in)
            ms_valid <= es_to_ms_valid;
    end

/*-------------------------------------------------------*/

/*--------------------ms_to_ds_bus-------------------*/
//task12 add ms_csr_write, ms_csr_num
assign ms_to_ds_bus = {ms_gr_we,ms_dest,ms_final_result,
                       ms_csr_write, ms_csr_num, ms_csr};

/*-------------------------------------------------------*/

/*--------------------deliver if_ms_has_int to es------------------*/
//this signal is for helping ex_stage to judge if it should cancel inst_store due to exception
// in task 12 we just consider syscall
assign if_ms_has_int = ms_ex_syscall | ms_exc_ADEF | ms_exc_INE | ms_exc_ALE | ms_exc_break | ms_ertn_flush;

endmodule