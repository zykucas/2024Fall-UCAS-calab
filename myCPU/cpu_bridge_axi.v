module cpu_bridge_axi(
    input           clk,
    input           resetn,

    /*
    cpu --> bridge --> axi --
                            |
                            V
    cpu <-- bridge <-- axi --
    */

    /*
    inst sram:
    master: cpu ; slave: bridge
    input:  cpu --> bridge
    output: bridge --> cpu
    */
    /*input           inst_req,
    input           inst_wr,
    input  [1:0]    inst_size,
    input  [31:0]   inst_addr,
    input  [3:0]    inst_wstrb,
    input  [31:0]   inst_wdata,
    output [31:0]   inst_rdata,
    output          inst_addr_ok,
    output          inst_data_ok,*/

    /*
    data sram:
    master: cpu ; slave: bridge
    input:  cpu --> bridge
    output: bridge --> cpu
    */
    input           data_req,
    input           data_wr,
    input  [1:0]    data_size,
    input  [31:0]   data_addr,
    input  [3:0]    data_wstrb,
    input  [31:0]   data_wdata,
    output [31:0]   data_rdata,
    output          data_addr_ok,
    output          data_data_ok,

    /*
    axi:
    master: bridge ; slave: axi
    input:  axi --> bridge
    output: bridge --> axi
    */

    //ar    ������ͨ��
    output [3:0]    arid,           //������ID                           ȡָ0��ȡ1     
    output [31:0]   araddr,         //������ĵ�ַ    
    output [7:0]    arlen,          //fixed --> 8'b0
    output [2:0]    arsize,         //�������С(���ݴ���ÿ�ĵ��ֽ���)     
    output [1:0]    arburst,        //fixed --> 2'b1
    output [1:0]    arlock,         //fixed --> 2'b0
    output [3:0]    arcache,        //fixed --> 4'b0
    output [2:0]    arprot,         //fixed --> 3'b0
    output          arvalid,        //�������ַ����(�������ַ��Ч)
    input           arready,        //�������ַ����(slave��׼���ý��յ�ַ)

    //r  ����Ӧͨ��
    input  [3:0]    rid,            //�������ID�ţ�ͬһ�����rid=arid
    input  [31:0]   rdata,          //������Ķ�������
    input  [1:0]    rresp,          //ignore
    input           rlast,          //ignore
    input           rvalid,         //��������������(������������Ч)
    output          rready,         //��������������(master��׼���ý�������)

    //aw  д����ͨ��
    output [3:0]    awid,           //fixed, 4'b1
    output [31:0]   awaddr,         //д����ĵ�ַ
    output [7:0]    awlen,          //fixed, 8'b0
    output [2:0]    awsize,         //������Ĵ�С(���ݴ���ÿ�ĵ��ֽ���)
    output [1:0]    awburst,        //fixed, 2'b1
    output [1:0]    awlock,         //fixed, 2'b0
    output [1:0]    awcache,        //fixed, 4'b0
    output [2:0]    awprot,         //fixed, 3'b0
    output          awvalid,        //д�����ַ����(д�����ַ��Ч)
    input           awready,        //д�����ַ����(slave��׼���ý��յ�ַ)

    //w  д����ͨ��
    output [3:0]    wid,            //fixed, 4'b1
    output [31:0]   wdata,          //д�����д����
    output [3:0]    wstrb,          //�ֽ�ѡ��λ
    output          wlast,          //fixed, 1'b1
    output          wvalid,         //д������������(д����������Ч)
    input           wready,         //д������������(slave��׼���ý�������)

    //b  д��Ӧͨ��
    input  [3:0]    bid,            //ignore
    input  [1:0]    bresp,          //ignore
    input           bvalid,         //д������Ӧ����(д������Ӧ��Ч)
    output          bready,          //д������Ӧ����(master��׼���ý���д��Ӧ)

    // icache rd interface
    input               	icache_rd_req,
    input   	[ 2:0]      icache_rd_type,
    input   	[31:0]      icache_rd_addr,
    output              	icache_rd_rdy,		// icache_addr_ok
    output              	icache_ret_valid,	// icache_data_ok
	output					icache_ret_last,
    output  	[31:0]      icache_ret_data
);

