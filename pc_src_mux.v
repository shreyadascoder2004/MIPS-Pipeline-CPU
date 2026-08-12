// =============================================================
// Module      : pc_src_mux
// Description : Selects the next PC value.
//               Priority: jump_reg (jr/jalr) > jump (j/jal) >
//                         branch_taken > sequential (PC+4).
//               Priority ordering matters only in the theoretical
//               case where multiple sources are asserted at once,
//               which the control unit never actually produces
//               (an instruction is exactly one of: branch, jump,
//               jump_reg, or none) -- but a well-defined priority
//               is still correct defensive design.
// =============================================================

module pc_src_mux (
    input  wire [63:0] pc_plus4,
    input  wire [63:0] branch_target,
    input  wire [63:0] jump_target,     // covers both region-jump and jr/jalr
                                          // (jump_unit.v already resolves which)
    input  wire         branch_taken,
    input  wire         jump,            // j or jal
    input  wire         jump_reg,        // jr or jalr

    output reg  [63:0] pc_next
);

    always @(*) begin
        if (jump || jump_reg)
            pc_next = jump_target;
        else if (branch_taken)
            pc_next = branch_target;
        else
            pc_next = pc_plus4;
    end

endmodule
