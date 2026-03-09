`timescale 1ns / 1ps
//=============================================================
// Module : forward_unit
// Description : Resolves RAW data hazards by selecting the
//               most up-to-date value for ALU inputs (EX) and
//               the branch comparator (ID).
//
// Forwarding priority (newest first):
//   EX inputs  : MEM (2'b10) > WB (2'b01) > register (2'b00)
//   ID branch  : MEM (1) > WB (1 on separate bit) > register
//
// Fix applied : forwardAD / forwardBD now also check WB stage,
//               eliminating a class of branch stalls.
//               Added forwardAD_wb / forwardBD_wb outputs so
//               Top.v can mux WB result into comparator too.
//=============================================================

module forward_unit (
    // ID-stage source registers (for branch comparator)
    input  wire [4:0] RsD,
    input  wire [4:0] RtD,

    // EX-stage source registers (for ALU)
    input  wire [4:0] RsE,
    input  wire [4:0] RtE,

    // MEM-stage write-back info
    input  wire [4:0] WriteRegM,
    input  wire       RegWriteM,

    // WB-stage write-back info
    input  wire [4:0] WriteRegW,
    input  wire       RegWriteW,

    // ── EX-stage forwarding (3-way mux select) ───────────────
    output reg  [1:0] ForwardAE,    // 00=reg, 01=WB, 10=MEM
    output reg  [1:0] ForwardBE,

    // ── ID-stage forwarding (for branch comparator) ───────────
    // forwardXD_mem : forward MEM ALU result
    // forwardXD_wb  : forward WB result
    output reg        ForwardAD_mem,
    output reg        ForwardBD_mem,
    output reg        ForwardAD_wb,
    output reg        ForwardBD_wb
);

//─────────────────────────────────────────────────────────────
// EX stage: 3-way forwarding (MEM has priority over WB)
//─────────────────────────────────────────────────────────────
always @(*) begin

    // Default: use register file value
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;

    // Forward to ALU input A
    if (RegWriteM && (WriteRegM != 5'b0) && (WriteRegM == RsE))
        ForwardAE = 2'b10;          // from MEM
    else if (RegWriteW && (WriteRegW != 5'b0) && (WriteRegW == RsE))
        ForwardAE = 2'b01;          // from WB

    // Forward to ALU input B
    if (RegWriteM && (WriteRegM != 5'b0) && (WriteRegM == RtE))
        ForwardBE = 2'b10;          // from MEM
    else if (RegWriteW && (WriteRegW != 5'b0) && (WriteRegW == RtE))
        ForwardBE = 2'b01;          // from WB

end

//─────────────────────────────────────────────────────────────
// ID stage: forwarding for branch comparator
// Only MEM and WB can forward here (EX result not yet ready).
//─────────────────────────────────────────────────────────────
always @(*) begin

    ForwardAD_mem = 1'b0;
    ForwardBD_mem = 1'b0;
    ForwardAD_wb  = 1'b0;
    ForwardBD_wb  = 1'b0;

    // MEM → comparator A
    if (RegWriteM && (WriteRegM != 5'b0) && (WriteRegM == RsD))
        ForwardAD_mem = 1'b1;
    // WB  → comparator A (only if MEM not already forwarding)
    else if (RegWriteW && (WriteRegW != 5'b0) && (WriteRegW == RsD))
        ForwardAD_wb = 1'b1;

    // MEM → comparator B
    if (RegWriteM && (WriteRegM != 5'b0) && (WriteRegM == RtD))
        ForwardBD_mem = 1'b1;
    // WB  → comparator B
    else if (RegWriteW && (WriteRegW != 5'b0) && (WriteRegW == RtD))
        ForwardBD_wb = 1'b1;

end

endmodule
