import Common::*;

module VCtrlAddrCvt (
    // ptrs
     input  logic [$clog2(VRowLoop)-1:0] rowPtr
    ,input  logic [$clog2(VColLoop)-1:0] colPtr
    // OBuf
    ,output logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddr
    ,output logic [OBufBank-1:0]                        oBufBankSel
    // Channel-wise EBuf
    ,output logic [EBufBank-1:0][$clog2(EBufDepth)-1:0] cWiseEBufAddr
    // Element-wise EBuf
    ,output logic [EBufBank-1:0][$clog2(EBufDepth)-1:0] eWiseEBufAddr
    // Channel-wise VBuf
    ,output logic [VBufBank-1:0][$clog2(VBufDepth)-1:0] cWiseVBufAddr
    // Element-wise VBuf
    ,output logic [VBufBank-1:0][$clog2(VBufDepth)-1:0] eWiseVBufAddr
);

    // * OBuf Addr
    logic [$clog2(OBufBank)-1:1]                                      shuffleAddr     ;
    logic [$clog2(OBufDepth)-1:$clog2(OBufBank)]                      stableAddr      ;
    logic [1:0][OBufBank/2-1:0][$clog2(OBufBank)-1:1]                 oBufshuffleAddr ;
    logic [1:0][OBufBank/2-1:0][$clog2(OBufDepth)-1:$clog2(OBufBank)] oBufstableAddr  ;

    assign {stableAddr, shuffleAddr} = {colPtr[$clog2(VColLoop)-1:0], rowPtr[$clog2(VRowLoop)-1:1]};
    
    generate
        for (genvar i = 0; i < OBufBank/2; i = i+1) begin
            for (genvar j = 0; j < 2; j = j+1) begin
                // shuffle
                assign oBufshuffleAddr[j][i] = shuffleAddr + i;
                assign oBufstableAddr[j][i] = stableAddr;
                // I/O
                assign oBufAddr[j*OBufBank/2 + i] = {oBufstableAddr[j][i], oBufshuffleAddr[j][i]};
            end
        end
    endgenerate

    // * OBuf Sel
    generate
        for (genvar i = 0; i < OBufBank; i = i+1) begin : OBufEn
            if (i < OBufBank/2) begin
                assign oBufBankSel[i] = (rowPtr[0] == 0);
            end else begin
                assign oBufBankSel[i] = (rowPtr[0] == 1);
            end
        end
    endgenerate

    // * EBuf
    generate
        for (genvar i = 0; i < EBufBank; i = i+1) begin : EBuf
            assign cWiseEBufAddr[i] = ($bits(cWiseEBufAddr[i]))'(rowPtr);
            assign eWiseEBufAddr[i] = ($bits(eWiseEBufAddr[i]))'({colPtr, rowPtr});
        end
    endgenerate

    // * VBuf
    generate
        for (genvar i = 0; i < VBufBank; i = i+1) begin : VBuf
            assign cWiseVBufAddr[i] = ($bits(cWiseVBufAddr[i]))'(rowPtr);
            assign eWiseVBufAddr[i] = ($bits(eWiseVBufAddr[i]))'({colPtr, rowPtr});
        end
    endgenerate

endmodule