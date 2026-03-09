`timescale 1ns / 1ps
//=============================================================
// Module : alu_control
// Description : Second-level ALU decoder.
//               Converts ALUOp (2-bit) + funct/opcode (6-bit)
//               into a 4-bit ALUControl signal.
//               Also generates jrD for JR instruction.
//
// Fix applied : ALUControl is now 4 bits everywhere.
//=============================================================

module alu_control (
    input  wire [1:0] ALUOp,
    input  wire [5:0] funct,
    input  wire [5:0] opcode,

    output reg  [3:0] ALUControl,   // 4-bit (was silently 3-bit in Top)
    output reg        jrD
);

    // R-type funct codes
    localparam F_ADD = 6'b100000;
    localparam F_SUB = 6'b100010;
    localparam F_AND = 6'b100100;
    localparam F_OR  = 6'b100101;
    localparam F_SLT = 6'b101010;
    localparam F_XOR = 6'b100110;
    localparam F_NOR = 6'b100111;
    localparam F_SLL = 6'b000000;
    localparam F_SRL = 6'b000010;
    localparam F_SRA = 6'b000011;
    localparam F_JR  = 6'b001000;

    // I-type opcodes (ALUOp == 2'b11)
    localparam OP_ANDI = 6'b001100;
    localparam OP_ORI  = 6'b001101;
    localparam OP_SLTI = 6'b001010;
    localparam OP_LUI  = 6'b001111;

    always @(*) begin

        jrD        = 1'b0;
        ALUControl = 4'b0010;   // default: ADD

        case (ALUOp)

            // LW, SW, ADDI — address calculation (ADD)
            2'b00: ALUControl = 4'b0010;

            // BEQ, BNE — subtraction for comparison
            2'b01: ALUControl = 4'b0110;

            // R-type: decode via funct field
            2'b10: begin
                case (funct)
                    F_ADD: ALUControl = 4'b0010;
                    F_SUB: ALUControl = 4'b0110;
                    F_AND: ALUControl = 4'b0000;
                    F_OR : ALUControl = 4'b0001;
                    F_SLT: ALUControl = 4'b0111;
                    F_XOR: ALUControl = 4'b0011;
                    F_NOR: ALUControl = 4'b1100;
                    F_SLL: ALUControl = 4'b1000;
                    F_SRL: ALUControl = 4'b1001;
                    F_SRA: ALUControl = 4'b1010;
                    F_JR: begin
                        jrD        = 1'b1;
                        ALUControl = 4'b0010;   // ALU result unused for JR
                    end
                    default: ALUControl = 4'b0010;
                endcase
            end

            // I-type ALU ops: decode via opcode
            2'b11: begin
                case (opcode)
                    OP_ANDI: ALUControl = 4'b0000;
                    OP_ORI : ALUControl = 4'b0001;
                    OP_SLTI: ALUControl = 4'b0111;
                    OP_LUI : ALUControl = 4'b1011;  // handled in ALU as B<<16
                    default: ALUControl = 4'b0010;
                endcase
            end

            default: ALUControl = 4'b0010;

        endcase
    end

endmodule
