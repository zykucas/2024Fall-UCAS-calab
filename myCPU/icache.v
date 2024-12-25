module icache(
    input       clk,
    input       resetn,
    
    //cacheģ����CPU��ˮ�ߵĽ����ӿ�
    input           valid,          //cpu������������Ч
    input           op,             //0 --> �� ; 1 --> д
    input  [7:0]    index,          //��ַ��index��(addr[11:4])(��)
    input  [19:0]   tag,            //��ʵת����ĵ�ַ��??20λ
    input  [3:0]    offset,         //��ַ��offset��(addr[3:0])
    input  [3:0]    wstrb,          //д�ֽ�ʹ���ź�
    input  [31:0]   wdata,          //д����
    
    output          addr_ok,        //�ô�����ĵ�ַ����OK
    output          data_ok,        //�ô���������ݴ���OK
    output [31:0]   rdata,          //��cache���??

    //cacheģ����AXI���߽ӿ�ģ��ӿ�??

    //part1 --> read
    output          rd_req,         //��������Ч�ź�
    output [2:0]    rd_type,        //����������:
    //3'b000 : �ֽ� ; 3'b001 : ���� ; 3'b010 : �� ; 3'b100 : cache��
    output [31:0]   rd_addr,        //��������ʼ��ַ
    input           rd_rdy,         //�������ܷ񱻽��յ������ź�
    input           ret_valid,      //����������Ч�źź󣬸ߵ�ƽ��Ч
    input           ret_last,       //����������һ�ζ������Ӧ�����һ����������
    input  [31:0]   ret_data,       //����������

    //part2 --> write
    output          wr_req,         //д������Ч�ź�
    output [2:0]    wr_type,        //д��������
    //3'b000 : �ֽ� ; 3'b001 : ���� ; 3'b010 : �� ; 3'b100 : cache��
    output [31:0]   wr_addr,        //д������ʼ��ַ
    output [3:0]    wr_wstrb,       //д�������ֽ�����
    output [127:0]  wr_data,        //д����
    input           wr_rdy,          //д�����ܷ񱻽��յ������ź�
    
    input           uncache,

    //exp23 cacop add
    input           cacop_icache,
    input  [31:0]   cacop_addr,
    input  [4:0]    cacop_code,
    output          cacop_over

);

/*-----------------------------------????-----------------------------------------*/

localparam  IDLE            = 5'b00001,
            LOOKUP          = 5'b00010,
            //����������ΪMISS�����ƺ�����׼ȷ��ʵ��Ҫ���Ĺ����ǽ����д��??
            DIRTY_WB        = 5'b00100,
            REPLACE         = 5'b01000,
            REFILL          = 5'b10000,

            //Write Buffer״̬��
            WB_IDLE         = 2'b01,
            WB_WRITE        = 2'b10;

reg [4:0] curr_state;
reg [4:0] next_state;
reg [1:0] wb_curr_state;
reg [1:0] wb_next_state;

//part1: ��״̬��

