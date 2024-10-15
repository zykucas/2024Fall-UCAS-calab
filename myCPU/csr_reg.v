`include "mycpu_head.vh"

module csr_reg(
    input                         clk,
    input                         reset,

    input [`WIDTH_CSR_NUM-1:0]     csr_num,           // Register number

    input                         csr_re,            // Read enable
    output             [31:0]     csr_rvalue,        // Read data
    output             [31:0]     ertn_pc,
    output             [31:0]     ex_entry,

    input                         csr_we,            // Write enable
    input              [31:0]     csr_wmask,         // Write mask
    input              [31:0]     csr_wvalue,        // Write data

    input                         wb_ex,             // Write-back level exception
    input              [31:0]     wb_pc,             // Exception PC
    input                         ertn_flush,        // ERTN instruction execution valid signal
    input              [5:0]      wb_ecode,          // Exception type level 1 code
    input              [8:0]      wb_esubcode,       // Exception type level 2 code
    input              [31:0]     wb_vaddr, 
    input              [31:0]     coreid_in,

    output                        has_int,
    input              [7:0]      hw_int_in,
    input                         ipi_int_in
);

/*
Register numbers:
`define CSR_CRMD 0x0
`define CSR_PRMD 0x1
`define CSR_ECFG 0x4
`define CSR_ESTAT 0x5
`define CSR_ERA 0x6
`define CSR_BADV 0x7
`define CSR_EENTRY 0xc
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
CSR Partition
*/

/*-------------------------- Current Mode Information CRMD -------------------------*/

// Current privilege level
/*
2'b00: Highest privilege level  2'b11: Lowest privilege level
When an exception occurs, set PLV to 0 to ensure the kernel state at the highest privilege level after entering the exception.
When executing the ERTN instruction to return from the exception handler, CSR_PRMD[PPLV] --> CSR_CRMD[PLV].
*/
reg [1:0] csr_crmd_plv;
reg [1:0] csr_prmd_pplv;
reg csr_prmd_pie;

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

