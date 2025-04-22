module MMul(opA, opB, res, mode);
parameter opAWidth = 4;
parameter opBWidth = 4;
parameter resWidth = opAWidth + opBWidth + 2;
input logic [opAWidth - 1 : 0] opA;
input logic [opBWidth - 1 : 0] opB;
input logic [1:0] mode;
output logic [resWidth - 1 : 0] res;

//                 OPB/W OPA/A
//mode == 'b00 for UNT * UNT
//mode == 'b01 for UNT * INT
//mode == 'b10 for INT * UNT
//mode == 'b11 for INT * INT
logic extend_bitA;
logic extend_bitB;
assign extend_bitA = mode[0] & opA[opAWidth - 1];
assign extend_bitB = mode[1] & opB[opBWidth - 1];
assign res = signed'({extend_bitA, opA}) * signed'({extend_bitB, opB});

endmodule