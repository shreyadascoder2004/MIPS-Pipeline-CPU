// =============================================================
// Module      : jump_unit
// Description : ID-stage jump target computation.
//
//               j / jal: target = { pc_plus4[63:28], instr_index, 2'b00 }
//                 Standard MIPS "region jump": the top bits of the
//                 target come from the CURRENT program counter
//                 region (not the immediate), and the low bits come
//                 from the instruction's 26-bit index field,
//                 word-shifted. For this 64-bit-PC design we take
//                 all bits above [27:0] from pc_plus4 (extending the
//                 traditional MIPS32 4-bit-carryover convention to
//                 the full 64-bit address space) -- this means j/jal
//                 can jump anywhere within the current 256MB-aligned
//                 region (2^28 bytes), consistent with real MIPS's
//                 relative proportions.
//
//               jr / jalr: target = rs_val directly (register-
//                 sourced). rs_val MUST already be forwarded by the
//                 caller (same requirement as branch_unit.v) since
//                 jr commonly follows an immediately-preceding
//                 register computation (e.g. function return via
//                 $ra loaded a few instructions earlier, or a
//                 computed jump table address).
// =============================================================

module jump_unit (
    input  wire [63:0] pc_plus4,
    input  wire [25:0] instr_index,   // instr[25:0], the j/jal target field
    input  wire [63:0] rs_val,        // post-forwarding, for jr/jalr

    input  wire         jump,          // j or jal
    input  wire         jump_reg,      // jr or jalr

    output wire [63:0]  jump_target
);

    wire [63:0] region_jump_target = {pc_plus4[63:28], instr_index, 2'b00};

    assign jump_target = jump_reg ? rs_val : region_jump_target;

endmodule
