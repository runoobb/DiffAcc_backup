import Common::*;

module MMM #(
     parameter MMDimm1 = 0
    ,parameter MMDimm2 = 0
    ,parameter MMDimm3 = 0
)(clk, rst_n, mode, matrixAFirst, matrixARest, matrixB, matrixCFirst, matrixCRest);
// precision: matrixA[0] -> INT16/INT8, matrixA[1 : 7] -> INT8/INT4
localparam macShortWidth = 10 + $clog2(MMDimm3);
localparam macLongWidth = 14 + $clog2(MMDimm3);
input logic [MMDimm3-1:0][0:0][7:0] matrixAFirst;
input logic [MMDimm3-1:0][MMDimm1-1-1:0][3:0] matrixARest;
// precision: matrixB -> INT8/INT4
input logic [MMDimm3-1:0][MMDimm2-1:0][3:0] matrixB;
input logic clk;
input logic rst_n;
input logic [1:0] mode;
output logic  [0:0][MMDimm2-1:0][macLongWidth - 1 : 0] matrixCFirst;
output logic  [MMDimm1-1-1:0][MMDimm2-1:0][macShortWidth - 1 : 0] matrixCRest;

// logic reset_d1;
// logic reset_d2;

// always_ff @(posedge clk) begin
//     reset_d1 <= reset;
//     reset_d2 <= reset_d1;
// end


wire [MMDimm1-1-1:0][MMDimm2-1:0][MMDimm3-1:0][7 + 2 : 0] mulResShort;
wire [0:0][MMDimm2-1:0][MMDimm3-1:0][11 + 2 : 0] mulResLong;


// wire [macLongWidth - 1 : 0] matrixCFirst [1][MMDimm2];
// wire [macShortWidth - 1 : 0] matrixCRest [MMDimm1 - 1][MMDimm2];

 genvar i;
 genvar j;
 genvar k;

generate

        for (i = 0; i < MMDimm1 - 1; i++) begin
            for (j = 0; j < MMDimm2; j++) begin
                for (k = 0; k < MMDimm3; k++) begin : multipliersShort
                    MMul #(
                        .opAWidth(4),
                        .opBWidth(4)
                    ) mMulShort (
                        .opA(matrixARest[k][i]),
                        .opB(matrixB[k][j]),
                        .mode(mode),
                        .res(mulResShort[i][j][k])
                    );
                end
           end
       end

        for (i = 0; i < 1; i++) begin
            for (j = 0; j < MMDimm2; j++) begin
                for (k = 0; k < MMDimm3; k++) begin : multipliersLong
                    MMul #(
                        .opAWidth(8),
                        .opBWidth(4)
                    ) mMulLong(
                        .opA(matrixAFirst[k][i]),
                        .opB(matrixB[k][j]),
                        .mode(mode),
                        .res(mulResLong[i][j][k])
                    );
                end
           end
       end     

    for (i = 0; i < MMDimm1 - 1; i++) begin
        for(j = 0; j < MMDimm2; j++) begin: adderTreeShort
            MAdderTree #(
                .DATA_WIDTH(10),
                .LENGTH(MMDimm3)
            ) MAdderTreeShort(
                .clk(clk),
                .rst_n(rst_n),
                .x(mulResShort[i][j]),
                .y(matrixCRest[i][j])
            );
            // UnsignedAdderTreePipelined #(
            //     .DATA_WIDTH(10),
            //     .LENGTH(MMDimm3),
            //     .DELAY_STAGES($clog2(MMDimm3))
            // )U0_tree_short(
            //     .clk(clk),
            //     .rst_n(rst_n),
            //     .in_addends(mulResShort[i][j][0 : MMDimm3-1]),
            //     .out_sum(matrixCRest[i][j])
            // );
        end
    end

    for (i = 0; i < 1; i++) begin
        for(j = 0; j < MMDimm2; j++) begin: adderTreeLong
            MAdderTree #(
                .DATA_WIDTH(14),
                .LENGTH(MMDimm3)
            ) MAdderTreeLong(
                .clk(clk),
                .rst_n(rst_n),
                .x(mulResLong[i][j]),
                .y(matrixCFirst[i][j])
            );
            // UnsignedAdderTreePipelined #(
            //     .DATA_WIDTH(14),
            //     .LENGTH(MMDimm3),
            //     .DELAY_STAGES($clog2(MMDimm3))
            // )U0_tree_long(
            //     .clk(clk),
            //     .rst_n(rst_n),
            //     .in_addends(mulResLong[i][j][0 : MMDimm3-1]),
            //     .out_sum(matrixCFirst[i][j])
            // );
        end
    end

endgenerate



endmodule

