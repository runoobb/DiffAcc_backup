// -------------------------------------------------------------------------
// Title       : The module of PEs
// File        : pe.sv
// -------------------------------------------------------------------------
// Description :
//
// -------------------------------------------------------------------------
// Revisions   :
//     Date         Version     Author      Description
//  14-Mar-2023      v0.1      Dongxu Lv     Build
// -------------------------------------------------------------------------
module PE 
import ComputeCommon::*;
(
    // general signal
     input clk
    ,input rst_n
    // input ports
    ,input Buffer_to_PE buf2pe 
    ,input OMEM_to_PE   omem2pe
    // output ports
    ,output PE_to_OMEM  pe2omem
);

    //-----------------------------------------------------
    // PE Multiplication
    //-----------------------------------------------------
    // variable definition
    logic     [PE_OPS    -1 : 0][2*Q_DW     -1 : 0] mul_out;
    typedef struct packed {
        logic [PE_OPS    -1 : 0][2*Q_DW            -1 : 0] reg_mul_out      ;
        logic                   [1                 -1 : 0] reg_in_valid     ;
        logic                   [$bits(PE_OUT_CH)  -1 : 0] reg_out_ch       ; // current output channel index
        logic                   [1                 -1 : 0] reg_in_ch_end    ; // whether this output channel ends or not 
        logic                   [1                 -1 : 0] reg_new_center_in; // whether a new center is imported or not
    } MulOutput_t;
    MulOutput_t mul_output_reg;
    // combinational logic
    generate
        for (genvar i = 0; i < PE_OPS; i=i+1) begin: PE_MUL
            assign mul_out[i] = buf2pe.ifmap[i] * buf2pe.weight[i];
        end
    endgenerate
    // sequential logic
    always_ff @(posedge clk or negedge rst_n ) begin : MUL_CTRL_FF
        if (!rst_n) begin 
            mul_output_reg.reg_in_valid      <= 'b0             ;
            mul_output_reg.reg_out_ch        <= 'b0             ;
            mul_output_reg.reg_in_ch_end     <= 'b0             ;
            mul_output_reg.reg_new_center_in <= 'b0             ;
        end
        else begin
            mul_output_reg.reg_in_valid      <= buf2pe.in_valid ;
            mul_output_reg.reg_out_ch        <= buf2pe.out_ch   ;
            mul_output_reg.reg_in_ch_end     <= buf2pe.in_ch_end;
            mul_output_reg.reg_new_center_in <= buf2pe.new_center_in;
        end
    end
    generate
        for (genvar j = 0; j < PE_OPS; j = j + 1) begin: PE_MUL_DATA_FF
            always_ff @ (posedge clk or negedge rst_n) begin: MUL_DATA_FF
                if (!rst_n) begin
                    mul_output_reg.reg_mul_out[j] <= 'b0                          ;
                end
                else if (buf2pe.in_valid == 1) begin
                    mul_output_reg.reg_mul_out[j] <= mul_out[j]                   ;
                end
                else begin
                    mul_output_reg.reg_mul_out[j] <= mul_output_reg.reg_mul_out[j];
                end
            end
        end
    endgenerate

    //-----------------------------------------------------
    // PE Adder Tree
    //-----------------------------------------------------
    // variable definition
    logic     [PE_OPS/2  -1 : 0][2*Q_DW+1          -1 : 0] add_level_1      ;
    logic     [PE_OPS/4  -1 : 0][2*Q_DW+2          -1 : 0] add_level_2      ;
    typedef struct packed {
        logic                   [2*Q_DW+2          -1 : 0] reg_add_out      ;
        logic                   [1                 -1 : 0] reg_in_valid     ;
        logic                   [$bits(PE_OUT_CH)  -1 : 0] reg_out_ch       ; // current output channel index
        logic                   [1                 -1 : 0] reg_in_ch_end    ; // whether this output channel ends or not 
        logic                   [1                 -1 : 0] reg_new_center_in; // whether a new center is imported or not
    } AdderOutput_t;
    AdderOutput_t adder_output_reg;
    // combinational logic
    generate
        for (genvar k = 0; k < PE_OPS/2; k=k+1) begin: ADDER_TREE_COMP_1
            assign add_level_1[k] = mul_output_reg.reg_mul_out[2*k] * mul_output_reg.reg_mul_out[2*k+1];
        end
        for (genvar k = 0; k < PE_OPS/4; k=k+1) begin: ADDER_TREE_COMP_2
            assign add_level_2[k] = add_level_1[2*k] * add_level_1[2*k+1];
        end
    endgenerate
    // sequential logic
    always_ff @(posedge clk or negedge rst_n ) begin : ADDER_TREE_CTRL_FF
        if (!rst_n) begin 
            adder_output_reg.reg_in_valid      <= 'b0                             ;
            adder_output_reg.reg_out_ch        <= 'b0                             ;
            adder_output_reg.reg_in_ch_end     <= 'b0                             ;
            adder_output_reg.reg_new_center_in <= 'b0                             ;
        end
        else begin
            adder_output_reg.reg_in_valid      <= mul_output_reg.reg_in_valid     ;
            adder_output_reg.reg_out_ch        <= mul_output_reg.reg_out_ch       ;
            adder_output_reg.reg_in_ch_end     <= mul_output_reg.reg_in_ch_end    ;
            adder_output_reg.reg_new_center_in <= mul_output_reg.reg_new_center_in;
        end
    end
    generate
        for (genvar i = 0; i < PE_OPS/4; i = i + 1) begin: ADDER_TREE_DATA_GEN
            always_ff @ (posedge clk or negedge rst_n) begin: ADDER_TREE_DATA_FF
                if (!rst_n) begin
                    adder_output_reg.reg_add_out[i] <= 'b0                            ;
                end
                else if (mul_output_reg.reg_in_valid == 1'b0) begin
                    adder_output_reg.reg_add_out[i] <= add_level_2[i]                 ;
                end
                else begin
                    adder_output_reg.reg_add_out[i] <= adder_output_reg.reg_add_out[i];
                end
            end
        end
    endgenerate

    //-----------------------------------------------------
    // PE Accumulator
    //-----------------------------------------------------
    // variable definition
    logic                       [2*Q_DW+$bits(PE_IN_CH)  -1 : 0] acc_local        ; // local accumulation: addertree + acc_reg
    logic                       [2*Q_DW+$bits(PE_IN_CH)  -1 : 0] acc_global       ; // global accumulation: acc_local + acc_omem
    logic                       [1                       -1 : 0] acc_out_valid    ;
    typedef struct packed {
        logic                   [$bits(PE_IN_CH)+2*Q_DW  -1 : 0] reg_acc          ;
        logic                   [1                       -1 : 0] reg_out_valid    ;
        logic                   [$bits(PE_OUT_CH)        -1 : 0] reg_out_ch       ; // current output channel index
    } AccReg_t;
    AccReg_t acc_reg;
    // combinational logic
    assign acc_local     = (adder_output_reg.reg_in_valid == 1'b1 && adder_output_reg.reg_new_center_in == 1'b1) ? 
                            adder_output_reg.reg_add_out : adder_output_reg.reg_add_out + acc_reg.reg_acc;
    assign acc_global    = (adder_output_reg.reg_in_valid == 1'b1 && omem2pe.acc_valid                  == 1'b1) ? 
                            acc_local + omem2pe.psum     : acc_local;
    assign acc_out_valid =  adder_output_reg.reg_in_ch_end == 1'b1 &&
                           (adder_output_reg.reg_in_valid  == 1'b1 || omem2pe.acc_valid == 1'b1);
    // sequential logic
    always_ff @(posedge clk or negedge rst_n ) begin : ACC_REG_FF
        if (!rst_n) begin 
            acc_reg.reg_acc                    <= 'b0                             ;
            acc_reg.reg_out_valid              <= 'b0                             ;
            acc_reg.reg_out_ch                 <= 'b0                             ;
        end
        else begin
            acc_reg.reg_acc                    <= acc_global                      ;
            acc_reg.reg_out_valid              <= acc_out_valid                   ;
            acc_reg.reg_out_ch                 <= adder_output_reg.reg_out_ch     ;
        end
    end

    //-----------------------------------------------------
    // Output
    //-----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n ) begin : OUTPUT_FF
        if (!rst_n) begin 
            pe2omem.ofmap                      <= 'b0                             ;
            pe2omem.out_ch                     <= 'b0                             ;
            pe2omem.out_valid                  <= 'b0                             ;
        end
        else if (acc_reg.reg_out_valid == 1'b1) begin
            pe2omem.ofmap                      <= acc_reg.reg_acc                 ; 
            pe2omem.out_ch                     <= acc_reg.reg_out_ch              ;
            pe2omem.out_valid                  <= acc_reg.reg_out_valid           ;
        end
        else begin
            pe2omem.ofmap                      <= pe2omem.ofmap                   ; 
            pe2omem.out_ch                     <= pe2omem.out_ch                  ;
            pe2omem.out_valid                  <= pe2omem.out_valid               ;
        end
    end

endmodule:PE