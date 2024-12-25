/*  from soc_lite_top.v
mycpu_top u_cpu(
    .aclk      (cpu_clk       ),
    .aresetn   (cpu_resetn    ),   //low active

    .arid      (cpu_arid      ),
    .araddr    (cpu_araddr    ),
    .arlen     (cpu_arlen     ),
    .arsize    (cpu_arsize    ),
    .arburst   (cpu_arburst   ),
    .arlock    (cpu_arlock    ),
    .arcache   (cpu_arcache   ),
    .arprot    (cpu_arprot    ),
    .arvalid   (cpu_arvalid   ),
    .arready   (cpu_arready   ),
                
    .rid       (cpu_rid       ),
    .rdata     (cpu_rdata     ),
    .rresp     (cpu_rresp     ),
    .rlast     (cpu_rlast     ),
    .rvalid    (cpu_rvalid    ),
    .rready    (cpu_rready    ),
               
    .awid      (cpu_awid      ),
    .awaddr    (cpu_awaddr    ),
    .awlen     (cpu_awlen     ),
    .awsize    (cpu_awsize    ),
    .awburst   (cpu_awburst   ),
    .awlock    (cpu_awlock    ),
    .awcache   (cpu_awcache   ),
    .awprot    (cpu_awprot    ),
    .awvalid   (cpu_awvalid   ),
    .awready   (cpu_awready   ),
    
    .wid       (cpu_wid       ),
    .wdata     (cpu_wdata     ),
    .wstrb     (cpu_wstrb     ),
    .wlast     (cpu_wlast     ),
    .wvalid    (cpu_wvalid    ),
    .wready    (cpu_wready    ),
    
    .bid       (cpu_bid       ),
    .bresp     (cpu_bresp     ),
    .bvalid    (cpu_bvalid    ),
    .bready    (cpu_bready    ),

    //debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
*/

