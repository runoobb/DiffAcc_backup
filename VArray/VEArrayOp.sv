import Common::*;

module VEArrayMaxReduce #(
     parameter ELTNUM = 4
    ,parameter ELTBIT = 16
    ,parameter PIPE   = 3'b111
) (
    // clk & rst
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic                           inValid
    ,input  logic [ELTNUM-1:0][ELTBIT-1:0]  inVec
    ,input  logic [ELTBIT-1:0]              inElt
    ,output logic                           outValid
    ,output logic [ELTBIT-1:0]              outElt
);
    // * local parameters
    localparam LAYER = $clog2(ELTNUM);    

    // * MaxReduce Tree
    generate
        for (genvar i = 0; i < LAYER; i = i+1) begin : tree
            localparam NODE_N = ELTNUM / (2**(i+1));
            logic [NODE_N-1:0][ELTBIT-1:0] node     ;
            logic [NODE_N-1:0][ELTBIT-1:0] nodeD    ;
            logic [ELTBIT-1:0]             maxNode  ;
            logic [ELTBIT-1:0]             maxNodeD ;
            logic                          valid    ;
            logic                          validD   ;
            // MaxReduce
            if (i == 0) begin
                for (genvar j = 0; j < NODE_N; j = j+1) begin
                    assign node[j] = (inVec[2*j] > inVec[2*j+1]) ? inVec[2*j] : inVec[2*j+1];
                end
                assign maxNode = inElt  ;
                assign valid   = inValid;
            end else begin
                for (genvar j = 0; j < NODE_N; j = j+1) begin
                    assign node[j] = (tree[i-1].nodeD[2*j] > tree[i-1].nodeD[2*j+1]) ? 
                                      tree[i-1].nodeD[2*j] : tree[i-1].nodeD[2*j+1];
                end
                assign maxNode = tree[i-1].maxNodeD ;
                assign valid   = tree[i-1].validD   ;
            end
            // pipe
            if (PIPE[i]) begin
                always_ff @( posedge clk or negedge rst_n ) begin
                    if (!rst_n) begin
                        nodeD    <= 0;
                        maxNodeD <= 0;
                        validD   <= 0;
                    end else begin
                        nodeD    <= node    ;
                        maxNodeD <= maxNode ;
                        validD   <= valid   ;
                    end
                end
            end else begin
                assign nodeD    = node    ;
                assign maxNodeD = maxNode ;
                assign validD   = valid   ;
            end
        end
    endgenerate

    // * Merge Gobalmax
    generate
        if (PIPE[LAYER]) begin
            always_ff @( posedge clk or negedge rst_n ) begin
                if (!rst_n) begin
                    outValid <= 0;
                    outElt   <= 0;
                end else begin
                    outValid <= tree[LAYER-1].validD;
                    outElt   <= (tree[LAYER-1].maxNodeD > tree[LAYER-1].nodeD) ?
                                 tree[LAYER-1].maxNodeD : tree[LAYER-1].nodeD;
                end
            end
        end else begin
            assign outValid = tree[LAYER-1].validD;
            assign outElt   = (tree[LAYER-1].maxNodeD > tree[LAYER-1].nodeD) ?
                               tree[LAYER-1].maxNodeD : tree[LAYER-1].nodeD;
        end
    endgenerate

endmodule

