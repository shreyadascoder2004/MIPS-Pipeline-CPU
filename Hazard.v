`timescale 1ns / 1ps
//=============================================================
// Module : hazard_unit
// Description : Detects load-use, branch-data, and control
//               hazards; generates stall and flush signals.
//
// Hazards handled:
//   1. Load-use  : LW followed immediately by dependent instr.
//                  → stall PC + IF/ID, flush ID/EX (1 bubble)
//   2. Branch data hazard (EX-stage result needed by branch):
//                  → stall PC + IF/ID (1 cycle)
//   3. Branch data hazard (MEM-stage load needed by branch):
//                  → stall PC + IF/ID (1 cycle)
//   4. Control   : branch or jump resolved in ID
//                  → flush IF/ID (1 cycle penalty)
//=============================================================

module hazard_unit (
    // ── ID-stage source registers ─────────────────────────────
    input  wire [4:0] RsD,
    input  wire [4:0] RtD,

    // ── EX-stage info ─────────────────────────────────────────
    input  wire [4:0] RtE,          // EX destination (for load-use)
    input  wire [4:0] WriteRegE,    // resolved write register in EX
    input  wire       MemtoRegE,    // EX instruction is a load
    input  wire       RegWriteE,

    // ── MEM-stage info ────────────────────────────────────────
    input  wire [4:0] WriteRegM,
    input  wire       MemtoRegM,    // MEM instruction is a load

    // ── Branch / jump flags (from ID) ─────────────────────────
    input  wire       BranchD,
    input  wire       BranchNotEqualD,
    input  wire       JumpD,

    // ── Hazard control outputs ────────────────────────────────
    output reg        StallF,       // freeze PC
    output reg        StallD,       // freeze IF/ID register
    output reg        FlushD,       // flush IF/ID (NOP)
    output reg        FlushE        // flush ID/EX (NOP)
);

wire w_branchOrJump = BranchD | BranchNotEqualD | JumpD;

always @(*) begin

    // Safe defaults
    StallF = 1'b0;
    StallD = 1'b0;
    FlushD = 1'b0;
    FlushE = 1'b0;

    //─────────────────────────────────────────────────────────
    // 1. Load-use hazard
    //    LW  Rt, ...         <- EX stage (MemtoRegE=1)
    //    OP  Rs/Rt, Rt, ...  <- ID stage
    //─────────────────────────────────────────────────────────
    if (MemtoRegE && ((RtE == RsD) || (RtE == RtD))) begin
        StallF = 1'b1;
        StallD = 1'b1;
        FlushE = 1'b1;  // inject bubble into EX
    end

    //─────────────────────────────────────────────────────────
    // 2. Branch data hazard
    //    An instruction one cycle before branch (in EX) or
    //    a load two cycles before branch (in MEM) writes a
    //    register that the branch comparator reads.
    //    Forwarding from WB covers the 2-cycle non-load case,
    //    so only EX writes and MEM loads need a stall.
    //─────────────────────────────────────────────────────────
    else if (w_branchOrJump) begin
        if ((RegWriteE && ((WriteRegE == RsD) || (WriteRegE == RtD))) ||
            (MemtoRegM && ((WriteRegM == RsD) || (WriteRegM == RtD)))) begin
            StallF = 1'b1;
            StallD = 1'b1;
            // FlushE not needed here — the stall holds the branch
            // in ID so it can re-compare next cycle with forwarded data
        end
    end

    //─────────────────────────────────────────────────────────
    // 3. Control hazard — flush the incorrectly fetched instr
    //    Branch/jump is resolved in ID; one instruction was
    //    already fetched speculatively — discard it.
    //─────────────────────────────────────────────────────────
    if (w_branchOrJump && !StallF) begin
        // Only flush when we are NOT stalling (stall means the
        // branch itself hasn't resolved yet, flush comes next cycle)
        FlushD = 1'b1;
    end

end

endmodule
