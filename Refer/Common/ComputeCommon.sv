package ComputeCommon;

// ***** Data format ***** //
parameter Q_DW       = 8  ; // quantization data width

// ***** PE Array ***** //
// ***** PE parameters
parameter PE_OPS     = 4  ; // 4 multiplier
parameter PE_OUT_CH  = 256; // max output channel number 
parameter PE_IN_CH   = 256; // max input channel number 
// ***** PE Array parameters
parameter PE_NUM     = 16 ; // 16 PEs

// ***** PEA struct
typedef struct packed {
    // data
    logic                   [PE_OPS    -1 : 0][Q_DW                    -1 : 0] ifmap        ; // input data
    logic [PE_NUM    -1 : 0][PE_OPS    -1 : 0][Q_DW                    -1 : 0] weight       ; // input weight
    // ctrl     
    logic                                     [1                       -1 : 0] in_valid     ; // input valid
    logic                   [PE_NUM    -1 : 0][$bits(PE_OUT_CH)        -1 : 0] out_ch       ; // current output channel index
    logic                                     [1                       -1 : 0] in_ch_end    ; // whether this output channel ends or not 
    logic                                     [1                       -1 : 0] new_center_in; // whether a new center is imported or not 
} Buffer_to_PEA;

typedef struct packed {
    // data
    logic                   [PE_NUM    -1 : 0][Q_DW*2+$clog2(PE_OPS)   -1 : 0] ofmap        ; 
    // ctrl
    logic                                     [1                       -1 : 0] out_valid    ;
    logic                   [PE_NUM    -1 : 0][$bits(PE_OUT_CH)        -1 : 0] out_ch       ;
} PEA_to_OMEM;

typedef struct packed {
    // data
    logic                   [PE_NUM    -1 : 0][Q_DW*2+$clog2(PE_IN_CH) -1 : 0] psum         ;
    // ctrl
    logic                                     [1                       -1 : 0] acc_valid    ;
} OMEM_to_PEA;

// ***** PE struct
typedef struct packed {
    // data
    logic [PE_OPS    -1 : 0][Q_DW       -1 : 0] ifmap        ; // input data
    logic [PE_OPS    -1 : 0][Q_DW       -1 : 0] weight       ; // input weight
    // ctrl
    logic [1                            -1 : 0] in_valid     ; // input valid
    logic [$bits(PE_OUT_CH)             -1 : 0] out_ch       ; // current output channel index
    logic [1                            -1 : 0] in_ch_end    ; // whether this output channel ends or not 
    logic [1                            -1 : 0] new_center_in; // whether a new center is imported or not 
} Buffer_to_PE;

typedef struct packed {
    // data
    logic [Q_DW*2+$clog2(PE_OPS)        -1 : 0] ofmap    ; 
    // ctrl
    logic [1                            -1 : 0] out_valid;
    logic [$bits(PE_OUT_CH)             -1 : 0] out_ch   ;
} PE_to_OMEM;

typedef struct packed {
    // data
    logic [Q_DW*2+$clog2(PE_IN_CH)      -1 : 0] psum     ; 
    // ctrl
    logic [1                            -1 : 0] acc_valid;
} OMEM_to_PE;

endpackage