module mycpu_top(
    input           aclk,
    input           aresetn,

     //ar ������ͨ��

    output [3:0]    arid,           //������ID��                           ȡָ0��ȡ��1        
    output [31:0]   araddr,         //������ĵ�ַ                          
    output [7:0]    arlen,          //�����䳤��(���ݴ�������)            �̶�Ϊ0
    output [2:0]    arsize,         //�������С(���ݴ���ÿ�ĵ��ֽ���)     
    output [1:0]    arburst,        //��������                             �̶�Ϊ2'b01
    output [1:0]    arlock,         //ԭ����                               
    output [3:0]    arcache,        //CACHE����
    output [2:0]    arprot,         //��������
    output          arvalid,        //�������ַ����(�������ַ��Ч)
    input           arready,        //�������ַ����(slave��׼���ý��յ�ַ)

    //r  ����Ӧͨ��
    input  [3:0]    rid,            //�������ID�ţ�ͬһ�����rid=arid
    input  [31:0]   rdata,          //������Ķ�������
    input  [1:0]    rresp,          //���ζ������Ƿ�ɹ����(�ɺ���)
    input           rlast,          //���ζ��������һ��ָʾ�ź�(�ɺ���)
    input           rvalid,         //��������������(������������Ч)
    output          rready,         //��������������(master��׼���ý�������)

    //aw  д����ͨ��
    output [3:0]    awid,           //д�����ID��
    output [31:0]   awaddr,         //д����ĵ�ַ
    output [7:0]    awlen,          //������ĳ���
    output [2:0]    awsize,         //������Ĵ�С(���ݴ���ÿ�ĵ��ֽ���)
    output [1:0]    awburst,        //��������
    output [1:0]    awlock,         //ԭ����
    output [1:0]    awcache,        //CACHE����
    output [2:0]    awprot,         //��������
    output          awvalid,        //д�����ַ����(д�����ַ��Ч)
    input           awready,        //д�����ַ����(slave��׼���ý��յ�ַ)

    //w  д����ͨ��
    output [3:0]    wid,            //д�����ID��
    output [31:0]   wdata,          //д�����д����
    output [3:0]    wstrb,          //�ֽ�ѡͨλ
    output          wlast,          //����д��������һ�����ݵ�ָʾ�ź�
    output          wvalid,         //д������������(д����������Ч)
    input           wready,         //д������������(slave��׼���ý�������)

    //b  д��Ӧͨ��
    input  [3:0]    bid,            //bid = wid = awid
    input  [1:0]    bresp,          //����д�����Ƿ�ɹ����
    input           bvalid,         //д������Ӧ����(д������Ӧ��Ч)
    output          bready,         //д������Ӧ����(master��׼���ý���д��Ӧ)

    // debug
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_we ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

wire        cpu_inst_req;
wire        cpu_inst_wr;
wire [1:0]  cpu_inst_size;
wire [31:0] cpu_inst_addr;
wire [3:0]  cpu_inst_wstrb;
wire [31:0] cpu_inst_wdata;
wire        cpu_inst_addr_ok;
wire        cpu_inst_data_ok;
wire [31:0] cpu_inst_rdata;

wire        cpu_data_req;
wire        cpu_data_wr;
wire [1:0]  cpu_data_size;
wire [31:0] cpu_data_addr;
wire [3:0]  cpu_data_wstrb;
wire [31:0] cpu_data_wdata;
wire        cpu_data_addr_ok;
wire        cpu_data_data_ok;
wire [31:0] cpu_data_rdata;

//icache read channel
    wire [31:0] inst_addr_vrtl;
    wire        icache_addr_ok;
    wire        icache_data_ok;
    wire [31:0] icache_rdata;
    wire        icache_rd_req;
    wire [ 2:0] icache_rd_type;
    wire [31:0] icache_rd_addr;
    wire        icache_rd_rdy;
    wire        icache_ret_valid;
    wire        icache_ret_last;
    wire [31:0] icache_ret_data;

    //icache write channel=meaning less ,all is 0        
    wire        icache_wr_req;
    wire [ 2:0] icache_wr_type;
    wire [31:0] icache_wr_addr;
    wire [ 3:0] icache_wr_strb;
    wire [127:0]icache_wr_data;
    wire        icache_wr_rdy=1'b0;  
    
    wire        icache_uncache;

//dcache read channel
    wire [31:0] data_addr_vrtl;
    wire        dcache_addr_ok;
    wire        dcache_data_ok;
    wire [31:0] dcache_rdata;
    wire        dcache_rd_req;
    wire [ 2:0] dcache_rd_type;
    wire [31:0] dcache_rd_addr;
    wire        dcache_rd_rdy;
    wire        dcache_ret_valid;
    wire        dcache_ret_last;
    wire [31:0] dcache_ret_data;

    //dcache write channel       
    wire        dcache_wr_req;
    wire [ 2:0] dcache_wr_type;
    wire [31:0] dcache_wr_addr;
    wire [ 3:0] dcache_wr_strb;
    wire [127:0]dcache_wr_data;
    wire        dcache_wr_rdy;
    wire        dcache_uncache;
    wire        axi_uncache;

    //cacop add
    wire [31:0] cacop_addr;
    wire [ 4:0] cacop_code;
    wire        cacop_icache;
    wire        cacop_dcache;
    wire        cacop_over_dcache;
    wire        cacop_over_icache;
    
cpu_bridge_axi u_cpu_bridge_axi(
    .clk        (aclk),
    .resetn     (aresetn),

    //inst sram
    .icache_rd_req  (icache_rd_req),
    .icache_rd_type (icache_rd_type),
    .icache_rd_addr (icache_rd_addr),
    .icache_rd_rdy  (icache_rd_rdy),
    .icache_ret_valid(icache_ret_valid),
    .icache_ret_last(icache_ret_last),
    .icache_ret_data(icache_ret_data),
    
    //data sram -- dcache
    .dcache_rd_req  (dcache_rd_req),
    .dcache_rd_type (dcache_rd_type),
    .dcache_rd_addr (dcache_rd_addr),
    .dcache_rd_rdy  (dcache_rd_rdy),
    .dcache_wr_req  (dcache_wr_req),
    .dcache_wr_type (dcache_wr_type),
    .dcache_wr_addr (dcache_wr_addr),
    .dcache_wr_strb (dcache_wr_strb),
    .dcache_wr_data (dcache_wr_data),
    .dcache_wr_rdy  (dcache_wr_rdy),
    .dcache_uncache  (axi_uncache),
    
    .dcache_ret_valid(dcache_ret_valid),
    .dcache_ret_last(dcache_ret_last),
    .dcache_ret_data(dcache_ret_data),
    
    //data sram
//    .data_req       (),
//    .data_wr        (),
//    .data_size      (),
//    .data_addr      (),
//    .data_wstrb     (),
//    .data_wdata     (),
//    .data_addr_ok   (),
//    .data_data_ok   (),
//    .data_rdata     (),

    //ar
    .arid           (arid),
    .araddr         (araddr),
    .arlen          (arlen),
    .arsize         (arsize),
    .arburst        (arburst),
    .arlock         (arlock),
    .arcache        (arcache),
    .arprot         (arprot),
    .arvalid        (arvalid),
    .arready        (arready),
    
    //r
    .rid            (rid),
    .rdata          (rdata),
    .rresp          (rresp),
    .rlast          (rlast),
    .rvalid         (rvalid),
    .rready         (rready),
    
    //aw
    .awid           (awid),
    .awaddr         (awaddr),
    .awlen          (awlen),
    .awsize         (awsize),
    .awburst        (awburst),
    .awlock         (awlock),
    .awcache        (awcache),
    .awprot         (awprot),
    .awvalid        (awvalid),
    .awready        (awready),
    
    //w
    .wid            (wid),
    .wdata          (wdata),
    .wstrb          (wstrb),
    .wlast          (wlast),
    .wvalid         (wvalid),
    .wready         (wready),
    
    //b
    .bid            (bid),
    .bresp          (bresp),
    .bvalid         (bvalid),
    .bready         (bready)
);

mycpu u_cpu(
    .clk              (aclk),
    .resetn           (aresetn),  //low active

    // inst sram
    .inst_sram_req    (cpu_inst_req),
    .inst_sram_wr     (cpu_inst_wr),
    .inst_sram_size   (cpu_inst_size),
    .inst_sram_wstrb  (cpu_inst_wstrb),
    .inst_sram_addr   (cpu_inst_addr),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_addr_ok(icache_addr_ok),
    .inst_sram_data_ok(icache_data_ok),
    .inst_sram_rdata  (icache_rdata),

    // data sram
    .data_sram_req    (cpu_data_req),
    .data_sram_wr     (cpu_data_wr),
    .data_sram_size   (cpu_data_size),
    .data_sram_wstrb  (cpu_data_wstrb),
    .data_sram_addr   (cpu_data_addr),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_addr_ok(dcache_addr_ok),
    .data_sram_data_ok(dcache_data_ok),
    .data_sram_rdata  (dcache_rdata),

    //debug interface
    .debug_wb_pc      (debug_wb_pc),
    .debug_wb_rf_we  (debug_wb_rf_we),
    .debug_wb_rf_wnum (debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    //icache add
    .inst_addr_vrtl   (inst_addr_vrtl),
    .inst_uncache   (icache_uncache),
    
    //dcache add
    .data_addr_vrtl   (data_addr_vrtl),
    .data_uncache   (dcache_uncache),

    //cacop add
    .cacop_code        (cacop_code),
    .cacop_addr        (cacop_addr),
    .cacop_icache      (cacop_icache),
    .cacop_dcache      (cacop_dcache),

    .cacop_over_dcache        (cacop_over_dcache),
    .cacop_over_icache        (cacop_over_icache)    
);

icache icache(
    //----------cpu interface------
        .clk    (aclk                       ),
        .resetn (aresetn                    ),
        .valid  (cpu_inst_req               ),//pre-if request valid
        .op     (cpu_inst_wr                ),//always 0==read
        .index  (inst_addr_vrtl[11:4]       ),
        .tag    (cpu_inst_addr[31:12]       ),//from tlb:inst_sram_addr[31:12]=ʵ��ַ
        .offset (inst_addr_vrtl[3:0]        ),
        .wstrb  (cpu_inst_wstrb             ),
        .wdata  (cpu_inst_wdata             ),
        .addr_ok(icache_addr_ok             ),//output ��ˮ�߷��� ������ˮ�ߵ�ָ��
        .data_ok(icache_data_ok             ),
        .rdata  (icache_rdata               ),//output
        //--------AXI read interface-------
        .rd_req (icache_rd_req              ),//output
        .rd_type(icache_rd_type             ),
        .rd_addr(icache_rd_addr             ),

        .rd_rdy   (icache_rd_rdy            ),//input ���߷�����
        .ret_valid(icache_ret_valid         ),
        .ret_last (icache_ret_last          ),
        .ret_data (icache_ret_data          ),

        //--------AXI write interface------
        .wr_req (icache_wr_req              ),//output,����icache��Զ��0
        .wr_type(icache_wr_type             ),
        .wr_addr(icache_wr_addr             ),
        .wr_wstrb(icache_wr_strb             ),
        .wr_data(icache_wr_data             ),
        .wr_rdy (icache_wr_rdy              ),//icache��������Ҫдsram����1û�й�ϵ

        .uncache(icache_uncache             ),

        .cacop_icache(cacop_icache          ),
        .cacop_addr  (cacop_addr            ),
        .cacop_code  (cacop_code            ),

        .cacop_over  (cacop_over_icache      )
);


dcache dcache(
    //----------cpu interface------
        .clk    (aclk                       ),
        .resetn (aresetn                    ),
        .valid  (cpu_data_req               ),//pre-if request valid
        .op     (cpu_data_wr                ),//always 0==read
        .index  (data_addr_vrtl[11:4]       ),
        .tag    (cpu_data_addr[31:12]       ),//from tlb:inst_sram_addr[31:12]=ʵ��ַ
        .offset (data_addr_vrtl[3:0]        ),
        .wstrb  (cpu_data_wstrb             ),
        .wdata  (cpu_data_wdata             ),
        .addr_ok(dcache_addr_ok             ),//output ��ˮ�߷��� ������ˮ�ߵ�ָ��
        .data_ok(dcache_data_ok             ),
        .rdata  (dcache_rdata               ),//output
        //--------AXI read interface-------
        .rd_req (dcache_rd_req              ),//output
        .rd_type(dcache_rd_type             ),
        .rd_addr(dcache_rd_addr             ),

        .rd_rdy   (dcache_rd_rdy            ),//input ���߷�����
        .ret_valid(dcache_ret_valid         ),
        .ret_last (dcache_ret_last          ),
        .ret_data (dcache_ret_data          ),

        //--------AXI write interface------
        .wr_req (dcache_wr_req              ),//output,����icache��Զ��0
        .wr_type(dcache_wr_type             ),
        .wr_addr(dcache_wr_addr             ),
        .wr_wstrb(dcache_wr_strb             ),
        .wr_data(dcache_wr_data             ),
        .wr_rdy (dcache_wr_rdy              ),
        .axi_uncache(axi_uncache),
        
        .uncache(dcache_uncache             ),

        .cacop_dcache(cacop_dcache          ),
        .cacop_addr  (cacop_addr            ),
        .cacop_code  (cacop_code            ),
        .cacop_over  (cacop_over_dcache     )
);

endmodule