module VEArrayExpProd #(
    parameter ELTNUM = 4
   ,parameter ELTBIT = 16
) (
    // clk & rst
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic                           inValid
    ,input  logic                           inLast
    ,input  logic [ELTNUM-1:0][ELTBIT-1:0]  inPartSum
    ,input  logic [ELTNUM-1:0][ELTBIT-1:0]  inPartMax
    ,input  logic [ELTBIT-1:0]              inAllMax
    ,input  logic [ELTBIT-1:0]              inAllSum
    ,output logic                           outValid
    ,output logic [ELTBIT-1:0]              outAllSum
);
    // * local parameters
    localparam LAYER = $clog2(ELTNUM);

    // * ctrl logics
    logic allSumValid;
    logic lnAllSumValid;
    assign allSumValid = inValid & ~inLast;
    assign lnAllSumValid = inValid & inLast;

    // * Sub
    logic [ELTNUM-1:0][ELTBIT-1:0] aMaxSubPMax;
    VSub #(
         .PIPE      ( 1         )
        ,.ELTNUM    ( ELTNUM    )
    ) u_sub (
         .clk       ( clk                   )
        ,.rst_n     ( rst_n                 )
        ,.op1       ( inPartMax             )
        ,.op2       ( {ELTNUM{inAllMax}}    )
        ,.z         ( aMaxSubPMax           )
    );

    // * Exp: Exp(Mult)
    logic [ELTNUM-1:0][ELTBIT-1:0] expSub;
    VExp #(
        .ELTNUM     ( ELTNUM    )
    ) u_exp (
         .clk   ( clk           )
        ,.rst_n ( rst_n         )
        ,.op    ( aMaxSubPMax   )
        ,.z     ( expSub        )
    );
    
    // * Prod
    logic [ELTNUM-1:0][ELTBIT-1:0] partSumD;
    logic [ELTNUM-1:0][ELTBIT-1:0] prodExp;
    VDelay #(
         .VDelay    ( 6                 )
        ,.DATAW     ( $bits(partSumD)   )
    ) u_partSumDelay (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.inData    ( inPartSum )
        ,.outData   ( partSumD  )
    );
    VMult #(
         .PIPE      ( 1         )
        ,.ELTNUM    ( ELTNUM    )
    ) u_mult (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.op1       ( partSumD  )
        ,.op2       ( expSub    )
        ,.mult      ( prodExp   )
    );

    // * Sum
    logic [ELTBIT-1:0] inAllSumD;
    logic [ELTBIT-1:0] allSum   ;
    VDelay #(
         .VDelay    ( 7                 )
        ,.DATAW     ( $bits(inAllSumD)  )
    ) u_inAllSumDelay (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.inData    ( inAllSum  )
        ,.outData   ( inAllSumD )
    );
    VSum #(
         .ELTNUM    ( ELTNUM    )
    ) u_vSum (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.op        ( prodExp   )
        ,.psum      ( inAllSumD )
        ,.sum       ( allSum    )
    );

    // * Ln
    logic [ELTBIT-1:0] lnAllSum;
    VLn #(
        .ELTNUM     ( 1         )
    ) u_VLn (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.op        ( allSum    )
        ,.ln        ( lnAllSum  )
    );

    // * Ctrl
    logic allSumValidD;
    logic lnAllSumValidD;
    VDelay #(
         .PIPE      ( 9 )
        ,.DATAW     ( 1 )
    ) u_allsumvalid (
         .clk       ( clk           )
        ,.rst_n     ( rst_n         )
        ,.inData    ( allSumValid   )
        ,.outData   ( allSumValidD  )
    );
    VDelay #(
         .PIPE      ( 14 )
        ,.DATAW     ( 1  )
    ) u_lnallsumvalid (
         .clk       ( clk           )
        ,.rst_n     ( rst_n         )
        ,.inData    ( lnAllSumValid )
        ,.outData   ( lnAllSumValidD)
    );

    // * I/O
    assign outValid = allSumValidD & lnAllSumValidD;
    always_comb begin
        if (allSumValidD) begin
            outAllSum = allSum;
        end else if (lnAllSumValidD) begin
            outAllSum = lnAllSum;
        end else begin
            outAllSum = 0;
        end
    end

endmodule

