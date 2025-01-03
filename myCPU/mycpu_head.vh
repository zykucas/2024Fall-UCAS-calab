`define WIDTH_BR_BUS       35
`define WIDTH_FS_TO_DS_BUS 69
`define WIDTH_DS_TO_ES_BUS 253
`define WIDTH_ES_TO_MS_BUS 245
`define WIDTH_MS_TO_WS_BUS 238
`define WIDTH_WS_TO_DS_BUS 55
`define WIDTH_ES_TO_DS_BUS 56
`define WIDTH_MS_TO_DS_BUS 57

`define WIDTH_CSR_NUM 14

//�Ĵ�����
`define CSR_CRMD 14'h0
`define CSR_PRMD 14'h1
`define CSR_ECFG 14'h4
`define CSR_ESTAT 14'h5
`define CSR_ERA 14'h6
`define CSR_BADV 14'h7
`define CSR_EENTRY 14'hc
`define CSR_TLBIDX 14'h10
`define CSR_TLBEHI 14'h11
`define CSR_TLBELO0 14'h12
`define CSR_TLBELO1 14'h13
`define CSR_ASID 14'h18
`define CSR_SAVE0 14'h30
`define CSR_SAVE1 14'h31
`define CSR_SAVE2 14'h32
`define CSR_SAVE3 14'h33
`define CSR_TID 14'h40
`define CSR_TCFG 14'h41
`define CSR_TVAL 14'h42
`define CSR_TICLR 14'h44
`define CSR_TLBRENTRY 14'h88

`define CSR_DMW0 14'h180
`define CSR_DMW1 14'h181

//CSR����

//CSR_CRMD
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2:2
`define CSR_CRMD_DA 3:3
`define CSR_CRMD_PG 4:4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7
`define CSR_CRMD_ZERO 31:9

//CSR_PRMD
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2:2
`define CSR_PRMD_ZERO 31:3

//CSR_ECFG
`define CSR_ECFG_LIE_9_0 9:0
`define CSR_ECFG_LIE_12_11 12:11
`define CSR_ECFG_ZERO_31_13 31:13
`define CSR_ECFG_ZERO_10 10

//CSR_ESTAT
`define CSR_ESTAT_IS_SOFT 1:0     
`define CSR_ESTAT_IS_HARD 9:2   
`define CSR_ESTAT_IS_LEFT1 10    
`define CSR_ESTAT_IS_TI 11       
`define CSR_ESTAT_IS_IPI 12       
`define CSR_ESTAT_LEFT2 15:13  
`define CSR_ESTAT_ECODE 21:16  
`define CSR_ESTAT_ESUBCODE 30:22 
`define CSR_ESTAT_ZERO 31  

//CSR_ERA
`define CSR_ERA_PC 31:0

//CSR_BADV
`define CSR_BADV_VADDR 31:0

//CSR_EENTRY
`define CSR_EENTRY_ZERO 5:0
`define CSR_EENTRY_VA 31:6

//CSR_SAVR0-3
`define CSR_SAVE_DATA 31:0

//CSR_TID
`define CSR_TID_TID 31:0

//CSR_TCFG
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIODIC 1
`define CSR_TCFG_INITVAL 31:2

//CSR_TICLR
`define CSR_TICLR_CLR 0
`define CSR_TICLR_ZERO 31:1


//ECODE
`define ECODE_INT 6'h0
`define ECODE_PIL 6'h1
`define ECODE_PIS 6'h2
`define ECODE_PIF 6'h3
`define ECODE_PME 6'h4
`define ECODE_PPI 6'h7
`define ECODE_ADE 6'h8
`define ECODE_ALE 6'h9
`define ECODE_SYS 6'hb
`define ECODE_BRK 6'hc
`define ECODE_INE 6'hd
`define ECODE_IPE 6'he
`define ECODE_FPD 6'hf
`define ECODE_FPE 6'h12

`define ECODE_TLBR 6'h3f

//ESUBCODE
`define ESUBCODE_INT 9'h0
`define ESUBCODE_PIL 9'h0
`define ESUBCODE_PIS 9'h0
`define ESUBCODE_PIF 9'h0
`define ESUBCODE_PME 9'h0
`define ESUBCODE_PPI 9'h0
`define ESUBCODE_ADEF 9'h0
`define ESUBCODE_ADEM 9'h1
`define ESUBCODE_ALE 9'h0
`define ESUBCODE_SYS 9'h0
`define ESUBCODE_BRK 9'h0
`define ESUBCODE_INE 9'h0
`define ESUBCODE_IPE 9'h0
`define ESUBCODE_FPD 9'h0
`define ESUBCODE_FPE 9'h0

`define ESUBCODE_TLBR 9'h0

//TLB
//����Ϊ4����TLBΪ2 ^ 4 = 16λ
`define TLB_LEN 4   

//TLBIDX (TLB����)
`define TLBIDX_INDEX    3:0
`define TLBIDX_ZERO1    23:4
`define TLBIDX_PS       29:24
`define TLBIDX_ZERO2    30:30
`define TLBIDX_NE       31:31

//TLBEHI (TLB�����λ)
`define TLBEHI_ZERO     12:0
`define TLBEHI_VPPN     31:13

//TLBELO0, TLBELO1 (TLB�����λ)
//�������Ĵ����ֱ��Ӧ˫ҳ�е�ż��ҳ������ҳ���ṹ��ȫ��ͬ
`define TLBELO_V        0:0
`define TLBELO_D        1:1
`define TLBELO_PLV      3:2
`define TLBELO_MAT      5:4
`define TLBELO_G        6:6
`define TLBELO_ZERO1    7:7
`define TLBELO_PPN      27:8
`define TLBELO_ZERO2    31:28

//ASID (��ַ�ռ��ʶ��)
`define ASID_ASID       9:0
`define ASID_ZERO1      15:10
`define ASID_ASIDBITS   23:16
`define ASID_ZERO2      31:24

//TLBRENTRY (TLB����������ڵ�ַ)
`define TLBRENTRY_LOW   5:0     //only read
`define TLBRENTRY_HIGH  31:6    //read and write

//DMW0,DMW1 (ֱ��ӳ�����ô���)
`define DMW_PLV0        0:0
`define DMW_ZERO1       2:1
`define DMW_PLV3        3:3
`define DMW_MAT         5:4
`define DMW_ZERO2       24:6
`define DMW_PSEG        27:25
`define DMW_ZERO3       28:28
`define DMW_VSEG        31:29