import Common::*;

module TopSync (
    // clk & rst
     input logic clk
    ,input logic rst_n
    // interconnect
    ,TopSync2MCtrl.TopCtrlSide mCtrlIf
    ,TopSync2VCtrl.TopCtrlSide vCtrlIf
    ,TopSync2VECtrl.TopCtrlSide veCtrlIf
);
    // * mvSync
    logic [$clog2(OBufCol)-1:0] mvWPtr;
    logic [$clog2(OBufCol)-1:0] mvRPtr;

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            mvWPtr <= 0;
        end else if (mCtrlIf.mvWSync) begin
            mvWPtr <= mvWPtr + MPECol;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            mvRPtr <= 0;
        end else if (vCtrlIf.mvRSync) begin
            mvRPtr <= mvRPtr + 1;
        end
    end

    assign vCtrlIf.mvEmpty = (mvWPtr == mvRPtr);

    // * veSync
    logic [$clog2(OBufCol)-1:0] veWPtr;
    logic [$clog2(OBufCol)-1:0] veRPtr;

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            veWPtr <= 0;
        end else if (vCtrlIf.veWSync) begin
            veWPtr <= veWPtr + 1;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            veRPtr <= 0;
        end else if (veCtrlIf.veRSync) begin
            veRPtr <= veRPtr + 1;
        end
    end

    assign vCtrlIf.veEmpty = (veWPtr == veRPtr);

    // * evSync
    logic [$clog2(OBufCol)-1:0] evWPtr;
    logic [$clog2(OBufCol)-1:0] evRPtr;

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            evWPtr <= 0;
        end else if (veCtrlIf.evWSync) begin
            evWPtr <= evWPtr + 1;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            evRPtr <= 0;
        end else if (vCtrlIf.evRSync) begin
            evRPtr <= evRPtr + 1;
        end
    end

    assign vCtrlIf.evEmpty = (evWPtr == evRPtr);

endmodule