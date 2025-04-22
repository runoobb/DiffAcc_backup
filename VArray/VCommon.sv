import Common::*;

module VDelay # (
    parameter DELAY = 1,
    parameter DATAW = 8
) (
    // clk & rst
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic [DATAW-1:0] inData
    ,output logic [DATAW-1:0] outData
);
    
    // * Generate Delay Chain
    generate
        for (genvar i = 0; i < DELAY; i = i+1) begin : chain
            logic [DATAW-1:0] node;
            if (i == 0) begin
                always_ff @( posedge clk or negedge rst_n ) begin
                    if (!rst_n) begin
                        node <= 0;
                    end else begin
                        node <= inData;
                    end
                end
            end else begin
                always_ff @( posedge clk or negedge rst_n ) begin
                    if (!rst_n) begin
                        node <= 0;
                    end else begin
                        node <= chain[i-1].node;
                    end
                end
            end
        end
    endgenerate

    // * I/O
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            outData <= 0;
        end else begin
            outData <= chain[DELAY-1].node;
        end
    end

endmodule

module VSub # (
    parameter PIPE   = 1,
    parameter ELTNUM = 8
) (
    // clk & rst_n
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic [ELTNUM-1:0][16-1:0] op1
    ,input  logic [ELTNUM-1:0][16-1:0] op2
    ,output logic [ELTNUM-1:0][16-1:0] sub
);

    // * internal logics
    logic [ELTNUM-1:0][16-1:0] sub_w;

    // * Generate Vector Sub
    for (genvar i = 0; i < ELTNUM; i = i+1) begin : VecSub
        DW_fp_sub #(
             .sig_width( 16 )
            ,.exp_width( 5  )
        ) u_sub (
             .a     ( op1[i]    )
            ,.b     ( op2[i]    )
            ,.rnd   ( 3'b000    )
            ,.z     ( sub_w[i]  )
        );
    end

    // * I/O
    generate
        if (PIPE) begin
            always_ff @( posedge clk or negedge rst_n ) begin : blockName
                if (!rst_n) begin
                    sub <= 0;
                end else begin
                    sub <= sub_w;
                end
            end
        end else begin
            assign sub = sub_w;
        end
    endgenerate
    
endmodule

module VMult # (
     parameter PIPE   = 1
    ,parameter ELTNUM = 8
) (
    // clk & rst_n
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic [ELTNUM-1:0][16-1:0] op1
    ,output logic [ELTNUM-1:0][16-1:0] op2
    ,output logic [ELTNUM-1:0][16-1:0] mult
);

    // * internal logics
    logic [ELTNUM-1:0][16-1:0] mult_w;

    // * Generate Vector Sub
    for (genvar i = 0; i < ELTNUM; i = i+1) begin : VecSub
        DW_fp_mult #(
             .sig_width         ( 10 )
            ,.exp_width         ( 5  )
            ,.ieee_compliance   ( 0  )
        ) u_mult (
             .a     ( op1[i]    )
            ,.b     ( op2[i]    )
            ,.rnd   ( 3'b000    )
            ,.z     ( mult_w[i] )
        );
    end

    // * I/O
    generate
        if (PIPE) begin
            always_ff @( posedge clk or negedge rst_n ) begin : blockName
                if (!rst_n) begin
                    mult <= 0;
                end else begin
                    mult <= mult_w;
                end
            end
        end else begin
            assign mult = mult_w;
        end
    endgenerate

endmodule

module VExp # (
    parameter ELTNUM = 8
) (
    // clk & rst_n
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic [ELTNUM-1:0][16-1:0] op
    ,output logic [ELTNUM-1:0][16-1:0] exp
);

    // * internal logics
    logic [ELTNUM-1:0][16-1:0] multInvLn2;
    logic [ELTNUM-1:0][16-1:0] multInvLn2D;
    logic [ELTNUM-1:0][16-1:0] exp2multInvLn2;

    // * mult
    generate
        for (genvar i = 0; i < ELTNUM; i = i+1) begin
            // datapath
            DW_fp_mult #(
                 .sig_width         ( 10    )
                ,.exp_width         ( 5     )
                ,.ieee_compliance   ( 0     )
            ) u_mult (
                 .a     ( op[i]                 )
                ,.b     ( 16'b0011110111000101  )
                ,.rnd   ( 3'b0                  )
                ,.z     ( multInvLn2[i]         )
            );
            // pipe
            VDelay #(
                 .DELAY ( 1                     )
                ,.DATAW ( $bits(multInvLn2[i])  )
            ) u_multDelay (
                 .inData    ( multInvLn2[i] )
                ,.outData   ( multInvLn2D[i])
            );
        end
    endgenerate

    // * exp
    generate
        for (genvar i = 0; i < ELTNUM; i = i+1) begin
            // datapath
            DW_fp_exp2 #(
                .sig_width      ( 10    ), 
                .exp_width      ( 5     ), 
                .ieee_compliance( 0     ),
                .arch           ( 1     )
            ) U1 (
                .a  ( multInvLn2D[i]    ),
                .z  ( exp2multInvLn2[i] )
            );
            // pipe
            VDelay #(
                 .DELAY ( 4                         )
                ,.DATAW ( $bits(exp2multInvLn2[i])  )
            ) u_expDelay (
                 .inData    ( exp2multInvLn2[i] )
                ,.outData   ( exp[i]            )
            );
        end
    endgenerate

