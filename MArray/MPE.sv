import Common::*;

module MPE #(
     parameter MPEDimm1 = 2
    ,parameter MPEDimm2 = 1
    ,parameter MPEDimm3 = 64
)(
     input logic clk
    ,input logic rst_n
    // high AFTER the last DATA is on port
    ,input logic inValid
    ,input logic [1:0] mode
    ,input logic [MPEDimm3-1:0][0:0][7:0] matrixAFirst
    ,input logic [MPEDimm3-1:0][MPEDimm1-1-1:0][3:0] matrixARest
    ,input logic [MPEDimm3-1:0][MPEDimm2-1:0][3:0] matrixB
    ,input logic [MPEDimm1-1:0][MPEDimm2-1:0][1:0][15:0] matrixScale
    ,input logic [MPEDimm1-1:0][MPEDimm2-1:0][15:0] matrixBias
    ,output logic [MPEDimm1-1:0][MPEDimm2-1:0][15:0] outMM
    ,output logic outValid
);

//AdderTree Output Length
localparam macShortWidth = 8 + 2 + $clog2(MPEDimm3);
localparam macLongWidth = 12 + 2 + $clog2(MPEDimm3);

//Shifter Output Length
localparam shiftShortWidth = macShortWidth + 8;
localparam shiftLongWidth = macLongWidth + 12;

//Pipe latency in MPE(if only pipe in acc, pipeLatency=0)
localparam pipeLatency = 1;
//Converter Input Length
wire [0:0][MPEDimm2-1:0][macLongWidth - 1 : 0] wireFirst;
wire [MPEDimm1-1-1:0][MPEDimm2-1:0][macShortWidth - 1 : 0] wireRest;

logic [0:0][MPEDimm2-1:0][shiftLongWidth - 1 : 0] shifterFirst;
logic [MPEDimm1-1-1:0][MPEDimm2-1:0][shiftShortWidth - 1 : 0] shifterRest;


