`timescale 1ns / 1ps
//=============================================================
// Module : decode_execute  (ID/EX Pipeline Register)
// Description : Latches all Decode-stage data and control
//               signals for the Execute stage.
//               - flush : zeros all control signals (bubble).
//               - reset : zeros everything.
//
// Fix applied : Port names now use consistent camelCase to
//               match Top.v instantiation exactly.
//               MemReadD/E added to propagate read-enable.
//=============================================================

module decode_execute (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,       // inserts NOP bubble

    // ── Datapath inputs (from ID stage) ──────────────────────
    input  wire [31:0] RD1_D,
    input  wire [31:0] RD2_D,
    input  wire [4:0]  RsD,
    input  wire [4:0]  RtD,
    input  wire [4:0]  RdD,
    input  wire [31:0] SignImmD,

    // ── Control inputs (from ID stage) ───────────────────────
    input  wire        RegWriteD,
    input  wire        MemtoRegD,
    input  wire        MemWriteD,
    input  wire        MemReadD,
    input  wire        ALUSrcD,
    input  wire        RegDstD,
    input  wire        BranchD,
    input  wire        BranchNotEqualD,
    input  wire        JumpD,
    input  wire        jrD,
    input  wire [3:0]  ALUControlD,

    // ── Datapath outputs (to EX stage) ───────────────────────
    output reg  [31:0] RD1_E,
    output reg  [31:0] RD2_E,
    output reg  [4:0]  RsE,
    output reg  [4:0]  RtE,
    output reg  [4:0]  RdE,
    output reg  [31:0] SignImmE,

    // ── Control outputs (to EX stage) ────────────────────────
    output reg         RegWriteE,
    output reg         MemtoRegE,
    output reg         MemWriteE,
    output reg         MemReadE,
    output reg         ALUSrcE,
    output reg         RegDstE,
    output reg         BranchE,
    output reg         BranchNotEqualE,
    output reg         JumpE,
    output reg         jrE,
    output reg  [3:0]  ALUControlE
);

// Helper task: zero all control outputs (create bubble)
task flush_controls;
begin
    RegWriteE       <= 1'b0;
    MemtoRegE       <= 1'b0;
    MemWriteE       <= 1'b0;
    MemReadE        <= 1'b0;
    ALUSrcE         <= 1'b0;
    RegDstE         <= 1'b0;
    BranchE         <= 1'b0;
    BranchNotEqualE <= 1'b0;
    JumpE           <= 1'b0;
    jrE             <= 1'b0;
    ALUControlE     <= 4'b0000;
end
endtask

always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        // Zero everything
        RD1_E   <= 32'b0;
        RD2_E   <= 32'b0;
        RsE     <= 5'b0;
        RtE     <= 5'b0;
        RdE     <= 5'b0;
        SignImmE <= 32'b0;
        flush_controls;
    end

    else begin
        // Datapath always passes through (needed for forwarding logic)
        RD1_E    <= RD1_D;
        RD2_E    <= RD2_D;
        RsE      <= RsD;
        RtE      <= RtD;
        RdE      <= RdD;
        SignImmE <= SignImmD;

        if (flush)
            flush_controls;
        else begin
            RegWriteE       <= RegWriteD;
            MemtoRegE       <= MemtoRegD;
            MemWriteE       <= MemWriteD;
            MemReadE        <= MemReadD;
            ALUSrcE         <= ALUSrcD;
            RegDstE         <= RegDstD;
            BranchE         <= BranchD;
            BranchNotEqualE <= BranchNotEqualD;
            JumpE           <= JumpD;
            jrE             <= jrD;
            ALUControlE     <= ALUControlD;
        end
    end

end

endmodule