always @(posedge clk)
    begin
        if(~resetn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

always @(*)
    begin
        case(curr_state)
            IDLE:
                begin
                    if (cacop_cst) begin
                        next_state <= LOOKUP;
                    end
                    else if(~valid)
                        //���cpuû�з�������ͣ����IDLE
                        next_state <= IDLE;
                    else
                        begin
                            if(hit_write)
                                //��������󵫸�������Hit Write��ͻ���޷���Cache����
                                next_state <= IDLE;
                            else
                                //�������Ҳ���ͻ
                                next_state <= LOOKUP;
                        end
                end
            LOOKUP:
            begin
                if (cacop_cst) begin
                    if (cache_hit) begin
                        next_state = REFILL;
                    end
                    else
                        next_state = IDLE;
                end
                else if(cache_hit && !buff_uncache)
                    begin
                        if(~valid)
                            //��cache������û���������򷵻�IDLE�ȴ�
                            next_state <= IDLE;
                        else
                            begin
                            //��cache���е�������������������
                                if(hit_write)
                                    //����������hit write��ͻ����ʱ�޷�����
                                    //��ʱû�д���Hit Write�ĵ�һ�����??
                                    next_state <= IDLE;
                                else
                                    //���Խ���������
                                    next_state <= LOOKUP;
                            end
                    end
                else
                    begin
                        if(if_dirty || (buff_uncache && buff_op == 1))
                            //�����滻������飬����Ҫд��??
                            next_state <= DIRTY_WB;
                        else
                            //�����滻�����飬����Ҫд��
                            next_state <= REPLACE;
                    end
            end
        DIRTY_WB:
            begin
                if(~wr_rdy)
                    //���߲�û��׼���ý���д����״̬������DIRTY_WB
                        next_state <= DIRTY_WB;
                    else
                        //����׼���ý���д���󣬴�ʱ������wr_req
                        //ͬʱ��������wr_type,wr_addr,wr_wtrb,wr_data
                        //���wr_req���ж�����ӦΪ
                        //(curr_state == DIRTY_WB) && (wr_rdy) 
                        next_state <= REPLACE;
                end
            REPLACE:
                begin
                    if(buff_op==1)
                        next_state <= IDLE;
                    else if(~rd_rdy)
                        //AXI����û��׼���ý��ն�����
                        next_state <= REPLACE;
                    else
                        //AXI����׼���ý��ն�����
                        //Ҳ��AXI���߷���ȱʧcache�Ķ�����
                        next_state <= REFILL;
                end
            REFILL:
                begin
                    if (cacop_cst) begin
                        next_state = IDLE;
                    end
                    else if(ret_valid && ret_last)
                         next_state <= IDLE;
                    // if(ret_valid && ~ret_last)
                    //     //��δ�������һ��??32λ����
                    //     next_state <= REFILL;
                    // else if(ret_valid && ret_last)
                    //     next_state <= IDLE;
                    else
                        next_state <= REFILL;
                end
            default:
                next_state <= IDLE;
        endcase
    end

//part2: Write Buffer״̬��

always @(posedge clk)
    begin
        if(~resetn)
            wb_curr_state <= WB_IDLE;
        else
            wb_curr_state <= wb_next_state;
    end

always @(*)
    begin
        case(wb_curr_state)
            WB_IDLE:
                begin
                    if(((curr_state == LOOKUP) && (op == 1) && cache_hit) || (curr_state == REFILL && buff_op == 1 && ret_last && ret_valid))
                        //��״̬������LOOKUP״̬�ҷ���Store��������Cache
                        wb_next_state <= WB_WRITE;
                    else
                        wb_next_state <= WB_IDLE;
                end
            WB_WRITE:
                begin
                    if((curr_state == LOOKUP) && (op == 1) && cache_hit)
                        //��״̬�������µ�Hit Write
                        wb_next_state <= WB_WRITE;
                    else
                        wb_next_state <= WB_IDLE;
                end
            default:
                wb_next_state <= WB_IDLE;
        endcase
    end

/*---------------------------------------------------------------------------------*/

/*-------------------------------BLOCK RAM(v,tag)----------------------------------*/
reg [19:0] reg_tag;

//�����������ͬʱ������MMU����ʵtag����Ҫ���䱣��
always @(posedge clk)
    begin
        if(~resetn)
            reg_tag <= 0;
        else if((curr_state == IDLE && valid && wb_curr_state != WB_WRITE) || (curr_state == LOOKUP && next_state == LOOKUP))
            reg_tag <= cacop_cst ? cacop_addr[31:12] : tag;
        else begin
            reg_tag <= reg_tag;
        end
    end

//����ΪLOOKUP�׶β���ʱ������·
//��Ҫ��replace_way���ֿ�

wire way0_v;
wire way1_v;

assign way0_v = tagv_rdata[0][20];
assign way1_v = tagv_rdata[1][20];

wire [19:0] way0_tag;
wire [19:0] way1_tag;

assign way0_tag = tagv_rdata[0][19:0];
assign way1_tag = tagv_rdata[1][19:0];

wire way0_hit;
wire way1_hit;
wire cache_hit;

reg [7:0] buff_index_reg;
always @(posedge clk)
    begin
        if(~resetn)
            buff_index_reg <= 0;
        else 
            buff_index_reg <= buff_index;
    end

assign way0_hit = way0_v && (way0_tag == reg_tag);
assign way1_hit = way1_v && (way1_tag == reg_tag);
assign cache_hit =  cacop_cst ? (way0_hit || way1_hit) :
                    ((buff_index_reg == buff_index) && (way0_hit || way1_hit));

assign tagv_we[0] = (!uncache && ((curr_state == REFILL) && (buff_way == 0 || (cacop_cst && way0_hit)))) || (cacop_init && cacop_init_way == 0);
assign tagv_we[1] = (!uncache && ((curr_state == REFILL) && (buff_way == 1 || (cacop_cst && way1_hit)))) || (cacop_init && cacop_init_way == 1);

assign tagv_addr[0] = cacop_init ? cacop_init_index : 
                      cacop_cst ? cacop_addr[11:4] :
                      buff_index;
assign tagv_addr[1] = cacop_init ? cacop_init_index : 
                      cacop_cst ? cacop_addr[11:4] :  
                      buff_index;

assign tagv_wdata[0] = cacop_init ? 0 : 
                       cacop_cst ? {1'b0,reg_tag} :
                       {1'b1, reg_tag};
assign tagv_wdata[1] = cacop_init ? 0 : 
                       cacop_cst ? {1'b0,reg_tag} :
                       {1'b1, reg_tag};

//����·��ÿ·4x(20 + 1)����8��bank
wire        tagv_we   [1:0];
wire [7:0]  tagv_addr [1:0];       //depth = 256 = 2 ^ 8
wire [20:0] tagv_wdata[1:0];
wire [20:0] tagv_rdata[1:0];

//way0
TAGV_RAM tagv_way0_ram
(
    .clka (clk),
    .ena(1'b1),
    .wea  (tagv_we[0]),
    .addra(tagv_addr[0]),
    .dina (tagv_wdata[0]),
    .douta(tagv_rdata[0])
);

//way1
TAGV_RAM tagv_way1_ram
(
    .clka (clk),
    .ena(1'b1),
    .wea  (tagv_we[1]),
    .addra(tagv_addr[1]),
    .dina (tagv_wdata[1]),
    .douta(tagv_rdata[1])
);

/*---------------------------------------------------------------------------------*/

/*----------------------------------reg file(d)------------------------------------*/
reg [255:0] way0_d_reg;
reg [255:0] way1_d_reg;

always @(posedge clk)
    begin
        if(~resetn)
            begin
                way0_d_reg <= 256'b0;
                way1_d_reg <= 256'b0;
            end
        if(curr_state == LOOKUP && op == 1 && cache_hit)
            //��cache������Ϊд����ʱ����Ҫ����λ
            begin
                if(way0_hit == 1)
                    way0_d_reg[index] <= 1'b1;
                else if(way1_hit == 1)
                    way1_d_reg[index] <= 1'b1;
            end
        else if(curr_state == REFILL)
            //��cache����ʱ����Ϊ������������λ��0����Ϊд��������1
            begin
                if(op == 0)
                    //������������λ��0
                    begin
                        if(buff_way == 0)
                            way0_d_reg[index] <= 1'b0;
                        else
                            way1_d_reg[index] <= 1'b0;
                    end
                else
                    //д����������λ��1
                    begin
                        if(buff_way == 0)
                            way0_d_reg[index] <= 1'b1;
                        else
                            way1_d_reg[index] <= 1'b1;
                    end
            end
    end

wire way0_d;
wire way1_d;

wire replace_way;
reg  random_way;               //��������·
always @(posedge clk) begin
    if(~resetn)
        random_way <= 1'b0;
    else if(next_state == LOOKUP)
        random_way <= ({$random()} % 2);
end
assign replace_way = random_way;      //ʹ������滻��??


assign way0_d = way0_d_reg[index];
assign way1_d = way1_d_reg[index];

wire if_dirty;
assign if_dirty = replace_way ? way1_d : way0_d;

/*---------------------------------------------------------------------------------*/

/*-----------------------------BLOCK RAM(data_bank)--------------------------------*/

//����·��ÿ·4x32����8��bank
wire [3:0]  data_bank_we   [1:0][3:0];         //�������ֽ�дʹ��֮��weΪ4λ
wire [7:0]  data_bank_addr [1:0][3:0];         //depth = 256 = 2 ^ 8
wire [31:0] data_bank_wdata[1:0][3:0];
wire [31:0] data_bank_rdata[1:0][3:0];

//���ն���������
wire [127:0] cache_rdata;
assign cache_rdata = (buff_way == 1'b0) ? {data_bank_rdata[0][3], data_bank_rdata[0][2], data_bank_rdata[0][1], data_bank_rdata[0][0]} :
                                         {data_bank_rdata[1][3], data_bank_rdata[1][2], data_bank_rdata[1][1], data_bank_rdata[1][0]};

//��wb_curr_state������WB_IDEL����WB_WRITEʱ�轫д��Ϣ�Ĵ�
wire if_write;
assign if_write = (wb_curr_state == WB_WRITE);

assign data_bank_we[0][0] =({4{if_write && ~buff_way && buff_offset[3:2] == 0}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & ~buff_way & ret_cnt == 2'b00}});
assign data_bank_we[0][1] =({4{if_write && ~buff_way && buff_offset[3:2] == 1}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & ~buff_way & ret_cnt == 2'b01}});
assign data_bank_we[0][2] =({4{if_write && ~buff_way && buff_offset[3:2] == 2}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & ~buff_way & ret_cnt == 2'b10}});
assign data_bank_we[0][3] =({4{if_write && ~buff_way && buff_offset[3:2] == 3}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & ~buff_way & ret_cnt == 2'b11}});
assign data_bank_we[1][0] =({4{if_write && buff_way  && buff_offset[3:2] == 0}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & buff_way  & ret_cnt == 2'b00}});
assign data_bank_we[1][1] =({4{if_write && buff_way  && buff_offset[3:2] == 1}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & buff_way  & ret_cnt == 2'b01}});
assign data_bank_we[1][2] =({4{if_write && buff_way  && buff_offset[3:2] == 2}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & buff_way  & ret_cnt == 2'b10}});
assign data_bank_we[1][3] =({4{if_write && buff_way  && buff_offset[3:2] == 3}} & buff_wstrb) | ( {4{~buff_uncache}} & {4{ret_valid & buff_way  & ret_cnt == 2'b11}});

assign data_bank_addr[0][0] = buff_index;
assign data_bank_addr[0][1] = buff_index;
assign data_bank_addr[0][2] = buff_index;
assign data_bank_addr[0][3] = buff_index;
assign data_bank_addr[1][0] = buff_index;
assign data_bank_addr[1][1] = buff_index;
assign data_bank_addr[1][2] = buff_index;
assign data_bank_addr[1][3] = buff_index;

assign data_bank_wdata[0][0] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[0][1] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[0][2] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[0][3] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][0] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][1] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][2] = (ret_valid)? ret_data : buff_wdata;
assign data_bank_wdata[1][3] = (ret_valid)? ret_data : buff_wdata;

genvar i;

//way0
generate
     for (i = 0; i < 4; i = i + 1)
        begin
            DATA_bank_RAM data_bank_way0_ram_i
            (
                .clka (clk),
                .ena(1'b1),
                .wea  (data_bank_we[0][i]),
                .addra(data_bank_addr[0][i]),
                .dina (data_bank_wdata[0][i]),
                .douta(data_bank_rdata[0][i])
            );
        end
endgenerate

//way1
generate
     for (i = 0; i < 4; i = i + 1)
        begin
            DATA_bank_RAM data_bank_way1_ram_i
            (
                .clka (clk),
                .ena(1'b1),
                .wea  (data_bank_we[1][i]),
                .addra(data_bank_addr[1][i]),
                .dina (data_bank_wdata[1][i]),
                .douta(data_bank_rdata[1][i])
            );
        end
endgenerate
/*---------------------------------------------------------------------------------*/

/*-------------------------------API with CPU and AXI------------------------------*/

/*����valid����ʱ��CPU����addr_ok��ע�����������������??
1����IDLE��������LOOKUP
2����LOOKUP������������������LOOKUP
�����������next_state��ΪLOOKUP
*/
assign addr_ok = (next_state == LOOKUP);

/*׼���ö������ݻ�д�ɹ�ʱ��CPU����data_ok�����������??
1����LOOKUP״̬����д��������ʱ����������񶼿��Է���data_ok
2����LOOKUP״̬���Ƕ�����������cache
3����REFILL״̬�µ����һ�ģ�������AXI���������һ��??32λ����ʱ
*/
reg refill_ok;
always @(posedge clk)
begin
    if(~resetn)
        refill_ok <= 1'b0;
    else if(curr_state == REFILL && op == 0 && ret_valid && ret_last)
        refill_ok <= 1'b1;
    else
        refill_ok <= 1'b0;
end
reg [1:0] lookup_reg;
always @(posedge clk)
begin
    if(~resetn)
        lookup_reg <= 2'b0;
    else if(curr_state == LOOKUP)
        lookup_reg <= lookup_reg + 1;
    else if(next_state == LOOKUP)
        lookup_reg <= 2'b0;
end

assign data_ok = ((curr_state == LOOKUP) && (cache_hit)) || (refill_ok) || ((curr_state == IDLE) && (buff_op == 1));

//��REPLACE״̬�·���������
assign rd_req  = curr_state == REPLACE;

reg reg_wr_req;
always @(posedge clk)
begin
    if(~resetn)
        reg_wr_req <= 1'b0;
    else 
        begin
            if(curr_state == DIRTY_WB && wr_rdy == 1)
                reg_wr_req <= 1'b1;
            else if(wr_rdy)
                reg_wr_req <= 1'b0;
        end
end
assign wr_req  = reg_wr_req;

assign rdata   = buff_uncache ? ret_data:(
                  way0_hit?
                  ((buff_offset[3:2] == 2'b00) ? data_bank_rdata[0][0] :
                   (buff_offset[3:2] == 2'b01) ? data_bank_rdata[0][1] :
                   (buff_offset[3:2] == 2'b10) ? data_bank_rdata[0][2] :
                   data_bank_rdata[0][3]) :
                  way1_hit?
                  ((buff_offset[3:2] == 2'b00) ? data_bank_rdata[1][0] :
                   (buff_offset[3:2] == 2'b01) ? data_bank_rdata[1][1] :
                   (buff_offset[3:2] == 2'b10) ? data_bank_rdata[1][2] :
                   data_bank_rdata[1][3]) : 32'b0);

assign rd_addr = buff_uncache ?  {buff_tag, buff_index, buff_offset} : {buff_tag, buff_index, 4'b0};

assign wr_addr = buff_uncache ?  {buff_tag, buff_index, buff_offset}:
                 (buff_way == 0) ?
                 {tagv_rdata[0], tagv_addr[0], 4'b0}:
                 {tagv_rdata[1], tagv_addr[1], 4'b0};

assign wr_data = buff_uncache? {96'b0,buff_wdata} :cache_rdata;

reg        buff_op;
reg [7:0]  buff_index;
reg [19:0] buff_tag;
reg [3:0]  buff_offset;
reg [3:0]  buff_wstrb;
reg [31:0] buff_wdata;
reg        buff_uncache;

always @(posedge clk)
begin
    if(~resetn)
        begin
            buff_op <= 0;
            buff_index <= 0;
            buff_tag <= 0;
            buff_offset <= 0;
            buff_wstrb  <= 0;
            buff_wdata  <= 0;
            buff_uncache <= 1;
        end
    else if(next_state == LOOKUP)
        begin
            buff_op <= op;
            buff_index <= index;
            buff_tag <= tag;
            buff_offset <= offset;
            buff_wstrb  <= wstrb;
            buff_wdata  <= wdata;
            buff_uncache<= uncache;
        end
    else begin
        buff_op <= buff_op;
        buff_index <= buff_index;
        buff_tag <= buff_tag;
        buff_offset <= buff_offset;
        buff_wstrb  <= buff_wstrb;
        buff_wdata  <= buff_wdata;
        buff_uncache<= buff_uncache;
    end
end

reg        buff_way;
always @(posedge clk)
    begin
        if(~resetn)
            buff_way <= 0;
        else if(curr_state == LOOKUP && cache_hit)
            buff_way <= way0_hit ? 1'b0 : 1'b1;
        else if(curr_state == LOOKUP && ~cache_hit)
            buff_way <= replace_way;
    end

//���Գ���û���õ�
assign rd_type  = uncache ? 3'b010 : 3'b100;
assign wr_type  = uncache ? 3'b010 : 3'b100;
assign wr_wstrb = uncache ? buff_wstrb : 4'hf;

//for ret cnt, �������ζ���һ��cache�е�ÿ��32λ����
reg [1:0] ret_cnt;
always@(posedge clk)
begin
    if(~resetn)
        ret_cnt <= 2'b0;
    else if(ret_valid && ret_last)
        ret_cnt <= 2'b0;
    else if(ret_valid)
        ret_cnt <= ret_cnt + 2'b1;
end

//for hit write
wire hit_write = (curr_state == LOOKUP && wb_next_state == WB_WRITE) ||
                 (wb_curr_state == WB_WRITE) || 
                 (curr_state == REFILL && buff_op == 1 && ret_last && ret_valid);

//uncache

//exp23 cacop add
wire cacop_init = cacop_icache && (cacop_code[4:3] == 0);
wire cacop_cst = cacop_icache && ((cacop_code[4:3] == 2'b01) || (cacop_code[4:3] == 2'b10));

wire cacop_init_way = cacop_addr[0];
wire [7:0] cacop_init_index = cacop_addr[11:4];

/*reg cacop_cst_reg;
always @(posedge clk) begin
    if(~resetn)
        cacop_cst_reg <= 0;
    else if (cacop_cst) begin
        cacop_cst_reg <= 1;
    end
    else if (cacop_cst_reg && curr_state == REFILL && next_state == IDLE) begin
        cacop_cst_reg <= 0;
    end
    else
        cacop_cst_reg <= cacop_cst_reg;
end*/

/*reg [31:0] cacop_addr_reg;
always @(posedge clk) begin
    if(~resetn)
        cacop_addr_reg <= 0;
    else if (cacop_cst) begin
        cacop_addr_reg <= cacop_addr;
    end
    else if (cacop_cst && curr_state == REFILL && next_state == IDLE) begin
        cacop_addr_reg <= 0;
    end
    else
        cacop_addr_reg <= cacop_addr_reg;
end*/

assign cacop_over = cacop_init || (curr_state == REFILL && cacop_cst) || (curr_state == LOOKUP && cacop_cst && ~cache_hit);


endmodule