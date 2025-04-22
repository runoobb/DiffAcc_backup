package Common;

// ***** MPE Array ***** //
// ***** MPE Array parameters
parameter MPERow     = 16  ;
parameter MPECol     = 8   ; 
parameter MPEAcc     = 64  ; 

// ***** VPE Array ***** //
// ***** VPE parameters
parameter VPENum     = 64 ;
parameter OPNum     = 16  ;

// ***** Buffers ***** //
// ***** Activation Buffer
parameter ABufRow   = 64                ;
parameter ABufCol   = 256               ;
parameter ABufBank  = 0                 ;
parameter ABufDepth = 0                 ;
parameter ABufWidth = 0                 ;
parameter ABufAddrW = $clog2(ABufDepth) ;
// ***** Weight Buffer
parameter WBufRow   = 64                ;
parameter WBufCol   = 256               ;
parameter WBufBank  = 0                 ;
parameter WBufDepth = 0                 ;
parameter WBufWidth = 0                 ;
parameter WBufAddrW = $clog2(WBufDepth) ;
// ***** Scale Buffer
parameter SBufBank  = 0                 ;
parameter SBufDepth = 0                 ;
parameter SBufWidth = 0                 ;
parameter SBufAddrW = $clog2(SBufDepth) ;
// ***** Output Buffer
parameter OBufRow   = 256               ;
parameter OBufCol   = 256               ;
parameter OBufBank  = 0                 ;
parameter OBufDepth = 0                 ;
parameter OBufWidth = 0                 ;
parameter OBufAddrW = $clog2(OBufDepth) ;
// ***** Vector Buffer
parameter VBufBank  = 0                 ;
parameter VBufDepth = 0                 ;
parameter VBufWidth = 0                 ;
parameter VBufAddrW = $clog2(VBufDepth) ;
// ***** Element Buffer
parameter EBufBank  = 0                 ;
parameter EBufDepth = 0                 ;
parameter EBufWidth = 0                 ;
parameter EBufMaskW = 0                 ; // write bit mask
parameter EBufAddrW = $clog2(EBufDepth) ;
// ***** Gobal Buffer
parameter GBufBank  = 0                 ;
parameter GBufDepth = 0                 ;
parameter GBufWidth = 0                 ;
parameter GBufAddrW = $clog2(GBufDepth) ;

// ***** Computing Round ***** //
// ***** MArray
parameter MRowLoop  = ABufRow / MPEAcc;
parameter MAColLoop = ABufCol / MPECol;
parameter MWColLoop = WBufCol / MPERow;
// ***** VArray
parameter VRowLoop = OBufRow;
parameter VColLoop = OBufCol / VPENum;
// ***** EArray
parameter EColLoop = VColLoop;

// ***** Instruction ***** //
// ***** MInst
typedef struct packed {
    // Loop
    logic [$clog2(MRowLoop)-1:0]  rowABegin ;
    logic [$clog2(MRowLoop)-1:0]  rowAEnd   ;
    logic [$clog2(MRowLoop)-1:0]  rowWBegin ;
    logic [$clog2(MRowLoop)-1:0]  rowWEnd   ;
    logic [$clog2(MAColLoop)-1:0] colABegin ;
    logic [$clog2(MAColLoop)-1:0] colAEnd   ;
    logic [$clog2(MWColLoop)-1:0] colWBegin ;
    logic [$clog2(MWColLoop)-1:0] colWEnd   ;
    // Ctrl
    logic                   wOutlier  ;
    logic [MRowLoop-1:0]    aOutlier  ;
    logic                   transpose ;
    logic                   mvsync    ;
    logic                   amsync    ;
} MInst;

// ***** MFSM
typedef enum logic [1:0] {
    MIDLE,  // waiting for instruction
    MASYNC, // working but wait for sync
    MWORK,  // working
    MWAIT   // waiting for array
} MFSM;

