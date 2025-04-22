import Common::*;


// False definition
// interface TopCtrl2MCtrl();
// ...
// endinterface

// ***** InterConnect ***** //
// ***** TopCtrl to MCtrl
interface TopCtrl2MCtrl(input logic clk);
    logic mValid;
    logic mReady;
    MInst mInst;
    modport TopCtrlSide (
        output mValid,
        input  mReady,
        output mInst
    );
    modport MCtrlSide (
        input  mValid,
        output mReady,
        input  mInst
    );
endinterface

// ***** MCtrl to MArray
interface MCtrl2MArray(input logic clk);
    logic                                       mValid ;
    logic                                       mFinish;
    logic [1:0]                                 mShift ;
    logic                                       mOut   ;
    logic                                       mvWSync;
    logic                                       mOutTileFinish;
    logic [OBufBank-1:0]                        oBufBankSel;
    logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddr;
    // logic [$clog2(MAColLoop)-1:0]               colAPtr;
    // logic [$clog2(MAColLoop)-1:0]               colAEnd;
    // logic [$clog2(MWColLoop)-1:0]               colWPtr;
    // logic [$clog2(MWColLoop)-1:0]               colWEnd;
    modport CtrlSide (
        output mValid,
        input  mFinish,
        output mShift, 
        output mOut,   
        input  mvWSync,
        output mOutTileFinish,
        output oBufBankSel,
        output oBufAddr
        // output colAPtr,
        // output colAEnd,
        // output colWPtr,
        // output colWEnd
    );
    modport ArraySide (
        input  mValid,
        output mFinish,
        input  mShift,
        input  mOut,
        output mvWSync,
        input  mOutTileFinish,
        input  oBufBankSel,
        input  oBufAddr
        // input  colAPtr,
        // input  colAEnd,
        // input  colWPtr,
        // input  colWEnd
    );
endinterface

// ***** TopSync to MCtrl
interface TopSync2MCtrl(input logic clk);
    logic mvWSync;
    logic amRSync;
    logic amEmpty;
    modport MCtrlSide (
        output mvWSync,
        output amRSync,
        input  amEmpty
    );
    modport TopSyncSide (
        input  mvWSync,
        input  amRSync,
        output amEmpty
    );
endinterface

// // ***** TopCtrl to VCtrl
// interface TopCtrl2VCtrl(input logic clk);
//     logic               vValid;
//     logic               vReady;
//     VInst               vInst ;
//     modport TopCtrlSide (
//         output vValid,
//         input  vReady,
//         output vInst
//     );
//     modport VCtrlSide (
//         input  vValid,
//         output vReady,
//         input  vInst
//     );
// endinterface

// // ***** VCtrl to VArray
// interface VCtrl2VArray(input logic clk);
//     logic                           vValid  ;
//     logic                           vFinish ;
//     logic [$clog2(VRowLoop)-1:0]    rowPtr  ;
//     logic [$clog2(VRowLoop)-1:0]    rowEnd  ;
//     logic [$clog2(VColLoop)-1:0]    colPtr  ;
//     logic [$clog2(VColLoop)-1:0]    colEnd  ;
//     VOpCode                         vOpCode ;
//     logic                           veWSync ;
//     modport CtrlSide (
//         output vValid,
//         input  vFinish,
//         output rowPtr,
//         output rowEnd,
//         output colPtr,
//         output colEnd,
//         output vOpCode,
//         input  veWSync
//     );
//     modport ArraySide (
//         input  vValid,
//         output vFinish,
//         input  rowPtr,
//         input  rowEnd,
//         input  colPtr,
//         input  colEnd,
//         input  vOpCode,
//         output veWSync
//     );
// endinterface

// // ***** TopSync to VCtrl
// interface TopSync2VCtrl(input logic clk);
//     logic veWSync;
//     logic evRSync;
//     logic evEmpty;
//     logic mvRSync;
//     logic mvEmpty;
//     modport VCtrlSide (
//         output veWSync,
//         output evRSync,
//         input  evEmpty,
//         output mvRSync,
//         input  mvEmpty
//     );
//     modport TopSyncSide (
//         input  veWSync,
//         input  evRSync,
//         output evEmpty,
//         input  mvRSync,
//         output mvEmpty
//     );
// endinterface

