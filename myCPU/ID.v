`include "mycpu_head.h"

module stage2_ID(
    input clk,
    input reset,

    input es_allow_in,
    output ds_allow_in,

    input fs_to_ds_valid,
    output ds_to_es_valid, 

    input [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,
    output [`WIDTH_DS_TO_ES_BUS-1:0] ds_to_es_bus,

    input [`WIDTH_WS_TO_DS_BUS-1:0] ws_to_ds_bus,

    output [`WIDTH_BR_BUS-1:0] br_bus,

    input [`WIDTH_ES_TO_DS_BUS-1:0] es_to_ds_bus,
    input [`WIDTH_MS_TO_WS_BUS-1:0] ms_to_ds_bus
);

wire [31:0] inst;

wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire [2:0]  mul_op;
wire [2:0]  div_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;


wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

assign op_31_26  = inst[31:26];     //checked
assign op_25_22  = inst[25:22];     //checked
assign op_21_20  = inst[21:20];     //checked
assign op_19_15  = inst[19:15];     //checked

assign rd   = inst[ 4: 0];  //checked
assign rj   = inst[ 9: 5];  //checked
assign rk   = inst[14:10];  //checked

assign i12  = inst[21:10];  //checked
assign i20  = inst[24: 5];  //checked
assign i16  = inst[25:10];  //checked
assign i26  = {inst[ 9: 0], inst[25:10]};   //checked  

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

