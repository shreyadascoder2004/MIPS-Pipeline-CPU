# MIPS64-style Pipeline — ISA Reference

Datapath: 64-bit. Instructions: 32-bit, byte-addressed, PC increments by 4.

## Instruction formats (32-bit encoding, MIPS-standard)

R-type: [ opcode(6) | rs(5) | rt(5) | rd(5) | shamt(5) | funct(6) ]
I-type: [ opcode(6) | rs(5) | rt(5) | immediate(16)              ]
J-type: [ opcode(6) | address(26)                                ]

## Opcode map (bits [31:26])

| Mnemonic | Opcode  | Type | Notes                              |
|----------|---------|------|-------------------------------------|
| R-type   | 000000  | R    | funct field selects operation       |
| addi     | 001000  | I    | rt = rs + sext(imm), 32b result, sext to 64 |
| addiu    | 001001  | I    | unsigned, no overflow trap          |
| daddi    | 011000  | I    | 64-bit add immediate                |
| daddiu   | 011001  | I    | 64-bit add immediate unsigned       |
| andi     | 001100  | I    | zero-extended imm                   |
| ori      | 001101  | I    | zero-extended imm                   |
| xori     | 001110  | I    | zero-extended imm                   |
| slti     | 001010  | I    | signed compare                      |
| sltiu    | 001011  | I    | unsigned compare                    |
| lui      | 001111  | I    | rt = imm << 16 (sign-ext to 64)     |
| lb       | 100000  | I    | load byte, sign-extend               |
| lbu      | 100100  | I    | load byte, zero-extend               |
| lh       | 100001  | I    | load halfword, sign-extend           |
| lhu      | 100101  | I    | load halfword, zero-extend           |
| lw       | 100011  | I    | load word (32b), sign-extend to 64  |
| ld       | 110111  | I    | load doubleword (64b)               |
| sb       | 101000  | I    | store byte                          |
| sh       | 101001  | I    | store halfword                      |
| sw       | 101011  | I    | store word (lower 32b)              |
| sd       | 111111  | I    | store doubleword                    |
| beq      | 000100  | I    | branch if rs == rt                  |
| bne      | 000101  | I    | branch if rs != rt                  |
| blez     | 000110  | I    | branch if rs <= 0                   |
| bgtz     | 000111  | I    | branch if rs > 0                    |
| bltz     | 000001  | I    | rt field = 00000; branch if rs < 0  |
| bgez     | 000001  | I    | rt field = 00001; branch if rs >= 0 |
| j        | 000010  | J    | jump                                 |
| jal      | 000011  | J    | jump and link ($ra = PC+8, MIPS convention with branch-delay slot omitted here → PC+4 in our no-delay-slot design) |

## Funct map (opcode = 000000, bits [5:0])

| Mnemonic | Funct   | Width | Notes                          |
|----------|---------|-------|----------------------------------|
| add      | 100000  | 32    | trap on 32-bit overflow (impl: flag only, no trap unit yet) |
| addu     | 100001  | 32    | no overflow check                |
| sub      | 100010  | 32    |                                   |
| subu     | 100011  | 32    |                                   |
| dadd     | 101100  | 64    |                                   |
| daddu    | 101101  | 64    |                                   |
| dsub     | 101110  | 64    |                                   |
| dsubu    | 101111  | 64    |                                   |
| and      | 100100  | 64    | bitwise, width-agnostic           |
| or       | 100101  | 64    |                                   |
| xor      | 100110  | 64    |                                   |
| nor      | 100111  | 64    |                                   |
| slt      | 101010  | 64    | signed compare, full 64b          |
| sltu     | 101011  | 64    | unsigned compare, full 64b        |
| sll      | 000000  | 32    | shamt field, result sign-ext      |
| srl      | 000010  | 32    |                                   |
| sra      | 000011  | 32    |                                   |
| sllv     | 000100  | 32    | shift amt from rs[4:0]            |
| srlv     | 000110  | 32    |                                   |
| srav     | 000111  | 32    |                                   |
| dsll     | 111000  | 64    | shamt field                       |
| dsrl     | 111010  | 64    |                                   |
| dsra     | 111011  | 64    |                                   |
| dsllv    | 010100  | 64    | shift amt from rs[5:0] (64b shifts need 6 bits) |
| dsrlv    | 010110  | 64    |                                   |
| dsrav    | 010111  | 64    |                                   |
| jr       | 001000  | -     |                                   |
| jalr     | 001001  | -     |                                   |
| mult     | 011000  | 32    | HI/LO <= rs * rt (32b operands)   |
| multu    | 011001  | 32    |                                   |
| div      | 011010  | 32    |                                   |
| divu     | 011011  | 32    |                                   |
| dmult    | 011100  | 64    | HI/LO <= rs * rt (64b operands)   |
| dmultu   | 011101  | 64    |                                   |
| ddiv     | 011110  | 64    |                                   |
| ddivu    | 011111  | 64    |                                   |
| mfhi     | 010000  | -     | rd = HI                          |
| mflo     | 010010  | -     | rd = LO                          |
| mthi     | 010001  | -     | HI = rs                          |
| mtlo     | 010011  | -     | LO = rs                          |

Note: funct codes above are assigned by us for this project (kept close to real
MIPS where possible, but d-variants for shifts/shift-var are reassigned to
avoid collision, since real MIPS64 uses a second 6-bit space we're not
implementing). This table is the single source of truth — the assembler and
the control unit / ALU control unit must both be generated from it.

## ALU control encoding (internal, EX stage) — LOCKED (see rtl/alu.v)

| Code (5b) | Operation | Notes |
|-----------|-----------|-------|
| 00000 | ADD      | width32 selects 32b-then-sign-extend vs full 64b |
| 00001 | SUB      | also used for branch comparisons (alu_op=001 class) |
| 00010 | AND      | width-agnostic, always full 64b |
| 00011 | OR       | width-agnostic |
| 00100 | XOR      | width-agnostic |
| 00101 | NOR      | width-agnostic |
| 00110 | SLT      | signed compare, width-agnostic |
| 00111 | SLTU     | unsigned compare, width-agnostic |
| 01000 | SLL      | shamt_in: 5b for 32-bit shifts, 6b for 64-bit (dsll) |
| 01001 | SRL      | logical right shift |
| 01010 | SRA      | arithmetic (sign-preserving) right shift |
| 01011 | LUI_PASS | passes operand_b through (already shifted+extended upstream by sign_extend.v lui_mode) |
| 01100 | PASS_A   | reserved / passthrough of operand_a (not currently used in datapath; jr/jalr bypass ALU) |

alu_control.v (next module) maps {alu_op (from control_unit.v), funct} -> this
5-bit code. mult/div/dmult/ddiv do NOT go through the ALU -- they route to a
separate HI/LO multi-cycle unit (see is_mult_div signal), so no ALU_MUL/DIV
codes exist here.

## Register conventions

- 32 GPRs, 64-bit each, $0 hardwired to 0.
- $ra = $31 (link register, used by jal/jalr).
- HI/LO: 64-bit each, hold mult/div results.

## Open items to decide before assembler/control unit lock-in
- Overflow trap handling (add/sub/daddi etc.) — flag-only vs actual trap/exception unit.
- Delay slot: THIS DESIGN HAS NO BRANCH DELAY SLOT (branches resolved in ID
  with 1-cycle flush instead). Real MIPS has a delay slot; we're deviating
  intentionally for the hazard-handling design goal. Documented here so the
  assembler does NOT need to account for delay-slot instruction reordering.
