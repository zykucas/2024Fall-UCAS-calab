module tlb
#(
    parameter TLBNUM = 16
)
(
    input wire clk,

    // search port 0 (for fetch)
    input wire [              18:0] s0_vppn,
    input wire                      s0_va_bit12,
    input wire [               9:0] s0_asid,
    output wire                     s0_found,
    output wire[$clog2(TLBNUM)-1:0] s0_index,
    output wire[              19:0] s0_ppn,
    output wire[               5:0] s0_ps,
    output wire[               1:0] s0_plv,
    output wire[               1:0] s0_mat,
    output wire                     s0_d,
    output wire                     s0_v,

    // search port 1 (for load/store)
    input  wire[              18:0] s1_vppn,
    input  wire                     s1_va_bit12,
    input  wire[               9:0] s1_asid,
    output wire                     s1_found,
    output wire[$clog2(TLBNUM)-1:0] s1_index,
    output wire[              19:0] s1_ppn,
    output wire[               5:0] s1_ps,
    output wire[               1:0] s1_plv,
    output wire[               1:0] s1_mat,
    output wire                     s1_d,
    output wire                     s1_v,

    // invtlb opcode
    input wire                      invtlb_valid,
    input wire [               4:0] invtlb_op,

    // write port
    input wire                      we,
    input wire [$clog2(TLBNUM)-1:0] w_index,
    input wire                      w_e,
    input wire [              18:0] w_vppn,
    input wire [               5:0] w_ps,
    input wire [               9:0] w_asid,
    input wire                      w_g,

    input wire [              19:0] w_ppn0,
    input wire [               1:0] w_plv0,
    input wire [               1:0] w_mat0,
    input wire                      w_d0,
    input wire                      w_v0,

    input wire [              19:0] w_ppn1,
    input wire [               1:0] w_plv1,
    input wire [               1:0] w_mat1,
    input wire                      w_d1,
    input wire                      w_v1,

    // read port
    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output wire                      r_e,
    output wire [              18:0] r_vppn,
    output wire [               5:0] r_ps,
    output wire [               9:0] r_asid,
    output wire                      r_g,

    output wire [              19:0] r_ppn0,
    output wire [               1:0] r_plv0,
    output wire [               1:0] r_mat0,
    output wire                      r_d0,
    output wire                      r_v0,
    output wire [              19:0] r_ppn1,
    output wire [               1:0] r_plv1,
    output wire [               1:0] r_mat1,
    output wire                      r_d1,
    output wire                      r_v1
);

reg [TLBNUM-1:0] tlb_e;
reg [TLBNUM-1:0] tlb_ps4MB;   //pagesize 1:4MB, 0:4KB

reg [18:0] tlb_vppn [TLBNUM-1:0];  // 19 bits = 32 - 12(4KB) - 1(odd/even)
reg [ 9:0] tlb_asid [TLBNUM-1:0];
reg        tlb_g    [TLBNUM-1:0];

reg [19:0] tlb_ppn0 [TLBNUM-1:0];
reg [ 1:0] tlb_plv0 [TLBNUM-1:0];
reg [ 1:0] tlb_mat0 [TLBNUM-1:0];
reg        tlb_d0   [TLBNUM-1:0];
reg        tlb_v0   [TLBNUM-1:0];

reg [19:0] tlb_ppn1 [TLBNUM-1:0];
reg [ 1:0] tlb_plv1 [TLBNUM-1:0];
reg [ 1:0] tlb_mat1 [TLBNUM-1:0];
reg        tlb_d1   [TLBNUM-1:0];
reg        tlb_v1   [TLBNUM-1:0];

// read port
assign r_e    = tlb_e    [r_index];
assign r_vppn = tlb_vppn [r_index];
assign r_ps   = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;
assign r_asid = tlb_asid [r_index];
assign r_g    = tlb_g    [r_index];
// even
assign r_ppn0 = tlb_ppn0 [r_index];
assign r_plv0 = tlb_plv0 [r_index];
assign r_mat0 = tlb_mat0 [r_index];
assign r_d0   = tlb_d0   [r_index];
assign r_v0   = tlb_v0   [r_index];
//odd
assign r_ppn1 = tlb_ppn1 [r_index];
assign r_plv1 = tlb_plv1 [r_index];
assign r_mat1 = tlb_mat1 [r_index];
assign r_d1   = tlb_d1   [r_index];
assign r_v1   = tlb_v1   [r_index];