wire           inst_req = icache_rd_req;
wire           inst_wr = 1'b0;
wire  [1:0]    inst_size = 2'b10;
wire  [31:0]   inst_addr = icache_rd_addr;
wire  [3:0]    inst_wstrb = 4'b0;
wire  [31:0]   inst_wdata = 32'b0;
wire  [31:0]   inst_rdata;
assign         icache_ret_data = inst_rdata;
wire           inst_addr_ok;
assign         icache_rd_rdy = inst_addr_ok;
wire           inst_data_ok; 
assign         icache_ret_valid = inst_data_ok;
assign         icache_ret_last = (r_cur_state == R_INST && r_next_state == R_START && rlast);

            //������״̬��
localparam  AR_START        = 3'b001,
            AR_DATA         = 3'b010,
            AR_INST         = 3'b100,

            //����Ӧ״̬��
            R_START         = 3'b001,
            R_DATA          = 3'b010,
            R_INST          = 3'b100,

            //д����д����״̬��
            AW_START        = 3'b001,
            AW_DATA         = 3'b010,
            W_DATA          = 3'b100,

            //д��Ӧ״̬��
            B_START         = 2'b01,
            B_DATA          = 2'b10;

reg [2:0] ar_cur_state;
reg [2:0] ar_next_state;

reg [2:0] r_cur_state;
reg [2:0] r_next_state;

reg [2:0] aw_cur_state;
reg [2:0] aw_next_state;

reg [1:0] b_cur_state;
reg [1:0] b_next_state;

wire reset;
assign reset = ~resetn;

wire need_wait;  //д�����ͻ����Ҫ�ȴ�
assign need_wait = 1'b0;

/*---------------------------------������״̬��-------------------------------------*/
always @(posedge clk)
    begin
        if(reset)
            ar_cur_state <= AR_START;
        else
            ar_cur_state <= ar_next_state;
    end

always @(*)
    begin
        case(ar_cur_state)
            AR_START:
                begin
                    //deal with data_req first
                    if(rd_data_req && ~need_wait)
                        ar_next_state = AR_DATA;
                    else if(rd_inst_req)
                        ar_next_state = AR_INST;
                    else
                        ar_next_state = AR_START;
                end
            AR_INST:
                begin
                    if(rvalid && rready)
                        ar_next_state = AR_START;
                    else
                        ar_next_state = AR_INST;
                end
            AR_DATA:
                begin
                    if(rvalid && rready)
                        ar_next_state = AR_START;
                    else
                        ar_next_state = AR_DATA;
                end
        endcase
    end

/*---------------------------------------------------------------------------------*/

/*---------------------------------����Ӧ״̬��-------------------------------------*/

always @(posedge clk)
    begin
        if(reset)
            r_cur_state <= R_START;
        else
            r_cur_state <= r_next_state;
    end

always @(*)
    begin
        case(r_cur_state)
            R_START:
                begin
                    //deal with data_req first
                    if((rd_data_req || rd_data_req_reg) && ~need_wait)
                        r_next_state = R_DATA;
                    else if(rd_inst_req)
                        r_next_state = R_INST;
                    else
                        r_next_state = R_START;
                end
            R_INST:
                begin
                    if(rvalid && rready && rlast)
                        r_next_state = R_START;
                    else
                        r_next_state = R_INST;
                end
            R_DATA:
                begin
                    if(rvalid && rready)
                        r_next_state = R_START;
                    else
                        r_next_state = R_DATA;
                end
        endcase
    end

/*---------------------------------------------------------------------------------*/

/*---------------------------------д����״̬��-------------------------------------*/
always @(posedge clk)
    begin
        if(reset)
            aw_cur_state <= AW_START;
        else
            aw_cur_state <= aw_next_state;
    end

always @(*)
    begin
        case(aw_cur_state)
            AW_START:
                begin
                    if(wr_data_req)
                        aw_next_state = AW_DATA;
                    else
                        aw_next_state = AW_START;
                end
            AW_DATA:
                begin
                    if(awvalid && awready)
                        aw_next_state = W_DATA;
                    else
                        aw_next_state = AW_DATA;
                end
            W_DATA:
                begin
                    //if(wvalid && wready)
                    if(bvalid && bready)
                        aw_next_state = AW_START;
                    else
                        aw_next_state = W_DATA;
                end
        endcase
    end

/*---------------------------------------------------------------------------------*/

/*---------------------------------д��Ӧ״̬��-------------------------------------*/
always @(posedge clk)
    begin
        if(reset)
            b_cur_state <= B_START;
        else
            b_cur_state <= b_next_state;
    end

