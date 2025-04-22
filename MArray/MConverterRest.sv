import Common::*;

module MConverterRest (clk, rst_n, intMM, fpMM);
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

input logic clk;
input logic rst_n;
// delete modeacc no need to add 3
input logic [MPERow-1-1:0][MPECol-1:0][shiftShortWidth-1 : 0] intMM;
output logic [MPERow-1-1:0][MPECol-1:0][15 : 0] fpMM;

wire [MPERow-1-1:0][MPECol-1:0][7:0] status;

generate
    for(genvar i = 0; i < MPERow-1; i++) begin
        for(genvar j = 0; j < MPECol; j++) begin
            DW_fp_i2flt #(sig_width, exp_width, shiftShortWidth, isign)
                U1(
                    .a(intMM[i][j]),
                    .rnd(3'b000),
                    .z(fpMM[i][j]),
                    .status(status[i][j])
                );
        end
    end
endgenerate

endmodule