// write
always @(posedge clk) begin
    if(we) begin
        tlb_e    [w_index] <= w_e;
        tlb_ps4MB[w_index] <= w_ps == 6'd21;
        tlb_vppn [w_index] <= w_vppn;
        tlb_asid [w_index] <= w_asid;
        tlb_g    [w_index] <= w_g;

        tlb_ppn0 [w_index] <= w_ppn0;
        tlb_plv0 [w_index] <= w_plv0;
        tlb_mat0 [w_index] <= w_mat0;
        tlb_d0   [w_index] <= w_d0;
        tlb_v0   [w_index] <= w_v0;

        tlb_ppn1 [w_index] <= w_ppn1;
        tlb_plv1 [w_index] <= w_plv1;
        tlb_mat1 [w_index] <= w_mat1;
        tlb_d1   [w_index] <= w_d1;
        tlb_v1   [w_index] <= w_v1;
    end
    else if(invtlb_valid)//invtlb
        tlb_e <= ~invtlb_mask[invtlb_op] & tlb_e;
end

wire [TLBNUM - 1: 0] match0;
wire [TLBNUM - 1: 0] match1;
genvar i;
generate for(i = 0; i < TLBNUM; i = i + 1) begin
        assign match0[i] = (s0_vppn[18:9] == tlb_vppn[i][18:9])
                        && (tlb_ps4MB[i] || s0_vppn[8:0] == tlb_vppn[i][8:0])
                        && ((s0_asid == tlb_asid[i]) || tlb_g[i]);
        
        assign match1[i] = (s1_vppn[18:9] == tlb_vppn[i][18:9])
                        && (tlb_ps4MB[i] || s1_vppn[8:0] == tlb_vppn[i][8:0])
                        && ((s1_asid == tlb_asid[i]) || tlb_g[i]);
end
endgenerate

wire s0_odd;
wire s1_odd;

// fetch inst
assign s0_found = |match0;

assign s0_index =   match0[ 1] ? 4'd1  :
                    match0[ 2] ? 4'd2  :
                    match0[ 3] ? 4'd3  :
                    match0[ 4] ? 4'd4  :
                    match0[ 5] ? 4'd5  :
                    match0[ 6] ? 4'd6  :
                    match0[ 7] ? 4'd7  :
                    match0[ 8] ? 4'd8  :
                    match0[ 9] ? 4'd9  :
                    match0[10] ? 4'd10 :
                    match0[11] ? 4'd11 :
                    match0[12] ? 4'd12 :
                    match0[13] ? 4'd13 :
                    match0[14] ? 4'd14 :
                    match0[15] ? 4'd15 :
                    4'd0; // Default, 没有找到时需要把found置为0

assign s0_odd = tlb_ps4MB[s0_index] ? s0_vppn[8] : s0_va_bit12; //whether the odd page hit
assign s0_ps = tlb_ps4MB[s0_index] ? 6'd21 : 6'd12;
assign s0_ppn = s0_odd ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_plv = s0_odd ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_mat = s0_odd ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d   = s0_odd ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
assign s0_v   = s0_odd ? tlb_v1  [s0_index] : tlb_v0  [s0_index];

//load / store
assign s1_found = |match1;

assign s1_index =   match1[ 1] ? 4'd1  :
                    match1[ 2] ? 4'd2  :
                    match1[ 3] ? 4'd3  :
                    match1[ 4] ? 4'd4  :
                    match1[ 5] ? 4'd5  :
                    match1[ 6] ? 4'd6  :
                    match1[ 7] ? 4'd7  :
                    match1[ 8] ? 4'd8  :
                    match1[ 9] ? 4'd9  :
                    match1[10] ? 4'd10 :
                    match1[11] ? 4'd11 :
                    match1[12] ? 4'd12 :
                    match1[13] ? 4'd13 :
                    match1[14] ? 4'd14 :
                    match1[15] ? 4'd15 :
                    4'd0; // Default, 没有找到时需要把found置为0

assign s1_odd = tlb_ps4MB[s1_index] ? s1_vppn[8] : s1_va_bit12;
assign s1_ps = tlb_ps4MB[s1_index] ? 6'd21: 6'd12;
assign s1_ppn = s1_odd ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_plv = s1_odd ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_mat = s1_odd ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d   = s1_odd ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
assign s1_v   = s1_odd ? tlb_v1  [s1_index] : tlb_v0  [s1_index];

// invtlb
wire [TLBNUM - 1:0] cond [3:0];
wire [TLBNUM - 1:0] invtlb_mask [6:0];
generate for(i = 0; i < TLBNUM; i = i + 1) begin
        assign cond[0][i] = ~tlb_g[i];
        assign cond[1][i] = tlb_g[i];
        assign cond[2][i] = s1_asid == tlb_asid[i];
        assign cond[3][i] = (s1_vppn[18:9] == tlb_vppn[i][18:9]) && (tlb_ps4MB[i] || s1_vppn[8:0] == tlb_vppn[i][8:0]);

end    
endgenerate

assign invtlb_mask[0] = 16'hffff;
assign invtlb_mask[1] = 16'hffff;
assign invtlb_mask[2] = cond[1];
assign invtlb_mask[3] = cond[0];
assign invtlb_mask[4] = cond[0] & cond[2];
assign invtlb_mask[5] = cond[0] & cond[2] & cond[3];
assign invtlb_mask[6] = (cond[1] | cond[2]) & cond[3];

endmodule