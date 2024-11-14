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

    //ar ?????????

    output [3:0]    arid,           //??????ID??                           ??0?????1        
    output [31:0]   araddr,         //?????????                          
    output [7:0]    arlen,          //????????(???????????)            ????0
    output [2:0]    arsize,         //???????��(????????????????)     
    output [1:0]    arburst,        //????????                             ????2'b01
    output [1:0]    arlock,         //?????                               
    output [3:0]    arcache,        //CACHE????
    output [2:0]    arprot,         //????????
    output          arvalid,        //????????????(??????????��)
    input           arready,        //????????????(slave????????????)

    //r  ????????
    input  [3:0]    rid,            //???????ID??????????rid=arid
    input  [31:0]   rdata,          //??????????????
    input  [1:0]    rresp,          //???��?????????????(?????)
    input           rlast,          //???��????????????????(?????)
    input           rvalid,         //??????????????(????????????��)
    output          rready,         //??????????????(master??????????????)

    //aw  ��???????
    output [3:0]    awid,           //��?????ID??
    output [31:0]   awaddr,         //��???????
    output [7:0]    awlen,          //??????????
    output [2:0]    awsize,         //????????��(????????????????)
    output [1:0]    awburst,        //????????
    output [1:0]    awlock,         //?????
    output [1:0]    awcache,        //CACHE????
    output [2:0]    awprot,         //????????
    output          awvalid,        //��??????????(��????????��)
    input           awready,        //��??????????(slave????????????)

    //w  ��???????
    output [3:0]    wid,            //��?????ID??
    output [31:0]   wdata,          //��?????��????
    output [3:0]    wstrb,          //?????��
    output          wlast,          //????��?????????????????????
    output          wvalid,         //��????????????(��??????????��)
    input           wready,         //��????????????(slave??????????????)

    //b  ��??????
    input  [3:0]    bid,            //bid = wid = awid
    input  [1:0]    bresp,          //????��????????????
    input           bvalid,         //��???????????(��?????????��)
    output          bready,         //��???????????(master??????????��???)

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



cpu_bridge_axi u_cpu_bridge_axi(
    .clk        (aclk),
    .resetn     (aresetn),

    //inst sram
    .inst_req       (cpu_inst_req),
    .inst_wr        (cpu_inst_wr),
    .inst_size      (cpu_inst_size),
    .inst_addr      (cpu_inst_addr),
    .inst_wstrb     (cpu_inst_wstrb),
    .inst_wdata     (cpu_inst_wdata),
    .inst_addr_ok   (cpu_inst_addr_ok),
    .inst_data_ok   (cpu_inst_data_ok),
    .inst_rdata     (cpu_inst_rdata),

    //data sram
    .data_req       (cpu_data_req),
    .data_wr        (cpu_data_wr),
    .data_size      (cpu_data_size),
    .data_addr      (cpu_data_addr),
    .data_wstrb     (cpu_data_wstrb),
    .data_wdata     (cpu_data_wdata),
    .data_addr_ok   (cpu_data_addr_ok),
    .data_data_ok   (cpu_data_data_ok),
    .data_rdata     (cpu_data_rdata),

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
    .inst_sram_addr_ok(cpu_inst_addr_ok),
    .inst_sram_data_ok(cpu_inst_data_ok),
    .inst_sram_rdata  (cpu_inst_rdata),

    // data sram
    .data_sram_req    (cpu_data_req),
    .data_sram_wr     (cpu_data_wr),
    .data_sram_size   (cpu_data_size),
    .data_sram_wstrb  (cpu_data_wstrb),
    .data_sram_addr   (cpu_data_addr),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_addr_ok(cpu_data_addr_ok),
    .data_sram_data_ok(cpu_data_data_ok),
    .data_sram_rdata  (cpu_data_rdata),

    //debug interface
    .debug_wb_pc      (debug_wb_pc),
    .debug_wb_rf_we  (debug_wb_rf_we),
    .debug_wb_rf_wnum (debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule