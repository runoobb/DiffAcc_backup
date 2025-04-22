import Common::*;

module VArray (
    // clk & rst
     input logic clk     
    ,input logic rst_n   
    // interconnect
    ,VCtrl2VArray.ArraySide      vCtrlIf
    ,VArray2OBuffer.ArraySide    oBufIf
    ,VArray2VBuffer.ArraySide    vBufIf
    ,VArray2EBuffer.ArraySide    eBufIf
);

// TODO: @JRD, @CYZ

endmodule