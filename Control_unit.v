`timescale 1ns / 1ps
//=============================================================
// Module : control_unit  (wrapper)
// Description : Combines main_control and alu_control into a
//               single module so Top.v has one clean interface.
//               Instantiated as u_ctrl in Top.v.
//
// Fix applied : This file was previously empty. Now it wraps
//               main_control + alu_control with a unified port.
//=============================================================

module control_unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,

    // From main_control
    output wire        RegWriteD,
    output wire        MemtoRegD,
    output wire        MemWriteD,
    output wire        MemReadD,
    output wire        ALUSrcD,
    output wire        RegDstD,
    output wire        BranchD,
    output wire        BranchNotEqualD,
    output wire        JumpD,

    // From alu_control
    output wire [3:0]  ALUControlD,
    output wire        jrD
);

wire [1:0] w_ALUOp;

// ── First-level decoder ─────────────────────────────────────
main_control u_main_ctrl (
    .opcode          (opcode),
    .RegWriteD       (RegWriteD),
    .MemtoRegD       (MemtoRegD),
    .MemWriteD       (MemWriteD),
    .MemReadD        (MemReadD),
    .ALUSrcD         (ALUSrcD),
    .RegDstD         (RegDstD),
    .BranchD         (BranchD),
    .BranchNotEqualD (BranchNotEqualD),
    .JumpD           (JumpD),
    .ALUOpD          (w_ALUOp)
);

// ── Second-level decoder ────────────────────────────────────
alu_control u_alu_ctrl (
    .ALUOp      (w_ALUOp),
    .funct      (funct),
    .opcode     (opcode),
    .ALUControl (ALUControlD),
    .jrD        (jrD)
);

endmodule
