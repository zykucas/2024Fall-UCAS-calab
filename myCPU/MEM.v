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

    input        data_sram_data_ok,
    input [31:0] data_sram_rdata,

    //tlb crush
    output       if_ms_crush_with_tlbsrch,
    input        tlb_reflush
);

/*-----------------------接收es_to_ms_bus----------------*/
/*
assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we & ~es_ex_ALE &
                             ~es_ex_load_invalid & ~es_ex_loadstore_plv_invalid & ~es_ex_loadstore_tlb_fill &
                             ~es_ex_store_invalid & ~es_ex_store_dirty ; 
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
assign es_to_ms_bus[173:173] = es_ex_ADEF;
assign es_to_ms_bus[174:174] = es_ex_INE;
assign es_to_ms_bus[175:175] = es_ex_ALE;
assign es_to_ms_bus[176:176] = es_ex_break;
assign es_to_ms_bus[177:177] = es_has_int;
assign es_to_ms_bus[209:178] = es_vaddr;
//exp14
assign es_to_ms_bus[210:210] = es_mem_we;
//tlb add
assign es_to_ms_bus[211:211] = es_inst_tlbsrch;
assign es_to_ms_bus[212:212] = es_inst_tlbrd;
assign es_to_ms_bus[213:213] = es_inst_tlbwr;
assign es_to_ms_bus[214:214] = es_inst_tlbfill;
assign es_to_ms_bus[215:215] = es_inst_invtlb;

assign es_to_ms_bus[216:216] = s1_found;    //tlbsrch got
assign es_to_ms_bus[220:217] = s1_index;    //tlbsrch index

assign es_to_ms_bus[225:221] = es_inst_invtlb_op;
assign es_to_ms_bus[226:226] = es_tlb_zombie;

assign es_to_ms_bus[236:227] = es_rj_value[9:0];

//tlb exception
assign es_to_ms_bus[237:237] = es_ex_fetch_tlb_refill;
assign es_to_ms_bus[238:238] = es_ex_inst_invalid;
assign es_to_ms_bus[239:239] = es_ex_fetch_plv_invalid;
assign es_to_ms_bus[240:240] = es_ex_loadstore_tlb_fill;
assign es_to_ms_bus[241:241] = es_ex_load_invalid;
assign es_to_ms_bus[242:242] = es_ex_store_invalid;
assign es_to_ms_bus[243:243] = es_ex_loadstore_plv_invalid;
assign es_to_ms_bus[244:244] = es_ex_store_dirty;

*/

wire [31:0] ms_pc;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [1:0]  ms_unaligned_addr;
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
wire ms_ex_ADEF;
wire ms_ex_INE;
wire ms_ex_ALE;
wire ms_ex_break;
wire ms_has_int;
wire [31:0] ms_vaddr;
wire        ms_mem_we;


//tlb add
wire        ms_inst_tlbsrch;
wire        ms_inst_tlbrd;
wire        ms_inst_tlbwr;
wire        ms_inst_tlbfill;
wire        ms_inst_invtlb;

wire        ms_s1_found;
wire [3:0]  ms_s1_index;

wire [4:0]  ms_inst_invtlb_op;
wire        ms_tlb_zombie;
wire [9:0]  ms_s1_asid;

//tlb exception
wire ms_ex_fetch_tlb_refill;
wire ms_ex_inst_invalid;
wire ms_ex_fetch_plv_invalid;
wire ms_ex_loadstore_tlb_fill;
wire ms_ex_load_invalid;
wire ms_ex_store_invalid;
wire ms_ex_loadstore_plv_invalid;
wire ms_ex_store_dirty;


reg [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            es_to_ms_bus_reg <= 0;
        else if(ertn_flush || wb_ex || tlb_reflush)
            es_to_ms_bus_reg <= 0;
        else if(es_to_ms_valid && ms_allow_in)
            es_to_ms_bus_reg <= es_to_ms_bus;
        //else
          //  es_to_ms_bus_reg <= 0;
    end 
//exp14
//加入ms_mem_we
assign { ms_ex_store_dirty, ms_ex_loadstore_plv_invalid, ms_ex_store_invalid,
        ms_ex_load_invalid, ms_ex_loadstore_tlb_fill, ms_ex_fetch_plv_invalid,
        ms_ex_inst_invalid, ms_ex_fetch_tlb_refill,
        ms_s1_asid, ms_tlb_zombie,
        ms_inst_invtlb_op,ms_s1_index, ms_s1_found, ms_inst_invtlb, ms_inst_tlbfill, ms_inst_tlbwr, ms_inst_tlbrd, ms_inst_tlbsrch,
        ms_mem_we, ms_vaddr, ms_has_int, ms_ex_break, ms_ex_ALE, ms_ex_INE, ms_ex_ADEF,
        ms_code, ms_ex_syscall, ms_csr_wvalue, ms_csr, ms_ertn_flush, ms_csr_write, ms_csr_wmask, ms_csr_num,
        ms_ld_op, ms_unaligned_addr, ms_alu_result, ms_dest,
        ms_res_from_mem, ms_gr_we, ms_pc} = es_to_ms_bus_reg;

/*-------------------------------------------------------*/

/*----------------------ms_to_ws_bus-----------------*/
wire [31:0] mem_result;
wire [31:0] load_b_res,load_h_res;
assign load_b_res   = (ms_unaligned_addr == 2'h0) ? {{ms_ld_op[2]?{24{data_sram_rdata[7]}}:24'b0} ,data_sram_rdata[7:0]}
        :(ms_unaligned_addr == 2'h1) ? {{ms_ld_op[2]?{24{data_sram_rdata[15]}}:24'b0},data_sram_rdata[15:8]}
        :(ms_unaligned_addr == 2'h2) ? {{ms_ld_op[2]?{24{data_sram_rdata[23]}}:24'b0},data_sram_rdata[23:16]}
        :(ms_unaligned_addr == 2'h3) ? {{ms_ld_op[2]?{24{data_sram_rdata[31]}}:24'b0},data_sram_rdata[31:24]} : 32'b0;
