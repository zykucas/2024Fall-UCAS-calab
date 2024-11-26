`include "mycpu_head.vh"
module csr_reg(
    input                         clk,
    input                         reset,

    input [`WIDTH_CSR_NUM-1:0]     csr_num,           //寄存器号

    input                         csr_re,            //读使�?
    output             [31:0]     csr_rvalue,        //读数�?
    output             [31:0]     ertn_pc,
    output             [31:0]     ex_entry,
    output             [31:0]     ex_tlbentry,

    input                         csr_we,            //写使�?
    input              [31:0]     csr_wmask,         //写掩�?
    input              [31:0]     csr_wvalue,        //写数�?

    input                         wb_ex,             //写回级异�?
    input              [31:0]     wb_pc,             //异常pc
    input                         ertn_flush,        //ertn指令执行有效信号
    input              [5:0]      wb_ecode,          //异常类型1级码
    input              [8:0]      wb_esubcode,       //异常类型2级码
    input              [31:0]     wb_vaddr, 
    input                         if_fetch_plv_ex,
    input                         if_fetch_tlb_refill,
    input              [31:0]     coreid_in,

    output                        has_int,
    input              [7:0]      hw_int_in,
    input                         ipi_int_in,

    //tlb info
    //1:TLBIDX
    output             [3:0]      tlbidx_index,
    output             [5:0]      tlbidx_ps,
    output                        tlbidx_ne,

    //2:TLBEHI
    output             [18:0]     tlbehi_vppn,

    //3:TLBELO0
    output                        tlbelo0_v,
    output                        tlbelo0_d,
    output             [1:0]      tlbelo0_plv,
    output             [1:0]      tlbelo0_mat,
    output                        tlbelo0_g,
    output             [19:0]     tlbelo0_ppn,

    //4:TLBELO1
    output                        tlbelo1_v,
    output                        tlbelo1_d,
    output             [1:0]      tlbelo1_plv,
    output             [1:0]      tlbelo1_mat,
    output                        tlbelo1_g,
    output             [19:0]     tlbelo1_ppn,

    //5:ASID
    output             [9:0]      tlbasid_asid,

    //for tlbsrch
    input        inst_tlbsrch,
    input        tlbsrch_got,        //tlbsrch 命中了表�?
    input [3:0]  tlbsrch_index,

    //for tlbrd
    input        inst_tlbrd,         
    input        tlbrd_valid,        //tlbrd 指定位置是有效TLB�?

    input [18:0] tlbrd_tlbehi_vppn,

    input [19:0] tlbrd_tlbelo0_ppn,
    input        tlbrd_tlbelo0_g,
    input [1:0]  tlbrd_tlbelo0_mat,
    input [1:0]  tlbrd_tlbelo0_plv,
    input        tlbrd_tlbelo0_d,
    input        tlbrd_tlbelo0_v,

    input [19:0] tlbrd_tlbelo1_ppn,
    input        tlbrd_tlbelo1_g,
    input [1:0]  tlbrd_tlbelo1_mat,
    input [1:0]  tlbrd_tlbelo1_plv,
    input        tlbrd_tlbelo1_d,
    input        tlbrd_tlbelo1_v,

    input [5:0]  tlbrd_tlbidx_ps,
    input [9:0]  tlbrd_asid_asid,

    //for exception
    input        ex_tlb_refill,

    //guchaoyang add
    output [1:0] crmd_plv,
    output       crmd_da,
    output       crmd_pg,
    output [1:0] crmd_datf,
    output [1:0] crmd_datm,

    //6:DMW
    output       tlbdmw0_plv0,
    output       tlbdmw0_plv3,
    output [1:0] tlbdmw0_mat,
    output [2:0] tlbdmw0_pseg,
    output [2:0] tlbdmw0_vseg,

    output       tlbdmw1_plv0,
    output       tlbdmw1_plv3,
    output [1:0] tlbdmw1_mat,
    output [2:0] tlbdmw1_pseg,
    output [2:0] tlbdmw1_vseg,

    output [5:0] stat_ecode
);

/*
寄存器号�?
`define CSR_CRMD 0x0
`define CSR_PRMD 0x1
`define CSR_ECFG 0x4
`define CSR_ESTAT 0x5
`define CSR_ERA 0x6
`define CSR_BADV 0x7
`define CSR_EENTRY 0xc
`define CSR_ASID 0x18
`define CSR_SAVE0 0x30
`define CSR_SAVE1 0x31
`define CSR_SAVE2 0x32
`define CSR_SAVE3 0x33
`define CSR_TID 0x40
`define CSR_TCFG 0x41
`define CSR_TVAL 0x42
`define CSR_TICLR 0x44
*/

