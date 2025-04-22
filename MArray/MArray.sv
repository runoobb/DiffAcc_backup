import Common::*;

module MArray (
    // clk & rst
     input logic clk     
    ,input logic rst_n   
    // interconnect
    ,MCtrl2MArray.ArraySide      mCtrlIf
    ,ABuffer2MArray.ArraySide    aBufIf 
    ,WBuffer2MArray.ArraySide    wBufIf 
    ,SBuffer2MArray.ArraySide    sBufIf 
    ,MArray2OBuffer.ArraySide    oBufIf 
);

// TODO: @WYK, @CYZ
// control signal: 
// input
// mCtrlIf.mValid
// mCtrlIf.mShift
// mCtrlIf.mOut
// output
// mCtrlIf.mFinish


// delay control signal
// delay1: Sync Addr to Data (1 cycle delay)
// delay2: 
logic mValidDelay1;
logic [1:0] mShiftDelay1;
// high when the last accumulate data is on port
logic mOutTileFinishDelay1;
// high after the last accumulate data is on port, pipe in MArray
logic mOutTileFinishDelay2;
// logic mOutTileFinishDelay2;

logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddrDelay1;
logic [OBufBank-1:0]                        oBufBankSelDelay1;
logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddrDelay2;
logic [OBufBank-1:0]                        oBufBankSelDelay2;
logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddrDelay3;
logic [OBufBank-1:0]                        oBufBankSelDelay3;
logic [OBufBank-1:0][$clog2(OBufDepth)-1:0] oBufAddrDelay4;
logic [OBufBank-1:0]                        oBufBankSelDelay4;
logic                                       valid            ;


always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        mValidDelay1 <= 0;
    else
        mValidDelay1 <= mCtrlIf.mValid;
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        mShiftDelay1 <= 0;
    else
        mShiftDelay1 <= mCtrlIf.mShift;
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        mOutTileFinishDelay1 <= 0;
    else
        mOutTileFinishDelay1 <= mCtrlIf.mOutTileFinish;
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        mOutTileFinishDelay2 <= 0;
    else
        mOutTileFinishDelay2 <= mOutTileFinishDelay1;
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        oBufBankSelDelay1 <= 0;
        oBufAddrDelay1 <= 0;
    end else begin
        oBufBankSelDelay1 <= mCtrlIf.oBufBankSel;
        oBufAddrDelay1 <= mCtrlIf.oBufAddr;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        oBufBankSelDelay2 <= 0;
        oBufAddrDelay2 <= 0;
    end else begin
        oBufBankSelDelay2 <= oBufBankSelDelay1;
        oBufAddrDelay2 <= oBufAddrDelay1;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        oBufBankSelDelay3 <= 0;
        oBufAddrDelay3 <= 0;
    end else begin
        oBufBankSelDelay3 <= oBufBankSelDelay2;
        oBufAddrDelay3 <= oBufAddrDelay2;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        oBufBankSelDelay4 <= 0;
        oBufAddrDelay4 <= 0;
    end else begin
        oBufBankSelDelay4 <= oBufBankSelDelay3;
        oBufAddrDelay4 <= oBufAddrDelay3;
    end
end
// {aOutlierShift[0], wOutlier} control mode
// shift matrixAFirst/matrixARest
// {0, 0} 
// cycle  0
// mShift 00
// shift  0/0

// {1, 0} 
// cycle  0 -> 1
// mShift 00-> 01
// shift  0/0  8/4

// {0, 1}
// cycle  0  -> 1
// mShift 00 -> 10
// shift  0/0   4/4

// {1, 1}
// cycle  0  -> 1  -> 2  -> 3
// mShift 00 -> 01 -> 10 -> 11
// shift  0/0   8/4   4/4   12/8
// mode   00    01    10    11

logic [MPEAcc-1:0][0:0][7:0] aBufDataFirst;
logic [MPEAcc-1:0][MPERow-1-1:0][3:0] aBufDataRest;
logic [MPEAcc-1:0][MPECol-1:0][3:0] wBufData;
logic [MPERow-1:0][MPECol-1:0][1:0][15:0] sBufData;
logic [MPERow-1:0][MPECol-1:0][15:0] oBufData;
logic [1:0] cnt;
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt <= 0;
    else if(valid)
        cnt <= cnt + 1;
    else
        cnt <= cnt;
end
// TODO: the order need fix
generate
    for(genvar i=0; i<MPEAcc; i++) begin
        assign {aBufDataFirst[i][0], aBufDataRest[i]} = aBufIf.rData[i];
    end

    for (genvar i=0; i<MPEAcc; i++) begin
        assign wBufData[i] = wBufIf.rData[i];
    end

    for (genvar i=0; i<MPERow; i++) begin
        assign sBufData[i] = sBufIf.rData[i];
    end

    for(genvar i=0; i<MPERow; i++) begin
        assign oBufIf.wData[i] = oBufData[i];  
    end
endgenerate

MPE #(
     .MPEDimm1(MPERow)
    ,.MPEDimm2(MPECol)
    ,.MPEDimm3(MPEAcc)
) u_MPE(
     .clk(clk)
    ,.rst_n(rst_n)
    ,.inValid(mOutTileFinishDelay2)
    ,.mode(mShiftDelay1)
    ,.matrixAFirst(aBufDataFirst)
    ,.matrixARest(aBufDataRest)
    ,.matrixB(wBufData)
    ,.matrixScale(sBufData)
    ,.outMM(oBufData)
    ,.outValid(valid)
);

assign oBufIf.wEn = oBufBankSelDelay4 & {OBufBank{valid}};
assign oBufIf.wAddr = oBufAddrDelay4;
assign mCtrlIf.mvWSync = ((cnt == 2'b11) & valid);

endmodule