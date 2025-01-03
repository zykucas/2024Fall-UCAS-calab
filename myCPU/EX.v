`include "mycpu_head.vh"

module stage3_EX(
    input clk,
    input reset,

    input ertn_flush,
    input has_int,
    input wb_ex,

    input ms_allow_in,
    output es_allow_in,

    input ds_to_es_valid,
    output es_to_ms_valid,

    input [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,
    output [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,

    input if_ms_has_int,

    output              data_sram_req,
    output              data_sram_wr,
    output [1:0]        data_sram_size,
    output [3:0]        data_sram_wstrb,
    output [31:0]       data_sram_addr,
    output [31:0]       data_sram_wdata,

    input               data_sram_addr_ok,
    input               data_sram_data_ok,

    //port with tlb.v
    output [18:0] s1_vppn,
    output        s1_va_bit12,
    output [9:0]  s1_asid,

    input         s1_found,
    input [3:0]   s1_index,

    //tlb add
    input [18:0] tlbehi_vppn,
    input [9:0]  tlbasid_asid,

    //tlb crush
    input        if_ms_crush_with_tlbsrch,
    input        if_ws_crush_with_tlbsrch,
    input        tlb_reflush,

    //for translate
    input crmd_da,      //��ǰ����ģʽ
    input crmd_pg,

    input [1:0] plv,    //��ǰ��Ȩ�ȼ�, 0-3, 0Ϊ���?
    input [1:0] datm,    //ֱ�ӵ�ַ����ģʽ�£�load/store�����Ĵ洢��������

    input DMW0_PLV0,        //Ϊ1��ʾ��PLV0�¿���ʹ�øô��ڽ���ֱ��ӳ���ַ����?
    input DMW0_PLV3,        //Ϊ1��ʾ��PLV3�¿���ʹ�øô��ڽ���ֱ��ӳ���ַ����?
    input [1:0] DMW0_MAT,   //���ַ���ڸ�ӳ�䴰���·ô�����Ĵ洢���ͷ���
    input [2:0] DMW0_PSEG,  //ֱ��ӳ�䴰��������ַ��3λ
    input [2:0] DMW0_VSEG,  //ֱ��ӳ�䴰�����ַ��?3λ


    input DMW1_PLV0,        
    input DMW1_PLV3,       
    input [1:0] DMW1_MAT,  
    input [2:0] DMW1_PSEG,  
    input [2:0] DMW1_VSEG,

    //input s1_found,
    input [19:0] s1_ppn,
    input [1:0] s1_plv,
    input s1_d,
    input s1_v,
    input [1:0] s1_mat,

    output invtlb_valid,
    output [4:0] invtlb_op,
    
    //dcache add
    output [31:0]  data_addr_vrtl,
    output         data_uncache,

    //exp23 cacop add
    output [4:0] es_cacop_code,
    output cacop_icache,
    output cacop_dcache,
    output [31:0] cacop_addr,
    input  cacop_over_dcache,
    input  cacop_over_icache
);

/*------------------------------------------------------------*/
/*
1: es_ex_loadstore_tlb_refill   TLB��������
2: es_ex_load_invalid           load����ҳ��Ч����
3: es_ex_store_invalid          store����ҳ��Ч����
4: es_ex_loadstore_plv_invalid  ҳ��Ȩ�ȼ����Ϲ�����
5��es_ex_store_dirty               ҳ�޸����� 
*/

wire es_ex_loadstore_tlb_fill;
wire es_ex_load_invalid;
wire es_ex_store_invalid;
wire es_ex_loadstore_plv_invalid;
wire es_ex_store_dirty;

assign s1_vppn = (es_inst_tlbsrch) ? tlbehi_vppn:
                (es_inst_invtlb)?
                 es_rkd_value[31:13] : es_alu_result[31:13];

assign s1_va_bit12 = es_alu_result[12];

assign s1_asid = (es_inst_tlbsrch) ? tlbasid_asid : 
                 (es_inst_invtlb)?
                 es_rj_value[9:0] : tlbasid_asid;
assign invtlb_valid = es_inst_invtlb;
assign invtlb_op    = es_inst_invtlb_op;

/*------------------------------------------------------------*/



parameter   EXE         = 5'b00001;
parameter   DIV_WAIT    = 5'b00010;
parameter   DIVU_WAIT   = 5'b00100;
parameter   OUT_WAIT    = 5'b01000;
parameter   UOUT_WAIT   = 5'b10000;


reg  [4:0]  current_state;
reg  [4:0]  next_state; 
wire [31:0] es_pc;
wire [31:0] es_rj_value;
wire [31:0] es_rkd_value;
wire [31:0] es_imm;
wire [4:0]  es_dest;
wire        es_gr_we;
wire        es_mem_we;
wire [11:0] es_alu_op;
wire        es_src1_is_pc;
wire        es_src2_is_imm;
wire        es_res_from_mem;
wire [2:0]  es_mul_op;
wire [2:0]  es_div_op;

wire [2:0]  es_st_op;
wire [2:0]  es_ld_op;
//exp12
wire [14:0] es_code;
wire        es_ex_syscall;
wire        es_csr;
wire        es_ertn_flush;
wire        es_csr_write;
wire [31:0] es_csr_wmask;
wire [13:0] es_csr_num;
//exp13
wire        es_ex_ADEF;
wire        es_ex_INE;
wire        es_ex_break;
wire        es_rdcntvh_w,es_rdcntvl_w;
wire        es_has_int;
wire [31:0] es_vaddr;
wire        es_ex_ALE;

//task tlb add
wire        es_inst_tlbsrch;
wire        es_inst_tlbrd;
wire        es_inst_tlbwr;
wire        es_inst_tlbfill;
wire        es_inst_invtlb;
wire [4:0]  es_inst_invtlb_op;  
wire        es_tlb_zombie;

//tlb exception
wire        es_ex_fetch_tlb_refill;
wire        es_ex_inst_invalid;
wire        es_ex_fetch_plv_invalid;

//exp23 cacop add
wire es_inst_cacop;
wire [4:0] es_cacop_code;

assign cacop_icache = es_inst_cacop && (es_cacop_code[2:0] == 3'b0) && (es_cacop_code[4:3] != 2'b11);
assign cacop_dcache = es_inst_cacop && (es_cacop_code[2:0] == 3'b1) && (es_cacop_code[4:3] != 2'b11);
assign cacop_addr = (es_cacop_code[4] == 0) ? data_addr_vrtl :
                         (es_cacop_code[4:3] == 2'b10) ? address_p : 0;


wire dividend_ready,dividend_u_ready;
wire dividend_valid,dividend_u_valid;
wire divisor_ready,divisor_u_ready;
wire divisor_valid,divisor_u_valid;
wire out_valid,out_u_valid;
wire [63:0] div_out,div_u_out;
wire inst_div; 

reg [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ds_to_es_bus_reg <= 0;
        else if(ertn_flush || wb_ex || cacop_over_dcache || cacop_over_icache)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        //else if(es_need_wait_div)        
          //  ds_to_es_bus_reg <= ds_to_es_bus_reg;
    end
    
    
always @(posedge clk)begin
    if(reset || (ds_to_es_valid && es_allow_in))
        current_state <= EXE ;
    else
        current_state <= next_state;              
end


always @(*) begin
    case(current_state)
        EXE:
            if(es_div_op[0])begin
                if(es_div_op[1])
                    next_state = DIV_WAIT;
                else
                    next_state = DIVU_WAIT;
            end
            else
                next_state = EXE;
        DIV_WAIT:
            if(dividend_ready & divisor_ready)
                next_state = OUT_WAIT;
            else
                next_state = DIV_WAIT;
        DIVU_WAIT:
            if(dividend_u_ready & divisor_u_ready)
                next_state = UOUT_WAIT;
            else
                next_state = DIVU_WAIT;
        OUT_WAIT:
            if(out_valid)
                next_state = EXE;
            else
                next_state = OUT_WAIT;
        UOUT_WAIT:
            if(out_u_valid)
                next_state = EXE;
            else
                next_state = UOUT_WAIT;
        default:
            next_state = EXE;
    endcase
end

assign  dividend_valid = current_state == DIV_WAIT;
assign  divisor_valid  = current_state == DIV_WAIT;
assign  dividend_u_valid = current_state == DIVU_WAIT ;
assign  divisor_u_valid  = current_state == DIVU_WAIT;
//exp13 global timer
reg [63:0] global_time_cnt;

always @(posedge clk)
    begin
        if(reset)
            global_time_cnt <= 0;
        else if(global_time_cnt == 64'hffffffffffffffff)
            global_time_cnt <= 0;
        else
            global_time_cnt <= global_time_cnt + 1'b1;
    end
/* data from ds_to_es_bus
assign ds_to_es_bus[31:   0] = ds_pc;     
assign ds_to_es_bus[63:  32] = rj_value; 
assign ds_to_es_bus[95:  64] = rkd_value; 
assign ds_to_es_bus[127: 96] = imm;      
assign ds_to_es_bus[132:128] = dest;  
assign ds_to_es_bus[133:133] = gr_we;     
assign ds_to_es_bus[134:134] = mem_we;  
assign ds_to_es_bus[146:135] = alu_op;   
assign ds_to_es_bus[147:147] = src1_is_pc;  
assign ds_to_es_bus[148:148] = src2_is_imm;  
assign ds_to_es_bus[149:149] = res_from_mem; 
assign ds_to_es_bus[152:150] = mul_op;
assign ds_to_es_bus[155:153] = div_op;
assign ds_to_es_bus[158:156] = st_op;
assign ds_to_es_bus[161:159] = ld_op;
//task12
assign ds_to_es_bus[175:162] = ds_csr_num;
assign ds_to_es_bus[207:176] = ds_csr_wmask;
assign ds_to_es_bus[208:208] = ds_csr_write;
assign ds_to_es_bus[209:209] = ds_ertn_flush;
assign ds_to_es_bus[210:210] = ds_csr;
assign ds_to_es_bus[211:211] = ds_ex_syscall;
assign ds_to_es_bus[226:212] = ds_code;
//exp13
assign ds_to_es_bus[227:227] = ds_ex_ADEF;
assign ds_to_es_bus[228:228] = ds_ex_INE;
assign ds_to_es_bus[229:229] = inst_break;
assign ds_to_es_bus[230:230] = inst_rdcntvh_w;
assign ds_to_es_bus[231:231] = inst_rdcntvl_w;
assign ds_to_es_bus[232:232] = has_int;
//task tlb add
assign ds_to_es_bus[233:233] = inst_tlbsrch;
assign ds_to_es_bus[234:234] = inst_tlbrd;
assign ds_to_es_bus[235:235] = inst_tlbwr;
assign ds_to_es_bus[236:236] = inst_tlbfill;
assign ds_to_es_bus[237:237] = inst_invtlb;
assign ds_to_es_bus[242:238] = inst_invtlb_op;
assign ds_to_es_bus[243:243] = ds_tlb_zombie;

//tlb exception
assign ds_to_es_bus[244:244] = ds_ex_fetch_tlb_refill;
assign ds_to_es_bus[245:245] = ds_ex_inst_invalid;
assign ds_to_es_bus[246:246] = ds_ex_fetch_plv_invalid;

*/
assign {es_cacop_code,es_inst_cacop,es_ex_fetch_plv_invalid, es_ex_inst_invalid, es_ex_fetch_tlb_refill, es_tlb_zombie,
        es_inst_invtlb_op, es_inst_invtlb, es_inst_tlbfill, es_inst_tlbwr, es_inst_tlbrd, es_inst_tlbsrch,
        es_has_int, es_rdcntvl_w, es_rdcntvh_w, es_ex_break, es_ex_INE, es_ex_ADEF,
        es_code, es_ex_syscall, es_csr, es_ertn_flush, es_csr_write, es_csr_wmask, es_csr_num,
        es_ld_op, es_st_op, es_div_op, es_mul_op, es_res_from_mem, es_src2_is_imm,
        es_src1_is_pc, es_alu_op, es_mem_we, es_gr_we, es_dest, es_imm,
        es_rkd_value, es_rj_value, es_pc} = ds_to_es_bus_reg;

assign inst_div = es_div_op[0];

wire [31:0] es_cal_result;
wire [31:0] es_div_result,es_div_signed,es_div_unsigned;
wire [31:0] es_mod_result,es_mod_signed,es_mod_unsigned;
wire [31:0] es_mul_result;
wire [31:0] es_alu_result;

assign es_cal_result = es_rdcntvl_w ? global_time_cnt[31:0] : es_rdcntvh_w ? global_time_cnt[63:32] :
            es_div_op[0] ? (es_div_op[2] ? es_div_result:es_mod_result ):
            ((es_mul_op != 0) ? es_mul_result : es_alu_result);
assign es_div_result = es_div_op[1] ? es_div_signed : es_div_unsigned;
assign es_mod_result = es_div_op[1] ? es_mod_signed : es_mod_unsigned;

//task 11 add Unaligned memory access, we should deliver unaligned info
wire [1:0] es_unaligned_addr;
assign es_unaligned_addr = address_p[1:0];


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
/*when st, we need raise ms_ready_go when data_ok*/
/*so we need to tell ms that it's a st inst*/
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



wire [31:0] cal_src1;
wire [31:0] cal_src2;

assign cal_src1 = es_src1_is_pc  ? es_pc[31:0] : es_rj_value;   
assign cal_src2 = es_src2_is_imm ? es_imm : es_rkd_value;        

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (cal_src1  ),
    .alu_src2   (cal_src2  ),
    .alu_result (es_alu_result)
    );

mul u_mul(
    .mul_op     (es_mul_op    ),
    .mul_src1   (es_rj_value  ),
    .mul_src2   (es_rkd_value  ),
    .mul_result (es_mul_result)
    );    

//assign es_allow_in = (current_state == EXE);


div_signed u_div_w(
        .aclk(clk),
        .s_axis_dividend_tdata(es_rj_value),
        .s_axis_dividend_tready(dividend_ready),
        .s_axis_dividend_tvalid(dividend_valid),
        .s_axis_divisor_tdata(es_rkd_value),
        .s_axis_divisor_tready(divisor_ready),
        .s_axis_divisor_tvalid(divisor_valid),
        .m_axis_dout_tdata(div_out),
        .m_axis_dout_tvalid(out_valid)
    );
assign {es_div_signed,es_mod_signed} = div_out;

div_unsigned u_div_wu(
        .aclk(clk),
        .s_axis_dividend_tdata(es_rj_value),
        .s_axis_dividend_tready(dividend_u_ready),
        .s_axis_dividend_tvalid(dividend_u_valid),
        .s_axis_divisor_tdata(es_rkd_value),
        .s_axis_divisor_tready(divisor_u_ready),
        .s_axis_divisor_tvalid(divisor_u_valid),
        .m_axis_dout_tdata(div_u_out),
        .m_axis_dout_tvalid(out_u_valid)
    );
assign {es_div_unsigned,es_mod_unsigned} = div_u_out;

/*-------------------------valid-------------------------*/
wire no_exception;
assign no_exception = ~if_es_has_int && ~if_ms_has_int && ~wb_ex && ~es_has_int;
wire if_es_has_int;
assign if_es_has_int = es_ex_syscall || es_ertn_flush || es_ex_ADEF || es_ex_ALE || es_ex_INE || es_ex_break || es_has_int 
                || es_ex_fetch_tlb_refill || es_ex_inst_invalid || es_ex_fetch_plv_invalid
                || es_ex_loadstore_tlb_fill || es_ex_load_invalid || es_ex_store_invalid
                || es_ex_loadstore_plv_invalid || es_ex_store_dirty ;
// ��MS����allowin1ʱ�ٷ���req����Ϊ�˱�֤req��addr_ok����ʱallowinҲ������
// ��es��ˮ����ms,ws���쳣ʱ��ֹ�ô棬Ϊ��ά����ȷ�쳣
assign data_sram_req = (ms_allow_in && no_exception) && (es_res_from_mem || es_mem_we) && es_valid;

reg es_valid;
always @(posedge clk)
    begin
        if(reset)
            es_valid <= 1'b0;
        else if(es_allow_in)
            es_valid <= ds_to_es_valid;
    end    

wire es_ready_go;

assign es_ready_go = es_inst_cacop ? (cacop_over_dcache | cacop_over_icache) :
                     block_with_tlbsrch ? 1'b0 :
                     if_es_has_int ? 1'b1 : 
                     (es_mem_we || es_res_from_mem) ? (data_sram_req && data_sram_addr_ok) : 
                     (!es_div_op[0] | (current_state==OUT_WAIT & out_valid | current_state==UOUT_WAIT & out_u_valid)) ;//��ȷ���Ƿ����߼�����

assign es_allow_in = (!es_valid || es_ready_go && ms_allow_in &&
                      (current_state == EXE | current_state==OUT_WAIT & out_valid | current_state==UOUT_WAIT & out_u_valid));

assign es_to_ms_valid = es_valid && es_ready_go;

wire block_with_tlbsrch;
assign block_with_tlbsrch = es_inst_tlbsrch && (if_ms_crush_with_tlbsrch || if_ws_crush_with_tlbsrch);

//task 11 add Unaligned memory access, so addr[1:0] should be 2'b00
wire [3:0] w_strb;  //depend on st_op
/* st_op = (one hot)
* 3'b001 st_w
* 3'b010 st_b
* 5'b100 st_h
*/
assign w_strb =  es_st_op[0] ? 4'b1111 :
                 es_st_op[1] ? (es_unaligned_addr==2'b00 ? 4'b0001 : es_unaligned_addr==2'b01 ? 4'b0010 : 
                                es_unaligned_addr==2'b10 ? 4'b0100 : 4'b1000) : 
                 es_st_op[2] ? (es_unaligned_addr[1] ? 4'b1100 : 4'b0011) : 4'b0000;

//consider st_b, st_h
wire [31:0] real_wdata;
assign real_wdata = es_st_op[0] ? es_rkd_value :
                    es_st_op[1] ? {4{es_rkd_value[7:0]}} :
                    es_st_op[2] ? {2{es_rkd_value[15:0]}} : 32'b0;

/*----------------------------------------------------------------------*/

wire [31:0] address_dt;     //dt --> directly translate
assign address_dt = es_vaddr;

wire [31:0] address_dmw0;
assign address_dmw0 = {DMW0_PSEG, es_vaddr[28:0]};

wire [31:0] address_dmw1;
assign address_dmw1 = {DMW1_PSEG, es_vaddr[28:0]};

wire [31:0] address_ptt;
assign address_ptt = {s1_ppn, es_vaddr[11:0]};

wire if_dt;
assign if_dt = crmd_da & ~crmd_pg;   //da=1, pg=0 --> ֱ�ӵ�ַ����ģʽ

wire if_indt;
assign if_indt = ~crmd_da & crmd_pg;   //da=0, pg=1 --> ӳ���ַ����ģ�?

wire if_dmw0;
assign if_dmw0 = ((plv == 0 && DMW0_PLV0) || (plv == 3 && DMW0_PLV3)) &&
                    (es_vaddr[31:29] == DMW0_VSEG);
                    
wire if_dmw1;
assign if_dmw1 = ((plv == 0 && DMW1_PLV0) || (plv == 3 && DMW1_PLV3)) &&
                    (es_vaddr[31:29] == DMW1_VSEG);

wire if_ppt;
assign if_ppt = if_indt & ~(if_dmw0 | if_dmw1);

wire [31:0] address_p;
assign address_p = if_dt ? address_dt : if_indt ?
                (if_dmw0 ? address_dmw0 : if_dmw1 ? address_dmw1 : address_ptt) : 0;
//uncache
assign data_uncache = ~(if_dt ? datm[0]:(if_indt ? 
                (if_dmw0 ? DMW0_MAT[0] : if_dmw1 ? DMW1_MAT[0] : s1_mat[0] ) : 1'b1));

// tlb exception

assign es_ex_loadstore_tlb_fill = (if_ppt & (es_res_from_mem | es_mem_we | es_inst_cacop) & ~s1_found);
assign es_ex_load_invalid = if_ppt & (es_res_from_mem | es_inst_cacop) & s1_found & ~s1_v;
assign es_ex_store_invalid = if_ppt & es_mem_we & s1_found & ~s1_v;
assign es_ex_loadstore_plv_invalid = if_ppt & (es_res_from_mem | es_mem_we) & s1_found
                                    & s1_v & (plv > s1_plv);
assign es_ex_store_dirty = if_ppt & es_mem_we & s1_found & s1_v & ~s1_d & ((plv < s1_plv) | (plv == s1_plv));
//                            (plv == 2'b00 || (plv == 2'b01 &&(s1_plv == 2'b01 || s1_plv == 2'b10 || s1_plv == 2'b11)) ||
//                            (plv == 2'b10 &&( s1_plv == 2'b10 || s1_plv == 2'b11)) ||
//                            (plv == 2'b11 &&(s1_plv == 2'b11)) );

/*----------------------------------------------------------------------*/


/*
    output              data_sram_req,
    output              data_sram_wr,
    output [1:0]        data_sram_size,
    output [3:0]        data_sram_wstrb,
    output [31:0]       data_sram_addr,
    output [31:0]       data_sram_wdata,
*/

assign data_sram_wr = es_mem_we;
assign data_sram_size = es_mem_we ? 
                        (es_st_op[0] ? 2'b10 :  //st_w  
                         es_st_op[1] ? 2'b00 :  //st_b
                         es_st_op[2] ? 2'b01 : 2'b00)
                        :
                        es_res_from_mem ?
                        ((es_ld_op == 0) ? 2'b10 :  //ld_w
                         es_ld_op[0] ? 2'b00 :  //ld_b. ld_bu
                         es_ld_op[1] ? 2'b01 : 2'b00) //ld_h, ld_hu
                        :
                        2'b00;   
assign data_sram_wstrb = es_st_op[0] ? 4'b1111 :
                         es_st_op[1] ? (es_unaligned_addr==2'b00 ? 4'b0001 : 
                                        es_unaligned_addr==2'b01 ? 4'b0010 : 
                                        es_unaligned_addr==2'b10 ? 4'b0100 : 4'b1000) : 
                         es_st_op[2] ? (es_unaligned_addr[1] ? 4'b1100 : 4'b0011) : 4'b0000;
//assign data_sram_addr  = (es_mul_op != 0) ? {es_mul_result[31:2],2'b00} : {es_alu_result[31:2],2'b00};
assign data_sram_addr  = address_p;
assign data_sram_wdata = real_wdata;      

//exp13 ALE exception
wire ld_st_w,ld_st_h;
assign ld_st_w = es_st_op[0] | (es_ld_op[1:0] == 2'b0 & es_res_from_mem);
assign ld_st_h = es_st_op[2] | es_ld_op[1];
assign es_ex_ALE = ((ld_st_w & (es_unaligned_addr != 2'b0))
            | (ld_st_h & (es_unaligned_addr[0]))) & es_valid;

//assign es_vaddr = (es_mul_op != 0) ? es_mul_result : es_alu_result;
assign es_vaddr = es_alu_result;
/*-----------------------deliver es_to_ds_bus----------------*/

wire if_es_load;   //if inst is load --> which means forward needs block for one clk
assign if_es_load = es_res_from_mem;
//task12 add es_csr_write, es_csr_num
assign es_to_ds_bus = {es_valid,es_gr_we,es_dest,if_es_load,es_cal_result,
                       es_csr_write, es_csr_num, es_csr};

//dcache add
assign data_addr_vrtl = es_vaddr;


endmodule