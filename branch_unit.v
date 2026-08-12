// =============================================================
// Module      : branch_unit
// Description : ID-stage branch resolution.
//
//               Branches are decided HERE (in ID), not in EX, so
//               that a taken branch only costs 1 flush cycle
//               (squash the just-fetched instruction in IF/ID)
//               instead of the 3 cycles a classic EX-stage-resolved
//               design would cost. This is the "advanced" hazard
//               choice we committed to at project start.
//
//               Comparator operands (rs_val, rt_val) MUST already be
//               forwarded by the caller (the ID-stage top module) --
//               this module does not itself forward; it only expects
//               post-forwarding-mux values on its inputs. Forwarding
//               INTO the ID-stage comparator (from EX/MEM and
//               MEM/WB, in addition to the usual EX-stage forwarding)
//               is what makes 1-cycle-flush branch resolution
//               correct; without it, a branch depending on a very
//               recently computed value would get a stale operand.
//
//               branch_type encoding (from control_unit.v):
//                 000 = beq   (rs == rt)
//                 001 = bne   (rs != rt)
//                 010 = blez  (rs <= 0, signed)
//                 011 = bgtz  (rs > 0, signed)
//                 100 = bltz  (rs < 0, signed)
//                 101 = bgez  (rs >= 0, signed)
//
//               Target address = pc_plus4_of_branch_instr +
//                                 (sign_extended_imm << 2)
//               (MIPS convention: branch offset is word-granular,
//               shifted left 2 to become a byte offset, and is
//               relative to the instruction AFTER the branch --
//               i.e. PC+4 of the branch itself, since this design
//               has no branch delay slot.)
// =============================================================

module branch_unit (
    input  wire [63:0] rs_val,       // post-forwarding
    input  wire [63:0] rt_val,       // post-forwarding
    input  wire [2:0]  branch_type,
    input  wire         branch_en,    // control_unit.branch signal
    input  wire [63:0] pc_plus4,
    input  wire [63:0] imm_sext,     // sign-extended 16-bit immediate (pre-shift)

    output wire         branch_taken,
    output wire [63:0]  branch_target
);

    wire signed [63:0] rs_signed = $signed(rs_val);

    reg taken;
    always @(*) begin
        case (branch_type)
            3'b000:  taken = (rs_val == rt_val);        // beq
            3'b001:  taken = (rs_val != rt_val);         // bne
            3'b010:  taken = (rs_signed <= 64'sd0);       // blez
            3'b011:  taken = (rs_signed >  64'sd0);       // bgtz
            3'b100:  taken = (rs_signed <  64'sd0);       // bltz
            3'b101:  taken = (rs_signed >= 64'sd0);       // bgez
            default: taken = 1'b0;
        endcase
    end

    assign branch_taken  = branch_en && taken;
    assign branch_target = pc_plus4 + (imm_sext << 2);

endmodule