assign load_h_res   = (ms_unaligned_addr[1]) ? {{ms_ld_op[2]?{16{data_sram_rdata[31]}}:16'b0} ,data_sram_rdata[31:16]}
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
assign ms_to_ws_bus[167:167] = ms_ex_ADEF;
assign ms_to_ws_bus[168:168] = ms_ex_INE;
assign ms_to_ws_bus[169:169] = ms_ex_ALE;
assign ms_to_ws_bus[170:170] = ms_ex_break;
assign ms_to_ws_bus[171:171] = ms_has_int;
assign ms_to_ws_bus[203:172] = ms_vaddr;

//tlb add
assign ms_to_ws_bus[204:204] = ms_inst_tlbsrch;
assign ms_to_ws_bus[205:205] = ms_inst_tlbrd;
assign ms_to_ws_bus[206:206] = ms_inst_tlbwr;
assign ms_to_ws_bus[207:207] = ms_inst_tlbfill;
assign ms_to_ws_bus[208:208] = ms_inst_invtlb;

assign ms_to_ws_bus[209:209] = ms_s1_found;    //tlbsrch got
assign ms_to_ws_bus[213:210] = ms_s1_index;    //tlbsrch index

assign ms_to_ws_bus[218:214] = ms_inst_invtlb_op;
assign ms_to_ws_bus[219:219] = ms_tlb_zombie;
assign ms_to_ws_bus[229:220] = ms_s1_asid;

assign ms_to_ws_bus[230:230] = ms_ex_fetch_tlb_refill;
assign ms_to_ws_bus[231:231] = ms_ex_inst_invalid;
assign ms_to_ws_bus[232:232] = ms_ex_fetch_plv_invalid;
assign ms_to_ws_bus[233:233] = ms_ex_loadstore_tlb_fill;
assign ms_to_ws_bus[234:234] = ms_ex_load_invalid;
assign ms_to_ws_bus[235:235] = ms_ex_store_invalid;
assign ms_to_ws_bus[236:236] = ms_ex_loadstore_plv_invalid;
assign ms_to_ws_bus[237:237] = ms_ex_store_dirty;


/*-------------------------------------------------------*/

/*--------------------------valid------------------------*/
reg ms_valid;    
wire ms_ready_go;
//exp14
//当是load指令时，需要等待数据握手
//data_ok拉高时表示store已经写入数据 或 load已经取到数据，将ms_ready_go拉高
assign ms_ready_go = if_ms_has_int ? 1'b1 : (ms_mem_we || ms_res_from_mem) ? data_sram_data_ok : 1'b1;
assign ms_allow_in = !ms_valid || ms_ready_go && ws_allow_in;
assign ms_to_ws_valid = (ms_valid && ms_ready_go) & ~ertn_flush & ~wb_ex & ~tlb_reflush;

always @(posedge clk)
    begin
        if(reset)
            ms_valid <= 1'b0;
        else if(ms_allow_in)
            ms_valid <= es_to_ms_valid;
    end


/*--------------------deliver ms_to_ds_bus-------------------*/

//task12 add ms_csr_write, ms_csr_num

wire if_ms_load;
assign if_ms_load = ms_res_from_mem;
assign ms_to_ds_bus = {ms_to_ws_valid,ms_valid,ms_gr_we,ms_dest,if_ms_load,ms_final_result,
                       ms_csr_write, ms_csr_num, ms_csr};

/*--------------------deliver if_ms_has_int to es------------------*/

//this signal is for helping ex_stage to judge if it should cancel inst_store due to exception
// in task 12 we just consider syscall
assign if_ms_has_int = ms_ex_syscall || ms_ertn_flush || ms_ex_ADEF || ms_ex_INE || ms_ex_ALE || ms_ex_break || ms_has_int
                || ms_ex_fetch_tlb_refill || ms_ex_inst_invalid || ms_ex_fetch_plv_invalid
                || ms_ex_loadstore_tlb_fill || ms_ex_load_invalid || ms_ex_store_invalid
                || ms_ex_loadstore_plv_invalid || ms_ex_store_dirty ;

//tlb add
/*-------------------deliver if_ms_crush_tlbsrch---------------------*/
wire if_csr_crush_with_tlbsrch;

assign if_csr_crush_with_tlbsrch = ms_csr_write && (ms_csr_num == `CSR_ASID 
                                                    || ms_csr_num == `CSR_TLBEHI);

wire if_tlbrd_crush_with_tlbsrch;

assign if_tlbrd_crush_with_tlbsrch = ms_inst_tlbrd;

assign if_ms_crush_with_tlbsrch = if_csr_crush_with_tlbsrch
                                || if_tlbrd_crush_with_tlbsrch;

/*-------------------------------------------------------*/
endmodule