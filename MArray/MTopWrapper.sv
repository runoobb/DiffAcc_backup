import Common::*;

module MTopWrapper(
    // clk & rst
     input logic clk
    ,input logic rst_n

    // topCtrlIf
    ,input  logic mValid
    ,output logic mReady
    ,input  MInst mInst

    // topSyncIf
    ,output logic mvWSync
    ,output logic amRSync
    ,input  logic amEmpty

    // ABuffer
    ,output logic [ABufBank-1:0][ABufAddrW-1:0] aBufRAddr
    ,output logic [ABufBank-1:0]                aBufREn
    ,input  logic [ABufBank-1:0][ABufWidth-1:0] aBufRData
    
    // WBuffer
    ,output logic [WBufBank-1:0][WBufAddrW-1:0] wBufRAddr
    ,output logic [WBufBank-1:0]                wBufREn
    ,input  logic [WBufBank-1:0][WBufWidth-1:0] wBufRData
    
    // ScaleBuffer
    ,output logic [SBufBank-1:0][SBufAddrW-1:0] sBufRAddr
    ,output logic [SBufBank-1:0]                sBufREn
    ,input  logic [SBufBank-1:0][SBufWidth-1:0] sBufRData
    
    // OBuffer
    // * Write Port 2 -> MArray
    ,output logic [OBufBank-1:0][OBufAddrW-1:0] oBufW2Addr
    ,output logic [OBufBank-1:0]                oBufW2En
    ,output logic [OBufBank-1:0][OBufWidth-1:0] oBufW2Data

);

    // * I/O interface
    // ** MCtrl
    // ** False reference
    // TopCtrl2MCtrl   topCtrl2MCtrl   ;
    // ** Correct reference
    TopCtrl2MCtrl   topCtrl2MCtrl(clk)   ;
    TopSync2MCtrl   topSync2MCtrl(clk)   ;
    MCtrl2ABuffer   mCtrl2ABuffer(clk)   ;
    MCtrl2WBuffer   mCtrl2WBuffer(clk)   ;
    MCtrl2SBuffer   mCtrl2SBuffer(clk)   ;
    // ** MArray
    ABuffer2MArray  aBuffer2MArray(clk)  ;
    WBuffer2MArray  wBuffer2MArray(clk)  ;
    SBuffer2MArray  sBuffer2MArray(clk)  ;
    MArray2OBuffer  mArray2OBuffer(clk)  ;

    // * Drive I/O Interface
    // ** MCtrl
    assign topCtrl2MCtrl.mValid = mValid    ;
    assign topCtrl2MCtrl.mInst  = mInst     ;
    assign mReady = topCtrl2MCtrl.mReady    ;
    assign topSync2MCtrl.amEmpty = amEmpty  ;
    assign mvWSync = topSync2MCtrl.mvWSync  ;
    assign amRSync = topSync2MCtrl.amRSync  ;
    assign aBufRAddr = mCtrl2ABuffer.rAddr      ;
    assign aBufREn   = mCtrl2ABuffer.rEn        ;
    assign wBufRAddr = mCtrl2WBuffer.rAddr      ;
    assign wBufREn   = mCtrl2WBuffer.rEn        ;
    assign sBufRAddr = mCtrl2SBuffer.rAddr      ;
    assign sBufREn   = mCtrl2SBuffer.rEn        ;
    // ** MArray
    assign aBuffer2MArray.rData = aBufRData     ;
    assign wBuffer2MArray.rData = wBufRData     ;
    assign sBuffer2MArray.rData = sBufRData     ;
    assign oBufW2Addr = mArray2OBuffer.wAddr    ;
    assign oBufW2Data = mArray2OBuffer.wData    ;
    assign oBufW2En   = mArray2OBuffer.wEn      ;

    // * Connect Submodules
    MTop mTop(
        .clk           ( clk                       )
       ,.rst_n         ( rst_n                     )
       ,.topCtrlIf     ( topCtrl2MCtrl   )
       ,.topSyncIf     ( topSync2MCtrl   )
       ,.aBufCtrlIf    ( mCtrl2ABuffer   )
       ,.wBufCtrlIf    ( mCtrl2WBuffer   )
       ,.sBufCtrlIf    ( mCtrl2SBuffer   )
       ,.aBufArrayIf   ( aBuffer2MArray  )
       ,.wBufArrayIf   ( wBuffer2MArray  )
       ,.sBufArrayIf   ( sBuffer2MArray  )
       ,.oBufArrayIf   ( mArray2OBuffer  )
   );
   
endmodule