import Common::*;

module MCtrl (
    // clk & rst
     input logic clk
    ,input logic rst_n
    // interconnect
    ,TopCtrl2MCtrl.MCtrlSide topCtrlIf
    ,TopSync2MCtrl.MCtrlSide topSyncIf
    ,MCtrl2ABuffer.MCtrlSide aBufIf
    ,MCtrl2WBuffer.MCtrlSide wBufIf
    ,MCtrl2MArray.CtrlSide  mArrayIf
);

    //-----------------------------------------------------
    // Internal Logics
    //-----------------------------------------------------
    // * MInst FIFO
    logic mInstPush_n   ;
    logic mInstPop_n    ;
    logic mInstEmpty    ;
    logic mInstFull     ;
    MInst mInstCrt      ;

    // * MCtrl FSM
    MFSM mFSM_w;
    MFSM mFSM_r;
    logic [$clog2(MRowLoop)-1:0]    rowAPtr         ;
    logic [$clog2(MRowLoop)-1:0]    rowWPtr         ;
    logic [$clog2(MRowLoop)-1:0]    nextRowAPtr     ;
    logic [$clog2(MRowLoop)-1:0]    nextRowWPtr     ;
    logic [1:0]                     rowAExBit       ;
    logic                           rowWExBit       ;
    logic [1:0]                     nextRowAExBit   ;
    logic                           nextRowWExBit   ;
    logic [$clog2(MAColLoop)-1:0]   colAPtr         ;
    logic [$clog2(MWColLoop)-1:0]   colWPtr         ;
    logic                           rowAFinish      ;
    logic                           rowWFinish      ;
    logic                           colAFinish      ;
    logic                           colWFinish      ;
    logic                           allFinish       ;

    // * Outlier
    logic [MRowLoop-1:0] aOutlierShift  ;
    logic                aOutlierNext   ;
    logic                aOutlierFormer ;

    // * Sync
    logic amCtrlSync;
    logic passSync;

    // * Buffer
    logic [ABufBank-1:0][$clog2(ABufDepth)-1:0] aBufAddr;
    logic [ABufBank-1:0]                        aBufBankSel;
    logic [WBufBank-1:0][$clog2(WBufDepth)-1:0] wBufAddr;
    logic [WBufBank-1:0]                        wBufBankSel;
    logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddr;
    logic [OBufBank-1:0]                        oBufBankSel;
    logic [SBufBank-1:0][$clog2(SBufDepth)-1:0] sBufAddr;
    logic [SBufBank-1:0]                        sBufBankSel;
    logic [SBufBank-1:0][$clog2(SBufDepth)-1:0] sBufAddrDelay1;
    logic [SBufBank-1:0]                        sBufBankSelDelay1;

    //-----------------------------------------------------
    // MInst FIFO
    //-----------------------------------------------------
    DW_fifo_s1_sf # (
         .width     ( $bits(MInst)  )
        ,.depth     ( 4             )
        ,.rst_mode  ( 0             )
    ) mInstFifo (
         .clk       ( clk               )
        ,.rst_n     ( rst_n             )
        ,.push_req_n( mInstPush_n       )
        ,.pop_req_n ( mInstPop_n        )
        ,.diag_n    ( 1'b1              )
        ,.data_in   ( topCtrlIf.mInst   )
        ,.data_out  ( mInstCrt          )
        ,.empty     ( mInstEmpty        )
        ,.full      ( mInstFull         )
    );

    assign mInstPush_n = ~((topCtrlIf.mValid) & (~mInstFull));
    assign mInstPop_n  = ~((mFSM_r != MWAIT) & (mFSM_w == MWAIT) & ~mInstEmpty);

    //-----------------------------------------------------
    // MCtrl FSM
    //-----------------------------------------------------
    // * Main FSM
    always_comb begin
        case (mFSM_r)
            MIDLE : begin
                if ((~mInstEmpty) & mInstCrt.amsync) begin
                    mFSM_w = MASYNC;
                end else if (~mInstEmpty) begin
                    mFSM_w = MWORK;
                end else begin
                    mFSM_w = MIDLE;
                end
            end
            MASYNC : begin
                if (allFinish & amCtrlSync) begin
                    mFSM_w = MWAIT;
                end else begin
                    mFSM_w = MASYNC;
                end
            end
            MWORK : begin
                if (allFinish) begin
                    mFSM_w = MWAIT;
                end else begin
                    mFSM_w = MWORK;
                end
            end
            MWAIT : begin
                if (mArrayIf.mFinish) begin
                    mFSM_w = MIDLE;
                end else begin
                    mFSM_w = MWAIT;
                end
            end
            default: mFSM_w = MIDLE;
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            mFSM_r <= MIDLE;
        end else begin
            mFSM_r <= mFSM_w;
        end
    end

    assign allFinish = rowAFinish & rowWFinish & colAFinish & colWFinish;

    // * Row/Col Ptr
    // ** Row-W Ptr
    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                nextRowWPtr = rowWPtr + 1;
                nextRowWExBit = rowWExBit;
            end
            2'b01 : begin
                nextRowWPtr = rowWPtr + 1;
                nextRowWExBit = rowWExBit;
            end
            2'b10 : begin
                {nextRowWPtr,nextRowWExBit} = {rowWPtr,rowWExBit} + 1;
            end
            2'b11 : begin
                {nextRowWPtr,nextRowWExBit} = {rowWPtr,rowWExBit} + 1;
            end
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            rowWPtr <= 0;
            rowWExBit <= 0;
        end else if (rowWFinish & passSync) begin
            rowWPtr <= 0;
            rowWExBit <= 0;
        end else if (~rowWFinish & (mFSM_r != MIDLE)) begin
            rowWPtr <= nextRowWPtr;
            rowWExBit <= nextRowWExBit;
        end
    end

    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                rowWFinish = (rowWPtr == mInstCrt.rowWEnd);
            end
            2'b01 : begin
                rowWFinish = (rowWPtr == mInstCrt.rowWEnd);
            end
            2'b10 : begin
                rowWFinish = (rowWPtr == mInstCrt.rowWEnd) & rowWExBit;
            end
            2'b11 : begin
                rowWFinish = (rowWPtr == mInstCrt.rowWEnd) & rowWExBit & rowAExBit;
            end
        endcase
    end

    // ** Row-A Ptr
    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                nextRowAPtr = rowAPtr + 1;
                nextRowAExBit = rowAExBit;
            end
            2'b01 : begin
                {nextRowAPtr,nextRowAExBit[0]} = {rowAPtr,rowAExBit[0]} + 1;
                nextRowAExBit[1] = rowAExBit[1];
            end
            2'b10 : begin
                nextRowAPtr = rowAPtr + 1;
                nextRowAExBit = rowAExBit;
            end
            2'b11 : begin
                if (rowAExBit == 2'b01) begin
                    nextRowAPtr = rowAPtr - 1; 
                end else begin
                    nextRowAPtr = rowAPtr + 1; 
                end
                if (rowAExBit == 2'b11) begin
                    nextRowAExBit = 0;
                end else begin
                    nextRowAExBit = rowAExBit + 1;
                end
            end
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            rowAPtr <= 0;
            rowAExBit <= 0;
        end else if (rowAFinish & passSync) begin
            rowAPtr <= 0;
            rowAExBit <= 0;
        end else if (~rowAFinish & (mFSM_r != MIDLE)) begin
            rowAPtr <= nextRowAPtr;
            rowAExBit <= nextRowAExBit;
        end
    end

    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                rowAFinish = (rowWPtr == mInstCrt.rowWEnd);
            end
            2'b01 : begin
                rowAFinish = (rowWPtr == mInstCrt.rowWEnd) & rowAExBit;
            end
            2'b10 : begin
                rowAFinish = (rowWPtr == mInstCrt.rowWEnd);
            end
            2'b11 : begin
                rowAFinish = (rowWPtr == mInstCrt.rowWEnd) & rowWExBit & rowAExBit;
            end
        endcase
    end

    // ** Col-W Ptr
    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            colWPtr <= 0;
        end else if (colWFinish & rowWFinish & passSync) begin
            colWPtr <= 0;
        end else if (~colWFinish & rowWFinish & (mFSM_r != MIDLE)) begin
            colWPtr <= colWPtr + 1;
        end
    end

    assign colWFinish = (colWPtr == mInstCrt.colWEnd);

    // ** Col-A Ptr
    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            colAPtr <= 0;
        end else if (colAFinish & colWFinish & rowAFinish & ((mFSM_r == MWORK) | amCtrlSync)) begin
            colAPtr <= 0;
        end else if (~colAFinish & colWFinish & rowAFinish & ((mFSM_r == MWORK) | amCtrlSync)) begin
            colAPtr <= colAPtr + 1;
        end
    end

    assign colAFinish = (colAFinish == mInstCrt.colAEnd);

    // * Outlier
    // Out of Bound
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            aOutlierShift <= 0;
        end else if (mFSM_r == MIDLE) begin
            aOutlierShift <= mInstCrt.aOutlier;
        end else if (aOutlierFormer & ~rowAFinish) begin
            aOutlierShift <= {aOutlierShift[MRowLoop-2:0],aOutlierShift[MRowLoop-1]};
        end else if (aOutlierNext & ~rowAFinish) begin
            aOutlierShift <= {aOutlierShift[0],aOutlierShift[MRowLoop-1:1]};
        end
    end

    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                aOutlierNext = 1;
            end
            2'b01 : begin
                if (rowAExBit[0]) begin
                    aOutlierNext = 1;
                end else begin
                    aOutlierNext = 0;
                end
            end
            2'b10 : begin
                aOutlierNext = 1;
            end
            2'b11 : begin
                aOutlierNext = 1;
            end
        endcase
    end

    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                aOutlierFormer = 0;
            end
            2'b01 : begin
                aOutlierFormer = 0;
            end
            2'b10 : begin
                aOutlierFormer = 0;
            end
            2'b11 : begin
                aOutlierFormer = (nextRowAExBit == 2'b01);
            end
        endcase
    end

    // * Address Cvt
    MCtrlAddrCvt u_MCtrlAddrCvt(
         .rowAPtr        ( rowAPtr       )
        ,.rowWPtr        ( rowWPtr       )
        ,.colAPtr        ( colAPtr       )
        ,.colWPtr        ( colWPtr       )
        ,.aBufBankSel    ( aBufBankSel   )
        ,.aBufAddr       ( aBufAddr      )
        ,.wBufBankSel    ( wBufBankSel   )
        ,.wBufAddr       ( wBufAddr      )
        ,.oBufBankSel    ( oBufBankSel   )
        ,.oBufAddr       ( oBufAddr      )
        ,.sBufBankSel    ( sBufBankSel   )
        ,.sBufAddr       ( sBufAddr      )
    );
    // pipe sBufBankSel & sBufAddr to align due to pipeline in MPE, not pipe data in MPE
    // pipe oBufBankSel & oBufAddr in MPE module
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sBufBankSelDelay1 <= 0;
            sBufAddrDelay1 <= 0;
        end else begin
            sBufBankSelDelay1 <= sBufBankSel;
            sBufAddrDelay1 <= sBufAddr;
        end
    end

    // * SYNC
    assign amCtrlSync = ((mFSM_r == MASYNC) & ~topSyncIf.amEmpty);
    assign passSync = ~(colWFinish & rowAFinish & (mFSM_r == MASYNC) & topSyncIf.amEmpty);

    //-----------------------------------------------------
    // I/O
    //-----------------------------------------------------
    // * TopCtrl2MCtrl
    assign topCtrlIf.mReady = ~mInstFull;

    // * TopSync2MCtrl
    assign topSyncIf.mvWSync = mArrayIf.mvWSync;
    assign topSyncIf.amRSync = colWFinish & rowAFinish & (mFSM_r == MASYNC) & ~topSyncIf.amEmpty;

    // * MCtrl2ABuffer
    assign aBufIf.rAddr = aBufAddr  ;
    assign aBufIf.rEn = aBufBankSel ;

    // * MCtrl2WBuffer
    assign wBufIf.rAddr = wBufAddr  ;
    assign wBufIf.rEn = wBufBankSel ;

    // * MCtrl2MArray
    assign mArrayIf.mValid  = (mFSM_r == MWORK) | ((mFSM_r == MASYNC) & passSync);
    // assign mArrayIf.colAPtr = colAPtr;
    // assign mArrayIf.colAEnd = mInstCrt.colAEnd;
    // assign mArrayIf.rowAPtr = rowAPtr;
    // assign mArrayIf.rowAEnd = mInstCrt.rowAEnd;
    assign mArrayIf.mOutTileFinish = rowAFinish;
    assign mArrayIf.oBufBankSel = oBufBankSel;
    assign mArrayIf.oBufAddr = oBufAddr;

    always_comb begin
        case ({aOutlierShift[0], mInstCrt.wOutlier})
            2'b00 : begin
                mArrayIf.mShift = 0;
                mArrayIf.mOut = 1;
            end
            2'b01 : begin
                mArrayIf.mShift = {rowAExBit[0], 1'b0};
                mArrayIf.mOut = rowAExBit[0];
            end
            2'b10 : begin
                mArrayIf.mShift = {1'b0, rowWExBit};
                mArrayIf.mOut = rowWExBit;
            end
            2'b11 : begin
                mArrayIf.mShift = rowAExBit;
                mArrayIf.mOut = (rowAExBit == 2'b11);
            end
        endcase
    end
endmodule