// // ***** TopCtrl to VECtrl
// interface TopCtrl2VEctrl(input logic clk);
//     logic eValid;
//     logic eReady;
//     logic eImm  ;
//     EInst eInst ;
//     modport TopCtrlSide(
//         output eValid,
//         input  eReady,
//         output eImm,
//         output eInst
//     );
//     modport VECtrl (
//     input  eValid,
//     output eReady,
//     input  eImm,
//     input  eInst
//     );
// endinterface

// // ***** TopSync to VECtrl
// interface TopSync2VECtrl(input logic clk);
//     logic veRSync;
//     logic veEmpty;
//     logic evWSync;
//     modport VCtrlSide (
//         output veRSync,
//         input  veEmpty,
//         output evWSync
//     );
//     modport TopSyncSide (
//         input  veRSync,
//         output veEmpty,
//         input  evWSync
//     );
// endinterface

// // ***** VECtrl to VEArray *****//
// interface VECtrl2VEArray(input logic clk);
//     logic           eValid      ;
//     logic           eFinish     ;
//     logic           eFirst      ;
//     logic           eLast       ;
//     logic           eImm        ;
//     logic [8-1:0]   colBegin    ;
//     logic [8-1:0]   colEnd      ;
//     EOpCode         eOpCode     ;
//     logic           evWSync     ;
//     modport CtrlSide (
//         output eValid,
//         input  eFinish,
//         output eLast,
//         output colBegin,
//         output colEnd,
//         output eOpCode,
//         input  evWSync
//     );
//     modport ArraySide (
//         input  eValid,
//         output eFinish,
//         input  eLast,
//         input  colBegin,
//         input  colEnd,
//         input  eOpCode,
//         output evWSync
//     );
// endinterface

// ***** BufferConnect ***** //
// ***** MCtrl to ABuffer
interface MCtrl2ABuffer(input logic clk);
    logic [ABufBank-1:0][ABufAddrW-1:0] rAddr;
    logic [ABufBank-1:0] rEn;
    modport MCtrlSide(
        output rAddr,
        output rEn
    );
    modport BufSide(
        input  rAddr,
        input  rEn
    );
endinterface

// ***** MCtrl to WBuffer
interface MCtrl2WBuffer(input logic clk);
    logic [WBufBank-1:0][WBufAddrW-1:0] rAddr;
    logic [WBufBank-1:0] rEn;
    modport MCtrlSide(
        output rAddr,
        output rEn
    );
    modport BufSide(
        input  rAddr,
        input  rEn
    );
endinterface

// ***** MCtrl to ScaleBuffer
interface MCtrl2SBuffer(input logic clk);
    logic [SBufBank-1:0][SBufAddrW-1:0] rAddr;
    logic [SBufBank-1:0] rEn;
    modport MCtrlSide(
        output rAddr,
        output rEn
    );
    modport BufSide(
        input  rAddr,
        input  rEn
    );
endinterface

// ***** ABuffer to MArray
interface ABuffer2MArray(input logic clk);
    logic [ABufBank-1:0][ABufWidth-1:0] rData;
    modport BufSide(
        output rData
    );
    modport ArraySide(
        input  rData
    );
endinterface

// ***** WBuffer to MArray
interface WBuffer2MArray(input logic clk);
    logic [WBufBank-1:0][WBufWidth-1:0] rData;
    modport BufSide(
        output rData
    );
    modport ArraySide(
        input  rData
    );
endinterface

// ***** ScaleBuffer to MArray
interface SBuffer2MArray(input logic clk);
    logic [SBufBank-1:0][SBufWidth-1:0] rData;
    modport BufSide(
        output rData
    );
    modport ArraySide(
        input  rData
    );
endinterface

// ***** MArray to OBuffer
interface MArray2OBuffer(input logic clk);
    logic [OBufBank-1:0][OBufAddrW-1:0] wAddr;
    logic [OBufBank-1:0][OBufWidth-1:0] wData;
    logic [OBufBank-1:0]                wEn;
    modport ArraySide(
        output wAddr,
        output wData,
        output wEn
    );
    modport BufSide(
        input  wAddr,
        input  wData,
        input  wEn
    );
endinterface

// // ***** VCtrl to OBuffer
// interface VCtrl2OBuffer(input logic clk);
//     logic [OBufBank-1:0][OBufAddrW-1:0] rAddr;
//     logic [OBufBank-1:0] rEn;
//     modport CtrlSide(
//         output rAddr,
//         output rEn
//     );
//     modport BufSide(
//         input  rAddr,
//         input  rEn
//     );
// endinterface

