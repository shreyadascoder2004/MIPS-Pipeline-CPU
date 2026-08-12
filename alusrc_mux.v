// =============================================================
// Module      : alusrc_mux
// Description : Selects the ALU's second operand: the (possibly
//               forwarded) register value, or the sign/zero-
//               extended immediate.
// =============================================================

module alusrc_mux (
    input  wire [63:0] reg_val,
    input  wire [63:0] imm_ext,
    input  wire          alu_src,   // 0 = reg_val, 1 = imm_ext
    output wire [63:0]  alu_operand_b
);

    assign alu_operand_b = alu_src ? imm_ext : reg_val;

endmodule