always @(*)
    begin
        case(b_cur_state)
            B_START:
                begin
                    if(wvalid && wready)
                        b_next_state = B_DATA;
                    else
                        b_next_state = B_START;
                end
            B_DATA:
                begin
                    if(bvalid && bready)
                        b_next_state = B_START;
                    else
                        b_next_state = B_DATA;
                end
        endcase
    end

/*---------------------------------------------------------------------------------*/

/*-----------------------------------simplify--------------------------------------*/
wire arid_for_inst;
wire arid_for_data;

assign arid_for_inst = ~arid[0];      //arid == 4'd0 ��ָ
assign arid_for_data = arid[0];       //arid == 4'd1 ����

reg arid_for_inst_reg;
always @(posedge clk ) begin
    if (reset)
        arid_for_inst_reg <= 1'b0;
    else if(arid_for_inst)
        arid_for_inst_reg <= 1'b1;
    else if (rlast) 
        arid_for_inst_reg <= 1'b0;
end

wire rd_inst_req;
wire wr_inst_req;
wire rd_data_req;
wire wr_data_req;

reg rd_data_req_reg;
always @(posedge clk ) begin
    if(reset)
        rd_data_req_reg <= 1'b0;
    else if(r_cur_state != R_START && rd_data_req)
        rd_data_req_reg <= 1'b1;
    else if(r_cur_state != R_START && !rd_data_req)
        rd_data_req_reg <= rd_data_req_reg;
    else
        rd_data_req_reg <= 1'b0;
end

//wr --> 0??? ; 1???
assign rd_inst_req = inst_req && ~inst_wr;      
assign wr_inst_req = inst_req && inst_wr;
assign rd_data_req = data_req && ~data_wr;
assign wr_data_req = data_req && data_wr;

/*----------------------------------------------------------------------------------*/

/*------------------------------------ar_assign-------------------------------------*/
reg  [3:0]  arid_reg;
reg  [31:0] araddr_reg;
reg  [1:0]  arsize_reg;
reg         arvalid_reg;

always @(posedge clk)
    begin
        if(reset)
            arid_reg <= 4'd0;
        else if(ar_cur_state == AR_START && rd_data_req)
            arid_reg <= 4'd1;   //1 --> ȡ��
        else if(ar_cur_state == AR_START && rd_inst_req)
            arid_reg <= 4'd0;   //0 --> ȡָ
        /*
        else if(ar_cur_state == AR_DATA && (arvalid && arready))
            arid_reg <= 4'd0;
        */
    end