// // ***** VCtrl to VBuffer
// interface VCtrl2VBuffer(input logic clk);
//     logic [VBufBank-1:0][VBufAddrW-1:0] rAddr;
//     logic [VBufBank-1:0] rEn;
//     modport CtrlSide(
//         output rAddr,
//         output rEn
//     );
//     modport BufSide(
//         input  rAddr,
//         input  rEn
//     );
// endinterface

// // ***** VCtrl to EBuffer
// interface VCtrl2EBuffer(input logic clk);
//     logic [EBufBank-1:0][EBufAddrW-1:0] rAddr;
//     logic [EBufBank-1:0] rEn;
//     modport CtrlSide(
//         output rAddr,
//         output rEn
//     );
//     modport BufSide(
//         input  rAddr,
//         input  rEn
//     );
// endinterface

// // ***** VArray to OBuffer
// interface VArray2OBuffer(input logic clk);
//     // read
//     logic [OBufBank-1:0][OBufWidth-1:0] rData;
//     // write
//     logic [OBufBank-1:0][OBufAddrW-1:0] wAddr;
//     logic [OBufBank-1:0][OBufWidth-1:0] wData;
//     logic [OBufBank-1:0]                wEn;
//     modport ArraySide(
//         input  rData,
//         output wAddr,
//         output wData,
//         output wEn
//     );
//     modport BufSide(
//         output rData,
//         input  wAddr,
//         input  wData,
//         input  wEn
//     );
// endinterface

// // ***** VArray to VBuffer
// interface VArray2VBuffer(input logic clk);
//     logic [VBufBank-1:0][VBufWidth-1:0] rData;
//     modport ArraySide(
//         input  rData
//     );
//     modport BufSide(
//         output rData
//     );
// endinterface

// // ***** VArray to EBuffer
// interface VArray2EBuffer(input logic clk);
//     // read
//     logic [EBufBank-1:0][EBufWidth-1:0] rData;
//     // write
//     logic [EBufBank-1:0][EBufAddrW-1:0] wAddr;
//     logic [EBufBank-1:0][EBufWidth-1:0] wData;
//     logic [EBufBank-1:0]                wEn;
//     modport ArraySide(
//         input  rData,
//         output wAddr,
//         output wData,
//         output wEn
//     );
//     modport BufSide(
//         output rData,
//         input  wAddr,
//         input  wData,
//         input  wEn
//     );
// endinterface

// // ***** VECtrl to GBuffer
// interface VECtrl2GBuffer(input logic clk);
//     logic [GBufBank-1:0][GBufAddrW-1:0] rAddr;
//     logic [GBufBank-1:0] rEn;
//     modport CtrlSide(
//         output rAddr,
//         output rEn
//     );
//     modport BufSide (
//         input  rAddr,
//         input  rEn
//     );
// endinterface

// // ***** VECtrl to EBuffer
// interface VECtrl2EBuffer(input logic clk);
//     logic [EBufBank-1:0][EBufAddrW-1:0] rAddr;
//     logic [EBufBank-1:0] rEn;
//     modport CtrlSide(
//         output rAddr,
//         output rEn
//     );
//     modport BufSide (
//         input  rAddr,
//         input  rEn
//     );
// endinterface

// // ***** VEArray to GBuffer
// interface VEArray2GBuffer(input logic clk);
//     // read
//     logic [GBufBank-1:0][GBufWidth-1:0] rData;
//     logic [GBufBank-1:0]                rValid;
//     // write
//     logic [GBufBank-1:0][GBufAddrW-1:0] wAddr;
//     logic [GBufBank-1:0][GBufWidth-1:0] wData;
//     logic [GBufBank-1:0]                wEn;
//     modport ArraySide(
//         input  rData,
//         input  rValid,
//         output wAddr,
//         output wData,
//         output wEn
//     );
//     modport BufSide(
//         output rData,
//         output rValid,
//         input  wAddr,
//         input  wData,
//         input  wEn
//     );
// endinterface

// // ***** VEArray to EBuffer
// interface VEArray2EBuffer(input logic clk);
//     logic [EBufBank-1:0][EBufWidth-1:0] rData;
//     logic [EBufBank-1:0]                rValid;
//     modport ArraySide(
//         input  rData,
//         input  rValid
//     );
//     modport BufSide(
//         output rData,
//         output rValid
//     );
// endinterface