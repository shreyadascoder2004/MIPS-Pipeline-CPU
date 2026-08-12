// =============================================================
// Module      : zero_extend
// Description : Zero-extends a 16-bit immediate to 64 bits.
//               Used for andi, ori, xori (logical immediates use
//               zero-extension per MIPS convention, unlike
//               arithmetic immediates which sign-extend).
// =============================================================

module zero_extend (
    input  wire [15:0] imm_in,
    output wire [63:0]  ext_out
);

    assign ext_out = {48'h0, imm_in};

endmodule
