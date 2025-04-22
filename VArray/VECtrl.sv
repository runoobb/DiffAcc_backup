import Common::*;

module VECtrl (
    // clk & rst
     input logic clk
    ,input logic rst_n
    // interconnect
    ,TopCtrl2VECtrl.VCtrlSide topCtrlIf
    ,TopSync2VECtrl.VCtrlSide topSyncIf
    ,VECtrl2EBuffer.CtrlSide  eBufIf
    ,VECtrl2GBuffer.CtrlSide  gBufIf
    ,VECtrl2VEArray.CtrlSide  veArrayIf
);
    //-----------------------------------------------------
    // Internal Logics
    //-----------------------------------------------------
    // * EInst FIFO
    logic eInstPush_n   ;
    logic eInstPop_n    ;
    logic eInstEmpty    ;
    logic eInstFull     ;
    EInst eInstCrt      ;

    // * VCtrl FSM
    EFSM  eFSM_w;
    EFSM  eFSM_r;
    logic [$clog2(VColLoop)-1:0]                colPtr      ;
    logic [EBufBank-1:0][$clog2(EBufDepth)-1:0] eBufAddr    ;
    logic [EBufBank-1:0]                        eBufBankSel ;
    logic [GBufBank-1:0][$clog2(GBufDepth)-1:0] gBufAddr    ;
    logic [GBufBank-1:0]                        gBufBankSel ;

    // * Sync
    logic veCtrlSync;

    //-----------------------------------------------------
    // VInst FIFO
    //-----------------------------------------------------
    DW_fifo_s1_sf #(
        .width      ( $bits(EInst)  ),  
        .depth      ( 4             ),    
        .rst_mode   ( 0             ) // Sync including Memory
    ) vInstFifo (
        .clk        ( clk               ),
        .rst_n      ( rst_n             ),
        .push_req_n ( eInstPush_n       ),
        .pop_req_n  ( eInstPop_n        ),
        .diag_n     ( 1'b1              ),
        .data_in    ( topCtrlIf.eInst   ),
        .data_out   ( eInstCrt          ),
        .empty      ( eInstEmpty        ),
        .full       ( eInstFull         )
    );
    assign eInstPush_n = ~((topCtrlIf.eValid) & (~eInstFull));
    assign eInstPop_n  = ~((eFSM_r != EWAIT) & (eFSM_w == EWAIT) & ~eInstEmpty);

    //-----------------------------------------------------
    // VECtrl FSM
    //-----------------------------------------------------
    // * Main FSM
    always_comb begin
        case (eFSM_r)
            EIDLE : begin
                if ((~eInstEmpty) & eInstCrt.mvsync) begin
                    eFSM_w = ESYNC;
                end else if ((~eInstEmpty)) begin
                    eFSM_w = EWORK;
                end else begin
                    eFSM_w = EIDLE;
                end
            end
            ESYNC : begin
                if ((colPtr == eInstCrt.colEnd) & veCtrlSync) begin
                    eFSM_w = EWAIT;
                end else begin
                    eFSM_w = ESYNC;
                end
            end
            EWORK : begin
                if ((colPtr == eInstCrt.colEnd) & veCtrlSync) begin
                    eFSM_w = EWAIT;
                end else begin
                    eFSM_w = EWORK;
                end
            end
            EWAIT : begin
                if (veArrayIf.eFinish) begin
                    eFSM_w = EIDLE;
                end else begin
                    eFSM_w = EWAIT;
                end
            end
            default: eFSM_w = EIDLE;
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            eFSM_r <= EIDLE;
        end else begin
            eFSM_r <= eFSM_w;
        end
    end

    // * Col Ptr
    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            colPtr <= 0;
        end else if ((colPtr == eInstCrt.colEnd) & ((eFSM_r == EWORK) | veCtrlSync)) begin
            colPtr <= 0;
        end else if ((eFSM_r == ESYNC) & ~topSyncIf.veEmpty) begin
            colPtr <= colPtr + 1;
        end else if ((eFSM_r == EWORK)) begin
            colPtr <= colPtr + 1;
        end
    end

    // * SYNC
    assign veCtrlSync = (eFSM_r == ESYNC) & ~topSyncIf.veEmpty;

    // * Drive Buffer
    generate
        for (genvar i = 0; i < EBufBank; i = i+1) begin
            if (i < EBufBank / 2) begin
                assign eBufBankSel[i] = (eFSM_r == EWORK) 
                                      | ((eFSM_r == ESYNC) & ~topSyncIf.veEmpty);
            end else begin
                assign eBufBankSel[i] = (eInstCrt.eOpCode == MaxReduce) 
                                      ? 0 
                                      : eBufBankSel[i-EBufBank/2];
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < EBufBank; i = i+1) begin
            assign eBufAddr[i] = colPtr;
        end
    endgenerate

    generate
        for (genvar i = 0; i < GBufBank; i = i+1) begin
            if (i < GBufBank / 2) begin
                assign gBufBankSel[i] = (eFSM_r == EWORK) 
                                      | ((eFSM_r == ESYNC) & ~topSyncIf.veEmpty);
            end else begin
                assign gBufBankSel[i] = 0;
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < GBufBank; i = i+1) begin
            assign gBufAddr[i] = colPtr;
        end
    endgenerate

    //-----------------------------------------------------
    // I/O
    //-----------------------------------------------------
    // * TopCtrl2VCtrl
    assign topCtrlIf.eReady = ~eInstFull;

    // * TopSync2VCtrl
    assign topSyncIf.veRSync = (eFSM_r == ESYNC) & ~topSyncIf.veEmpty;
    assign topSyncIf.evWSync = veArrayIf.evWSync;

    // * VCtrl2EBuffer
    assign eBufIf.rAddr = eBufAddr      ;
    assign eBufIf.rEn   = eBufBankSel   ;
    
    // * VCtrl2GBuffer
    assign gBufIf.rAddr = gBufAddr      ;
    assign gBufIf.rEn   = gBufBankSel   ;

    // * VCtrl2VArray
    assign veArrayIf.eValid = (eFSM_r == EWORK) | veCtrlSync;
    assign veArrayIf.eFirst = (eFSM_r != EIDLE) & (colPtr == eInstCrt.colBegin);
    assign veArrayIf.eLast  = (eFSM_r != EIDLE) & eInstCrt.eLast;
    assign veArrayIf.eImm   = topCtrlIf.eImm;
    assign veArrayIf.colBegin = eInstCrt.colBegin;
    assign veArrayIf.colEnd   = eInstCrt.colEnd;

endmodule