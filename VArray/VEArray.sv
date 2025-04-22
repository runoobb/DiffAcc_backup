import Common::*;

module VEArray #(
     parameter ELTNUM = 4
    ,parameter ELTBIT = 16
) (
    // clk & rst
     input  logic clk
    ,input  logic rst_n
    // data
    ,VECtrl2VEArray.ArraySide    veCtrlIf
    ,VEArray2GBuffer.ArraySide  gBufIf  
    ,VEArray2EBuffer.ArraySide  eBufIf  
);

    //-----------------------------------------------------
    // Internal Logics
    //-----------------------------------------------------
    // * Data Reshape    
    logic [ELTNUM-1:0][ELTBIT-1:0] inVec0;
    logic [ELTNUM-1:0][ELTBIT-1:0] inVec1;
    logic [ELTBIT-1:0]             inElt0;
    logic [ELTBIT-1:0]             inELt1;

    // * Read-Data Cross Bar
    // ** MaxReduce
    logic                          inMaxReduceValid ;
    logic [ELTNUM-1:0][ELTBIT-1:0] inMaxReduceVec   ;
    logic [ELTBIT-1:0]             inMaxReduceElt   ;
    // ** ExpProd
    logic                          inExpProdValid   ;
    logic                          inExpProdLast    ;
    logic [ELTNUM-1:0][ELTBIT-1:0] inExpProdPartSum ;
    logic [ELTNUM-1:0][ELTBIT-1:0] inExpProdPartMax ;
    logic [ELTBIT-1:0]             inExpProdAllMax  ;
    logic [ELTBIT-1:0]             inExpProdAllSum  ;
    // ** MergeNorm
    logic                          inMergeNormValid     ;
    logic                          inMergeNormLast      ;
    logic [ELTNUM-1:0][ELTBIT-1:0] inMergeNormMu        ;
    logic [ELTNUM-1:0][ELTBIT-1:0] inMergeNormSigma     ;
    logic [ELTBIT-1:0]             inMergeNormInvN      ;
    logic [ELTBIT-1:0]             inMergeNormAllMu     ;
    logic [ELTBIT-1:0]             inMergeNormAllSigma  ;

    // * Ops
    // ** MaxReduce
    logic              outMaxReduceValid;
    logic [ELTBIT-1:0] outMaxReduceElt  ;
    // ** ExpProd
    logic              outExpProdValid  ;
    logic [ELTBIT-1:0] outExpProdAllSum ;
    // ** MergeNorm
    logic              outMergeNormMuValid  ;
    logic [ELTBIT-1:0] outMergeNormAllMu    ;
    logic              outMergeNormSigValid ;
    logic [ELTBIT-1:0] outMergeNormAllSigma ;

    // * Write-Data Cross Bar
    EOpCode                        outEOpcode   ;
    logic [8-1:0]                  outColEnd    ;
    logic                          outEVSync    ;
    logic [GBufAddrW-1:0]          outAddr0     ;
    logic [GBufAddrW-1:0]          outAddr1     ;
    logic                          outElt0En    ;
    logic                          outElt1En    ;
    logic [ELTBIT-1:0]             outElt0      ;
    logic [ELTBIT-1:0]             outElt1      ;

    //-----------------------------------------------------
    // Data Reshape
    //-----------------------------------------------------
    VOneHotMux # (
         .ELTNUM    ( EBufBank/2    )
        ,.ELTBIT    ( EBufWidth     )
    ) u_inVec0Mux (
         .inData    ( eBufIf.rData[EBufBank/2-1:0]  )
        ,.oneHot    ( eBufIf.rValid[EBufBank/2-1:0] )
        ,.outData   ( inVec0                        )
    );

    VOneHotMux # (
         .ELTNUM    ( EBufBank/2    )
        ,.ELTBIT    ( EBufWidth     )
    ) u_inVec1Mux (
         .inData    ( eBufIf.rData[EBufBank-1:EBufBank/2]  )
        ,.oneHot    ( eBufIf.rValid[EBufBank-1:EBufBank/2] )
        ,.outData   ( inVec1                               )
    );

    VOneHotMux # (
         .ELTNUM    ( GBufBank/2    )
        ,.ELTBIT    ( GBufWidth     )
    ) u_inElt0Mux (
         .inData    ( gBufIf.rData[GBufBank/2-1:0]  )
        ,.oneHot    ( gBufIf.rValid[GBufBank/2-1:0] )
        ,.outData   ( inElt0                        )
    );

    VOneHotMux # (
         .ELTNUM    ( GBufBank/2    )
        ,.ELTBIT    ( GBufWidth     )
    ) u_inElt1Mux (
         .inData    ( gBufIf.rData[GBufBank-1:GBufBank/2]  )
        ,.oneHot    ( gBufIf.rValid[GBufBank-1:GBufBank/2] )
        ,.outData   ( inElt1                               )
    );

    //-----------------------------------------------------
    // Read-Data CrossBar
    //-----------------------------------------------------
    // * MaxReduce
    always_comb begin
        if ((veCtrlIf.eOpCode == MaxReduce) & veCtrlIf.eValid) begin
            inMaxReduceValid = 1;
            inMaxReduceVec   = inVec0;
        end else begin
            inMaxReduceValid = 0;
            inMaxReduceVec   = 0;
        end
    end

    // ** ExpProd
    always_comb begin
        if ((veCtrlIf.eOpCode == ExpProd) & veCtrlIf.eValid) begin
            inExpProdValid   = 1;
            inExpProdLast    = veCtrlIf.eLast;
            inExpProdPartSum = inVec0;
            inExpProdPartMax = inVec1;
            inExpProdAllMax  = inElt0;
            inExpProdAllSum  = inELt1;
        end else begin
            inExpProdValid   = 0;
            inExpProdLast    = 0;
            inExpProdPartSum = 0;
            inExpProdPartMax = 0;
            inExpProdAllMax  = 0;
            inExpProdAllSum  = 0;
        end
    end

    // ** MergeNorm
    always_comb begin
        if ((veCtrlIf.eOpCode == MergeNorm) & veCtrlIf.eValid) begin
            inMergeNormValid    = 1;
            inMergeNormLast     = veCtrlIf.eLast;
            inMergeNormMu       = inVec0;
            inMergeNormSigma    = inVec1;
            inMergeNormInvN     = veCtrlIf.eImm;
            inMergeNormAllMu    = inElt0;
            inMergeNormAllSigma = inELt1;
        end else begin
            inMergeNormValid   = 0;
            inMergeNormLast    = 0;
            inMergeNormMu      = 0;
            inMergeNormSigma   = 0;
            inMergeNormInvN    = 0;
            inMergeNormAllMu   = 0;
            inMergeNormAllSigma= 0;
        end
    end

    //-----------------------------------------------------
    // VEArray Ops
    //-----------------------------------------------------
    VEArrayMaxReduce #(
         .ELTNUM    ( ELTNUM    )
        ,.ELTBIT    ( ELTBIT    )
        ,.PIPE      ( 3'b100    )
    ) u_veArrayMaxReduce (
         .clk       ( clk               )
        ,.rst_n     ( rst_n             )
        ,.inValid   ( inMaxReduceValid  )
        ,.inVec     ( inMaxReduceVec    )
        ,.inElt     ( inMaxReduceElt    )
        ,.outValid  ( outMaxReduceValid )
        ,.outElt    ( outMaxReduceElt   )
    );

    VEArrayExpProd #(
        .ELTNUM     ( ELTNUM    ) 
       ,.ELTBIT     ( ELTBIT    ) 
    ) (
         .clk        ( clk               )
        ,.rst_n      ( rst_n             )
        ,.inValid    ( inExpProdValid    )
        ,.inLast     ( inExpProdLast     )
        ,.inPartSum  ( inExpProdPartSum  )
        ,.inPartMax  ( inExpProdPartMax  )
        ,.inAllMax   ( inExpProdAllMax   )
        ,.inAllSum   ( inExpProdAllSum   )
        ,.outValid   ( outExpProdValid   )
        ,.outAllSum  ( outExpProdAllSum  )
    );

    VEArrayMergeNorm #(
         .ELTNUM    ( ELTNUM    )
        ,.ELTBIT    ( ELTBIT    )
    ) (
         .clk           ( clk                   )
        ,.rst_n         ( rst_n                 )
        ,.inValid       ( inMergeNormValid      )
        ,.inLast        ( inMergeNormLast       )
        ,.inMu          ( inMergeNormMu         )
        ,.inSigma       ( inMergeNormSigma      )
        ,.invN          ( inMergeNormInvN       )
        ,.inAllMu       ( inMergeNormAllMu      )
        ,.inAllSigma    ( inMergeNormAllSigma   )
        ,.outMuValid    ( outMergeNormMuValid   )
        ,.outAllMu      ( outMergeNormAllMu     )
        ,.outSigValid   ( outMergeNormSigValid  )
        ,.outAllSigma   ( outMergeNormAllSigma  )
    );

    //-----------------------------------------------------
    // Write-Data CrossBar
    //-----------------------------------------------------
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            outEOpcode <= MaxReduce;
        end else begin
            outEOpcode <= veCtrlIf.eOpCode;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            outColEnd <= 0;
        end else if (veCtrlIf.eFirst) begin
            outColEnd <= veCtrlIf.colEnd;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            outEVSync <= 0;
        end else if (veCtrlIf.eFirst) begin
            outEVSync <= veCtrlIf.evWSync;
        end
    end

    assign outElt0En = outMaxReduceValid | outExpProdValid | outMergeNormMuValid;
    assign outElt1En = outMergeNormSigValid;
    
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            outAddr0 <= 0;
        end else if (veCtrlIf.eFirst) begin
            outAddr0 <= veCtrlIf.colBegin;
        end else if (outElt0En) begin
            outAddr0 <= outAddr0 + 1;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            outAddr1 <= 0;
        end else if (veCtrlIf.eFirst) begin
            outAddr1 <= veCtrlIf.colBegin;
        end else if (outElt1En) begin
            outAddr1 <= outAddr1 + 1;
        end
    end

    VOneHotMux # (
         .ELTNUM    (   3       )
        ,.ELTBIT    ( ELTBIT    )
    ) u_out0Mux (
         .inData    ({
             outMaxReduceElt
            ,outExpProdAllSum
            ,outMergeNormAllMu
         })
        ,.oneHot    ({
             outMaxReduceValid
            ,outExpProdValid
            ,outMergeNormMuValid
        })
        ,.outData   ( outElt0   )
    );

    assign outElt1 = outMergeNormSigValid;

    //-----------------------------------------------------
    // I/O
    //-----------------------------------------------------
    assign gBufIf.wAddr = {outAddr0, outAddr1};
    assign gBufIf.wData = {outElt1, outElt0};
    assign gBufIf.wEn   = {outElt1En, outElt0En};

    always_comb begin
        if (outEOpcode == MergeNorm) begin
            veCtrlIf.eFinish = (outAddr1 == outColEnd) & outElt1;
        end else begin
            veCtrlIf.eFinish = (outAddr0 == outColEnd) & outElt0;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            veCtrlIf.evWSync <= 0;
        end else if (outEOpcode == MergeNorm) begin
            veCtrlIf.evWSync <= outEVSync & outElt1;
        end else begin
            veCtrlIf.evWSync <= outEVSync & outElt0;
        end
    end

endmodule