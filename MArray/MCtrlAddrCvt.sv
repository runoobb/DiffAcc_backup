import Common::*;

// TODO Ptr Index to be fixed
module MCtrlAddrCvt( 
     input logic [$clog2(MRowLoop)-1:0] rowAPtr
    ,input logic [$clog2(MRowLoop)-1:0] rowWPtr
    ,input logic [$clog2(MAColLoop)-1:0] colAPtr
    ,input logic [$clog2(MWColLoop)-1:0] colWPtr
    ,output logic [ABufBank-1:0] aBufBankSel
    ,output logic [ABufBank-1:0][$clog2(ABufDepth)-1:0] aBufAddr
    ,output logic [WBufBank-1:0] wBufBankSel
    ,output logic [WBufBank-1:0][$clog2(WBufDepth)-1:0] wBufAddr
    ,output logic [OBufBank-1:0] oBufBankSel
    ,output logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddr
    ,output logic [SBufBank-1:0] sBufBankSel
    ,output logic [SBufBank-1:0][$clog2(SBufDepth)-1:0] sBufAddr
    );

    // * WBuf Addr
    generate
        for(genvar i=0; i<WBufBank/2; i=i+1) begin
            for(genvar j=0; j<2; j=j+1) begin 
                assign wBufAddr [j*WBufBank/2+i] = {colWPtr[$clog2(MWColLoop)-1:0], rowWPtr[$clog2(MRowLoop)-1:1]};
            end
        end
    endgenerate

    // * WBuf Sel
    generate
        for (genvar i=0; i < WBufBank; i=i+1) begin
            if(i < WBufBank/2) begin
                assign wBufBankSel[i] = (rowWPtr[0] == 0);
            end else begin
                assign wBufBankSel[i] = (rowWPtr[0] == 1);
            end
        end
    endgenerate

    // * ABuf Addr
    logic [$clog2(ABufBank)-1:1]                                      shuffleAddr     ;
    logic [$clog2(ABufDepth)-1:$clog2(ABufBank)]                      stableAddr      ;
    logic [1:0][ABufBank/2-1:0][$clog2(ABufBank)-1:1]                 aBufshuffleAddr ;
    logic [1:0][ABufBank/2-1:0][$clog2(ABufDepth)-1:$clog2(ABufBank)] aBufstableAddr  ;

    assign {stableAddr, shuffleAddr} = {colAPtr[$clog2(MAColLoop)-1:0], rowAPtr[$clog2(MRowLoop)-1:1]};

    generate
        for (genvar i = 0; i < ABufBank/2; i = i+1) begin
            for (genvar j = 0; j < 2; j = j+1) begin
                // shuffle (truncate addr) //TODO: shuffleAddr not correct
                assign aBufshuffleAddr[j][i] = shuffleAddr + i;
                assign aBufstableAddr[j][i] = stableAddr;
                // I/O
                assign aBufAddr[j*ABufBank/2 + i] = {aBufstableAddr[j][i], aBufshuffleAddr[j][i]};
            end
        end
    endgenerate

    // * ABuf Sel
    generate
        for (genvar i = 0; i < ABufBank; i = i+1) begin : ABufEn
            if (i < ABufBank/2) begin
                assign aBufBankSel[i] = (rowAPtr[0] == 0);
            end else begin
                assign aBufBankSel[i] = (rowAPtr[0] == 1);
            end
        end
    endgenerate

    // * OBuf Addr
    generate
        for(genvar i=0; i<OBufBank/2; i=i+1) begin
            for(genvar j=0; j<2; j=j+1) begin 
                assign oBufAddr [j*OBufBank/2+i] = {colAPtr[$clog2(MAColLoop)-1:0], colWPtr[$clog2(MWColLoop)-1:1]};
            end
        end
    endgenerate

    // * OBuf Sel
    generate
        for (genvar i=0; i < OBufBank; i=i+1) begin
            if(i < OBufBank/2) begin
                assign oBufBankSel[i] = (rowWPtr[0] == 0);
            end else begin
                assign oBufBankSel[i] = (rowWPtr[0] == 1);
            end
        end
    endgenerate

    // * SBuf Addr
    generate
        for(genvar i=0; i<SBufBank/2; i=i+1) begin
            for(genvar j=0; j<2; j=j+1) begin 
                assign sBufAddr [j*SBufBank/2+i] = {colAPtr[$clog2(MAColLoop)-1:0], colWPtr[$clog2(MWColLoop)-1:1]};
            end
        end
    endgenerate

    // * SBuf Sel
    generate
        for (genvar i=0; i < SBufBank; i=i+1) begin
            if(i < SBufBank/2) begin
                assign sBufBankSel[i] = (rowWPtr[0] == 0);
            end else begin
                assign sBufBankSel[i] = (rowWPtr[0] == 1);
            end
        end
    endgenerate

endmodule