//add_w: rd = rj + rk   asm: add.w rd, rj, rk
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
//sun_w: rd = rj - rk   asm: sub.w rd, rj, rk
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
//slt: rd = (signed(rj) < signed(rk)) ? 1 : 0 
//asm: slt rd, rj, rk
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
//sltu: rd = (unsigned(rj) < unsigned(rk)) ? 1 : 0  
//asm: sltu rd, rj, rk
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
//nor: rd = ~(rj | rk)   asm: nor rd, rj, rk
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
//and: rd = rj & rk  asm: and rd, rj, rk
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
//or: rd = rj | rk  asm: or rd, rj, rk
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
//xor: rd = rj ^ rk  asm: xor rd, rj, rk
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
//slli.w: rd = SLL(rj, ui5)  asm: slli.w rd, rj, ui5
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
//srli.w: rd = SRL(rj, ui5)  asm: srli.w rd, rj, ui5
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
//srai.w: rd = SRA(rj, ui5)  asm: srai.w rd, rj, ui5
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
//addi.w: rd = rj + SignExtend(si12, 32)  asm: addi.w rd, rj, si12
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
//ld_w: ld.w rd, rj, si12
//vaddr = rj + SignExtend(si12, GRLEN)
//paddr = AddressTranslation(vaddr)
//word = MemoryLoad(paddr, WORD)
//rd = word
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
//st_w: st.w rd, rj, si12
//vaddr = rj + SignExtend(si12, GRLEN)
//paddr = AddressTranlation(vaddr)
//rd --> Mem(paddr)(len:WORD)
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
//jirl: rd, rj, offs16
//rd = pc + 4
//pc = rj + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_jirl   = op_31_26_d[6'h13];
//b: b offs26
//pc = pc + SignExtend({offs26, 2'b0}, GRLEN)
assign inst_b      = op_31_26_d[6'h14];
//bl: bl offs26
//GR[1] = pc + 4
//pc = pc + SignExtend({offs26, 2'b0}, GRLEN)
assign inst_bl     = op_31_26_d[6'h15];
//beq: rj, rd, offs16
//if (rj==rd)
//  pc = pc + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_beq    = op_31_26_d[6'h16];
//bne: rj, rd, offs16
//if (rj==rd)
//  pc = pc + SignExtend({offs16, 2'b0}, GRLEN)
assign inst_bne    = op_31_26_d[6'h17];
//lui2i_w: rd, si20
//rd = {si20, 12'b0}
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
//slti rd, rj, si12
//rd = (signed(rj) < SignExtend(si12, 32)) ? 1 : 0
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
//sltiu rd, rj, si12
//rd = (unsigned(rj) < SignExtend(si12, 32)) ? 1 : 0
assign inst_sltiu  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
//andi rd, rj, ui12
//GR[rd] = GR[rj] & ZeroExtend(ui12, 32)
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
//ori rd, rj, ui12
//GR[rd] = GR[rj] | ZeroExtend(ui12, 32)
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
//xori rd, rj, ui12
//GR[rd] = GR[rj] ^ ZeroExtend(ui12, 32)
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
//sll.w rd, rj, rk
//GR[rd] = SLL(GR[rj], GR[rk][4:0])
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
//srl.w rd, rj, rk
//GR[rd] = SRL(GR[rj], GR[rk][4:0])
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
//sra.w rd, rj, rk
//GR[rd] = SRA(GR[rj], GR[rk][4:0])
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
//pcaddu12i: rd, si20
//GR[rd] = PC + SignExtend({si20, 12'b0}, 32)
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];
//mul.w rd, rj, rk
//product = signed(GR[rj]) * signed(GR[rk])
//GR[rd] = product[31:0]
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
//mulh.w rd, rj, rk
//product = signed(GR[rj]) * signed(GR[rk])
//GR[rd] = product[63:32]
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
//mulh.wu rd, rj, rk
//product = unsigned(GR[rj]) * unsigned(GR[rk])
//GR[rd] = product[63:32]
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
//div.w rd, rj, rk
//quotient = signed(GR[rj]) / signed(GR[rk])
//GR[rd] = quotient[31:0]
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
//div.wu rd, rj, rk
//quotient = unsigned(GR[rj]) / unsigned(GR[rk])
//GR[rd] = quotient[31:0]
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
//mod.w rd, rj, rk
//remainder = signed(GR[rj]) % signed(GR[rk])
//GR[rd] = remainder[31:0]
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
//mod.wu rd, rj, rk
//remainder = unsigned(GR[rj]) % unsigned(GR[rk])
//GR[rd] = remainder[31:0]
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
//blt blt: rj, rd, offs16
//if(signed(rj) < signed(rd))
//      pc = pc + SignExtend(offs16,2'b0)
assign inst_blt = op_31_26_d[6'h18];
//bge bge: rj, rd, offs16
// if(signed(rj) >= signed(rd))
//      pc = pc + SignExtend(offs16,2'b0)
assign inst_bge = op_31_26_d[6'h19];
//bltu bltu: rj, rd, offs16
//if(unsigned(rj) < unsigned(rd))
//      pc = pc + SignExtend(offs16,2'b0)
assign inst_bltu = op_31_26_d[6'h1a];
//bgeu bgeu: rj, rd, offs16
//if(unsigned(rj) < unsigned(rd))
//      pc = pc + SignExtend(offs16,2'b0)
assign inst_bgeu = op_31_26_d[6'h1b];


assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;  
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltiu;   
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;       
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;          
assign need_si26  =  inst_b | inst_bl;    
assign need_ui12  =  inst_andi | inst_ori | inst_xori;   

assign src2_is_4  =  inst_jirl | inst_bl;   

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :   
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;   
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};   

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_blt | inst_bge | inst_bltu | inst_bgeu;

//used for judging br_taken
assign rj_eq_rd = (rj_value == rkd_value);

//imitation calcu slt and sltu in alu
wire signed_rj_less_rkd;
wire unsigned_rj_less_rkd;

wire cin;
assign cin = 1'b1;
wire [31:0] adver_rkd_value;
assign adver_rkd_value = ~rkd_value;
wire [31:0] rj_rkd_adder_result;
wire cout;
assign {cout, rj_rkd_adder_result} = rj_value + adver_rkd_value + cin;

assign signed_rj_less_rkd = (rj_value[31] & ~rkd_value[31])
                               | ((rj_value[31] ~^ rkd_value[31]) & rj_rkd_adder_result[31]);
assign unsigned_rj_less_rkd = ~cout;  

wire [31:0] ds_pc;

reg [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus_reg;
always @(posedge clk)
    begin
        if(reset)
            fs_to_ds_bus_reg <= 0;
        else if(fs_to_ds_valid && ds_allow_in)         
            fs_to_ds_bus_reg <= fs_to_ds_bus;
    end
assign {inst,ds_pc} = fs_to_ds_bus_reg;         //_reg;
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we,rf_waddr,rf_wdata} = ws_to_ds_bus;

wire es_we;
wire [4:0] es_dest;
wire [31:0] es_wdata;
wire ms_we;
wire [4:0] ms_dest;
wire [31:0] ms_wdata;

assign {es_we,es_dest,es_res_from_mem,es_wdata} = es_to_ds_bus;
assign {ms_we,ms_dest,ms_wdata} = ms_to_ds_bus;

assign br_taken = ((inst_beq && rj_eq_rd) || (inst_bne && !rj_eq_rd) 
                   || (inst_blt && signed_rj_less_rkd) || (inst_bltu && unsigned_rj_less_rkd)
                   || (inst_bge && ~signed_rj_less_rkd) || (inst_bgeu && ~unsigned_rj_less_rkd)
                   || inst_jirl || inst_bl || inst_b) && ds_valid;

wire br_taken_cancel;
//assign br_taken_cancel = (inst_beq || inst_bne || inst_jirl || inst_bl || inst_b) && ds_valid;

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt 
                             || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :   
                                                   /*inst_jirl*/ (rj_value + jirl_offs); 

assign br_bus = {br_taken_cancel,br_taken,br_target};           

assign rj_value  = forward_rdata1;   
assign rkd_value = forward_rdata2;   
assign imm = src2_is_4 ? 32'h4                      :   
             need_si20 ? {i20[19:0], 12'b0}         :   
             need_ui5  ? {27'b0,rk[4:0]}            :   
             need_si12 ? {{20{i12[11]}}, i12[11:0]} : 
             need_ui12 ? {20'b0,i12[11:0]}         :   
             32'b0 ;
             
assign dst_is_r1     = inst_bl;    
assign dest = dst_is_r1 ? 5'd1 : rd;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu;   
assign mem_we        = inst_st_w;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

assign mul_op[0] = inst_mul_w;
assign mul_op[1] = inst_mulh_w;
assign mul_op[2] = inst_mulh_wu;

assign div_op[0] = inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;
assign div_op[1] = inst_div_w | inst_mod_w;//is signed
assign div_op[2] = inst_div_w | inst_div_wu;//is div

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i; //checked

assign src2_is_imm   = inst_slli_w |    //checked
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu12i|
                       inst_slti   |
                       inst_sltiu  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   ;    

assign res_from_mem  = inst_ld_w;

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

reg ds_valid;   

wire if_read_addr1;  
wire if_read_addr2;   

assign if_read_addr1 = ~inst_b && ~inst_bl && ~inst_lu12i_w && ~inst_pcaddu12i;
assign if_read_addr2 = inst_beq || inst_bne || inst_xor || inst_or || inst_and || inst_nor ||
                       inst_sltu || inst_slt || inst_sub_w || inst_add_w || inst_st_w || inst_sll_w || inst_srl_w || inst_sra_w ||
                       inst_mul_w || inst_mulh_w || inst_mulh_wu || inst_div_w || inst_div_wu ||
                       inst_mod_w || inst_mod_wu || inst_blt || inst_bge || inst_bltu || inst_bgeu;

wire Need_Block;    //ex_crush & es_res_from_mem

assign Need_Block = (ex_crush1 || ex_crush2) && es_res_from_mem;

wire ex_crush1;
wire ex_crush2;
assign ex_crush1 = (es_we && es_dest!=0) && (if_read_addr1 && rf_raddr1==es_dest);
assign ex_crush2 = (es_we && es_dest!=0) && (if_read_addr2 && rf_raddr2==es_dest);

wire mem_crush1;
wire mem_crush2;
assign mem_crush1 = (ms_we && ms_dest!=0) && (if_read_addr1 && rf_raddr1==ms_dest);
assign mem_crush2 = (ms_we && ms_dest!=0) && (if_read_addr2 && rf_raddr2==ms_dest);

wire wb_crush1;
wire wb_crush2;
assign wb_crush1 = (rf_we && rf_waddr!=0) && (if_read_addr1 && rf_raddr1==rf_waddr);
assign wb_crush2 = (rf_we && rf_waddr!=0) && (if_read_addr2 && rf_raddr2==rf_waddr);

//forward deliver
wire [31:0] forward_rdata1;
wire [31:0] forward_rdata2;
assign forward_rdata1 = ex_crush1? es_wdata : mem_crush1? ms_wdata : wb_crush1? rf_wdata : rf_rdata1;
assign forward_rdata2 = ex_crush2? es_wdata : mem_crush2? ms_wdata : wb_crush2? rf_wdata : rf_rdata2;

wire ds_ready_go;
assign ds_ready_go = ~Need_Block;         
assign ds_allow_in = !ds_valid || ds_ready_go && es_allow_in;
assign ds_to_es_valid = ds_valid && ds_ready_go;


assign br_taken_cancel =  Need_Block ? 1'b0 : br_taken;

always @(posedge clk)
    begin
        if(reset)
            ds_valid <= 1'b0;
        else if(br_taken_cancel)
            ds_valid <= 1'b0;
        else if(ds_allow_in)
            ds_valid <= fs_to_ds_valid;
    end

assign rf_raddr1 = rj;  
assign rf_raddr2 = src_reg_is_rd ? rd : rk; 
regfile u_regfile(
    .clk    (clk      ),   
    .raddr1 (rf_raddr1),    
    .rdata1 (rf_rdata1),    
    .raddr2 (rf_raddr2),    
    .rdata2 (rf_rdata2),    
    .we     (rf_we    ),    
    .waddr  (rf_waddr ),    
    .wdata  (rf_wdata )     
    );


endmodule