module VEArrayMergeNorm #(
     parameter ELTNUM = 4
    ,parameter ELTBIT = 16
) (
    // clk $ rst
     input  logic clk
    ,input  logic rst_n
    // data
    ,input  logic                           inValid
    ,input  logic                           inLast
    ,input  logic [ELTNUM-1:0][ELTBIT-1:0]  inMu
    ,input  logic [ELTNUM-1:0][ELTBIT-1:0]  inSigma
    ,input  logic [ELTBIT-1:0]              invN
    ,input  logic [ELTBIT-1:0]              inAllMu
    ,input  logic [ELTBIT-1:0]              inAllSigma
    ,output logic                           outMuValid
    ,output logic [ELTBIT-1:0]              outAllMu
    ,output logic                           outSigValid
    ,output logic [ELTBIT-1:0]              outAllSigma
);

    // * Path
    // Mu-Sum(2) -> MuDivN(1) -> OutAllMu
    //                        -> Delay(1) -> Squre(1) ->
    // SigSquare(1) -> SigmaSum(3) -> Sigma-DivN(1)   -> Sigma-Sub(1) -> Sigma-Sqrt(4)

    // * internal logics
    logic [ELTBIT-1:0] allMu;
    logic [ELTBIT-1:0] allMuDivN;
    logic [ELTBIT-1:0] allMuDivND;
    logic [ELTBIT-1:0] allMuDivN2;
    logic [ELTBIT-1:0] allMuDivN2D;
    logic [ELTBIT-1:0] allMuDivN2D2;
    logic [ELTNUM-1:0][ELTBIT-1:0] muSquare;
    logic [ELTNUM-1:0][ELTBIT-1:0] sigmaD;
    logic [ELTBIT-1:0] inAllSigmaD;
    logic [ELTBIT-1:0] allSigma;
    logic [ELTBIT-1:0] allSigmaDivN;
    logic [ELTBIT-1:0] allSigmaDivND;
    logic [ELTBIT-1:0] allMuDivNSqure;
    logic [ELTBIT-1:0] allMuDivNSqureD;
    logic [ELTBIT-1:0] allSigmaDivNSub;
    logic [ELTBIT-1:0] allSigmaDivNSubSqrt;
    logic [ELTBIT-1:0] allSigmaDivNSubSqrtD;

    // * ctrl logics
    logic allMuValid;
    logic allMuDivNValid;
    logic allSigmaValid;
    logic allSigmaDivNSubvalid;
    assign allMuValid           = inValid & ~inLast ;
    assign allMuDivNValid       = inValid & inLast  ;
    assign allSigmaValid        = inValid & ~inLast ;
    assign allSigmaDivNSubvalid = inValid & inLast  ;

    // * Mu-Sum
    VSum #(
         .ELTNUM    ( ELTNUM    )
    ) u_vMuSum (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.op        ( inMu      )
        ,.psum      ( inAllMu   )
        ,.sum       ( allMu     )
    );

    // * Mu-DivN
    DW_fp_mult #(
        .sig_width         ( 10    )
       ,.exp_width         ( 5     )
       ,.ieee_compliance   ( 0     )
    ) u_muMult (
        .a     ( allMu      )
       ,.b     ( invN       )
       ,.rnd   ( 3'b0       )
       ,.z     ( allMuDivN  )
    );

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            allMuDivND <= 0;
        end else begin
            allMuDivND <= allMuDivN;
        end
    end

    // * Sigma-square
    VMult #(
         .PIPE      ( 1         )
        ,.ELTNUM    ( 2*ELTNUM  )
    ) u_vSigSquare (
         .clk       ( clk       )
        ,.rst_n     ( rst_n     )
        ,.op1       ( inMu      )
        ,.op2       ( inMu      )
        ,.mult      ( muSquare  )
    );

    // * Sigma-Sum
    VDelay # (
         .PIPE  ( 1                             )
        ,.DATAW ( $bits({inSigma, inAllSigma})  )
    ) u_SigmaSumAlign (
         .clk       ( clk                   )
        ,.rst_n     ( rst_n                 )
        ,.inData    ( {inSigma, inAllSigma} )
        ,.outData   ( {sigmaD, inAllSigmaD} )
    );

    VSum #(
         .ELTNUM    ( 2*ELTNUM  )
    ) u_vSigmaSum (
         .clk       ( clk                   )
        ,.rst_n     ( rst_n                 )
        ,.op        ( {muSquare, sigmaD}    )
        ,.psum      ( inAllSigmaD           )
        ,.sum       ( allSigma              )
    );

    // * Sigma-DivN
    DW_fp_mult #(
        .sig_width         ( 10    )
       ,.exp_width         ( 5     )
       ,.ieee_compliance   ( 0     )
    ) u_sigDivNMult (
        .a     ( allSigma       )
       ,.b     ( invN           )
       ,.rnd   ( 3'b0           )
       ,.z     ( allSigmaDivN   )
    );

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            allSigmaDivND <= 0;
        end else begin
            allSigmaDivND <= allSigmaDivN;
        end
    end

    // * Sigma-AllMuSqure
    VDelay # (
         .PIPE  ( 1                     )
        ,.DATAW ( $bits({allMuDivN2D})  )
    ) u_sigmaAllMuSqureAlign (
         .clk       ( clk           )
        ,.rst_n     ( rst_n         )
        ,.inData    ( allMuDivN2D   )
        ,.outData   ( allMuDivN2D2  )
    );

    DW_fp_mult #(
        .sig_width         ( 10    )
       ,.exp_width         ( 5     )
       ,.ieee_compliance   ( 0     )
    ) u_sigmaAllMuSqure (
        .a     ( allMuDivN2D2   )
       ,.b     ( allMuDivN2D2   )
       ,.rnd   ( 3'b0           )
       ,.z     ( allMuDivNSqure )
    );

    // * Sigma-Sub
    VDelay # (
         .PIPE  ( 1                     )
        ,.DATAW ( $bits(allMuDivNSqure) )
    ) u_sigmaSubAlign (
         .clk       ( clk               )
        ,.rst_n     ( rst_n             )
        ,.inData    ( allMuDivNSqure    )
        ,.outData   ( allMuDivNSqureD   )
    );

    VSub # (
         .PIPE      ( 1 )
        ,.ELTNUM    ( 1 )
    ) u_sigmaSub (
         .clk   ( clk               )
        ,.rst_n ( rst_n             )
        ,.op1   ( allSigmaDivND     )
        ,.op2   ( allMuDivNSqureD   )
        ,.sub   ( allSigmaDivNSub   )
    );

    // * Sigma-Sqrt
    DW_fp_sqrt # (
         .sig_width         ( 16    )
        ,.exp_width         ( 5     )
        ,.ieee_compliance   ( 0     )
    ) u_sigmaSqrt (
         .a     ( allSigmaDivNSub       )
        ,.rnd   ( 3'b0                  )
        ,.z     ( allSigmaDivNSubSqrt   )
    );

    VDelay # (
         .PIPE  ( 4                             )
        ,.DATAW ( $bits(allSigmaDivNSubSqrt)    )
    ) u_sigmaSqrtDelay (
         .clk       ( clk                   )
        ,.rst_n     ( rst_n                 )
        ,.inData    ( allSigmaDivNSubSqrt   )
        ,.outData   ( allSigmaDivNSubSqrtD  )
    );

    // * Ctrl
    logic allMuValidD;
    logic allMuDivNValidD;
    logic allSigmaValidD;
    logic allSigmaDivNSubvalidD;

    VDelay # (
         .PIPE  ( 2 )
        ,.DATAW ( 1 )
    ) u_allMuValidDelay (
         .clk       ( clk           )
        ,.rst_n     ( rst_n         )
        ,.inData    ( allMuValid    )
        ,.outData   ( allMuValidD   )

    );

    VDelay # (
         .PIPE  ( 3 )
        ,.DATAW ( 1 )
    ) u_allMuDivNValidDelay (
         .clk       ( clk               )
        ,.rst_n     ( rst_n             )
        ,.inData    ( allMuDivNValid    )
        ,.outData   ( allMuDivNValidD   )
    );

    VDelay # (
         .PIPE  ( 4 )
        ,.DATAW ( 1 )
    ) u_allSigmaValidDelay (
         .clk       ( clk               )
        ,.rst_n     ( rst_n             )
        ,.inData    ( allSigmaValid     )
        ,.outData   ( allSigmaValidD    )
    );

    VDelay # (
         .PIPE  ( 10    )
        ,.DATAW ( 1     )
    ) u_allSigmaDivNSubvalidDelay (
         .clk       ( clk                   )
        ,.rst_n     ( rst_n                 )
        ,.inData    ( allSigmaDivNSubvalid  )
        ,.outData   ( allSigmaDivNSubvalidD )
    );

    // * I/O
    assign outMuValid  = allMuValidD & allMuDivNValidD;
    assign outSigValid = allSigmaValidD & allSigmaDivNSubvalidD;

    always_comb begin
        if (allMuValidD) begin
            outAllMu = allMu;
        end else if (allMuDivNValidD) begin
            outAllMu = allMuDivND;
        end else begin
            outAllMu = 0;
        end
    end

    always_comb begin
        if (allSigmaValidD) begin
            outAllMu = allSigma;
        end else if (allSigmaDivNSubvalidD) begin
            outAllMu = allSigmaDivNSubSqrtD;
        end else begin
            outAllMu = 0;
        end
    end

endmodule