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

reg [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            ds_to_es_bus_reg <= 0;
        else if(ds_to_es_valid && es_allow_in)
            ds_to_es_bus_reg <= ds_to_es_bus;
        else
            ds_to_es_bus_reg <= 0; 
    end

assign {es_mul_op,es_res_from_mem, es_src2_is_imm, es_src1_is_pc,
        es_alu_op, es_mem_we, es_gr_we, es_dest, es_imm,
        es_rkd_value, es_rj_value, es_pc} = ds_to_es_bus_reg;

wire [31:0] es_cal_result;
wire [31:0] es_mul_result;
wire [31:0] es_alu_result;
assign es_cal_result = (es_mul_op != 0) ? es_mul_result : es_alu_result;

assign es_to_ms_bus[31:0] = es_pc;
assign es_to_ms_bus[32:32] = es_gr_we;
assign es_to_ms_bus[33:33] = es_res_from_mem;
assign es_to_ms_bus[38:34] = es_dest;
assign es_to_ms_bus[70:39] = es_cal_result;

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
    .mul_src1   (cal_src1  ),
    .mul_src2   (cal_src2  ),
    .mul_result (es_mul_result)
    );    

reg es_valid;    

wire es_ready_go;
assign es_ready_go = 1'b1;
assign es_allow_in = !es_valid || es_ready_go && ms_allow_in;
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk)
    begin
        if(reset)
            es_valid <= 1'b0;
        else if(es_allow_in)
            es_valid <= ds_to_es_valid;
    end


assign data_sram_en    = 1'b1;   
assign data_sram_wen   = (es_mem_we && es_valid) ? 4'b1111 : 4'b0000;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rkd_value;      

assign es_to_ds_bus = {es_gr_we,es_dest,es_res_from_mem,es_cal_result};

endmodule