// ***** VInst
typedef struct packed {
    // Loop
    logic [8-1:0]  rowBegin  ;
    logic [8-1:0]  rowEnd    ;
    logic [8-1:0]  colBegin  ;
    logic [8-1:0]  colEnd    ;
    // Ctrl
    logic [$clog2(OPNum)-1:0]   opFunc    ;
    logic                       mvsync    ;
    logic                       evsync    ;
    logic                       vesync    ;
    // Memory
    logic [OBufBank-1:0][OBufAddrW-1:0] vRAddr;
    logic [OBufBank-1:0]                vREn  ;
    logic [OBufBank-1:0][OBufAddrW-1:0] vWAddr;
    logic [OBufBank-1:0]                vWEn  ;
    logic                               oWen  ; // write to Output Buffer
    logic                               dWen  ; // write to DDR
} VInst;

// ***** VOpCode
typedef struct packed {
    // * Compute * //
    // Sum Shift
    logic [1:0] sS1In       ;
    logic [1:0] sS2In       ;
    // Max & Min
    logic [1:0] maxIn       ;
    logic [1:0] minIn       ;
    // AddSub
    logic [1:0] addSub1In1  ;
    logic [1:0] addSub1In2  ;
    logic [1:0] addSub2In1  ;
    logic [1:0] addSub2In2  ;
    logic [1:0] addSub3In1  ;
    logic [1:0] addSub3In2  ;
    // element-AddSub
    logic [1:0] eAddIn1     ;
    logic [1:0] eAddIn2     ;
    logic [1:0] eSubIn1     ;
    logic [1:0] eSubIn2     ;
    // Div
    logic [1:0] divIn1      ;
    logic [1:0] divIn2      ;
    // Mul
    logic [1:0] mul1In1     ;
    logic [1:0] mul1In2     ;
    logic [1:0] mul2In1     ;
    logic [1:0] mul2In2     ;
    // FP2INT
    logic [1:0] fp2IntIn    ;
    // Exp
    logic [1:0] expIn       ;
    // * Memory * //
    // DDR
    logic       vddrWen     ;
    logic [1:0] vddrIn      ;
    logic       s1ddrWen    ;
    logic [1:0] s1ddrIn     ;
    logic       s2ddrWen    ;
    logic [1:0] s2ddrIn     ;
    // OBuf
    logic       oBufWEn     ;
    logic [1:0] oBufIn      ;
    logic       oBufREn     ;
    // VBuf
    logic       vBufWMode   ; // 0: Channel-wise, 1: Element-wise
    logic       vBufWEn     ;
    logic [1:0] vBufIn      ;
    logic       vBufRMode   ; // 0: Channel-wise, 1: Element-wise
    logic       vBufREn     ;
    // EBuf
    logic       eBufWMode   ; // 0: Channel-wise, 1: Element-wise
    logic       eBufWEn     ;
    logic [1:0] eBufIn      ;
    logic       eBufRMode   ; // 0: Channel-wise, 1: Element-wise
    logic       eBufREn     ;
} VOPCode;

parameter OP0  = 128'b0;
parameter OP1  = 128'b0;
parameter OP2  = 128'b0;
parameter OP3  = 128'b0;
parameter OP4  = 128'b0;
parameter OP5  = 128'b0;
parameter OP6  = 128'b0;
parameter OP7  = 128'b0;
parameter OP8  = 128'b0;
parameter OP9  = 128'b0;
parameter OP10 = 128'b0;
parameter OP11 = 128'b0;
parameter OP12 = 128'b0;
parameter OP13 = 128'b0;
parameter OP14 = 128'b0;
parameter OP15 = 128'b0;

// ***** VFSM
typedef enum logic [2:0] {
    VIDLE, // waiting for instruction
    VMSYNC, // working but wait for mvsync
    VESYNC, // working but wait for evsync
    VWORK, // working
    VWAIT  // waiting for array
} VFSM;

// ***** EOpCode
typedef enum logic [1:0] {
    MaxReduce,
    ExpProd,
    MergeNorm
} EOpCode;

// ***** EInst
typedef struct packed {
    // OpCode
    EOpCode eOpCode;
    // Loop
    logic         eLast     ;
    logic [8-1:0] colBegin  ;
    logic [8-1:0] colEnd    ;
    // Ctrl
    logic evsync;
    logic vesync;
} EInst;

// ***** EFSM
typedef enum logic [1:0] {
    EIDLE, // waiting for instruction
    ESYNC, // working but wait for sync
    EWORK, // working
    EWAIT  // waiting for array
} EFSM;

endpackage
