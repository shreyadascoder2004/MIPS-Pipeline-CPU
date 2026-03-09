`timescale 1ns / 1ps
//=============================================================
// Module : execute_mem  (EX/MEM Pipeline Register)
// Description : Latches Execute-stage results and control
//               signals for the Memory stage.
//               - flushM : zeros all control signals (bubble).
//               - reset  : zeros everything.
//=============================================================

module execute_mem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flushM,      // bubble injection

    // ── Control inputs (from EX stage) ───────────────────────
    input  wire        RegWriteE,
    input  wire        MemtoRegE,
    input  wire        MemWriteE,
    input  wire        MemReadE,
    input  wire        BranchE,
    input  wire        BranchNotEqualE,
    input  wire        JumpE,
    input  wire        jrE,

    // ── Datapath inputs (from EX stage) ──────────────────────
    input  wire [31:0] ALUResultE,
    input  wire [31:0] WriteDataE,  // Rt value (for SW)
    input  wire [4:0]  WriteRegE,   // destination register

    // ── Control outputs (to MEM stage) ───────────────────────
    output reg         RegWriteM,
    output reg         MemtoRegM,
    output reg         MemWriteM,
    output reg         MemReadM,
    output reg         BranchM,
    output reg         BranchNotEqualM,
    output reg         JumpM,
    output reg         jrM,

    // ── Datapath outputs (to MEM stage) ──────────────────────
    output reg  [31:0] ALUResultM,
    output reg  [31:0] WriteDataM,
    output reg  [4:0]  WriteRegM
);

always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        RegWriteM       <= 1'b0;
        MemtoRegM       <= 1'b0;
        MemWriteM       <= 1'b0;
        MemReadM        <= 1'b0;
        BranchM         <= 1'b0;
        BranchNotEqualM <= 1'b0;
        JumpM           <= 1'b0;
        jrM             <= 1'b0;
        ALUResultM      <= 32'b0;
        WriteDataM      <= 32'b0;
        WriteRegM       <= 5'b0;
    end

    else begin
        // Datapath always passes through
        ALUResultM <= ALUResultE;
        WriteDataM <= WriteDataE;
        WriteRegM  <= WriteRegE;

        if (flushM) begin
            RegWriteM       <= 1'b0;
            MemtoRegM       <= 1'b0;
            MemWriteM       <= 1'b0;
            MemReadM        <= 1'b0;
            BranchM         <= 1'b0;
            BranchNotEqualM <= 1'b0;
            JumpM           <= 1'b0;
            jrM             <= 1'b0;
        end
        else begin
            RegWriteM       <= RegWriteE;
            MemtoRegM       <= MemtoRegE;
            MemWriteM       <= MemWriteE;
            MemReadM        <= MemReadE;
            BranchM         <= BranchE;
            BranchNotEqualM <= BranchNotEqualE;
            JumpM           <= JumpE;
            jrM             <= jrE;
        end
    end

end

endmodule
