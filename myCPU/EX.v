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

    output data_sram_en,
    output [3:0]data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata
);

parameter   EXE         = 5'b00001;
parameter   DIV_WAIT    = 5'b00010;
parameter   DIVU_WAIT   = 5'b00100;
parameter   OUT_WAIT    = 5'b01000;
parameter   UOUT_WAIT   = 5'b10000;


reg  [4:0]  current_state;
reg  [4:0]  next_state;   
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
*/
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
        else if(ertn_flush | has_int | wb_ex)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        else if(ds_to_es_valid)
            ds_to_es_bus_reg <= ds_to_es_bus_reg; 
            else
            ds_to_es_bus_reg <= 0;
    end
    
    
always @(posedge clk)begin
    if(reset)
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

//exp11
assign {es_code,es_ex_syscall,es_csr,es_ertn_flush,es_csr_write,es_csr_wmask,es_csr_num,es_ld_op,es_st_op,es_div_op,es_mul_op,es_res_from_mem, es_src2_is_imm, es_src1_is_pc,
        es_alu_op, es_mem_we, es_gr_we, es_dest, es_imm,
        es_rkd_value, es_rj_value, es_pc} = ds_to_es_bus_reg;

assign inst_div = es_div_op[0];

wire [31:0] es_cal_result;
wire [31:0] es_div_result,es_div_signed,es_div_unsigned;
wire [31:0] es_mod_result,es_mod_signed,es_mod_unsigned;
wire [31:0] es_mul_result;
wire [31:0] es_alu_result;

assign es_cal_result = es_div_op[0] ? (es_div_op[2] ? es_div_result:es_mod_result ):
         ((es_mul_op != 0) ? es_mul_result : es_alu_result);
assign es_div_result = es_div_op[1] ? es_div_signed : es_div_unsigned;
assign es_mod_result = es_div_op[1] ? es_mod_signed : es_mod_unsigned;

//task 11 add Unaligned memory access, we should deliver unaligned info
wire [1:0] es_unaligned_addr;
assign es_unaligned_addr = (es_mul_op != 0) ? es_mul_result[1:0] : es_alu_result[1:0];

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

reg es_valid;    
wire es_ready_go;

assign es_ready_go = !es_div_op[0] | (current_state==OUT_WAIT & out_valid |
      current_state==UOUT_WAIT & out_u_valid) ;
assign es_allow_in = (!es_valid || es_ready_go) && ms_allow_in &&
     (current_state == EXE | current_state==OUT_WAIT & out_valid |
      current_state==UOUT_WAIT & out_u_valid);
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk)
    begin
        if(reset)
            es_valid <= 1'b0;
        else if(es_allow_in)
            es_valid <= ds_to_es_valid;
    end

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

assign data_sram_en    = 1'b1;   
assign data_sram_wen   = (es_mem_we && es_valid && ~has_int && ~if_ms_has_int) ? w_strb : 4'b0000;
assign data_sram_addr  = (es_mul_op != 0) ? {es_mul_result[31:2],2'b00} : {es_alu_result[31:2],2'b00};
assign data_sram_wdata = real_wdata;      

assign es_to_ds_bus = {es_gr_we,es_dest,es_res_from_mem,es_cal_result,
                       es_csr_write, es_csr_num, es_csr};

endmodule