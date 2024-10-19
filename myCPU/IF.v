`include "mycpu_head.vh"

module stage1_IF(
    input clk,
    input reset,

    input ertn_flush,
    input has_int,
    input wb_ex,

    input [31:0] ertn_pc,
    input [31:0] ex_entry,

    input ds_allow_in,
    input [`WIDTH_BR_BUS-1:0] br_bus,
    output fs_to_ds_valid,
    output [`WIDTH_FS_TO_DS_BUS-1:0] fs_to_ds_bus,

    //exp14
    output          inst_sram_req,
    output          inst_sram_wr,
    //output          inst_sram_en,
    output [1:0]    inst_sram_size,
    output [3:0]    inst_sram_wstrb, 
    output [31:0]   inst_sram_addr,
    output [31:0]   inst_sram_wdata,

    //exp14
    input        inst_sram_addr_ok,
    input        inst_sram_data_ok,
    input [31:0] inst_sram_rdata
);

/*--------------------------------valid-----------------------------*/

// pre_if伪流水级的工作室发出取指请求
// 当IF级的allowin为1时再发出req，是为了保证req与addr_ok握手时allowin也是拉高的
assign inst_sram_req = (reset || br_stall) ? 1'b0 : fs_allow_in ? inst_sram_req_reg : 1'b0;

reg inst_sram_req_reg;
always @(posedge clk)
    begin
        if(reset)
            inst_sram_req_reg <= 1'b1;
        else if(inst_sram_req && inst_sram_addr_ok)
            //握手成功，在握手成功的下一个时钟上沿拉低req
            inst_sram_req_reg <= 1'b0;
        else if(inst_sram_data_ok)
            //在握手接收到数据(data_ok)时，重新拉高req
            inst_sram_req_reg <= 1'b1;
    end

/*当req与addr_ok握手成功时，代表请求发送成功，拉高ready_go*/
wire pre_if_ready_go;
assign pre_if_ready_go = inst_sram_req & inst_sram_addr_ok;
wire pre_if_to_fs_valid;
assign pre_if_to_fs_valid = !reset & pre_if_ready_go;

/*
当data_ok拉高时代表已送来指令码，将fs_ready_go拉高
当temp_inst有效时说明fs_ready_go已经拉高，而ds_allow_in没拉高
因此此时在等ds_allow_in，需要保持temp_inst拉高
同时当deal_with_cancel拉高时，表明需要丢弃下一个收到的错误指令，即将fs_ready_go拉低
assign fs_ready_go = deal_with_cancel ? (inst_sram_data_ok ? 1'b1: 1'b0) : ((temp_inst != 0) || inst_sram_data_ok);
*/
wire fs_ready_go;
assign fs_ready_go = deal_with_cancel ? 1'b0 : ((temp_inst != 0) || inst_sram_data_ok);

reg fs_valid;    
always @(posedge clk)
    begin
        if(reset)
            fs_valid <= 1'b0;
        else if(fs_allow_in)
            begin
                if(wb_ex || ertn_flush) //has_init ???
                    /*
                    IF级没有有效指令 或 有效指令将要流向ID级，
                    若收到cancel
                    则将下一拍fs_vaild置0
                    */
                    fs_valid <= 1'b0;
                else
                    fs_valid <= pre_if_to_fs_valid;
            end
        else if(br_taken_cancel)
            fs_valid <= 1'b0;
    end

wire   fs_allow_in;
assign fs_allow_in = !fs_valid || (fs_ready_go && ds_allow_in) || (deal_with_cancel && inst_sram_data_ok);
assign fs_to_ds_valid = fs_valid && fs_ready_go;

/*
当fs_ready_go = 1 而 ds_allow_in = 0 时
IF级收到了指令但是ID级还不让进入，需要设置一组触发器来保存取出的指令
当该组触发器有有效数据时，则选择该组触发器保存的数据作为IF级取回的指令送往ID级
*/
reg [31:0] temp_inst;
always @(posedge clk)
    begin
        if(reset)
            temp_inst <= 0;
        else if(fs_ready_go)
            begin
                if(wb_ex || ertn_flush) //has_init ???
                    //当cancel时，将缓存指令清0
                    temp_inst <= 0;
                else if(!ds_allow_in)
                    //暂存指令
                    temp_inst <= inst_sram_rdata;
                else
                    //当ds允许进入时，在这个时钟上沿就立刻将temp_inst
                    //送入ds级，同时将temp_inst清零，代表该指令缓存不再有有效指令
                    temp_inst <= 0;
            end
    end

/*
为了解决在cancel后，IF级后续收到的第一个返回的指令数据是对当前被cancel的取值指令的返回
因此后续收到的第一个返回的指令数据需要被丢弃，不能让其流向ID级。
需要维护一个触发器，复位值为0，遇到上述问题将该触发器置1，当收到data_ok时复置0
当该触发器为1时，将IF级的ready_go抹零，即当data_ok来临的时钟上沿，fs_ready_go
恰好仍为0，导致刚好丢弃了data（丢弃的指令） 
*/
reg deal_with_cancel;
always @(posedge clk)
    begin
        if(reset)
            deal_with_cancel <= 1'b0;
        else if((wb_ex || ertn_flush) && pre_if_to_fs_valid) //has_init???
            //pre_if_to_fs_valid 对应pre-if发送的地址正好被接收
            deal_with_cancel <= 1'b1;
        else if(~fs_allow_in && (wb_ex || ertn_flush) && ~fs_ready_go)//has_init???
            //~fs_allow_in 且 ~fs_ready_go 对应IF级正在等待data_ok
            deal_with_cancel <= 1'b1;
        else if(inst_sram_data_ok)
            deal_with_cancel <= 1'b0;
    end


wire [31:0] br_target; //跳转地址
wire br_taken;         //是否跳转
wire br_stall;//exp14 
wire br_taken_cancel;
assign {br_taken_cancel, br_stall, br_taken, br_target} = br_bus;

reg [31:0] fetch_pc; 

wire [31:0] seq_pc;     //PC in sequence
assign seq_pc = fetch_pc + 4;
wire [31:0] next_pc;    //nextpc from branch or sequence
//exp14
assign next_pc = if_keep_pc ? br_delay_reg : wb_ex? ex_entry : ertn_flush? ertn_pc : (br_taken && ~br_stall) ? br_target : seq_pc;

/*
当出现异常入口pc、异常返回pc和跳转pc时，信号和pc可能只能维持一拍，
但在req收到addr_ok前需要维持取址地址不变
*/
reg if_keep_pc;
reg [31:0] br_delay_reg;
always @(posedge clk)
    begin
        if(reset)
            if_keep_pc <= 1'b0;
        else if(inst_sram_addr_ok && ~deal_with_cancel && ~wb_ex && ~ertn_flush)
            if_keep_pc <= 1'b0;
        else if((br_taken && ~br_stall) || wb_ex || ertn_flush)
            if_keep_pc <= 1'b1;
    end   

always @(posedge clk)
    begin
        if(reset)
            br_delay_reg <= 32'b0;
        else if(wb_ex) 
            br_delay_reg <= ex_entry;
        else if(ertn_flush)
            br_delay_reg <= ertn_pc;
        else if(br_taken && ~br_stall)
            br_delay_reg <= br_target;
    end

always @(posedge clk)
    begin
        if(reset)
            fetch_pc <= 32'h1BFFFFFC;
        else if(pre_if_to_fs_valid && fs_allow_in)
            fetch_pc <= next_pc;
    end

/*----------------------------Link to inst_ram---------------------*/

/*
    output          inst_sram_req,
    output          inst_sram_wr,
    output [1:0]    inst_sram_size,
    output [3:0]    inst_sram_wstrb,
    output [31:0]   inst_sram_addr,
    output [31:0]   inst_sram_wdata,   
*/

//inst_sram_req在上面赋值
assign inst_sram_wr    = 1'b0;    //fetch阶段只读不写
assign inst_sram_size  = 2'b10;   //fetch阶段访问4字节
assign inst_sram_wstrb = 4'b0;    //fetch阶段wstrb无意义
assign inst_sram_addr  = next_pc;
assign inst_sram_wdata = 32'b0;

/*----------------------------deliver fs_to_ds_bus------------------------*/

wire [31:0] fetch_inst;
assign fetch_inst = inst_sram_rdata;
// ADEF exception
wire fs_exc_ADEF;//pc not end with 2'b00
//exp14
assign fs_exc_ADEF = ~inst_sram_wr && (fetch_pc[1] | fetch_pc[0]); //next_pc???

//assign fs_to_ds_bus = {fs_exc_ADEF,fetch_inst,fetch_pc};
//exp14
//当暂存指令缓存有效时，传入temp_inst,无效时正常传入 fetch_inst
assign fs_to_ds_bus[31:0] = fetch_pc;
assign fs_to_ds_bus[63:32] = (temp_inst == 0) ? fetch_inst : temp_inst;
assign fs_to_ds_bus[64:64] = fs_exc_ADEF;


endmodule