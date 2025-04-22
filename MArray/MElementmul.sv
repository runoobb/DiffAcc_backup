import Common::*;

module MElementmul #(
     parameter EleRow = 0
    ,parameter EleCol = 0
)
(clk, rst_n, inMM, scaleMM, biasMM, outPartialMM);
localparam sig_width = 10;
localparam exp_width = 5;
localparam ieee_compliance = 1;

input logic clk;
input logic rst_n;
input logic [MPERow-1:0][MPECol-1:0][15:0] inMM;
input logic [MPERow-1:0][MPECol-1:0][1:0][15:0] scaleMM;
input logic [MPERow-1:0][MPECol-1:0][15:0] biasMM;
output logic [MPERow-1:0][MPECol-1:0][15:0] outPartialMM;

wire [MPERow-1:0][MPECol-1:0][7:0] statusMult;
wire [MPERow-1:0][MPECol-1:0][7:0] statusMac;
wire [MPERow-1:0][MPECol-1:0][15:0] flpMulOut;
logic [MPERow-1:0][MPECol-1:0][15:0] outPartialMMPipe;
logic [MPERow-1:0][MPECol-1:0][15:0] outPartialMMWire;

generate
    for(genvar i = 0; i < MPERow; i++) begin
        for(genvar j = 0; j < MPECol; j++) begin 
            always_ff@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    outPartialMMPipe[i][j] <= 16'b0;
                end
                else begin
                    outPartialMMPipe[i][j] <= flpMulOut[i][j];
                end
            end
        end
    end
endgenerate

generate
    for(genvar i = 0; i < MPERow; i++) begin
        for(genvar j = 0; j < MPECol; j++) begin 
            always_ff@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    outPartialMM[i][j] <= 16'b0;
                end
                else begin
                    outPartialMM[i][j] <= outPartialMMWire[i][j];
                end
            end
        end
    end
endgenerate

generate
for(genvar i = 0; i < MPERow; i++) begin
    for(genvar j = 0; j < MPECol; j++) begin: elementwise
        DW_fp_mult #(sig_width, exp_width, ieee_compliance)
            U1( .a(inMM[i][j]),
                .b(scaleMM[0][i][j]),
                .rnd(3'b000),
                .z(flpMulOut[i][j]),
                .status(statusMult[i][j])
                );
    end
end
endgenerate

generate
for(genvar i = 0; i < MPERow; i++) begin
    for(genvar j = 0; j < MPECol; j++) begin: elementwise
        // DW_fp_add #(sig_width, exp_width, ieee_compliance)
        //     U1( .a(outPartialMMPipe[i][j]),
        //         .b(biasMM[i][j]),
        //         .rnd(3'b000),
        //         .z(outPartialMMWire[i][j]),
        //         .status(statusAdd[i][j])
        //         );
        DW_fp_mac #(sig_width, exp_width, ieee_compliance) 
            U1 (
                .a(outPartialMMPipe[i][j]),
                .b(scaleMM[1][i][j]),
                .c(biasMM[i][j]),
                .rnd(3'b000),
                .z(outPartialMM[i][j]),
                .status(statusMac[i][j]) );
    end
end
endgenerate

endmodule