always @(posedge clk)
    begin
        if(reset)
            araddr_reg <= 32'd0;
        else if(ar_cur_state == AR_START && rd_data_req)
            araddr_reg <= {data_addr[31:2], 2'd0};
        else if(ar_cur_state == AR_START && rd_inst_req)
            araddr_reg <= inst_addr;
        /*
        else if(ar_cur_state == AR_DATA && (arvalid && arready))
            araddr_reg <= 32'd0;
        */
    end

always @(posedge clk)
    begin
        if(reset)
            arsize_reg <= 2'd0;
        else if(ar_cur_state == AR_START && rd_data_req)
            arsize_reg <= data_size;
        else if(ar_cur_state == AR_START && rd_inst_req)
            arsize_reg <= inst_size;
        /*
        else if(ar_cur_state == AR_DATA && (arvalid && arready))
            arsize_reg <= 2'd0;
        */
    end

always @(posedge clk)
    begin
        if(reset)
            arvalid_reg <= 1'b0;
        else if(ar_cur_state == AR_START && (rd_inst_req || (rd_data_req && ~need_wait)))
            arvalid_reg <= 1'b1;
        else if(arready)
            arvalid_reg <= 1'b0;
    end

assign arid    = arid_reg;
assign araddr  = araddr_reg;
assign arlen   = arid ? 8'd0 : 8'd3;
assign arsize  = arsize_reg;
assign arburst = 2'b1;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = arvalid_reg;

/*----------------------------------------------------------------------------------*/

/*-------------------------------------r_assign-------------------------------------*/
reg rready_reg;

always @(posedge clk)
    begin
        if(reset)
            rready_reg <= 1'b0;
        else if((r_cur_state == R_DATA || r_cur_state == R_INST) && rvalid && rready)
            rready_reg <= 1'b0;
        else if((r_cur_state == R_DATA || r_cur_state == R_INST) && rvalid)
            rready_reg <= 1'b1;
        
    end

assign rready = rready_reg;

/*----------------------------------------------------------------------------------*/

/*------------------------------------aw_assign-------------------------------------*/
reg [31:0]  awaddr_reg;
reg [2:0]   awsize_reg;
reg         awvalid_reg;

always @(posedge clk)
    begin
        if(reset)
            awaddr_reg <= 32'd0;
        else if(aw_cur_state == AW_START && wr_data_req)
            awaddr_reg <= data_addr;
        else if(bvalid)
            awaddr_reg <= 32'b0;
    end

always @(posedge clk)
    begin
        if(reset)
            awsize_reg <= 3'b0;
        else if(aw_cur_state == AW_START && wr_data_req)
            awsize_reg <= data_size;
        else if(bvalid)
            awsize_reg <= 3'b0;
    end

always @(posedge clk)
    begin
        if(reset)
            awvalid_reg <= 1'b0;
        else if(aw_cur_state == AW_START && (wr_data_req))
            awvalid_reg <= 1'b1;
        else if(awready)
            awvalid_reg <= 1'b0;
    end

assign awid     = 4'b1;
assign awaddr   = awaddr_reg;
assign awlen    = 8'b0;
assign awsize   = awsize_reg;
assign awburst  = 2'b01;
assign awlock   = 1'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;
assign awvalid  = awvalid_reg;

/*----------------------------------------------------------------------------------*/

/*-------------------------------------w_assign-------------------------------------*/
reg [31:0] wdata_reg;
reg [3:0]  wstrb_reg;
reg        wvalid_reg;

always @(posedge clk)
    begin
        if(reset)
            wdata_reg <= 32'b0;
        else if(aw_cur_state == AW_START && wr_data_req)
            wdata_reg <= data_wdata;
        else if(bvalid)
            wdata_reg <= 32'b0;
    end

always @(posedge clk)
    begin
        if(reset)
            wstrb_reg <= 4'b0;
        else if(aw_cur_state == AW_START && wr_data_req)
            wstrb_reg <= data_wstrb;
        else if(bvalid)
            wstrb_reg <= 4'b0;
    end

always @(posedge clk)
    begin
        if(reset)
            wvalid_reg <= 1'b0;
        else if(aw_cur_state == AW_DATA && (awvalid && awready))
            wvalid_reg <= 1'b1;
        else if(wready)
            wvalid_reg <= 1'b0;
    end

assign wid      = 4'b1;
assign wdata    = wdata_reg;
assign wstrb    = wstrb_reg;
assign wlast    = 1'b1;
assign wvalid   = wvalid_reg;

/*----------------------------------------------------------------------------------*/

/*-------------------------------------b_assign-------------------------------------*/
reg bready_reg;

always @(posedge clk)
    if(reset)
        bready_reg <= 1'b0;
    else if(b_cur_state == B_START && (wvalid && wready))
        bready_reg <= 1'b1;
    else if(bvalid)
        bready_reg <= 1'b0;

assign bready = bready_reg;

/*----------------------------------------------------------------------------------*/

/*---------------------------------------to cpu-------------------------------------*/
assign inst_addr_ok = ( (ar_cur_state == AR_START) && rd_inst_req && ~rd_data_req)  //deal with rd_data_req first
                  ||  ( (aw_cur_state == AW_START) && wr_inst_req);

assign data_addr_ok = ( (ar_cur_state == AR_START) && rd_data_req && ~need_wait)
                  ||  ( (aw_cur_state == AW_START) && wr_data_req);

assign inst_data_ok = ( (r_cur_state == R_INST) && rvalid && rready);

assign data_data_ok = ( (r_cur_state == R_DATA) && rvalid && rready)
                  ||  ( (aw_cur_state == W_DATA) && bvalid);

reg [31:0] inst_rdata_reg;
reg [31:0] data_rdata_reg;

always @(posedge clk)
    begin
        if(reset)
            inst_rdata_reg <= 32'b0;
        else if(r_cur_state == R_INST && (arid_for_inst | arid_for_inst_reg) && rvalid)
            inst_rdata_reg <= rdata;
        /*  if temp_inst need it , can't clear it
        else if(r_cur_state == R_START)
            inst_rdata_reg <= 32'b0;
        */
    end

always @(posedge clk)
    begin
        if(reset)
            data_rdata_reg <= 32'b0;
        else if(r_cur_state == R_DATA && arid_for_data && rvalid)
            data_rdata_reg <= rdata;
        /*
        else if(r_cur_state == R_START)
            data_rdata_reg <= 32'b0;
        */
    end

assign inst_rdata = inst_rdata_reg;
assign data_rdata = data_rdata_reg;

/*----------------------------------------------------------------------------------*/
endmodule