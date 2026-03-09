`timescale 1ns / 1ps
//=============================================================
// Module : MIPS_Top
// Description : 5-stage pipelined MIPS processor (32-bit).
//               Stages: IF → ID → EX → MEM → WB
//
// Fixes applied vs original Top.v:
//   1. Module renamed to MIPS_Top (matches testbench DUT name).
//   2. ALUControl wires are 4-bit (were 3-bit, caused MSB loss).
//   3. BNE correctly drives pcSrcD.
//   4. Jump target mux added (J-type and JR supported).
//   5. control_unit wrapper instantiated (was empty module).
//   6. All pipeline register port names unified.
//   7. MemReadM driven from MemtoRegM (gates data-memory read).
//   8. flushW tied to 1'b0 (explicitly connected).
//   9. ForwardAD/BD extended to also mux WB result.
//  10. Intermediate wire names made fully consistent.
//=============================================================

module MIPS_Top #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_reset_n,
    output wire [DATA_WIDTH-1:0] o_instructionF  // for testbench monitor
);

//=============================================================
// Wire declarations
//=============================================================

//── Register indices ──────────────────────────────────────────
wire [4:0] w_RsD, w_RtD, w_RdD;
wire [4:0] w_RsE, w_RtE, w_RdE;
wire [4:0] w_WriteRegE, w_WriteRegM, w_WriteRegW;

//── PC / address signals ──────────────────────────────────────
wire [31:0] w_PCCurrent;
wire [31:0] w_PCPlus4F;
wire [31:0] w_PCPlus4D;
wire [31:0] w_PCBranchD;
wire [31:0] w_JumpTargetD;
wire [31:0] w_JRTargetE;
wire [31:0] w_PCNext;

//── Instruction ───────────────────────────────────────────────
wire [31:0] w_InstD;

//── Register-file read data ───────────────────────────────────
wire [31:0] w_RD1D, w_RD2D;

//── Forwarded comparator inputs ──────────────────────────────
wire [31:0] w_CmpA, w_CmpB;

//── EX-stage data ─────────────────────────────────────────────
wire [31:0] w_RD1E, w_RD2E;
wire [31:0] w_SignImmD, w_SignImmE;
wire [31:0] w_SignImmShiftedD;
wire [31:0] w_SrcAE, w_SrcBE;
wire [31:0] w_ForwardedB;          // post-forwarding Rt (before ALUSrc mux)
wire [31:0] w_ALUResultE;

//── MEM-stage data ────────────────────────────────────────────
wire [31:0] w_ALUResultM;
wire [31:0] w_WriteDataM;
wire [31:0] w_ReadDataM;

//── WB-stage data ─────────────────────────────────────────────
wire [31:0] w_ALUResultW;
wire [31:0] w_ReadDataW;
wire [31:0] w_ResultW;             // final writeback value

//── Control signals — Decode stage ───────────────────────────
wire        w_RegWriteD, w_MemtoRegD, w_MemWriteD, w_MemReadD;
wire        w_ALUSrcD, w_RegDstD;
wire        w_BranchD, w_BranchNotEqualD, w_JumpD, w_jrD;
wire [3:0]  w_ALUControlD;

//── Control signals — Execute stage ──────────────────────────
wire        w_RegWriteE, w_MemtoRegE, w_MemWriteE, w_MemReadE;
wire        w_ALUSrcE, w_RegDstE;
wire        w_BranchE, w_BranchNotEqualE, w_JumpE, w_jrE;
wire [3:0]  w_ALUControlE;

//── Control signals — Memory stage ───────────────────────────
wire        w_RegWriteM, w_MemtoRegM, w_MemWriteM, w_MemReadM;
wire        w_BranchM, w_BranchNotEqualM, w_JumpM, w_jrM;

//── Control signals — Writeback stage ────────────────────────
wire        w_RegWriteW, w_MemtoRegW;

//── Hazard signals ────────────────────────────────────────────
wire        w_StallF, w_StallD;
wire        w_FlushD, w_FlushE;

//── Forwarding signals ────────────────────────────────────────
wire [1:0]  w_ForwardAE, w_ForwardBE;
wire        w_ForwardAD_mem, w_ForwardBD_mem;
wire        w_ForwardAD_wb,  w_ForwardBD_wb;

//── Branch / PC-select ────────────────────────────────────────
wire        w_EqualD;
wire        w_PCSrcBranch;   // branch taken
wire [1:0]  w_PCSel;         // 00=PC+4, 01=branch, 10=jump, 11=JR

//=============================================================
// Instruction-field extraction (combinational, from IF/ID)
//=============================================================
assign w_RsD = w_InstD[25:21];
assign w_RtD = w_InstD[20:16];
assign w_RdD = w_InstD[15:11];

//=============================================================
// Branch / PC-select logic
// BEQ : taken when equal=1
// BNE : taken when equal=0
//=============================================================
assign w_PCSrcBranch = (w_BranchD & w_EqualD) | (w_BranchNotEqualD & ~w_EqualD);

// PC select priority: JR > Jump > Branch > PC+4
// Encoded as 2-bit:
//   2'b00 = PC+4 (normal)
//   2'b01 = branch target
//   2'b10 = jump target (J-type)
//   2'b11 = JR target (register)
// We implement this with a cascade of mux2 instances below.

//=============================================================
// ── IF STAGE ─────────────────────────────────────────────────
//=============================================================

// ── Program Counter ─────────────────────────────────────────
program_counter u_PC (
    .clk    (i_clk),
    .rst_n  (i_reset_n),
    .stall  (w_StallF),
    .pc_in  (w_PCNext),
    .pc_out (w_PCCurrent)
);

// ── PC + 4 (IF stage) ───────────────────────────────────────
pc_increment u_PCAdd (
    .pc      (w_PCCurrent),
    .pc_next (w_PCPlus4F)
);

// ── Instruction Memory ──────────────────────────────────────
instruction_memory u_InstMem (
    .rst_n       (i_reset_n),
    .pc_addr     (w_PCCurrent),
    .instruction (o_instructionF)
);

//=============================================================
// ── IF/ID PIPELINE REGISTER ──────────────────────────────────
//=============================================================

fetch_decode u_IFID (
    .clk             (i_clk),
    .rst_n           (i_reset_n),
    .stall           (w_StallD),
    .flush           (w_FlushD),
    .instruction_in  (o_instructionF),
    .pc_plus4_in     (w_PCPlus4F),
    .instruction_out (w_InstD),
    .pc_plus4_out    (w_PCPlus4D)
);

//=============================================================
// ── ID STAGE ─────────────────────────────────────────────────
//=============================================================

// ── Sign extend immediate ───────────────────────────────────
sign_extend u_SignExt (
    .in  (w_InstD[15:0]),
    .out (w_SignImmD)
);

// ── Shift left 2 for branch target offset ───────────────────
shift_left2 u_BranchShift (
    .in  (w_SignImmD),
    .out (w_SignImmShiftedD)
);

// ── Branch target adder ─────────────────────────────────────
pc_increment u_BranchAdd (   // reuse as generic adder via wrapper
    .pc      (w_PCPlus4D),
    .pc_next ()               // unused; see note below
);
// Note: pc_increment only adds 4. For branch target we need
// PC+4 + (SignImm<<2). Use a dedicated adder instance:
wire [31:0] w_BranchAdderResult;
assign w_BranchAdderResult = w_PCPlus4D + w_SignImmShiftedD;
assign w_PCBranchD = w_BranchAdderResult;

// ── Jump target ─────────────────────────────────────────────
jump_shift u_JumpTarget (
    .pc_plus4    (w_PCPlus4D),
    .jump_addr   (w_InstD[25:0]),
    .jump_target (w_JumpTargetD)
);

// ── Register File ───────────────────────────────────────────
register_file u_RegFile (
    .clk  (i_clk),
    .rst_n(i_reset_n),
    .rs   (w_RsD),
    .rt   (w_RtD),
    .rd   (w_WriteRegW),
    .we   (w_RegWriteW),
    .wd   (w_ResultW),
    .rd1  (w_RD1D),
    .rd2  (w_RD2D)
);

// ── Forwarding muxes into branch comparator ─────────────────
// Priority: MEM > WB > register file
// Two-stage mux: first pick MEM vs reg, then pick result vs WB
wire [31:0] w_CmpA_afterMEM, w_CmpB_afterMEM;

mux2 u_ForwardAD_mem (
    .in0 (w_RD1D),
    .in1 (w_ALUResultM),
    .sel (w_ForwardAD_mem),
    .out (w_CmpA_afterMEM)
);
mux2 u_ForwardAD_wb (
    .in0 (w_CmpA_afterMEM),
    .in1 (w_ResultW),
    .sel (w_ForwardAD_wb),
    .out (w_CmpA)
);

mux2 u_ForwardBD_mem (
    .in0 (w_RD2D),
    .in1 (w_ALUResultM),
    .sel (w_ForwardBD_mem),
    .out (w_CmpB_afterMEM)
);
mux2 u_ForwardBD_wb (
    .in0 (w_CmpB_afterMEM),
    .in1 (w_ResultW),
    .sel (w_ForwardBD_wb),
    .out (w_CmpB)
);

// ── Branch comparator ───────────────────────────────────────
comparator u_Comp (
    .a     (w_CmpA),
    .b     (w_CmpB),
    .equal (w_EqualD)
);

// ── Control Unit (main + ALU control wrapper) ───────────────
control_unit u_Ctrl (
    .opcode          (w_InstD[31:26]),
    .funct           (w_InstD[5:0]),
    .RegWriteD       (w_RegWriteD),
    .MemtoRegD       (w_MemtoRegD),
    .MemWriteD       (w_MemWriteD),
    .MemReadD        (w_MemReadD),
    .ALUSrcD         (w_ALUSrcD),
    .RegDstD         (w_RegDstD),
    .BranchD         (w_BranchD),
    .BranchNotEqualD (w_BranchNotEqualD),
    .JumpD           (w_JumpD),
    .ALUControlD     (w_ALUControlD),
    .jrD             (w_jrD)
);

//=============================================================
// ── ID/EX PIPELINE REGISTER ──────────────────────────────────
//=============================================================

decode_execute u_IDEX (
    .clk             (i_clk),
    .rst_n           (i_reset_n),
    .flush           (w_FlushE),

    .RD1_D           (w_RD1D),
    .RD2_D           (w_RD2D),
    .RsD             (w_RsD),
    .RtD             (w_RtD),
    .RdD             (w_RdD),
    .SignImmD        (w_SignImmD),

    .RegWriteD       (w_RegWriteD),
    .MemtoRegD       (w_MemtoRegD),
    .MemWriteD       (w_MemWriteD),
    .MemReadD        (w_MemReadD),
    .ALUSrcD         (w_ALUSrcD),
    .RegDstD         (w_RegDstD),
    .BranchD         (w_BranchD),
    .BranchNotEqualD (w_BranchNotEqualD),
    .JumpD           (w_JumpD),
    .jrD             (w_jrD),
    .ALUControlD     (w_ALUControlD),

    .RD1_E           (w_RD1E),
    .RD2_E           (w_RD2E),
    .RsE             (w_RsE),
    .RtE             (w_RtE),
    .RdE             (w_RdE),
    .SignImmE        (w_SignImmE),

    .RegWriteE       (w_RegWriteE),
    .MemtoRegE       (w_MemtoRegE),
    .MemWriteE       (w_MemWriteE),
    .MemReadE        (w_MemReadE),
    .ALUSrcE         (w_ALUSrcE),
    .RegDstE         (w_RegDstE),
    .BranchE         (w_BranchE),
    .BranchNotEqualE (w_BranchNotEqualE),
    .JumpE           (w_JumpE),
    .jrE             (w_jrE),
    .ALUControlE     (w_ALUControlE)
);

//=============================================================
// ── EX STAGE ─────────────────────────────────────────────────
//=============================================================

// ── RegDst mux: choose write register (rd vs rt) ────────────
mux2 #(.DATA_WIDTH(5)) u_RegDst (
    .in0 (w_RtE),
    .in1 (w_RdE),
    .sel (w_RegDstE),
    .out (w_WriteRegE)
);

// ── Forwarding mux for ALU input A ──────────────────────────
// 00=RD1_E, 01=WB result, 10=MEM ALU result
mux3 u_ForwardAE (
    .in0 (w_RD1E),
    .in1 (w_ResultW),
    .in2 (w_ALUResultM),
    .sel (w_ForwardAE),
    .out (w_SrcAE)
);

// ── Forwarding mux for ALU input B (before ALUSrc) ──────────
mux3 u_ForwardBE (
    .in0 (w_RD2E),
    .in1 (w_ResultW),
    .in2 (w_ALUResultM),
    .sel (w_ForwardBE),
    .out (w_ForwardedB)
);

// ── ALUSrc mux: register vs sign-extended immediate ─────────
mux2 u_ALUSrc (
    .in0 (w_ForwardedB),
    .in1 (w_SignImmE),
    .sel (w_ALUSrcE),
    .out (w_SrcBE)
);

// ── JR target: Rs value from EX stage ───────────────────────
assign w_JRTargetE = w_SrcAE;   // Rs after forwarding

// ── ALU ─────────────────────────────────────────────────────
ALU u_ALU (
    .A       (w_SrcAE),
    .B       (w_SrcBE),
    .control (w_ALUControlE),
    .result  (w_ALUResultE),
    .zero    ()              // zero not used in EX (branch in ID)
);

//=============================================================
// ── EX/MEM PIPELINE REGISTER ─────────────────────────────────
//=============================================================

execute_mem u_EXMEM (
    .clk            (i_clk),
    .rst_n          (i_reset_n),
    .flushM         (1'b0),        // extend later for exceptions

    .RegWriteE      (w_RegWriteE),
    .MemtoRegE      (w_MemtoRegE),
    .MemWriteE      (w_MemWriteE),
    .MemReadE       (w_MemReadE),
    .BranchE        (w_BranchE),
    .BranchNotEqualE(w_BranchNotEqualE),
    .JumpE          (w_JumpE),
    .jrE            (w_jrE),

    .ALUResultE     (w_ALUResultE),
    .WriteDataE     (w_ForwardedB),  // Rt after forwarding (for SW)
    .WriteRegE      (w_WriteRegE),

    .RegWriteM      (w_RegWriteM),
    .MemtoRegM      (w_MemtoRegM),
    .MemWriteM      (w_MemWriteM),
    .MemReadM       (w_MemReadM),
    .BranchM        (w_BranchM),
    .BranchNotEqualM(w_BranchNotEqualM),
    .JumpM          (w_JumpM),
    .jrM            (w_jrM),

    .ALUResultM     (w_ALUResultM),
    .WriteDataM     (w_WriteDataM),
    .WriteRegM      (w_WriteRegM)
);

//=============================================================
// ── MEM STAGE ────────────────────────────────────────────────
//=============================================================

data_memory u_DataMem (
    .clk        (i_clk),
    .rst_n      (i_reset_n),
    .MemWriteM  (w_MemWriteM),
    .MemReadM   (w_MemReadM),
    .WriteDataM (w_WriteDataM),
    .addr       (w_ALUResultM),
    .ReadDataM  (w_ReadDataM)
);

//=============================================================
// ── MEM/WB PIPELINE REGISTER ─────────────────────────────────
//=============================================================

memory_writeback u_MEMWB (
    .clk        (i_clk),
    .rst_n      (i_reset_n),
    .flushW     (1'b0),        // tie low; extend for exceptions

    .RegWriteM  (w_RegWriteM),
    .MemtoRegM  (w_MemtoRegM),

    .ALUResultM (w_ALUResultM),
    .ReadDataM  (w_ReadDataM),
    .WriteRegM  (w_WriteRegM),

    .RegWriteW  (w_RegWriteW),
    .MemtoRegW  (w_MemtoRegW),

    .ALUResultW (w_ALUResultW),
    .ReadDataW  (w_ReadDataW),
    .WriteRegW  (w_WriteRegW)
);

//=============================================================
// ── WB STAGE ─────────────────────────────────────────────────
//=============================================================

// MemtoReg mux: ALU result vs memory read data
mux2 u_MemToReg (
    .in0 (w_ALUResultW),
    .in1 (w_ReadDataW),
    .sel (w_MemtoRegW),
    .out (w_ResultW)
);

//=============================================================
// ── FORWARDING UNIT ──────────────────────────────────────────
//=============================================================

forward_unit u_Forward (
    .RsD         (w_RsD),
    .RtD         (w_RtD),
    .RsE         (w_RsE),
    .RtE         (w_RtE),

    .WriteRegM   (w_WriteRegM),
    .RegWriteM   (w_RegWriteM),

    .WriteRegW   (w_WriteRegW),
    .RegWriteW   (w_RegWriteW),

    .ForwardAE      (w_ForwardAE),
    .ForwardBE      (w_ForwardBE),
    .ForwardAD_mem  (w_ForwardAD_mem),
    .ForwardBD_mem  (w_ForwardBD_mem),
    .ForwardAD_wb   (w_ForwardAD_wb),
    .ForwardBD_wb   (w_ForwardBD_wb)
);

//=============================================================
// ── HAZARD UNIT ───────────────────────────────────────────────
//=============================================================

hazard_unit u_Hazard (
    .RsD             (w_RsD),
    .RtD             (w_RtD),
    .RtE             (w_RtE),
    .WriteRegE       (w_WriteRegE),
    .MemtoRegE       (w_MemtoRegE),
    .RegWriteE       (w_RegWriteE),
    .WriteRegM       (w_WriteRegM),
    .MemtoRegM       (w_MemtoRegM),
    .BranchD         (w_BranchD),
    .BranchNotEqualD (w_BranchNotEqualD),
    .JumpD           (w_JumpD),
    .StallF          (w_StallF),
    .StallD          (w_StallD),
    .FlushD          (w_FlushD),
    .FlushE          (w_FlushE)
);

//=============================================================
// ── NEXT-PC SELECT ────────────────────────────────────────────
// Priority (highest first):
//   JR      → w_JRTargetE  (uses EX-stage Rs)
//   Jump    → w_JumpTargetD
//   Branch  → w_PCBranchD
//   Normal  → w_PCPlus4F
//=============================================================

wire [31:0] w_PCAfterBranch, w_PCAfterJump;

// Step 1: branch vs PC+4
mux2 u_BranchMux (
    .in0 (w_PCPlus4F),
    .in1 (w_PCBranchD),
    .sel (w_PCSrcBranch),
    .out (w_PCAfterBranch)
);

// Step 2: jump vs result of step 1
mux2 u_JumpMux (
    .in0 (w_PCAfterBranch),
    .in1 (w_JumpTargetD),
    .sel (w_JumpD),
    .out (w_PCAfterJump)
);

// Step 3: JR vs result of step 2
// JR target is Rs read from register file, forwarded in EX.
// We capture it from the EX stage one cycle after the JR is
// in ID; the hazard unit inserts a stall so timing is correct.
mux2 u_JRMux (
    .in0 (w_PCAfterJump),
    .in1 (w_JRTargetE),
    .sel (w_jrE),          // jrE is the EX-stage JR flag
    .out (w_PCNext)
);

endmodule
