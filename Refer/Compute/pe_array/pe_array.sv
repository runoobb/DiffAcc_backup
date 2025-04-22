// -------------------------------------------------------------------------
// Title       : The module of PE Array
// File        : pe_array.sv
// -------------------------------------------------------------------------
// Description :
//
// -------------------------------------------------------------------------
// Revisions   :
//     Date         Version     Author      Description
//  15-Mar-2023      v0.1      Dongxu Lv     Build
// -------------------------------------------------------------------------
module PEArray 
import ComputeCommon::*;
(
    // general signal
     input               clk
    ,input               rst_n
    // input ports
    ,input Buffer_to_PEA buf2pea 
    ,input OMEM_to_PEA   omem2pea
    // output ports
    ,output PEA_to_OMEM  pea2omem
);

    //-----------------------------------------------------
    // Instantiate
    //-----------------------------------------------------
    Buffer_to_PE [PE_NUM -1 : 0] inst_buffer_to_pe;
    OMEM_to_PE   [PE_NUM -1 : 0] inst_omem_to_pe  ;
    PEA_to_OMEM  [PE_NUM -1 : 0] inst_pea_to_omem ;

    generate 
        // * signal connection
        for (genvar i = 0; i < PE_NUM; i = i + 1) begin: SIG_CONNECT
            // Buffer_to_PE
            assign inst_buffer_to_pe[i].ifmap         = buf2pea.ifmap                ;
            assign inst_buffer_to_pe[i].in_ch_end     = buf2pea.in_ch_end            ;
            assign inst_buffer_to_pe[i].in_valid      = buf2pea.in_valid             ;
            assign inst_buffer_to_pe[i].new_center_in = buf2pea.new_center_in        ;
            assign inst_buffer_to_pe[i].out_ch        = buf2pea.out_ch[i]            ;
            assign inst_buffer_to_pe[i].weight        = buf2pea.weight[i]            ;
            // OMEM_to_PE
            assign inst_omem_to_pe[i].acc_valid       = omem2pea.acc_valid           ;
            assign inst_omem_to_pe[i].psum            = omem2pea.psum[i]             ;
            // PEA_to_OMEM
            assign pea2omem.ofmap[i]                  = inst_pea_to_omem[i].ofmap    ;
            assign pea2omem.out_ch[i]                 = inst_pea_to_omem[i].out_ch   ;
            assign pea2omem.out_valid                 = inst_pea_to_omem[i].out_valid;
        end
        
        // * instantiate module
        for (genvar i = 0; i < PE_NUM; i = i + 1) begin: INST_GEN
            PE u_pe (
                 .clk    (clk                 )
                ,.rst_n  (rst_n               )
                ,.buf2pe (inst_buffer_to_pe[i]) 
                ,.omem2pe(inst_omem_to_pe[i]  )
                ,.pe2omem(inst_pea_to_omem[i] )
            );
        end
    endgenerate 

endmodule