`include "mycpu_head.h"

module stage3_EX(
    input clk,
    input reset,

    input ms_allow_in,
    output es_allow_in,

    input ds_to_es_valid,
    output es_to_ms_valid,

    input [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,
    output [`WIDTH_ES_TO_MS_BUS-1:0] es_to_ms_bus,
    output [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,

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
//exp11,可能�?要在�?前面加es_ld_op
assign {es_ld_op,es_st_op,es_div_op,es_mul_op,es_res_from_mem, es_src2_is_imm, es_src1_is_pc,
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
assign data_sram_wen   = (es_mem_we && es_valid) ? w_strb : 4'b0000;
assign data_sram_addr  = (es_mul_op != 0) ? {es_mul_result[31:2],2'b00} : {es_alu_result[31:2],2'b00};
assign data_sram_wdata = real_wdata;      

assign es_to_ds_bus = {es_gr_we,es_dest,es_res_from_mem,es_cal_result};

endmodule