endmodule

module VSum # (
    parameter ELTNUM = 8
) (
    // clk & rst_n
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic [ELTNUM-1:0][16-1:0]  op
    ,input  logic [16-1:0]              psum
    ,output logic [16-1:0]              sum
);

    // * local parameters
    localparam C2ELTNUM = 2 ** $clog2(ELTNUM)           ;
    localparam N4LAYER  = $floor($clog2(C2ELTNUM) / 2)  ;
    localparam N2LAYER  = $clog2(C2ELTNUM) % 2          ;

    // * internal logics
    logic [16-1:0] sum_w;

    // * Fill Void Nodes
    logic [C2ELTNUM-1:0][16-1:0] c2Op;
    generate
        for (genvar i = 0; i < C2ELTNUM; i = i+1) begin
            if (i < ELTNUM) begin
                assign c2Op[i] = op[i];
            end else begin
                assign c2Op[i] = 0;
            end
        end
    endgenerate

    // * N4 AdderTree
    generate
        for (genvar i = 0; i < N4LAYER; i = i+1) begin : n4Tree
            localparam NODE_N = C2ELTNUM / (4**(i+1));
            logic [NODE_N-1:0][16-1:0] node ;
            logic [NODE_N-1:0][16-1:0] nodeD;
            // Sum4
            if (i == 0) begin
                for (genvar j = 0; j < NODE_N; j = j+1) begin
                    DW_fp_sum4 #(
                        .sig_width         ( 10    ) 
                       ,.exp_width         ( 5     ) 
                       ,.ieee_compliance   ( 0     ) 
                       ,.arch_type         ( 1     )
                   ) u_sum4 (
                        .a     ( c2Op[4*j+0]    )
                       ,.b     ( c2Op[4*j+1]    )
                       ,.c     ( c2Op[4*j+2]    )
                       ,.d     ( c2Op[4*j+3]    )
                       ,.rnd   ( 3'b0           )
                       ,.z     ( node[j]        )
                   ); 
                end
            end else begin
                for (genvar j = 0; j < NODE_N; j = j+1) begin
                    DW_fp_sum4 #(
                        .sig_width         ( 10    ) 
                       ,.exp_width         ( 5     ) 
                       ,.ieee_compliance   ( 0     ) 
                       ,.arch_type         ( 1     )
                   ) u_sum4 (
                        .a     ( n4Tree[i-1].nodeD[4*j+0]   )
                       ,.b     ( n4Tree[i-1].nodeD[4*j+1]   )
                       ,.c     ( n4Tree[i-1].nodeD[4*j+2]   )
                       ,.d     ( n4Tree[i-1].nodeD[4*j+3]   )
                       ,.rnd   ( 3'b0                       )
                       ,.z     ( node[j]                    )
                   ); 
                end
            end
            // pipe
            always_ff @( posedge clk or negedge rst_n ) begin
                if (~rst_n) begin
                    nodeD <= 0;
                end else begin
                    nodeD <= node;
                end
            end
        end
    endgenerate

    // * N2 AdderTree & add psum
    generate
        if (N2LAYER == 0) begin : N2E0
            // add
            DW_fp_add # (
                 .sig_width         ( 10    )
                ,.exp_width         ( 5     )
                ,.ieee_compliance   ( 0     )
            ) u_add (
                 .a     ( psum                      )
                ,.b     ( n4Tree[N4LAYER-1].nodeD   )
                ,.rnd   ( 3'b0                      )
                ,.z     ( sum_w                     )
            );
        end else begin : N2G0
            // tree
            for (genvar i = 0; i < N2LAYER; i = i+1) begin : n2Tree
                localparam NODE_N = C2ELTNUM / (4**N4LAYER) / (2**(i+1));
                logic [NODE_N-1:0][ELTBIT-1:0] node     ;
                logic [NODE_N-1:0][ELTBIT-1:0] nodeD    ;
                if ((i == 0) & (i == (N2LAYER-1))) begin
                    // sum
                    DW_fp_sum3 # (
                         .sig_width         ( 10    )
                        ,.exp_width         ( 5     )
                        ,.ieee_compliance   ( 0     )
                        ,.arch_type         ( 1     )
                    ) u_sum3 (
                         .a     ( psum                          )
                        ,.b     ( n4Tree[N4LAYER-1].nodeD[0]    )
                        ,.c     ( n4Tree[N4LAYER-1].nodeD[1]    )
                        ,.rnd   ( 3'b000                        )
                        ,.z     ( node                          )
                    );
                    // dummy delay
                    assign nodeD = node;
                    assign sum_w = nodeD;
                end else if (i == 0) begin
                    // sum
                    for (genvar j = 0; j < NODE_N; j = j+1) begin
                        DW_fp_add # (
                            .sig_width         ( 10    )
                           ,.exp_width         ( 5     )
                           ,.ieee_compliance   ( 0     )
                        ) u_add (
                            .a     ( n4Tree[N4LAYER-1].nodeD[2*j+0] )
                           ,.b     ( n4Tree[N4LAYER-1].nodeD[2*j+1] )
                           ,.rnd   ( 3'b0                           )
                           ,.z     ( node[j]                        )
                        );
                    end
                    // delay
                    always_ff @( posedge clk or negedge rst_n ) begin
                        if (~rst_n) begin
                            nodeD <= 0;
                        end else begin
                            nodeD <= node;
                        end
                    end
                end else if (i == (N2LAYER-1)) begin
                    // sum
                    DW_fp_sum3 # (
                         .sig_width         ( 10    )
                        ,.exp_width         ( 5     )
                        ,.ieee_compliance   ( 0     )
                        ,.arch_type         ( 1     )
                    ) u_sum3 (
                         .a     ( psum                      )
                        ,.b     ( N2G0.n2Tree[i-1].nodeD[0] )
                        ,.c     ( N2G0.n2Tree[i-1].nodeD[1] )
                        ,.rnd   ( 3'b000                    )
                        ,.z     ( node                      )
                    );
                    // dummy delay
                    assign nodeD = node;
                    assign sum_w = nodeD;
                end else begin
                    // sum
                    for (genvar j = 0; j < NODE_N; j = j+1) begin
                        DW_fp_add # (
                            .sig_width         ( 10    )
                           ,.exp_width         ( 5     )
                           ,.ieee_compliance   ( 0     )
                        ) u_add (
                            .a     ( N2G0.n2Tree[i-1].nodeD[2*j+0]  )
                           ,.b     ( N2G0.n2Tree[i-1].nodeD[2*j+1]  )
                           ,.rnd   ( 3'b0                           )
                           ,.z     ( node[j]                        )
                        );
                    end
                    // delay
                    always_ff @( posedge clk or negedge rst_n ) begin
                        if (~rst_n) begin
                            nodeD <= 0;
                        end else begin
                            nodeD <= node;
                        end
                    end
                end
            end
        end
    endgenerate

    // I/O
    always_ff @( posedge clk or negedge rst_n ) begin
        if (~rst_n) begin
            sum <= 0;
        end else begin
            sum <= sum_w;
        end
    end
endmodule

module VLn # (
    parameter ELTNUM = 8
) (
    // clk & rst_n
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic [ELTNUM-1:0][16-1:0] op
    ,output logic [ELTNUM-1:0][16-1:0] ln
);

    // * internal logics
    logic [ELTNUM-1:0][16-1:0] multInvLog2e;
    logic [ELTNUM-1:0][16-1:0] multInvLog2eD;
    logic [ELTNUM-1:0][16-1:0] Ln2multInvLog2e;

    // * mult
    generate
        for (genvar i = 0; i < ELTNUM; i = i+1) begin
            // datapath
            DW_fp_mult #(
                 .sig_width         ( 10    )
                ,.exp_width         ( 5     )
                ,.ieee_compliance   ( 0     )
            ) u_mult (
                 .a     ( op[i]                 )
                ,.b     ( 16'b0011110111000101  )
                ,.rnd   ( 3'b0                  )
                ,.z     ( multInvLog2e[i]       )
            );
            // pipe
            VDelay #(
                 .DELAY ( 1                     )
                ,.DATAW ( $bits(multInvLog2e[i]))
            ) u_multDelay (
                 .inData    ( multInvLog2e[i]   )
                ,.outData   ( multInvLog2eD[i]  )
            );
        end
    endgenerate

    // * exp
    generate
        for (genvar i = 0; i < ELTNUM; i = i+1) begin
            // datapath
            DW_fp_log2 #(
                 .sig_width         ( 10)
                ,.exp_width         ( 5 ) 
                ,.ieee_compliance   ( 0 )
                ,.extra_prec        ( 0 )
                ,.arch              ( 1 )
            ) U1 (
                .a  ( multInvLog2eD[i]      ),
                .z  ( Ln2multInvLog2e[i]    )
            );
            // pipe
            VDelay #(
                 .DELAY ( 4                         )
                ,.DATAW ( $bits(Ln2multInvLog2e[i]) )
            ) u_lnDelay (
                 .inData    ( Ln2multInvLog2e[i] )
                ,.outData   ( ln[i]              )
            );
        end
    endgenerate

endmodule

module VOneHotMux # (
     parameter ELTNUM = 8
    ,parameter ELTBIT = 16
) (
     input  logic [ELTNUM-1:0][ELTBIT-1:0] inData
    ,input  logic [ELTNUM-1:0]             oneHot
    ,output logic [ELTBIT-1:0]             outData
);

    // * internal logics
    logic [ELTNUM-1:0][ELTBIT-1:0] mask;
    logic [ELTNUM-1:0][ELTBIT-1:0] maskData;

    // * Mux
    generate
        for (genvar i = 0; i < ELTNUM; i = i+1) begin
            assign mask[i] = {ELTBIT{oneHot[i]}};
            assign maskData[i] = mask[i] & inData[i];
        end
    endgenerate

    generate
        for (genvar i = 0; i < ELTBIT; i = i+1) begin
            logic [ELTNUM-1:0] gatherBits;
            for (genvar j = 0; j < ELTNUM; j = j+1) begin
                assign gatherBits[j] = maskData[j][i];
            end
            assign outData[i] = | gatherBits;
        end
    endgenerate

endmodule