// =============================================================
// Module      : control_unit
// Description : Main Control Unit for ID stage (two-level decode,
//               Patterson & Hennessy style). This module classifies
//               instructions and produces high-level control
//               signals. Exact ALU operation selection (funct-level
//               detail) is deferred to alu_control.v, which consumes
//               this module's alu_op output alongside the funct field.
//
// Encodings referenced: docs/ISA.md (single source of truth for
// opcode/funct assignments).
// =============================================================

module control_unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,     // only meaningful when opcode==000000
    input  wire [4:0] rt_field,  // needed to distinguish bltz/bgez (same opcode)

    output reg        reg_dst,        // 0=rt dest, 1=rd dest
    output reg        alu_src,        // 0=reg, 1=immediate
    output reg  [1:0] mem_to_reg,     // 00=ALU,01=Mem,10=PC+4(jal),11=HI/LO
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg  [2:0] branch_type,    // 000=beq 001=bne 010=blez 011=bgtz 100=bltz 101=bgez
    output reg        jump,
    output reg        jump_link,      // jal
    output reg        jump_reg,       // jr / jalr
    output reg  [2:0] alu_op,         // class fed to alu_control.v
    output reg        alu_width64,    // 0 = 32-bit op (sext result), 1 = 64-bit op
    output reg  [1:0] ext_ctrl,       // 00=sign,01=zero,10=lui
    output reg  [2:0] mem_width,      // 000=byte,001=half,010=word,011=dword; bit2 used as unsigned flag downstream
    output reg        mem_unsigned,   // 1 = zero-extend load result (lbu/lhu)
    output reg        is_mult_div,    // triggers multi-cycle HI/LO unit
    output reg        mult_div_signed,// 1 = signed (mult/div/dmult/ddiv), 0 = unsigned (*u variants)
    output reg         illegal_instr   // decode-error flag (unknown opcode/funct)
);

    // Opcode constants (see docs/ISA.md)
    localparam OP_RTYPE   = 6'b000000;
    localparam OP_ADDI    = 6'b001000;
    localparam OP_ADDIU   = 6'b001001;
    localparam OP_DADDI   = 6'b011000;
    localparam OP_DADDIU  = 6'b011001;
    localparam OP_ANDI    = 6'b001100;
    localparam OP_ORI     = 6'b001101;
    localparam OP_XORI    = 6'b001110;
    localparam OP_SLTI    = 6'b001010;
    localparam OP_SLTIU   = 6'b001011;
    localparam OP_LUI     = 6'b001111;
    localparam OP_LB      = 6'b100000;
    localparam OP_LBU     = 6'b100100;
    localparam OP_LH      = 6'b100001;
    localparam OP_LHU     = 6'b100101;
    localparam OP_LW      = 6'b100011;
    localparam OP_LD      = 6'b110111;
    localparam OP_SB      = 6'b101000;
    localparam OP_SH      = 6'b101001;
    localparam OP_SW      = 6'b101011;
    localparam OP_SD      = 6'b111111;
    localparam OP_BEQ     = 6'b000100;
    localparam OP_BNE     = 6'b000101;
    localparam OP_BLEZ    = 6'b000110;
    localparam OP_BGTZ    = 6'b000111;
    localparam OP_REGIMM  = 6'b000001; // bltz/bgez share this opcode, split by rt_field
    localparam OP_J       = 6'b000010;
    localparam OP_JAL     = 6'b000011;

    // R-type funct constants needed here only to detect jr/jalr/mult/div class
    // (full ALU-op funct decode lives in alu_control.v)
    localparam F_JR      = 6'b001000;
    localparam F_JALR    = 6'b001001;
    localparam F_MULT    = 6'b011000;
    localparam F_MULTU   = 6'b011001;
    localparam F_DIV     = 6'b011010;
    localparam F_DIVU    = 6'b011011;
    localparam F_DMULT   = 6'b011100;
    localparam F_DMULTU  = 6'b011101;
    localparam F_DDIV    = 6'b011110;
    localparam F_DDIVU   = 6'b011111;
    localparam F_MFHI    = 6'b010000;
    localparam F_MFLO    = 6'b010010;
    localparam F_MTHI    = 6'b010001;
    localparam F_MTLO    = 6'b010011;
    // 64-bit R-type functs (dadd, dsub, dsll, etc.) — used only to set alu_width64
    localparam F_DADD    = 6'b101100;
    localparam F_DADDU   = 6'b101101;
    localparam F_DSUB    = 6'b101110;
    localparam F_DSUBU   = 6'b101111;
    localparam F_DSLL    = 6'b111000;
    localparam F_DSRL    = 6'b111010;
    localparam F_DSRA    = 6'b111011;
    localparam F_DSLLV   = 6'b010100;
    localparam F_DSRLV   = 6'b010110;
    localparam F_DSRAV   = 6'b010111;

    always @(*) begin
        // ---- Safe defaults (NOP-equivalent: no writes, no side effects) ----
        reg_dst      = 1'b0;
        alu_src      = 1'b0;
        mem_to_reg   = 2'b00;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        branch       = 1'b0;
        branch_type  = 3'b000;
        jump         = 1'b0;
        jump_link    = 1'b0;
        jump_reg     = 1'b0;
        alu_op       = 3'b000;
        alu_width64  = 1'b1;   // default: 64-bit datapath op
        ext_ctrl     = 2'b00;  // default: sign-extend
        mem_width    = 3'b010; // default: word
        mem_unsigned = 1'b0;
        is_mult_div  = 1'b0;
        mult_div_signed = 1'b1; // default signed (irrelevant unless is_mult_div=1)
        illegal_instr = 1'b0;

        case (opcode)

            OP_RTYPE: begin
                reg_dst   = 1'b1;
                alu_src   = 1'b0;
                alu_op    = 3'b010; // "use funct" class
                case (funct)
                    F_JR: begin
                        jump_reg = 1'b1;
                    end
                    F_JALR: begin
                        jump_reg   = 1'b1;
                        jump_link  = 1'b1;
                        reg_write  = 1'b1;
                        mem_to_reg = 2'b10; // PC+4
                    end
                    F_MULT, F_MULTU, F_DIV, F_DIVU,
                    F_DMULT, F_DMULTU, F_DDIV, F_DDIVU: begin
                        is_mult_div = 1'b1;
                        alu_width64 = (funct == F_DMULT || funct == F_DMULTU ||
                                       funct == F_DDIV  || funct == F_DDIVU) ? 1'b1 : 1'b0;
                        mult_div_signed = (funct == F_MULT || funct == F_DIV ||
                                           funct == F_DMULT || funct == F_DDIV) ? 1'b1 : 1'b0;
                        // no reg_write here: result goes to HI/LO, not GPR
                    end
                    F_MFHI, F_MFLO: begin
                        reg_write  = 1'b1;
                        mem_to_reg = 2'b11; // HI/LO mux
                    end
                    F_MTHI, F_MTLO: begin
                        // writes internal HI/LO unit, not GPR; reg_write stays 0
                    end
                    F_DADD, F_DADDU, F_DSUB, F_DSUBU,
                    F_DSLL, F_DSRL, F_DSRA,
                    F_DSLLV, F_DSRLV, F_DSRAV: begin
                        reg_write   = 1'b1;
                        alu_width64 = 1'b1;
                    end
                    default: begin
                        // Covers add/addu/sub/subu/and/or/xor/nor/slt/sltu/
                        // sll/srl/sra/sllv/srlv/srav — all normal R-type ALU ops.
                        reg_write = 1'b1;
                        // 32-bit shift/arith variants narrow to 32b then sign-extend;
                        // alu_control.v + ALU handle the actual narrowing using this flag.
                        alu_width64 = 1'b0;
                        // NOTE: and/or/xor/nor/slt/sltu are width-agnostic in real MIPS
                        // (full 64b), but tagging them 32b here is harmless IF the ALU
                        // treats logical/compare ops as width-agnostic regardless of this
                        // flag (see alu.v). Documented at point of use.
                    end
                endcase
            end

            OP_ADDI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b000; alu_width64 = 1'b0; ext_ctrl = 2'b00;
            end
            OP_ADDIU: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b000; alu_width64 = 1'b0; ext_ctrl = 2'b00;
            end
            OP_DADDI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b000; alu_width64 = 1'b1; ext_ctrl = 2'b00;
            end
            OP_DADDIU: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b000; alu_width64 = 1'b1; ext_ctrl = 2'b00;
            end
            OP_ANDI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b011; ext_ctrl = 2'b01; // zero-extend
            end
            OP_ORI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b100; ext_ctrl = 2'b01;
            end
            OP_XORI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b101; ext_ctrl = 2'b01;
            end
            OP_SLTI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b110; ext_ctrl = 2'b00;
            end
            OP_SLTIU: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b110; ext_ctrl = 2'b00;
            end
            OP_LUI: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                alu_op = 3'b111; ext_ctrl = 2'b10; alu_width64 = 1'b1;
            end

            OP_LB, OP_LBU, OP_LH, OP_LHU, OP_LW, OP_LD: begin
                reg_dst = 1'b0; alu_src = 1'b1; reg_write = 1'b1;
                mem_read = 1'b1; mem_to_reg = 2'b01;
                alu_op = 3'b000; ext_ctrl = 2'b00; alu_width64 = 1'b1;
                case (opcode)
                    OP_LB:  begin mem_width = 3'b000; mem_unsigned = 1'b0; end
                    OP_LBU: begin mem_width = 3'b000; mem_unsigned = 1'b1; end
                    OP_LH:  begin mem_width = 3'b001; mem_unsigned = 1'b0; end
                    OP_LHU: begin mem_width = 3'b001; mem_unsigned = 1'b1; end
                    OP_LW:  begin mem_width = 3'b010; mem_unsigned = 1'b0; end
                    OP_LD:  begin mem_width = 3'b011; mem_unsigned = 1'b0; end
                    default: ;
                endcase
            end

            OP_SB, OP_SH, OP_SW, OP_SD: begin
                alu_src = 1'b1; mem_write = 1'b1;
                alu_op = 3'b000; ext_ctrl = 2'b00; alu_width64 = 1'b1;
                case (opcode)
                    OP_SB: mem_width = 3'b000;
                    OP_SH: mem_width = 3'b001;
                    OP_SW: mem_width = 3'b010;
                    OP_SD: mem_width = 3'b011;
                    default: ;
                endcase
            end

            OP_BEQ: begin branch = 1'b1; branch_type = 3'b000; alu_op = 3'b001; alu_width64 = 1'b1; end
            OP_BNE: begin branch = 1'b1; branch_type = 3'b001; alu_op = 3'b001; alu_width64 = 1'b1; end
            OP_BLEZ: begin branch = 1'b1; branch_type = 3'b010; alu_op = 3'b001; alu_width64 = 1'b1; end
            OP_BGTZ: begin branch = 1'b1; branch_type = 3'b011; alu_op = 3'b001; alu_width64 = 1'b1; end
            OP_REGIMM: begin
                branch = 1'b1; alu_op = 3'b001; alu_width64 = 1'b1;
                if (rt_field == 5'b00000)      branch_type = 3'b100; // bltz
                else if (rt_field == 5'b00001) branch_type = 3'b101; // bgez
                else                            illegal_instr = 1'b1;
            end

            OP_J: begin
                jump = 1'b1;
            end
            OP_JAL: begin
                jump = 1'b1; jump_link = 1'b1;
                reg_write = 1'b1; mem_to_reg = 2'b10; // PC+4 -> $ra
            end

            default: begin
                illegal_instr = 1'b1;
            end
        endcase
    end

endmodule