generate
    for(genvar i=0; i<pipeLatency+2; i++) begin:Pipe
        logic inValidPipe;
        if(i==0) begin
            always_ff@(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    inValidPipe <= 0;
                else 
                    inValidPipe <= inValid;
            end
        end else begin
            always_ff@(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    inValidPipe <= 0;
                else
                    inValidPipe <= Pipe[i-1].inValidPipe;
            end
        end
    end
endgenerate
assign clear = Pipe[pipeLatency+2-1].inValidPipe;
assign outValid = Pipe[pipeLatency+1-1].inValidPipe;

// always_ff@(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         inValidDelay1 <= 0;
//     end else begin
//         inValidDelay1 <= inValid;
//     end
// end

// always_ff@(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         outValid <= 0;
//     end else begin
//         outValid <= inValidDelay1;
//     end
// end

// always_ff@(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         clear <= 0;
//     end else begin
//         clear <= outValid;
//     end
// end

MMM #(
     .MMDimm1(MPEDimm1)
    ,.MMDimm2(MPEDimm2)
    ,.MMDimm3(MPEDimm3)
    )mMM(
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .matrixAFirst(matrixAFirst),
    .matrixARest(matrixARest),
    .matrixB(matrixB),
    .matrixCFirst(wireFirst),
    .matrixCRest(wireRest)
);
// 1 pipe at the output of adder_tree

// MShifterFirst mShifterFirst(
//     .shiftIn(wireFirst),
//     .shiftOut(shifterFirst),
//     .mode(mode)
// );

// MShifterRest mShifterRest(
//     .shiftIn(wireRest),
//     .shiftOut(shifterRest),
//     .mode(mode)
// );

// ### MShifter ###
generate
for(genvar i = 0; i < 1; i++) begin
    for(genvar j = 0; j < MPEDimm2; j++) begin
        always_comb begin
            case(mode)
                2'b00:
                    shifterFirst[i][j] = {12'b0000_0000_0000, wireFirst[i][j]};
                2'b10:
                    shifterFirst[i][j] = {{4{wireFirst[i][j][macLongWidth - 1]}}, wireFirst[i][j], 8'b00000000};
                2'b01:
                    shifterFirst[i][j] = {{8{wireFirst[i][j][macLongWidth - 1]}}, wireFirst[i][j], 4'b0000};
                2'b11:
                    shifterFirst[i][j] = {wireFirst[i][j], 12'b000000000000};
            endcase
        end
    end
end
endgenerate

generate
for(genvar i = 0; i < MPEDimm1 - 1; i++) begin
    for(genvar j = 0; j < MPEDimm2; j++) begin
        always_comb begin
            case(mode)
                2'b00:
                    shifterRest[i][j] = {8'b0000_0000, wireRest[i][j]};
                2'b01:
                    shifterRest[i][j] = {{4{wireRest[i][j][macShortWidth-1]}}, wireRest[i][j], 4'b0000};
                2'b10:
                    shifterRest[i][j] = {{4{wireRest[i][j][macShortWidth-1]}}, wireRest[i][j], 4'b0000};
                2'b11:
                    shifterRest[i][j] = {wireRest[i][j], 8'b00000000};
            endcase
        end
    end
end
endgenerate

wire [MPEDimm1-1:0][MPEDimm2-1:0][15 : 0] fpMM;
reg  [MPEDimm1-1:0][MPEDimm2-1:0][15 : 0] fpMMReg;
wire [MPEDimm1-1:0][MPEDimm2-1:0][15 : 0] weightMM;
wire [MPEDimm1-1:0][MPEDimm2-1:0][15 : 0] outPartialMMWire;

// MConverterFirst mConverterFirst(
//     .clk(clk),
//     .rst_n(rst_n),
//     .intMM(shifterFirst),
//     .fpMM(fpMM[0])
// );

// MConverterRest mConverterRest(
//     .clk(clk),
//     .rst_n(rst_n),
//     .intMM(shifterRest),
//     .fpMM(fpMM[MPEDimm1-1 : 1])
// );

localparam sig_width = 10;
localparam exp_width = 5;
localparam isign = 1;

generate
    for(genvar i = 0; i < 1; i++) begin
        for(genvar j = 0; j < MPEDimm2; j++) begin
            DW_fp_i2flt #(sig_width, exp_width, shiftLongWidth, isign)
                U0(
                    .a(shifterFirst[i][j]),
                    .rnd(3'b000),
                    .z(fpMM[i][j])
                );
        end
    end
endgenerate

generate
    for(genvar i = 1; i < MPEDimm1; i++) begin
        for(genvar j = 0; j < MPEDimm2; j++) begin
            DW_fp_i2flt #(sig_width, exp_width, shiftShortWidth, isign)
                U1(
                    .a(shifterRest[i][j]),
                    .rnd(3'b000),
                    .z(fpMM[i][j])
                );
        end
    end
endgenerate

generate
    for(genvar i=0; i<MPEDimm1; i++)
        for(genvar j=0; j<MPEDimm2; j++)
            always_ff@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    fpMMReg[i][j] <= 0;
                end else begin
                    fpMMReg[i][j] <= fpMM[i][j];
                end
            end
endgenerate

MElementmul #(
     .EleRow(MPEDimm1)
    ,.EleCol(MPEDimm2)
    ) mElementmul(
    .clk(clk),
    .rst_n(rst_n),
    .inMM(fpMMReg),
    .scaleMM(matrixScale),
    .biasMM(matrixBias),
    .outPartialMM(outPartialMMWire)
);
// 1 pipe at output of elementmul

MAcc #(
     .AccRow(MPEDimm1)
    ,.AccCol(MPEDimm2)
    ) mAcc(
    .clk(clk),
    .rst_n(rst_n),
    .clear(clear),
    .addMM(outPartialMMWire),
    .outMM(outMM)
);
// 1 pipe at output of acc

endmodule
