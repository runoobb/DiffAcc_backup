import Common::*;

module MAcc #(
     parameter AccRow = 0
    ,parameter AccCol = 0
)
(clk, rst_n, clear, addMM, outMM);
localparam sig_width = 10;
localparam exp_width = 5;
localparam ieee_compliance = 0;

input logic clk;
input logic rst_n;
input logic clear;
input logic [AccRow-1:0][AccCol-1:0][15:0] addMM;
output logic [AccRow-1:0][AccCol-1:0][15:0] outMM;

// reg [15:0] accMM [AccRow][AccCol];
wire [AccRow-1:0][AccCol-1:0][15:0] sumMM;
wire [AccRow-1:0][AccCol-1:0][7:0] status;

generate 
    for(genvar i = 0; i < AccRow; i++) begin
        for(genvar j = 0; j < AccCol; j++) begin
            DW_fp_add #(sig_width, exp_width, ieee_compliance)
                U0(
                    .a(addMM[i][j]),
                    .b(outMM[i][j]),
                    .rnd(3'b000),
                    .z(sumMM[i][j]),
                    .status(status[i][j])
                );
            // assign sumMM[i][j] = addMM[i][j] + outMM[i][j];
        end
    end
endgenerate

generate 
    for(genvar i = 0; i < AccRow; i++) begin
        for(genvar j = 0; j < AccCol; j++) begin
            always_ff@(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    outMM[i][j] <= 16'b0;
                else
                    if(clear) begin
                        outMM[i][j] <= 16'b0;
                    end
                    else begin
                        outMM[i][j] <= sumMM[i][j];
                    end
            end
        end
    end
endgenerate


endmodule