// Current global interrupt enable
/*
1'b1: Interruptible    1'b0: Masked interrupt
When an exception occurs, hardware sets to 0 to ensure the mask of interrupts after entering.
The exception handler decides to re-enable interrupt response, set it to 1.
When executing the ERTN instruction to return from the exception handler, CSR_PRMD[IE] --> CSR_CRMD[IE].
*/
reg csr_crmd_ie;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_ie <= 1'b0;
        else if(wb_ex)
            // Disable interrupt enable after entering interrupt
            csr_crmd_ie <= 1'b0;
        else if(ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if(csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end

// Direct address translation enable --> initialized to 1
reg csr_crmd_da;

always @(posedge clk)
    begin
        if(reset)
            csr_crmd_da <= 1'b1;
    end

// Not yet used
reg csr_crmd_pg;
reg [1:0] csr_crmd_datf;
reg [1:0] csr_crmd_datm;
reg [22:0] csr_crmd_zero;

/*---------------------------------------------------------------------*/

/*-------------------------- Previous Mode Information PRMD -------------------------*/


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

// Not yet used
reg [28:0] reg_prmd_zero;

/*---------------------------------------------------------------------*/

/*-------------------------- Exception Control ECFG -------------------------------*/

// Control the local enable bits of various interrupts
/*
1'b1: Interruptible    1'b0: Masked interrupt
The lower 10 bits of local interrupt enable bits correspond to 10 interrupt sources recorded in CSR_ESTAT in IS[9:0].
Bits 12:11 correspond to 2 interrupt sources recorded in CSR_ESTAT in IS[12:11].
*/
reg [12:0] csr_ecfg_lie;

always @(posedge clk)
    begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                         | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
    end

// Not yet used
reg [18:0] csr_ecgh_zero;

/*---------------------------------------------------------------------*/

/*-------------------------- Exception Status ESTAT -------------------------------*/

// 2 soft interrupt status bits, bits 0 and 1 correspond to SWI0 and SWI1 respectively.
// 8 hard interrupt status bits, bits 2 to 9 correspond to HWI0 to HWI7.
// 1 reserved field.
// Bit 11 corresponds to the timer interrupt TI status bit.
// Bit 12 corresponds to the inter-core interrupt.
reg [12:0] csr_estat_is;

always @(posedge clk)
    begin
        // Soft interrupt bit -- RW
        if(reset)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= 2'b0;
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[`CSR_ESTAT_IS_SOFT] <= csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_wvalue[`CSR_ESTAT_IS_SOFT]
                              | ~csr_wmask[`CSR_ESTAT_IS_SOFT] & csr_estat_is[`CSR_ESTAT_IS_SOFT];

        // Hard interrupt bit -- R
        csr_estat_is[`CSR_ESTAT_IS_HARD] <= hw_int_in[7:0];

        // Reserved bits
        csr_estat_is[`CSR_ESTAT_IS_LEFT1] <= 1'b0;

        // Timer interrupt -- R but writing CSR_TICLR_CLR can change CSR_ESTAT_IS_TI
        if(timer_cnt[31:0] == 32'b0)
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b1;
        else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
                && csr_wvalue[`CSR_TICLR_CLR])
            // Writing 1 to the CLR bit of the CSR_TICLR timer interrupt clear register represents clearing the timer interrupt mark
            csr_estat_is[`CSR_ESTAT_IS_TI] <= 1'b0;

        // Inter-core interrupt mark
        csr_estat_is[`CSR_ESTAT_IS_IPI] <= ipi_int_in;
    end

// Reserved bits
reg [2:0] csr_estat_left;

// Interrupt type level 1 and level 2 encoding
reg [5:0] csr_estat_ecode;
reg [8:0] csr_estat_esubcode;

always @(posedge clk)
    begin
        if(wb_ex)
            begin
                csr_estat_ecode <= wb_ecode;
                csr_estat_esubcode <= wb_esubcode;
            end
    end

// Not yet used
reg csr_estat_zero;

/*---------------------------------------------------------------------*/

/*----------------------- Exception Return Address ERA -------------------------------*/

// The PC of the instruction that triggered the exception will be recorded in the EPC register.
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

/*----------------------- Error Virtual Address BADV -------------------------------*/

// Record the erroneous virtual address when an address error exception is triggered
reg [31:0] csr_badv_vaddr;

wire wb_ex_addr_err;
/*
ECODE_ADEF: Address fault exception
ECODE_ADEM: Memory access instruction address error exception
ECODE_ALE: Address misalignment exception
*/
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE);

always @(posedge clk)
    begin
        if(wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADE && 
                               wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    end

/*---------------------------------------------------------------------*/

/*----------------------- Exception Entry Address EENTRY -------------------------------*/

// EENTRY is used to configure the entry address for exceptions and interrupts, excluding TLB fill exceptions
// Can only be updated by CSR instructions
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

/*----------------------- Temporary Registers SAVE0-3 -------------------------------*/

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

/*----------------------- Timer ID Register TID -------------------------------*/

// Timer ID register
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

/*----------------------- Timer Configuration Register TCFG -------------------------------*/

// Timer enable bit; when en is 1, the timer will perform countdown self-check and set the timer interrupt signal when it decrements to 0
reg csr_tcfg_en;
// Timer periodic mode control bit; when 1, it operates in periodic mode
reg csr_tcfg_periodic;
// Initial value for timer countdown
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

/*----------------------- TVAL's TimeVal Domain -------------------------------*/

wire [31:0] tcfg_cur_value;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg  [31:0] timer_cnt;

/*
Two wire type signals are used to define cur_tcfg and next_tcfg
to enable updating of timer_cnt while the software enables the timer.
This is reflected in the timing logic below:
        else if(csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
This updates the timer initial value written to the timer configuration register into timer_cnt

Since the timer is updated while writing to TCFG,
we look at the value being written to the TCFG register (next_value) instead of cur_value
*/

/*
When timer_cnt decrements to 0 and the timer is not in periodic mode,
timer_cnt continues decrementing to 32'hffffffff, and should stop at that point.
Therefore, the conditions for timer_cnt decrementing include timer_cnt!=32'hffffffff.

In periodic mode, it resets to {csr_tcfg_initval, 2'b0}.
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
                    // Looping timer
                    timer_cnt <= {csr_tcfg_initval, 2'b0};
                else
                    timer_cnt <= timer_cnt - 1'b1;
            end
    end

assign csr_tval = timer_cnt[31:0];

/*---------------------------------------------------------------------*/

/*----------------------- TICLR's CLR Domain ----------------------------------*/

// Software clears the timer interrupt signal by writing 1 to bit 0 of the TICLR register
// The CLR domain has a write attribute of W1, which means the software only takes effect when writing 1 to it; however, the CLR domain's value actually does not change and remains 0
wire csr_ticlr_clr;
assign csr_ticlr_clr = 1'b0;

/*---------------------------------------------------------------------*/

/*----------------------- rvalue ----------------------------------------*/
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_prmd_rvalue;
wire [31:0] csr_ecfg_rvalue;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_era_rvalue;
wire [31:0] csr_badv_rvalue;
wire [31:0] csr_eentry_rvalue;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;
wire [31:0] csr_tid_rvalue;
wire [31:0] csr_tcfg_rvalue;
wire [31:0] csr_tval_rvalue;

assign csr_crmd_rvalue = {28'b0, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 
                           3'b0, csr_estat_is};
assign csr_era_rvalue = csr_era_pc;
assign csr_badv_rvalue = csr_badv_vaddr;
assign csr_eentry_rvalue = {csr_eentry_va, csr_eentry_zero};
assign csr_save0_rvalue = csr_save0_data;
assign csr_save1_rvalue = csr_save1_data;
assign csr_save2_rvalue = csr_save2_data;
assign csr_save3_rvalue = csr_save3_data;
assign csr_tid_rvalue = csr_tid_tid;
assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign csr_tval_rvalue = csr_tval;

assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
                  | {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
                  | {32{csr_num==`CSR_ECFG}} & csr_ecfg_rvalue
                  | {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
                  | {32{csr_num==`CSR_ERA}} & csr_era_rvalue
                  | {32{csr_num==`CSR_BADV}} & csr_badv_rvalue
                  | {32{csr_num==`CSR_EENTRY}} & csr_eentry_rvalue
                  | {32{csr_num==`CSR_SAVE0}} & csr_save0_rvalue
                  | {32{csr_num==`CSR_SAVE1}} & csr_save1_rvalue
                  | {32{csr_num==`CSR_SAVE2}} & csr_save2_rvalue
                  | {32{csr_num==`CSR_SAVE3}} & csr_save3_rvalue
                  | {32{csr_num==`CSR_TID}} & csr_tid_rvalue
                  | {32{csr_num==`CSR_TCFG}} & csr_tcfg_rvalue
                  | {32{csr_num==`CSR_TVAL}} & csr_tval_rvalue;

/*---------------------------------------------------------------------*/

/*------------------------------- Output --------------------------------*/

assign ertn_pc = csr_era_rvalue;
assign ex_entry = csr_eentry_rvalue;

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[12:0]) != 12'b0)
                && (csr_crmd_ie == 1'b1);

/*---------------------------------------------------------------------*/

endmodule
