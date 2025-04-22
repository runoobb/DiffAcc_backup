import Common::*;

module MConverterFirst (clk, rst_n, intMM, fpMM);

localparam sig_width = 10;
localparam exp_width = 5;
localparam isize = 32;
localparam isign = 1;


//AdderTree Output Length
localparam macShortWidth = 8 + 2 + $clog2(MPEAcc);
localparam macLongWidth = 12 + 2 + $clog2(MPEAcc);

//Shifter Output Length
localparam shiftShortWidth = macShortWidth + 8;
localparam shiftLongWidth = macLongWidth + 12;

//Converter Input Length
//shiftShortWidth + 3
//shiftLongWidth + 3

input logic clk;
input logic rst_n;
// input logic [shiftLongWidth + 3 - 1 : 0] intMM [1][MPECol];
// delete modeacc no need to add 3
input logic [0:0][MPECol-1:0][shiftLongWidth-1 : 0] intMM;
output logic [0:0][MPECol-1:0][15 : 0] fpMM;

wire [0:0][MPECol-1:0][7:0] status;
 
generate
    for(genvar i = 0; i < 1; i++) begin
        for(genvar j = 0; j < MPECol; j++) begin
            DW_fp_i2flt #(sig_width, exp_width, shiftLongWidth, isign)
                U0(
                    .a(intMM[i][j]),
                    .rnd(3'b000),
                    .z(fpMM[i][j]),
                    .status(status[i][j])
                );
        end
    end
endgenerate

endmodule

