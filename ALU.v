`timescale 1ns / 1ps
//=============================================================
// Module : ALU
// Description : 32-bit MIPS ALU.
//
// Fixes applied :
//   1. Added 4'b1011 case for LUI (result = B << 16).
//   2. SLT now uses signed comparison ($signed).
//   3. zero flag drives directly from result.
//=============================================================

module ALU (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  control,
    output reg  [31:0] result,
    output wire        zero
);

always @(*) begin
    case (control)
        4'b0000: result = A & B;                                    // AND
        4'b0001: result = A | B;                                    // OR
        4'b0010: result = A + B;                                    // ADD
        4'b0110: result = A - B;                                    // SUB
        4'b0111: result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0; // SLT (signed)
        4'b0011: result = A ^ B;                                    // XOR
        4'b1100: result = ~(A | B);                                 // NOR
        4'b1000: result = B << A[4:0];                              // SLL
        4'b1001: result = B >> A[4:0];                              // SRL
        4'b1010: result = $signed(B) >>> A[4:0];                   // SRA
        4'b1011: result = {B[15:0], 16'b0};                        // LUI (B<<16)
        default: result = 32'b0;
    endcase
end

assign zero = (result == 32'b0);

endmodule
