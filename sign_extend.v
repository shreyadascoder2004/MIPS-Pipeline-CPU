// =============================================================
// Module      : sign_extend
// Description : Sign-extends a 16-bit immediate to 64 bits.
//
//               Two modes, selected by lui_mode:
//                 lui_mode = 0 : standard sign-extend
//                                out = {48{imm[15]}}, imm}
//                 lui_mode = 1 : LUI behavior -- imm is placed in
//                                bits [31:16], bits [15:0] = 0, then
//                                the resulting 32-bit value is
//                                sign-extended to 64 bits (bit 31
//                                replicated through [63:32]).
//                                This matches real MIPS64 lui
//                                semantics: result is always a
//                                sign-extended 32-bit value.
// =============================================================

module sign_extend (
    input  wire [15:0] imm_in,
    input  wire         lui_mode,
    output wire [63:0]  ext_out
);

    wire [31:0] lui_32 = {imm_in, 16'h0000};

    assign ext_out = lui_mode
                    ? {{32{lui_32[31]}}, lui_32}
                    : {{48{imm_in[15]}}, imm_in};

endmodule
