import Common::*;

module MShifterFirst(shiftIn, mode, shiftOut);
localparam macShortWidth = 8 + 2 + $clog2(MPEAcc);
localparam macLongWidth = 12 + 2 + $clog2(MPEAcc);
localparam shiftShortWidth = macShortWidth + 8;
localparam shiftLongWidth = macLongWidth + 12;

input logic [0:0][MPECol-1:0][macLongWidth - 1 : 0] shiftIn;
input logic [1:0] mode;
output logic [0:0][MPECol-1:0][shiftLongWidth - 1 : 0] shiftOut;

generate
for(genvar i = 0; i < 1; i++) begin
    for(genvar j = 0; j < MPECol; j++) begin
        always_comb begin
            case(mode)
                2'b00:
                    shiftOut[i][j] = {12'b0000_0000_0000, shiftIn[i][j]};
                2'b10:
                    shiftOut[i][j] = {{4{shiftIn[i][j][macLongWidth - 1]}}, shiftIn[i][j], 8'b00000000};
                2'b01:
                    shiftOut[i][j] = {{8{shiftIn[i][j][macLongWidth - 1]}}, shiftIn[i][j], 4'b0000};
                2'b11:
                    shiftOut[i][j] = {shiftIn[i][j], 12'b000000000000};
            endcase
        end
    end
end
endgenerate

endmodule

module MShifterRest(shiftIn, mode, shiftOut);
localparam macShortWidth = 10 + $clog2(MPEAcc);
localparam macLongWidth = 14 + $clog2(MPEAcc);
localparam shiftShortWidth = macShortWidth + 8;
localparam shiftLongWidth = macLongWidth + 12;

input logic [MPERow-1-1:0][MPECol-1:0][macShortWidth - 1 : 0] shiftIn;
input logic [1:0] mode;
output logic [MPERow-1-1:0][MPECol-1:0][shiftShortWidth - 1 : 0] shiftOut;

generate
for(genvar i = 0; i < MPERow - 1; i++) begin
    for(genvar j = 0; j < MPECol; j++) begin
        always_comb begin
            case(mode)
                2'b00:
                    shiftOut[i][j] = {8'b0000_0000, shiftIn[i][j]};
                2'b01:
                    shiftOut[i][j] = {{4{shiftIn[i][j][macShortWidth-1]}}, shiftIn[i][j], 4'b0000};
                2'b10:
                    shiftOut[i][j] = {{4{shiftIn[i][j][macShortWidth-1]}}, shiftIn[i][j], 4'b0000};
                2'b11:
                    shiftOut[i][j] = {shiftIn[i][j], 8'b00000000};
            endcase
        end
    end
end
endgenerate
endmodule
