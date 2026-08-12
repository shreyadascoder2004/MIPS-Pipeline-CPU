// =============================================================
// Module      : alu
// Description : 64-bit ALU for EX stage.
//
//               width32 = 1 selects "32-bit mode": the ALU computes
//               on operand_a[31:0]/operand_b[31:0] and the 32-bit
//               result is SIGN-EXTENDED to 64 bits on output. This
//               implements the MIPS64 convention where 32-bit
//               instructions (add, sub, addi, sll, lw address calc,
//               etc.) always produce a sign-extended-to-64 result.
//
//               Logical ops (AND/OR/XOR/NOR) and compares
//               (SLT/SLTU) are WIDTH-AGNOSTIC: they always operate
//               on the full 64-bit operands regardless of width32.
//               This matches real MIPS64 semantics and the note
//               left in control_unit.v -- width32 simply doesn't
//               apply to these ops, it is ignored for them.
//
//               alu_ctrl encoding (defined here, consumed by
//               alu_control.v which must produce these exact codes):
//                 00000 = ADD
//                 00001 = SUB
//                 00010 = AND
//                 00011 = OR
//                 00100 = XOR
//                 00101 = NOR
//                 00110 = SLT  (signed)
//                 00111 = SLTU (unsigned)
//                 01000 = SLL  (shift amt = shamt_in)
//                 01001 = SRL
//                 01010 = SRA
//                 01011 = LUI_PASS (operand_b passed through, already
//                          shifted+extended by sign_extend.v upstream)
//                 01100 = PASS_A (used for jr/jalr target passthrough
//                          if ever routed through ALU; currently jr
//                          bypasses ALU entirely in our datapath, kept
//                          for completeness/future use)
// =============================================================

module alu (
    input  wire [63:0] operand_a,
    input  wire [63:0] operand_b,
    input  wire [4:0]  alu_ctrl,
    input  wire         width32,     // 1 = 32-bit op, sign-extend result
    input  wire [5:0]   shamt_in,    // shift amount (5b for 32-bit shifts, 6b for 64-bit)

    output reg  [63:0]  result,
    output wire          zero,
    output reg           overflow
);

    localparam ALU_ADD      = 5'b00000;
    localparam ALU_SUB      = 5'b00001;
    localparam ALU_AND      = 5'b00010;
    localparam ALU_OR       = 5'b00011;
    localparam ALU_XOR      = 5'b00100;
    localparam ALU_NOR      = 5'b00101;
    localparam ALU_SLT      = 5'b00110;
    localparam ALU_SLTU     = 5'b00111;
    localparam ALU_SLL      = 5'b01000;
    localparam ALU_SRL      = 5'b01001;
    localparam ALU_SRA      = 5'b01010;
    localparam ALU_LUI_PASS = 5'b01011;
    localparam ALU_PASS_A   = 5'b01100;

    // ---- 32-bit-mode operand slicing (for arithmetic/shift ops only) ----
    wire [31:0] a32 = operand_a[31:0];
    wire [31:0] b32 = operand_b[31:0];

    wire [31:0] add32 = a32 + b32;
    wire [31:0] sub32 = a32 - b32;
    wire [63:0] add64 = operand_a + operand_b;
    wire [63:0] sub64 = operand_a - operand_b;

    // ---- overflow detection (signed add/sub, both widths) ----
    wire ovf_add32 = (a32[31] == b32[31]) && (add32[31] != a32[31]);
    wire ovf_sub32 = (a32[31] != b32[31]) && (sub32[31] != a32[31]);
    wire ovf_add64 = (operand_a[63] == operand_b[63]) && (add64[63] != operand_a[63]);
    wire ovf_sub64 = (operand_a[63] != operand_b[63]) && (sub64[63] != operand_a[63]);

    // ---- shift amount resolution ----
    wire [5:0] shamt64 = shamt_in;             // full 6 bits for 64-bit shifts
    wire [4:0] shamt32 = shamt_in[4:0];        // low 5 bits for 32-bit shifts

    always @(*) begin
        result   = 64'h0;
        overflow = 1'b0;

        case (alu_ctrl)

            ALU_ADD: begin
                if (width32) begin
                    result   = {{32{add32[31]}}, add32};
                    overflow = ovf_add32;
                end else begin
                    result   = add64;
                    overflow = ovf_add64;
                end
            end

            ALU_SUB: begin
                if (width32) begin
                    result   = {{32{sub32[31]}}, sub32};
                    overflow = ovf_sub32;
                end else begin
                    result   = sub64;
                    overflow = ovf_sub64;
                end
            end

            // Logical + compare ops: WIDTH-AGNOSTIC, always full 64-bit.
            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_NOR:  result = ~(operand_a | operand_b);
            ALU_SLT:  result = ($signed(operand_a) < $signed(operand_b)) ? 64'h1 : 64'h0;
            ALU_SLTU: result = (operand_a < operand_b) ? 64'h1 : 64'h0;

            ALU_SLL: begin: sll_blk
                reg [31:0] shifted32;
                if (width32) begin
                    shifted32 = b32 << shamt32;
                    result = {{32{shifted32[31]}}, shifted32};
                end else begin
                    result = operand_b << shamt64;
                end
            end

            ALU_SRL: begin: srl_blk
                reg [31:0] shifted32;
                if (width32) begin
                    shifted32 = b32 >> shamt32;
                    result = {{32{shifted32[31]}}, shifted32};
                end else begin
                    result = operand_b >> shamt64;
                end
            end

            ALU_SRA: begin: sra_blk
                reg signed [31:0] shifted32;
                if (width32) begin
                    shifted32 = $signed(b32) >>> shamt32;
                    result = {{32{shifted32[31]}}, shifted32};
                end else begin
                    result = $signed(operand_b) >>> shamt64;
                end
            end

            ALU_LUI_PASS: result = operand_b;
            ALU_PASS_A:   result = operand_a;

            default: result = 64'h0;

        endcase
    end

    assign zero = (result == 64'h0);

endmodule
