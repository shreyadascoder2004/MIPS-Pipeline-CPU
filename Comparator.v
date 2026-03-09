`timescale 1ns / 1ps
//=============================================================
// Module : comparator
// Description : 32-bit equality comparator for branch
//               resolution in the ID stage.
//               Used for both BEQ (equal=1) and BNE (equal=0).
//=============================================================

module comparator (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        equal
);

assign equal = (a == b);

endmodule
