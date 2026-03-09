`timescale 1ns / 1ps
//=============================================================
// Module : main_control
// Description : First-level control decoder.
//               Decodes the 6-bit opcode [31:26] and drives
//               all pipeline control signals.
//=============================================================

module main_control (
    input  wire [5:0] opcode,

    output reg        RegWriteD,
    output reg        MemtoRegD,
    output reg        MemWriteD,
    output reg        MemReadD,         // added: gate data-memory read
    output reg        ALUSrcD,
    output reg        RegDstD,
    output reg        BranchD,
    output reg        BranchNotEqualD,
    output reg        JumpD,
    output reg [1:0]  ALUOpD
);

    // Opcode definitions
    localparam R_TYPE = 6'b000000;
    localparam LW     = 6'b100011;
    localparam SW     = 6'b101011;
    localparam BEQ    = 6'b000100;
    localparam BNE    = 6'b000101;
    localparam ADDI   = 6'b001000;
    localparam ANDI   = 6'b001100;
    localparam ORI    = 6'b001101;
    localparam SLTI   = 6'b001010;
    localparam LUI    = 6'b001111;
    localparam JUMP   = 6'b000010;

    always @(*) begin

        // Safe defaults (NOP behaviour)
        RegWriteD       = 1'b0;
        MemtoRegD       = 1'b0;
        MemWriteD       = 1'b0;
        MemReadD        = 1'b0;
        ALUSrcD         = 1'b0;
        RegDstD         = 1'b0;
        BranchD         = 1'b0;
        BranchNotEqualD = 1'b0;
        JumpD           = 1'b0;
        ALUOpD          = 2'b00;

        case (opcode)

            R_TYPE: begin
                RegWriteD = 1'b1;
                RegDstD   = 1'b1;
                ALUOpD    = 2'b10;
            end

            LW: begin
                RegWriteD = 1'b1;
                MemtoRegD = 1'b1;
                MemReadD  = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b00;
            end

            SW: begin
                MemWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b00;
            end

            BEQ: begin
                BranchD = 1'b1;
                ALUOpD  = 2'b01;
            end

            BNE: begin
                BranchNotEqualD = 1'b1;
                ALUOpD          = 2'b01;
            end

            ADDI: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b00;
            end

            ANDI: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b11;
            end

            ORI: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b11;
            end

            SLTI: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b11;
            end

            LUI: begin
                RegWriteD = 1'b1;
                ALUSrcD   = 1'b1;
                ALUOpD    = 2'b11;
            end

            JUMP: begin
                JumpD = 1'b1;
            end

            default: ; // all signals already 0

        endcase
    end

endmodule
