`timescale 1ns / 1ps
//=============================================================
// Module : memory_writeback  (MEM/WB Pipeline Register)
// Description : Latches Memory-stage data and control signals
//               for the Write-Back stage.
//               - flushW : zeros control signals (bubble).
//               - reset  : zeros everything.
//
// Fix applied : flushW is now wired (was dangling in Top.v).
//               Port names unified with Top.v.
//=============================================================

module memory_writeback (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flushW,     // tie to 1'b0 if unused

    // ── Control inputs (from MEM stage) ──────────────────────
    input  wire        RegWriteM,
    input  wire        MemtoRegM,

    // ── Datapath inputs (from MEM stage) ─────────────────────
    input  wire [31:0] ALUResultM,
    input  wire [31:0] ReadDataM,
    input  wire [4:0]  WriteRegM,

    // ── Control outputs (to WB stage) ────────────────────────
    output reg         RegWriteW,
    output reg         MemtoRegW,

    // ── Datapath outputs (to WB stage) ───────────────────────
    output reg  [31:0] ALUResultW,
    output reg  [31:0] ReadDataW,
    output reg  [4:0]  WriteRegW
);

always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        RegWriteW  <= 1'b0;
        MemtoRegW  <= 1'b0;
        ALUResultW <= 32'b0;
        ReadDataW  <= 32'b0;
        WriteRegW  <= 5'b0;
    end

    else if (flushW) begin
        RegWriteW  <= 1'b0;
        MemtoRegW  <= 1'b0;
        ALUResultW <= 32'b0;
        ReadDataW  <= 32'b0;
        WriteRegW  <= 5'b0;
    end

    else begin
        RegWriteW  <= RegWriteM;
        MemtoRegW  <= MemtoRegM;
        ALUResultW <= ALUResultM;
        ReadDataW  <= ReadDataM;
        WriteRegW  <= WriteRegM;
    end

end

endmodule
