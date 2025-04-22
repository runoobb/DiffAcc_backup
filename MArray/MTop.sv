import Common::*;

module MTop (
    // clk & rst
     input  logic clk
    ,input  logic rst_n
    // interconnect
    ,TopCtrl2MCtrl.MCtrlSide  topCtrlIf
    ,TopSync2MCtrl.MCtrlSide  topSyncIf
    ,MCtrl2ABuffer.MCtrlSide  aBufCtrlIf
    ,MCtrl2WBuffer.MCtrlSide  wBufCtrlIf
    ,MCtrl2SBuffer.MCtrlSide  sBufCtrlIf
    ,ABuffer2MArray.ArraySide aBufArrayIf
    ,WBuffer2MArray.ArraySide wBufArrayIf
    ,SBuffer2MArray.ArraySide sBufArrayIf
    ,MArray2OBuffer.ArraySide oBufArrayIf
);

    // * internal interface
    MCtrl2MArray mCtrl2MArray(clk);

    // * connect submodules
    MCtrl mCtrl (
         .clk       ( clk                       )
        ,.rst_n     ( rst_n                     )
        ,.topCtrlIf ( topCtrlIf                 )
        ,.topSyncIf ( topSyncIf                 )
        ,.aBufIf    ( aBufCtrlIf                )
        ,.wBufIf    ( wBufCtrlIf                )
        ,.mArrayIf  ( mCtrl2MArray              )
    );

    MArray mArray (
         .clk       ( clk                       )
        ,.rst_n     ( rst_n                     )
        ,.mCtrlIf   ( mCtrl2MArray              )
        ,.aBufIf    ( aBufArrayIf               )
        ,.wBufIf    ( wBufArrayIf               )
        ,.sBufIf    ( sBufArrayIf               )
        ,.oBufIf    ( oBufArrayIf               )
    );

endmodule