// =============================================================
// Module      : alu_control
// Description : Second-level control (Patterson & Hennessy style).
//               Maps {alu_op, funct, opcode_lsb} -> the 5-bit
//               alu_ctrl code consumed by alu.v. Encoding is
//               locked in docs/ISA.md and rtl/alu.v.
//
//               alu_op classes (from control_unit.v):
//                 000 = add family (addi/daddi/lw/sw/ld/sd address calc)
//                 001 = branch family (subtract, compare to zero)
//                 010 = R-type: decode funct directly
//                 011 = andi
//                 100 = ori
//                 101 = xori
//                 110 = slti/sltiu (disambiguated by opcode_lsb)
//                 111 = lui
//
//               opcode_lsb is only consulted for alu_op=110, to tell
//               slti (opcode 001010, lsb=0) apart from sltiu
//               (opcode 001011, lsb=1) -- see docs/ISA.md opcode map.
// =============================================================

module alu_control (
    input  wire [2:0] alu_op,
    input  wire [5:0] funct,
    input  wire        opcode_lsb,   // used only when alu_op == 110

    output reg  [4:0] alu_ctrl
);

    // alu.v operation codes (must match rtl/alu.v exactly)
    localparam ALU_ADD      = 5'b00000;
    localparam ALU_SUB      = 5'b00001;
    localparam ALU_AND      = 5'b00010;
    localparam ALU_OR       = 5'b00011;
    localparam ALU_XOR      = 5'b00100;
    localparam ALU_NOR      = 5'b00101;
    localparam ALU_SLT      = 5'b00110;
    localparam ALU_SLTU     = 5'b00111;
    localparam ALU_SLL      = 5'b01000;
    localparam ALU_SRL      = 5'b01001;
    localparam ALU_SRA      = 5'b01010;
    localparam ALU_LUI_PASS = 5'b01011;
    localparam ALU_PASS_A   = 5'b01100;

    // R-type funct constants (see docs/ISA.md)
    localparam F_ADD    = 6'b100000;
    localparam F_ADDU   = 6'b100001;
    localparam F_SUB    = 6'b100010;
    localparam F_SUBU   = 6'b100011;
    localparam F_AND    = 6'b100100;
    localparam F_OR     = 6'b100101;
    localparam F_XOR    = 6'b100110;
    localparam F_NOR    = 6'b100111;
    localparam F_SLT    = 6'b101010;
    localparam F_SLTU   = 6'b101011;
    localparam F_SLL    = 6'b000000;
    localparam F_SRL    = 6'b000010;
    localparam F_SRA    = 6'b000011;
    localparam F_SLLV   = 6'b000100;
    localparam F_SRLV   = 6'b000110;
    localparam F_SRAV   = 6'b000111;
    localparam F_DADD   = 6'b101100;
    localparam F_DADDU  = 6'b101101;
    localparam F_DSUB   = 6'b101110;
    localparam F_DSUBU  = 6'b101111;
    localparam F_DSLL   = 6'b111000;
    localparam F_DSRL   = 6'b111010;
    localparam F_DSRA   = 6'b111011;
    localparam F_DSLLV  = 6'b010100;
    localparam F_DSRLV  = 6'b010110;
    localparam F_DSRAV  = 6'b010111;

    always @(*) begin
        case (alu_op)

            3'b000: alu_ctrl = ALU_ADD;  // add-family (loads/stores/addi/daddi)
            3'b001: alu_ctrl = ALU_SUB;  // branch compare
            3'b011: alu_ctrl = ALU_AND;  // andi
            3'b100: alu_ctrl = ALU_OR;   // ori
            3'b101: alu_ctrl = ALU_XOR;  // xori
            3'b110: alu_ctrl = opcode_lsb ? ALU_SLTU : ALU_SLT; // slti/sltiu
            3'b111: alu_ctrl = ALU_LUI_PASS; // lui

            3'b010: begin // R-type: decode funct
                case (funct)
                    F_ADD, F_ADDU, F_DADD, F_DADDU: alu_ctrl = ALU_ADD;
                    F_SUB, F_SUBU, F_DSUB, F_DSUBU: alu_ctrl = ALU_SUB;
                    F_AND:  alu_ctrl = ALU_AND;
                    F_OR:   alu_ctrl = ALU_OR;
                    F_XOR:  alu_ctrl = ALU_XOR;
                    F_NOR:  alu_ctrl = ALU_NOR;
                    F_SLT:  alu_ctrl = ALU_SLT;
                    F_SLTU: alu_ctrl = ALU_SLTU;
                    F_SLL, F_SLLV, F_DSLL, F_DSLLV: alu_ctrl = ALU_SLL;
                    F_SRL, F_SRLV, F_DSRL, F_DSRLV: alu_ctrl = ALU_SRL;
                    F_SRA, F_SRAV, F_DSRA, F_DSRAV: alu_ctrl = ALU_SRA;
                    default: alu_ctrl = ALU_ADD; // safe fallback (should be unreachable
                                                  // for is_mult_div/jr/jalr/mfhi/etc.,
                                                  // which never route through the ALU
                                                  // result mux in the datapath)
                endcase
            end

            default: alu_ctrl = ALU_ADD;

        endcase
    end

endmodule