/*
CSR分区
*/

/*--------------------------当前模式信息 CRMD-------------------------*/


//当前特权等级
/*
2'b00: �?高特权级  2'b11：最低特权等�?
触发特例时应将plv设为0，确保陷入后处于内核态最高特权等�?
当执行ERTN指令从例外处理程序返回时，讲CSR_PRMD[PPLV] --> CSR_CRMD[PLV]
*/
reg [1:0] csr_crmd_plv;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_plv <= 2'b0;
        else if(wb_ex)
            csr_crmd_plv <= 2'b0;
        else if(ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                         | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
    end

assign crmd_plv = csr_crmd_plv;

//当前全局中断使能
/*
1'b1：可中断    1'b0：屏蔽中�?
当触发例外时，硬件置�?0，确保陷入后屏蔽中断
例外处理程序决定重新�?启中断响应时，显示设1
当执行ERTN指令从例外处理程序返回时，讲CSR_PRMD[IE] --> CSR_CRMD[IE]
*/
reg csr_crmd_ie;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_ie <= 1'b0;
        else if(wb_ex)
            //进入中断后，关闭中断使能
            csr_crmd_ie <= 1'b0;
        else if(ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end

//直接地址翻译使能 --> 初始化置�?1
reg csr_crmd_da;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_da <= 1'b1;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                        | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        else if(ex_tlb_refill)
            //触发TLB重填例外时，硬件将da设为1
            csr_crmd_da <= 1'b1;
        else if(ertn_flush && csr_estat_ecode == 6'h3f)
            csr_crmd_da <= 1'b0;
    end

reg csr_crmd_pg;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_pg <= 1'b0;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                        | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        else if(ex_tlb_refill)
            csr_crmd_pg <= 1'b0;
        else if(ertn_flush && csr_estat_ecode == 6'h3f)
            csr_crmd_pg <= 1'b1;
    end

reg [1:0] csr_crmd_datf;
reg [1:0] csr_crmd_datm;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_datf <= 2'b00;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]
                        | ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
    end

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_datm <= 2'b00;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]
                        | ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
    end

reg [22:0] csr_crmd_zero;

assign   crmd_da    = csr_crmd_da;
assign   crmd_pg    = csr_crmd_pg;
assign   crmd_datf  = csr_crmd_datf;
assign   crmd_datm  = csr_crmd_datm;


/*---------------------------------------------------------------------*/

/*--------------------------例外前模式信�? PRMD-------------------------*/

reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;

always @(posedge clk)
    begin
        if(wb_ex)
            begin
                csr_prmd_pplv <= csr_crmd_plv;
                csr_prmd_pie  <= csr_crmd_ie;
            end
        else if(csr_we && csr_num == `CSR_PRMD)
            begin
                csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                              | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
                csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                              | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
            end
    end

//暂未使用�?
reg [28:0] reg_prmd_zero;

/*---------------------------------------------------------------------*/

/*--------------------------例外控制 ECFG-------------------------------*/

//控制各中断的�?部使能位
/*
1'b1：可中断    1'b0：屏蔽中�?
�?10位局部中断使能位与CSR_ESTAT中IS[9:0]域记录的10个中断源�?�?对应
12:11位局部中断使能位与CSR_ESTAT中IS[12:11]域记录的2个中断源�?�?对应
*/
reg [12:0] csr_ecfg_lie;

always @(posedge clk)
    begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)begin
            csr_ecfg_lie[`CSR_ECFG_LIE_9_0] <= csr_wmask[`CSR_ECFG_LIE_9_0] & csr_wvalue[`CSR_ECFG_LIE_9_0]
                         | ~csr_wmask[`CSR_ECFG_LIE_9_0] & csr_ecfg_lie[`CSR_ECFG_LIE_9_0];
            csr_ecfg_lie[`CSR_ECFG_LIE_12_11] <= csr_wmask[`CSR_ECFG_LIE_12_11] & csr_wvalue[`CSR_ECFG_LIE_12_11]
                         | ~csr_wmask[`CSR_ECFG_LIE_12_11] & csr_ecfg_lie[`CSR_ECFG_LIE_12_11];
        end
        else begin
            csr_ecfg_lie <= csr_ecfg_lie;
        end
    end

//暂未使用�?
reg [18:0] csr_ecfg_zero;

/*---------------------------------------------------------------------*/

/*--------------------------例外状�?? ESTAT-------------------------------*/

//2个软中断状�?�位�? 0�?1比特分别对应SWI0 �? SWI1
//8个硬中断状�?�位�? 2�?9比特分贝对应HWI0 �? HWI7
//1个保留域
//�?11位对应定时器中断TI的状态位
//�?12位对应核间中�?
reg [12:0] csr_estat_is;
always @(posedge clk)
    begin
        //软中断位 -- RW
        if(reset)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= 2'b0;
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_wvalue[`CSR_ESTAT_IS_SOFT]
                              | ~csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_estat_is[`CSR_ESTAT_IS_SOFT] ;

        //硬中断位 -- R
        csr_estat_is[`CSR_ESTAT_IS_HARD] <= hw_int_in[7:0];

        //保留�?
        csr_estat_is[`CSR_ESTAT_IS_LEFT1] <= 1'b0;

        //时钟中断 -- R 但是写CSR_TICLR_CLR可改变CSR_ESTAT_IS_TI
        if(timer_cnt[31:0] == 32'b0)
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b1;
        else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
                && csr_wvalue[`CSR_TICLR_CLR])
            //对CSR_TICLR定时中断清除寄存器的CLR位写1 代表 清除时钟中断标记
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b0;

        //核间中断标记
        csr_estat_is[`CSR_ESTAT_IS_IPI] <= ipi_int_in;
    end

//保留�?
reg [2:0] csr_estat_left;

//中断类型1�?2级编�?
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;
assign stat_ecode = csr_estat_ecode;
always @(posedge clk)
    begin
        if(wb_ex)
            begin
                csr_estat_ecode <= wb_ecode;
                csr_estat_esubcode <= wb_esubcode;
            end
    end

//暂未使用�?
reg csr_estat_zero;

/*---------------------------------------------------------------------*/

/*-----------------------例外返回地址 ERA-------------------------------*/

//触发例外的指令PC将被记录在EPC寄存�?
reg [31:0] csr_era_pc;

always @(posedge clk)
    begin
        if(wb_ex)
            csr_era_pc <= wb_pc;
        else if(csr_we && csr_num == `CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                       | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc; 
    end

/*---------------------------------------------------------------------*/

/*-----------------------出错虚地�? BADV-------------------------------*/

//触发地址错误相关例外时，记录出错的虚地址
reg [31:0] csr_badv_vaddr;

wire wb_ex_addr_err;
/*
ECODE_ADEF: 取�?�地�?错例�?
ECODE_ADEM：访存指令地�?错例�?
ECODE_ALE：地�?非对齐例�?
*/
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE) || 
                        (wb_ecode == `ECODE_TLBR) || (wb_ecode == `ECODE_PIL) ||
                        (wb_ecode == `ECODE_PIS) || (wb_ecode == `ECODE_PIF) ||
                        (wb_ecode == `ECODE_PME) || (wb_ecode == `ECODE_PPI);

always @(posedge clk)
    begin
        if(wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= ((wb_ecode == `ECODE_ADE && wb_esubcode == `ESUBCODE_ADEF) || 
                              (wb_ecode == `ECODE_PIF) ||
                              (wb_ecode == `ECODE_PPI && if_fetch_plv_ex) ||
                              (wb_ecode == `ECODE_TLBR && if_fetch_tlb_refill))
                               ? wb_pc : wb_vaddr;
    end

/*---------------------------------------------------------------------*/

/*-----------------------例外入口地址 EENTRY-------------------------------*/

//EENTRY用于配置除TLB充填例外之外的例外和中断的入口地�?
//只能由CSR指令更新
reg [5:0] csr_eentry_zero;
reg [25:0] csr_eentry_va;

always @(posedge clk)
    begin
        if(reset)
            csr_eentry_zero <= 6'b0;
    end

always @(posedge clk)
    begin
        if(csr_we && csr_num == `CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                          | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end
/*---------------------------------------------------------------------*/

/*-----------------------临时寄存�? SAVE0-3-------------------------------*/

reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

always @(posedge clk)
    begin
        if(csr_we && csr_num == `CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;

        if(csr_we && csr_num == `CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;

        if(csr_we && csr_num == `CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;

        if(csr_we && csr_num == `CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end

/*---------------------------------------------------------------------*/

/*-----------------------定时器编号寄存器 TID-------------------------------*/

//定时器编号寄存器
reg [31:0] csr_tid_tid;

always @(posedge clk)
    begin
        if(reset)
            csr_tid_tid <= coreid_in;
        else if(csr_we && csr_num == `CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

/*---------------------------------------------------------------------*/

/*-----------------------定时器配置寄存器 TCFG-------------------------------*/

//定时器使能位，en�?1时定时器才会进行倒计时自�?，并在减�?0时置起定时中断信�?
reg csr_tcfg_en;
//定时器循环模式控制位，为1时会循环
reg csr_tcfg_periodic;
//定时器�?�计时自减计数的初始�?
reg [29:0] csr_tcfg_initval;

always @(posedge clk)
    begin
        if(reset)
            csr_tcfg_en <= 1'b0;
        else if(csr_we && csr_num == `CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if(csr_we && csr_num == `CSR_TCFG)
            begin
                csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC]
                                | ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
                csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL]
                                | ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
            end
    end

/*---------------------------------------------------------------------*/

/*-----------------------TVAL的TimeVal�?-------------------------------*/

wire [31:0] tcfg_cur_value;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg  [31:0] timer_cnt;

/*
这里用两个wire类型信号定义cur_tcfg �? next_tcfg
是为了能在当软件�?启timer的使能的同时发起timer_cnt的更新操�?
即在下面的时序�?�辑中的
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        将此时写入的timer配置寄存器的定时器初始�?�更新到timer_cnt�?

因为是在软件写TCFG的同时更新timer�?
�?以要看当前写入TCFG寄存器的�?(next_value)，�?�不是用cur_value
*/

/*
当timer_cnt减到�?0且定时器不是周期性工作模式情况下�?
timer_cnt继续�?1变成32'hffffffff,之后应当停止即使�?
�?以timer_cnt自减的条件包含timer_cnt!=32'hffffffff

周期性工作模式下，就重置为{csr_tcfg_initval, 2'b0}
*/

assign tcfg_cur_value = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                      | ~csr_wmask[31:0] & tcfg_cur_value;

always @(posedge clk)
    begin
        if(reset)
            timer_cnt <= 32'hffffffff;
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        else if(csr_tcfg_en && timer_cnt!=32'hffffffff)
            begin
                if(timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                    //循环计时
                    timer_cnt <= {csr_tcfg_initval, 2'b0};
                else
                    timer_cnt <= timer_cnt - 1'b1;
            end
    end

assign csr_tval = timer_cnt[31:0];

/*---------------------------------------------------------------------*/

/*-----------------------TICLR的CLR�?----------------------------------*/

//软件通过对TICLR寄存器位0�?1来清除定时器置起的定时中断信�?
//CLR域的读写属�?�位W1,意味�?软件对它�?1才会产生执行效果，执行效�?
//具体体现在TCFG_EN上，但CLR域的值实际上不变，恒�?0
wire csr_ticlr_clr;
assign csr_ticlr_clr = 1'b0;

/*---------------------------------------------------------------------*/


/*---------------------------TLB相关寄存�?------------------------------*/

//1:TLBIDX
reg [3:0]   TLBIDX_INDEX;
reg [5:0]   TLBIDX_PS;
reg         TLBIDX_NE;

always @(posedge clk)
    begin
        if(reset)
            begin
                TLBIDX_INDEX    <= 0;
                TLBIDX_NE       <= 1'b1;   //初始表项为空 (1'b1)
                TLBIDX_PS        <= 0;
            end
        else if(csr_we && csr_num == `CSR_TLBIDX)
            begin
                TLBIDX_INDEX <= csr_wmask[`TLBIDX_INDEX] & csr_wvalue[`TLBIDX_INDEX]
                         | ~csr_wmask[`TLBIDX_INDEX] & TLBIDX_INDEX;
                TLBIDX_PS <= csr_wmask[`TLBIDX_PS] & csr_wvalue[`TLBIDX_PS]
                         | ~csr_wmask[`TLBIDX_PS] & TLBIDX_PS;
                TLBIDX_NE <= csr_wmask[`TLBIDX_NE] & csr_wvalue[`TLBIDX_NE]
                         | ~csr_wmask[`TLBIDX_NE] & TLBIDX_NE;
            end
        else if(inst_tlbsrch)
            begin
                if(tlbsrch_got)
                    begin
                        //tlbsrch命中表项，则�?要置index和ne=0
                        TLBIDX_INDEX <= tlbsrch_index;
                        TLBIDX_NE    <= 1'b0;
                    end
                else
                    begin
                        TLBIDX_NE    <= 1'b1;
                    end
            end
        else if(inst_tlbrd)
            begin
                if(tlbrd_valid)
                begin
                    TLBIDX_PS <= tlbrd_tlbidx_ps;
                    TLBIDX_NE <= 1'b0;
                end
                else
                begin
                    TLBIDX_PS <= 0;
                    TLBIDX_NE <= 1'b1;
                end
            end
    end

assign tlbidx_index = TLBIDX_INDEX;
assign tlbidx_ps = TLBIDX_PS;
assign tlbidx_ne = TLBIDX_NE;

/* 例外种类
PIL     load操作页无效例�?
PIS     store操作页无效例�?
PIF     取指操作页无效例�?
PME     页修改例�?
PPI     页特权等级不合规例外
ADEF    取指地址错例�?
ALE     地址非对齐例�?
TLBR    TLB重填例外
*/

//2:TLBEHI
reg [18:0]  TLBEHI_VPPN;
wire ex_elbehi;
assign ex_elbehi = (wb_ecode == `ECODE_PIL) || (wb_ecode == `ECODE_PIS) || (wb_ecode == `ECODE_PIF) || 
                   (wb_ecode == `ECODE_PME) || (wb_ecode == `ECODE_PPI) || (wb_ecode == `ECODE_TLBR);
always @(posedge clk)
    begin
        if(reset)
            TLBEHI_VPPN <= 0;
        else if(csr_we && csr_num == `CSR_TLBEHI)
            begin
                TLBEHI_VPPN <= csr_wmask[`TLBEHI_VPPN] & csr_wvalue[`TLBEHI_VPPN]
                         | ~csr_wmask[`TLBEHI_VPPN] & TLBEHI_VPPN;
            end
        else if(inst_tlbrd)
            begin
                if(tlbrd_valid)
                    //若tlbrd查找的TLB表项有效
                    TLBEHI_VPPN <= tlbrd_tlbehi_vppn;
                else
                    //若无效，则需�?0
                    TLBEHI_VPPN <= 0;
            end
        else if(wb_ex && ex_elbehi)
            TLBEHI_VPPN <=  ((wb_ecode == `ECODE_PIF) ||
                            (wb_ecode == `ECODE_PPI && if_fetch_plv_ex) ||
                            (wb_ecode == `ECODE_TLBR && if_fetch_tlb_refill))
                            ? wb_pc[31:13] : wb_vaddr[31:13];
    end

assign tlbehi_vppn = TLBEHI_VPPN;

//3:TLBELO0
reg         TLBELO0_V;
reg         TLBELO0_D;
reg [1:0]   TLBELO0_PLV;
reg [1:0]   TLBELO0_MAT;
reg         TLBELO0_G;
reg         TLBELO0_ZERO1;
reg [19:0]  TLBELO0_PPN;
reg [3:0]   TLBELO0_ZERO2;

always @(posedge clk)
    begin
        if(reset)
            begin
                TLBELO0_V   <= 0;
                TLBELO0_D   <= 0;
                TLBELO0_PLV <= 0;
                TLBELO0_MAT <= 0;
                TLBELO0_G   <= 0;
                TLBELO0_PPN <= 0;
            end
        else if(csr_we && csr_num == `CSR_TLBELO0)
            begin
                TLBELO0_V <= csr_wmask[`TLBELO_V] & csr_wvalue[`TLBELO_V]
                         | ~csr_wmask[`TLBELO_V] & TLBELO0_V;
                TLBELO0_D <= csr_wmask[`TLBELO_D] & csr_wvalue[`TLBELO_D]
                         | ~csr_wmask[`TLBELO_D] & TLBELO0_D;
                TLBELO0_PLV <= csr_wmask[`TLBELO_PLV] & csr_wvalue[`TLBELO_PLV]
                         | ~csr_wmask[`TLBELO_PLV] & TLBELO0_PLV;
                TLBELO0_MAT <= csr_wmask[`TLBELO_MAT] & csr_wvalue[`TLBELO_MAT]
                         | ~csr_wmask[`TLBELO_MAT] & TLBELO0_MAT;
                TLBELO0_G <= csr_wmask[`TLBELO_G] & csr_wvalue[`TLBELO_G]
                         | ~csr_wmask[`TLBELO_G] & TLBELO0_G;
                TLBELO0_PPN <= csr_wmask[`TLBELO_PPN] & csr_wvalue[`TLBELO_PPN]
                         | ~csr_wmask[`TLBELO_PPN] & TLBELO0_PPN;
            end
        else if(inst_tlbrd)
            begin
                if(tlbrd_valid)
                    begin
                        TLBELO0_V   <= tlbrd_tlbelo0_v;
                        TLBELO0_D   <= tlbrd_tlbelo0_d;
                        TLBELO0_PLV <= tlbrd_tlbelo0_plv;
                        TLBELO0_MAT <= tlbrd_tlbelo0_mat;
                        TLBELO0_G   <= tlbrd_tlbelo0_g;
                        TLBELO0_PPN <= tlbrd_tlbelo0_ppn;
                    end
                else
                    begin
                        TLBELO0_V   <= 0;
                        TLBELO0_D   <= 0;
                        TLBELO0_PLV <= 0;
                        TLBELO0_MAT <= 0;
                        TLBELO0_G   <= 0;
                        TLBELO0_PPN <= 0;
                    end
            end
    end

//4:TLBELO1
reg         TLBELO1_V;
reg         TLBELO1_D;
reg [1:0]   TLBELO1_PLV;
reg [1:0]   TLBELO1_MAT;
reg         TLBELO1_G;
reg         TLBELO1_ZERO1;
reg [19:0]  TLBELO1_PPN;
reg [3:0]   TLBELO1_ZERO2;

always @(posedge clk)
    begin
        if(reset)
            begin
                TLBELO1_V   <= 0;
                TLBELO1_D   <= 0;
                TLBELO1_PLV <= 0;
                TLBELO1_MAT <= 0;
                TLBELO1_G   <= 0;
                TLBELO1_PPN <= 0;
            end
        else if(csr_we && csr_num == `CSR_TLBELO1)
            begin
                TLBELO1_V <= csr_wmask[`TLBELO_V] & csr_wvalue[`TLBELO_V]
                         | ~csr_wmask[`TLBELO_V] & TLBELO1_V;
                TLBELO1_D <= csr_wmask[`TLBELO_D] & csr_wvalue[`TLBELO_D]
                         | ~csr_wmask[`TLBELO_D] & TLBELO1_D;
                TLBELO1_PLV <= csr_wmask[`TLBELO_PLV] & csr_wvalue[`TLBELO_PLV]
                         | ~csr_wmask[`TLBELO_PLV] & TLBELO1_PLV;
                TLBELO1_MAT <= csr_wmask[`TLBELO_MAT] & csr_wvalue[`TLBELO_MAT]
                         | ~csr_wmask[`TLBELO_MAT] & TLBELO1_MAT;
                TLBELO1_G <= csr_wmask[`TLBELO_G] & csr_wvalue[`TLBELO_G]
                         | ~csr_wmask[`TLBELO_G] & TLBELO1_G;
                TLBELO1_PPN <= csr_wmask[`TLBELO_PPN] & csr_wvalue[`TLBELO_PPN]
                         | ~csr_wmask[`TLBELO_PPN] & TLBELO1_PPN;
            end
        else if(inst_tlbrd)
            begin
                if(tlbrd_valid)
                    begin
                        TLBELO1_V   <= tlbrd_tlbelo1_v;
                        TLBELO1_D   <= tlbrd_tlbelo1_d;
                        TLBELO1_PLV <= tlbrd_tlbelo1_plv;
                        TLBELO1_MAT <= tlbrd_tlbelo1_mat;
                        TLBELO1_G   <= tlbrd_tlbelo1_g;
                        TLBELO1_PPN <= tlbrd_tlbelo1_ppn;
                    end
                else
                    begin
                        TLBELO1_V   <= 0;
                        TLBELO1_D   <= 0;
                        TLBELO1_PLV <= 0;
                        TLBELO1_MAT <= 0;
                        TLBELO1_G   <= 0;
                        TLBELO1_PPN <= 0;
                    end
            end
    end

//5:ASID
reg [9:0]   ASID_ASID;
reg [5:0]   ASID_ZERO1;
reg [7:0]   ASID_ASIDBITS;
reg [7:0]   ASID_ZERO2;

always @(posedge clk)
    begin
        if(reset)
            begin
            ASID_ASID <= 0;
            ASID_ZERO1 <= 0;
            ASID_ASIDBITS <= 8'ha;
            ASID_ZERO2 <= 0;
            end
        else if(csr_we && csr_num == `CSR_ASID)
                    ASID_ASID <= csr_wmask[`ASID_ASID] & csr_wvalue[`ASID_ASID]
                         | ~csr_wmask[`ASID_ASID] & ASID_ASID;
        else if(inst_tlbrd)
            begin
                if(tlbrd_valid)
                    ASID_ASID <= tlbrd_asid_asid;
                else
                    ASID_ASID <= 0;
            end
    end

assign tlbasid_asid = ASID_ASID;

//6:TLBRENTRY
reg [5:0]   TLBRENTRY_LOW;
reg [25:0]  TLBRENTRY_HIGH;

always @(posedge clk)
begin
    if(reset)
        begin
            TLBRENTRY_LOW  <= 0;
            TLBRENTRY_HIGH <= 0;
        end
    else if(csr_we && csr_num == `CSR_TLBRENTRY)
                TLBRENTRY_HIGH <= csr_wmask[`TLBRENTRY_HIGH] & csr_wvalue[`TLBRENTRY_HIGH]
                        |         ~csr_wmask[`TLBRENTRY_HIGH] & TLBRENTRY_HIGH;
end

//直接映射配置窗口

//8:DMW0
reg         DMW0_PLV0;
reg [1:0]   DMW0_ZERO1;
reg         DMW0_PLV3;
reg [1:0]   DMW0_MAT;
reg [18:0]  DMW0_ZERO2;
reg [2:0]   DMW0_PSEG;
reg         DMW0_ZERO3;
reg [2:0]   DMW0_VSEG;

always @(posedge clk)
    begin
        if(reset)
            begin
                DMW0_PLV0 <= 0;
                DMW0_ZERO1 <= 0;
                DMW0_PLV3 <= 0;
                DMW0_MAT <= 0;
                DMW0_ZERO2 <= 0;
                DMW0_PSEG <= 0;
                DMW0_ZERO3 <= 0;
                DMW0_VSEG <= 0;
            end
        else if(csr_we && csr_num == `CSR_DMW0)
            begin
                DMW0_PLV0 <= csr_wmask[`DMW_PLV0] & csr_wvalue[`DMW_PLV0]
                    | ~csr_wmask[`DMW_PLV0] & DMW0_PLV0;

                DMW0_PLV3 <= csr_wmask[`DMW_PLV3] & csr_wvalue[`DMW_PLV3]
                    | ~csr_wmask[`DMW_PLV3] & DMW0_PLV3;

                DMW0_MAT <= csr_wmask[`DMW_MAT] & csr_wvalue[`DMW_MAT]
                    | ~csr_wmask[`DMW_MAT] & DMW0_MAT;

                DMW0_PSEG <= csr_wmask[`DMW_PSEG] & csr_wvalue[`DMW_PSEG]
                    | ~csr_wmask[`DMW_PSEG] & DMW0_PSEG;

                DMW0_VSEG <= csr_wmask[`DMW_VSEG] & csr_wvalue[`DMW_VSEG]
                    | ~csr_wmask[`DMW_VSEG] & DMW0_VSEG;
            end
    end

assign tlbdmw0_plv0 = DMW0_PLV0;
assign tlbdmw0_plv3 = DMW0_PLV3;
assign tlbdmw0_mat = DMW0_MAT;
assign tlbdmw0_pseg = DMW0_PSEG;
assign tlbdmw0_vseg = DMW0_VSEG;

//9:DMW1
reg         DMW1_PLV0;
reg [1:0]   DMW1_ZERO1;
reg         DMW1_PLV3;
reg [1:0]   DMW1_MAT;
reg [18:0]  DMW1_ZERO2;
reg [2:0]   DMW1_PSEG;
reg         DMW1_ZERO3;
reg [2:0]   DMW1_VSEG;

always @(posedge clk)
    begin
        if(reset)
            begin
                DMW1_PLV0 <= 0;
                DMW1_ZERO1 <= 0;
                DMW1_PLV3 <= 0;
                DMW1_MAT <= 0;
                DMW1_ZERO2 <= 0;
                DMW1_PSEG <= 0;
                DMW1_ZERO3 <= 0;
                DMW1_VSEG <= 0;
            end
        else if(csr_we && csr_num == `CSR_DMW1)
            begin
                DMW1_PLV0 <= csr_wmask[`DMW_PLV0] & csr_wvalue[`DMW_PLV0]
                    | ~csr_wmask[`DMW_PLV0] & DMW1_PLV0;

                DMW1_PLV3 <= csr_wmask[`DMW_PLV3] & csr_wvalue[`DMW_PLV3]
                    | ~csr_wmask[`DMW_PLV3] & DMW1_PLV3;

                DMW1_MAT <= csr_wmask[`DMW_MAT] & csr_wvalue[`DMW_MAT]
                    | ~csr_wmask[`DMW_MAT] & DMW1_MAT;

                DMW1_PSEG <= csr_wmask[`DMW_PSEG] & csr_wvalue[`DMW_PSEG]
                    | ~csr_wmask[`DMW_PSEG] & DMW1_PSEG;

                DMW1_VSEG <= csr_wmask[`DMW_VSEG] & csr_wvalue[`DMW_VSEG]
                    | ~csr_wmask[`DMW_VSEG] & DMW1_VSEG;
            end
    end

assign tlbdmw1_plv0 = DMW1_PLV0;
assign tlbdmw1_plv3 = DMW1_PLV3;
assign tlbdmw1_mat = DMW1_MAT;
assign tlbdmw1_pseg = DMW1_PSEG;
assign tlbdmw1_vseg = DMW1_VSEG;

/*---------------------------------------------------------------------*/

/*-----------------------rvalue----------------------------------------*/
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_eentey_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;

wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbidx_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire [31:0] csr_tlbelo0_rvalue;
wire [31:0] csr_tlbelo1_rvalue;
wire [31:0] csr_tlbrentry_rvalue;

assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 
                           3'b0, csr_estat_is};
assign csr_era_rvalue = csr_era_pc;
assign csr_badv_rvalue = csr_badv_vaddr;
assign csr_eentey_rvalue = {csr_eentry_va, 6'b0};
assign csr_save0_rvalue = csr_save0_data;
assign csr_save1_rvalue = csr_save1_data;
assign csr_save2_rvalue = csr_save2_data;
assign csr_save3_rvalue = csr_save3_data;
assign csr_tid_rvalue = csr_tid_tid;
assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign csr_tval_rvalue = csr_tval;
assign csr_asid_rvalue = {ASID_ZERO2, ASID_ASIDBITS, ASID_ZERO1, ASID_ASID};
assign csr_tlbidx_rvalue = {TLBIDX_NE, 1'b0, TLBIDX_PS, 20'b0, TLBIDX_INDEX};
assign csr_tlbehi_rvalue = {TLBEHI_VPPN,13'b0};
assign csr_tlbelo0_rvalue = {4'b0, TLBELO0_PPN, 1'b0, TLBELO0_G, TLBELO0_MAT, TLBELO0_PLV, TLBELO0_D, TLBELO0_V};
assign csr_tlbelo1_rvalue = {4'b0, TLBELO1_PPN, 1'b0, TLBELO1_G, TLBELO1_MAT, TLBELO1_PLV, TLBELO1_D, TLBELO1_V};

assign csr_tlbrentry_rvalue = {TLBRENTRY_HIGH, TLBRENTRY_LOW};

assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
                  | {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
                  | {32{csr_num==`CSR_ECFG}} & csr_ecfg_rvalue
                  | {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
                  | {32{csr_num==`CSR_ERA}} & csr_era_rvalue
                  | {32{csr_num==`CSR_BADV}} & csr_badv_rvalue
                  | {32{csr_num==`CSR_EENTRY}} & csr_eentey_rvalue
                  | {32{csr_num==`CSR_TLBIDX}} & csr_tlbidx_rvalue
                  | {32{csr_num==`CSR_TLBEHI}} & csr_tlbehi_rvalue
                  | {32{csr_num==`CSR_TLBELO0}} & csr_tlbelo0_rvalue
                  | {32{csr_num==`CSR_TLBELO1}} & csr_tlbelo1_rvalue
                  | {32{csr_num==`CSR_ASID}} & csr_asid_rvalue
                  | {32{csr_num==`CSR_SAVE0}} & csr_save0_rvalue
                  | {32{csr_num==`CSR_SAVE1}} & csr_save1_rvalue
                  | {32{csr_num==`CSR_SAVE2}} & csr_save2_rvalue
                  | {32{csr_num==`CSR_SAVE3}} & csr_save3_rvalue
                  | {32{csr_num==`CSR_TID}} & csr_tid_rvalue
                  | {32{csr_num==`CSR_TCFG}} & csr_tcfg_rvalue
                  | {32{csr_num==`CSR_TVAL}} & csr_tval_rvalue
                  | {32{csr_num==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue;

/*---------------------------------------------------------------------*/

/*-------------------------------output--------------------------------*/

assign ertn_pc = csr_era_rvalue;
assign ex_entry = csr_eentey_rvalue;
assign ex_tlbentry = csr_tlbrentry_rvalue;
assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0)
                && (csr_crmd_ie == 1'b1);


/*---------------------------------------------------------------------*/

/*------------------------assign output wr-----------------------------*/
assign tlbelo0_v     =      TLBELO0_V;
assign tlbelo0_d     =      TLBELO0_D;
assign tlbelo0_plv   =      TLBELO0_PLV;
assign tlbelo0_mat   =      TLBELO0_MAT;
assign tlbelo0_g     =      TLBELO0_G;
assign tlbelo0_ppn   =      TLBELO0_PPN;

assign tlbelo1_v     =      TLBELO1_V;
assign tlbelo1_d     =      TLBELO1_D;
assign tlbelo1_plv   =      TLBELO1_PLV;
assign tlbelo1_mat   =      TLBELO1_MAT;
assign tlbelo1_g     =      TLBELO1_G;
assign tlbelo1_ppn   =      TLBELO1_PPN;

/*---------------------------------------------------------------------*/

endmodule