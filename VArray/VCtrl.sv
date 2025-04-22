import Common::*;

module VCtrl (
    // clk & rst
     input logic clk
    ,input logic rst_n
    // interconnect
    ,TopCtrl2VCtrl.VCtrlSide topCtrlIf
    ,TopSync2VCtrl.VCtrlSide topSyncIf
    ,VCtrl2OBuffer.CtrlSide  oBufIf
    ,VCtrl2VBuffer.CtrlSide  vBufIf
    ,VCtrl2EBuffer.CtrlSide  eBufIf
    ,VCtrl2VArray.CtrlSide   vArrayIf
);
    //-----------------------------------------------------
    // Internal Logics
    //-----------------------------------------------------
    // * VInst FIFO
    logic vInstPush_n   ;
    logic vInstPop_n    ;
    logic vInstEmpty    ;
    logic vInstFull     ;
    VInst vInstCrt      ;
    
    // * OpCode LUT
    VOpCode vOpCode;

    // * VCtrl FSM
    VFSM  vFSM_w;
    VFSM  vFSM_r;
    logic [$clog2(VRowLoop)-1:0] rowPtr;
    logic [$clog2(VColLoop)-1:0] colPtr;
    logic [OBufBank-1:0]                        oBufBankSel     ;
    logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddr        ;
    logic [EBufBank-1:0][$clog2(EBufDepth)-1:0] cWiseEBufAddr   ;
    logic [EBufBank-1:0][$clog2(EBufDepth)-1:0] eWiseEBufAddr   ;
    logic [VBufBank-1:0][$clog2(VBufDepth)-1:0] cWiseVBufAddr   ;
    logic [VBufBank-1:0][$clog2(VBufDepth)-1:0] eWiseVBufAddr   ;

    // * Sync
    logic vCtrlSync;

    //-----------------------------------------------------
    // VInst FIFO
    //-----------------------------------------------------
    DW_fifo_s1_sf #(
        .width      ( $bits(VInst)  ),  
        .depth      ( 4             ),    
        .rst_mode   ( 0             ) // including Memory
    ) vInstFifo (
        .clk        ( clk               ),
        .rst_n      ( rst_n             ),
        .push_req_n ( vInstPush_n       ),
        .pop_req_n  ( vInstPop_n        ),
        .diag_n     ( 1'b1              ),
        .data_in    ( topCtrlIf.vInst   ),
        .data_out   ( vInstCrt          ),
        .empty      ( vInstEmpty        ),
        .full       ( vInstFull         )
    );
    
    assign vInstPush_n = ~((topCtrlIf.vValid) & (~vInstFull));
    assign vInstPop_n  = ~((vFSM_r != VWAIT) & (vFSM_w == VWAIT) & ~vInstEmpty);

    //-----------------------------------------------------
    // OpCode LUT
    //-----------------------------------------------------
    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            vOpCode <= 0;
        end else begin
            case (vInstCrt.opFunc)
                'd1 : vOpCode <= OP0 ;
                'd0 : vOpCode <= OP1 ;
                'd2 : vOpCode <= OP2 ;
                'd3 : vOpCode <= OP3 ;
                'd4 : vOpCode <= OP4 ;
                'd5 : vOpCode <= OP5 ;
                'd6 : vOpCode <= OP6 ;
                'd7 : vOpCode <= OP7 ;
                'd8 : vOpCode <= OP8 ;
                'd9 : vOpCode <= OP9 ;
                'd10: vOpCode <= OP10;
                'd11: vOpCode <= OP11;
                'd12: vOpCode <= OP12;
                'd13: vOpCode <= OP13;
                'd15: vOpCode <= OP14;
                default: vOpCode <= 0;
            endcase
        end
    end

    //-----------------------------------------------------
    // VCtrl FSM
    //-----------------------------------------------------
    // * Main FSM
    always_comb begin
        case (vFSM_r)
            VIDLE : begin
                if ((~vInstEmpty) & vInstCrt.mvsync) begin
                    vFSM_w = VMSYNC;
                end else if ((~vInstEmpty) & vInstCrt.evsync) begin
                    vFSM_w = VESYNC;
                end else if ((~vInstEmpty)) begin
                    vFSM_w = VWORK;
                end else begin
                    vFSM_w = VIDLE;
                end
            end
            VMSYNC : begin
                if ((rowPtr == vInstCrt.rowEnd) & (colPtr == vInstCrt.colEnd) & vCtrlSync) begin
                    vFSM_w = VWAIT;
                end else begin
                    vFSM_w = VMSYNC;
                end
            end
            VESYNC : begin
                if ((rowPtr == vInstCrt.rowEnd) & (colPtr == vInstCrt.colEnd) & vCtrlSync) begin
                    vFSM_w = VWAIT;
                end else begin
                    vFSM_w = VESYNC;
                end
            end
            VWORK : begin
                if ((rowPtr == vInstCrt.rowEnd) & (colPtr == vInstCrt.colEnd)) begin
                    vFSM_w = VWAIT;
                end else begin
                    vFSM_w = VWORK;
                end
            end
            VWAIT : begin
                if (vArrayIf.vFinish) begin
                    vFSM_w = VIDLE;
                end else begin
                    vFSM_w = VWAIT;
                end
            end
            default: vFSM_w = VIDLE;
        endcase
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            vFSM_r <= VIDLE;
        end else begin
            vFSM_r <= vFSM_w;
        end
    end

    // * Row/Col Ptr
    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            rowPtr <= 0;
        end else if ((rowPtr == vInstCrt.rowEnd) & ((vFSM_r == VWORK) | vCtrlSync)) begin
            rowPtr <= 0;
        end else if ((vFSM_r == VMSYNC) & ~topSyncIf.mvEmpty) begin
            rowPtr <= rowPtr + 1;
        end else if ((vFSM_r == VESYNC) & ~topSyncIf.evEmpty) begin
            rowPtr <= rowPtr + 1;
        end else if ((vFSM_r == VWORK)) begin
            rowPtr <= rowPtr + 1;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            colPtr <= 0;
        end else if ((colPtr == vInstCrt.colEnd) & (rowPtr == vInstCrt.rowEnd) & ((vFSM_r == VWORK) | vCtrlSync)) begin
            colPtr <= 0;
        end else if ((vFSM_r == VMSYNC) & (rowPtr == vInstCrt.rowEnd) & ~topSyncIf.mvEmpty) begin
            colPtr <= colPtr + 1;
        end else if ((vFSM_r == VESYNC) & (rowPtr == vInstCrt.rowEnd) & ~topSyncIf.evEmpty) begin
            colPtr <= colPtr + 1;
        end else if ((vFSM_r == VWORK) & (rowPtr == vInstCrt.rowEnd)) begin
            colPtr <= colPtr + 1;
        end
    end

    // * Address Cvt
    VCtrlAddrCvt u_vCtrlAddrCvt(
         .rowPtr         ( rowPtr        )
        ,.colPtr         ( colPtr        )
        ,.oBufBankSel    ( oBufBankSel   )
        ,.oBufAddr       ( oBufAddr      )
        ,.cWiseEBufAddr  ( cWiseEBufAddr )
        ,.eWiseEBufAddr  ( eWiseEBufAddr )
        ,.cWiseVBufAddr  ( cWiseVBufAddr )
        ,.eWiseVBufAddr  ( eWiseVBufAddr )
    );

    // * SYNC
    assign vCtrlSync = ((vFSM_r == VMSYNC) & ~topSyncIf.mvEmpty) | ((vFSM_r == VESYNC) & ~topSyncIf.evEmpty);

    //-----------------------------------------------------
    // I/O
    //-----------------------------------------------------
    // * TopCtrl2VCtrl
    assign topCtrlIf.vReady = ~vInstFull;

    // * TopSync2VCtrl
    assign topSyncIf.mvRSync = (vFSM_r == VMSYNC) & ~topSyncIf.mvEmpty;
    assign topSyncIf.evRSync = (vFSM_r == VESYNC) & ~topSyncIf.evEmpty;
    assign topSyncIf.veWSync = vArrayIf.veWSync;

    // * VCtrl2OBuffer
    assign oBufIf.rAddr = oBufAddr  ;
    assign oBufIf.rEn = oBufBankSel & {OBufBank{vOpCode.oBufREn}};
    
    // * VCtrl2VBuffer
    assign vBufIf.rAddr = vOpCode.vBufRMode ? eWiseVBufAddr : cWiseVBufAddr;
    assign vBufIf.rEn = {VBufBank{vOpCode.vBufREn}};

    // * VCtrl2EBuffer
    assign eBufIf.rAddr = vOpCode.eBufRMode ? eWiseEBufAddr : cWiseEBufAddr;
    assign eBufIf.rEn = {EBufBank{vOpCode.eBufREn}};

    // * VCtrl2VArray
    assign vArrayIf.vValid = (vFSM_r == VWORK) | vCtrlSync;
    assign vArrayIf.rowPtr = rowPtr;
    assign vArrayIf.colPtr = colPtr;
    assign vArrayIf.vOpCode = vOpCode;

endmodule