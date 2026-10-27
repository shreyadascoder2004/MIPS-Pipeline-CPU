# ============================================================
# MIPS64-style custom assembler
#
# Input : sw/program.asm
# Output: sw/hex/program.hex
#
# ISA source:
#   Custom MIPS64-style ISA defined for this project.
#
# Instructions:
#   32-bit instructions
#   64-bit GPRs
#   PC increments by 4
#   No branch delay slot
# ============================================================

import re
import sys
from pathlib import Path


# ------------------------------------------------------------
# OPCODES
# ------------------------------------------------------------

OPCODES = {
    "addi":  0b001000,
    "addiu": 0b001001,
    "daddi": 0b011000,
    "daddiu":0b011001,

    "andi":  0b001100,
    "ori":   0b001101,
    "xori":  0b001110,
    "slti":  0b001010,
    "sltiu": 0b001011,
    "lui":   0b001111,

    "lb":    0b100000,
    "lbu":   0b100100,
    "lh":    0b100001,
    "lhu":   0b100101,
    "lw":    0b100011,
    "ld":    0b110111,

    "sb":    0b101000,
    "sh":    0b101001,
    "sw":    0b101011,
    "sd":    0b111111,

    "beq":   0b000100,
    "bne":   0b000101,
    "blez":  0b000110,
    "bgtz":  0b000111,

    "bltz":  0b000001,
    "bgez":  0b000001,

    "j":     0b000010,
    "jal":   0b000011,
}


# ------------------------------------------------------------
# R-TYPE FUNCTS
# ------------------------------------------------------------

FUNCTS = {
    "add":    0b100000,
    "addu":   0b100001,
    "sub":    0b100010,
    "subu":   0b100011,

    "dadd":   0b101100,
    "daddu":  0b101101,
    "dsub":   0b101110,
    "dsubu":  0b101111,

    "and":    0b100100,
    "or":     0b100101,
    "xor":    0b100110,
    "nor":    0b100111,

    "slt":    0b101010,
    "sltu":   0b101011,

    "sll":    0b000000,
    "srl":    0b000010,
    "sra":    0b000011,

    "sllv":   0b000100,
    "srlv":   0b000110,
    "srav":   0b000111,

    "dsll":   0b111000,
    "dsrl":   0b111010,
    "dsra":   0b111011,

    "dsllv":  0b010100,
    "dsrlv":  0b010110,
    "dsrav":  0b010111,

    "jr":     0b001000,
    "jalr":   0b001001,

    "mult":   0b011000,
    "multu":  0b011001,
    "div":    0b011010,
    "divu":   0b011011,

    "dmult":  0b011100,
    "dmultu": 0b011101,
    "ddiv":   0b011110,
    "ddivu":  0b011111,

    "mfhi":   0b010000,
    "mflo":   0b010010,
    "mthi":   0b010001,
    "mtlo":   0b010011,
}


# ------------------------------------------------------------
# REGISTER NAMES
# ------------------------------------------------------------

REGISTERS = {
    "$zero": 0,
    "$0": 0,

    "$at": 1,

    "$v0": 2,
    "$v1": 3,

    "$a0": 4,
    "$a1": 5,
    "$a2": 6,
    "$a3": 7,

    "$t0": 8,
    "$t1": 9,
    "$t2": 10,
    "$t3": 11,
    "$t4": 12,
    "$t5": 13,
    "$t6": 14,
    "$t7": 15,

    "$s0": 16,
    "$s1": 17,
    "$s2": 18,
    "$s3": 19,
    "$s4": 20,
    "$s5": 21,
    "$s6": 22,
    "$s7": 23,

    "$t8": 24,
    "$t9": 25,

    "$k0": 26,
    "$k1": 27,

    "$gp": 28,
    "$sp": 29,
    "$fp": 30,
    "$ra": 31,
}


# Also allow $r0, $r1, ..., $r31
for i in range(32):
    REGISTERS[f"$r{i}"] = i


# ------------------------------------------------------------
# REGISTER PARSER
# ------------------------------------------------------------

def reg_number(reg):
    reg = reg.strip().lower()

    if reg not in REGISTERS:
        raise ValueError(f"Unknown register: {reg}")

    return REGISTERS[reg]


# ------------------------------------------------------------
# INTEGER PARSER
# ------------------------------------------------------------

def parse_int(value):
    """
    Supports:
        10
        -10
        0x10
        -0x10
    """

    value = value.strip()

    try:
        return int(value, 0)
    except ValueError:
        raise ValueError(f"Invalid immediate value: {value}")


# ------------------------------------------------------------
# RANGE CHECK
# ------------------------------------------------------------

def check_signed(value, bits, name="immediate"):
    minimum = -(1 << (bits - 1))
    maximum = (1 << (bits - 1)) - 1

    if not (minimum <= value <= maximum):
        raise ValueError(
            f"{name} {value} does not fit in signed {bits} bits"
        )


def check_unsigned(value, bits, name="value"):
    if not (0 <= value < (1 << bits)):
        raise ValueError(
            f"{name} {value} does not fit in unsigned {bits} bits"
        )


def encode_signed(value, bits):
    return value & ((1 << bits) - 1)


# ------------------------------------------------------------
# TOKENIZATION
# ------------------------------------------------------------

def clean_line(line):
    # Remove comments
    line = line.split("#")[0]
    line = line.split(";")[0]

    return line.strip()


def tokenize(line):
    """
    Converts:

        dadd $t0, $t1, $t2

    into:

        ["dadd", "$t0", "$t1", "$t2"]
    """

    line = line.replace(",", " ")
    line = line.replace("(", " ")
    line = line.replace(")", " ")

    return line.split()


# ------------------------------------------------------------
# MEMORY OPERAND
# ------------------------------------------------------------

def parse_memory_operand(tokens, start_index):
    """
    Example:

        lw $t0, 8($sp)

    becomes:

        register = $t0
        offset   = 8
        base     = $sp
    """

    if len(tokens) < start_index + 3:
        raise ValueError("Invalid memory operand")

    offset = parse_int(tokens[start_index + 1])
    base = reg_number(tokens[start_index + 2])

    return offset, base


# ------------------------------------------------------------
# R-TYPE ENCODER
# ------------------------------------------------------------

def encode_r_type(mnemonic, args):
    funct = FUNCTS[mnemonic]

    # jr
    if mnemonic == "jr":
        if len(args) != 1:
            raise ValueError("jr requires 1 register")

        rs = reg_number(args[0])

        return (
            (0 << 26)
            | (rs << 21)
            | funct
        )

    # jalr
    if mnemonic == "jalr":
        if len(args) == 1:
            rd = 31
            rs = reg_number(args[0])

        elif len(args) == 2:
            rd = reg_number(args[0])
            rs = reg_number(args[1])

        else:
            raise ValueError("jalr syntax: jalr rd, rs")

        return (
            (0 << 26)
            | (rs << 21)
            | (rd << 11)
            | funct
        )

    # mfhi / mflo
    if mnemonic in ("mfhi", "mflo"):
        if len(args) != 1:
            raise ValueError(f"{mnemonic} requires rd")

        rd = reg_number(args[0])

        return (
            (rd << 11)
            | funct
        )

    # mthi / mtlo
    if mnemonic in ("mthi", "mtlo"):
        if len(args) != 1:
            raise ValueError(f"{mnemonic} requires rs")

        rs = reg_number(args[0])

        return (
            (rs << 21)
            | funct
        )

    # mult/div family
    if mnemonic in (
        "mult", "multu",
        "div", "divu",
        "dmult", "dmultu",
        "ddiv", "ddivu"
    ):
        if len(args) != 2:
            raise ValueError(f"{mnemonic} requires rs, rt")

        rs = reg_number(args[0])
        rt = reg_number(args[1])

        return (
            (rs << 21)
            | (rt << 16)
            | funct
        )

    # Variable shifts
    if mnemonic in ("sllv", "srlv", "srav",
                    "dsllv", "dsrlv", "dsrav"):

        if len(args) != 3:
            raise ValueError(f"{mnemonic} requires rd, rt, rs")

        rd = reg_number(args[0])
        rt = reg_number(args[1])
        rs = reg_number(args[2])

        return (
            (rs << 21)
            | (rt << 16)
            | (rd << 11)
            | funct
        )

    # Immediate shift instructions
    if mnemonic in (
        "sll", "srl", "sra",
        "dsll", "dsrl", "dsra"
    ):

        if len(args) != 3:
            raise ValueError(f"{mnemonic} requires rd, rt, shamt")

        rd = reg_number(args[0])
        rt = reg_number(args[1])
        shamt = parse_int(args[2])

        if mnemonic in ("sll", "srl", "sra"):
            check_unsigned(shamt, 5, "shamt")

        else:
            check_unsigned(shamt, 6, "shamt")

        return (
            (rt << 16)
            | (rd << 11)
            | (shamt << 6)
            | funct
        )

    # Normal R-type:
    #
    # add rd, rs, rt
    # dadd rd, rs, rt
    # and rd, rs, rt
    # etc.
    if len(args) != 3:
        raise ValueError(f"{mnemonic} requires rd, rs, rt")

    rd = reg_number(args[0])
    rs = reg_number(args[1])
    rt = reg_number(args[2])

    return (
        (rs << 21)
        | (rt << 16)
        | (rd << 11)
        | funct
    )


# ------------------------------------------------------------
# I-TYPE ENCODER
# ------------------------------------------------------------

def encode_i_type(mnemonic, args, pc, labels):
    opcode = OPCODES[mnemonic]

    # --------------------------------------------------------
    # lui rt, immediate
    # --------------------------------------------------------

    if mnemonic == "lui":

        if len(args) != 2:
            raise ValueError("lui syntax: lui rt, immediate")

        rt = reg_number(args[0])
        imm = parse_int(args[1])

        check_unsigned(imm, 16, "lui immediate")

        return (
            (opcode << 26)
            | (rt << 16)
            | imm
        )

    # --------------------------------------------------------
    # Branches
    # --------------------------------------------------------

    if mnemonic in ("beq", "bne"):

        if len(args) != 3:
            raise ValueError(
                f"{mnemonic} syntax: {mnemonic} rs, rt, label"
            )

        rs = reg_number(args[0])
        rt = reg_number(args[1])

        target = args[2]

        if target in labels:
            target_pc = labels[target]
            offset = (target_pc - (pc + 4)) // 4
        else:
            offset = parse_int(target)

        check_signed(offset, 16, "branch offset")

        return (
            (opcode << 26)
            | (rs << 21)
            | (rt << 16)
            | encode_signed(offset, 16)
        )

    # --------------------------------------------------------
    # blez / bgtz
    # --------------------------------------------------------

    if mnemonic in ("blez", "bgtz"):

        if len(args) != 2:
            raise ValueError(
                f"{mnemonic} syntax: {mnemonic} rs, label"
            )

        rs = reg_number(args[0])
        target = args[1]

        if target in labels:
            target_pc = labels[target]
            offset = (target_pc - (pc + 4)) // 4
        else:
            offset = parse_int(target)

        check_signed(offset, 16, "branch offset")

        return (
            (opcode << 26)
            | (rs << 21)
            | encode_signed(offset, 16)
        )

    # --------------------------------------------------------
    # bltz / bgez
    #
    # opcode = 000001
    # rt = 00000 → bltz
    # rt = 00001 → bgez
    # --------------------------------------------------------

    if mnemonic in ("bltz", "bgez"):

        if len(args) != 2:
            raise ValueError(
                f"{mnemonic} syntax: {mnemonic} rs, label"
            )

        rs = reg_number(args[0])

        rt = 0 if mnemonic == "bltz" else 1

        target = args[1]

        if target in labels:
            target_pc = labels[target]
            offset = (target_pc - (pc + 4)) // 4
        else:
            offset = parse_int(target)

        check_signed(offset, 16, "branch offset")

        return (
            (opcode << 26)
            | (rs << 21)
            | (rt << 16)
            | encode_signed(offset, 16)
        )

    # --------------------------------------------------------
    # Load/store
    #
    # lw rt, offset(rs)
    # --------------------------------------------------------

    if mnemonic in (
        "lb", "lbu",
        "lh", "lhu",
        "lw", "ld",
        "sb", "sh",
        "sw", "sd"
    ):

        if len(args) != 3:
            raise ValueError(
                f"{mnemonic} syntax: {mnemonic} rt, offset(rs)"
            )

        rt = reg_number(args[0])
        offset = parse_int(args[1])
        rs = reg_number(args[2])

        check_signed(offset, 16, "memory offset")

        return (
            (opcode << 26)
            | (rs << 21)
            | (rt << 16)
            | encode_signed(offset, 16)
        )

    # --------------------------------------------------------
    # Normal immediate instruction
    #
    # addi rt, rs, imm
    # daddi rt, rs, imm
    # andi rt, rs, imm
    # etc.
    # --------------------------------------------------------

    if len(args) != 3:
        raise ValueError(
            f"{mnemonic} syntax: {mnemonic} rt, rs, immediate"
        )

    rt = reg_number(args[0])
    rs = reg_number(args[1])
    imm = parse_int(args[2])

    if mnemonic in ("andi", "ori", "xori"):
        check_unsigned(imm, 16, "immediate")

    else:
        check_signed(imm, 16, "immediate")

    return (
        (opcode << 26)
        | (rs << 21)
        | (rt << 16)
        | (imm & 0xFFFF)
    )


# ------------------------------------------------------------
# J-TYPE ENCODER
# ------------------------------------------------------------

def encode_j_type(mnemonic, args, pc, labels):
    opcode = OPCODES[mnemonic]

    if len(args) != 1:
        raise ValueError(f"{mnemonic} requires one target")

    target = args[0]

    if target in labels:
        target_byte_address = labels[target]
    else:
        target_byte_address = parse_int(target)

    if target_byte_address % 4 != 0:
        raise ValueError(
            f"Jump target must be word aligned: {target}"
        )

    # MIPS-style J encoding stores word address.
    address = (target_byte_address >> 2) & 0x03FFFFFF

    return (
        (opcode << 26)
        | address
    )


# ------------------------------------------------------------
# INSTRUCTION ENCODER
# ------------------------------------------------------------

def encode_instruction(line, pc, labels):
    tokens = tokenize(line)

    if not tokens:
        return None

    mnemonic = tokens[0].lower()
    args = tokens[1:]

    if mnemonic == "nop":
        return 0

    if mnemonic in FUNCTS:
        return encode_r_type(mnemonic, args)

    if mnemonic in OPCODES:

        if mnemonic in ("j", "jal"):
            return encode_j_type(
                mnemonic,
                args,
                pc,
                labels
            )

        return encode_i_type(
            mnemonic,
            args,
            pc,
            labels
        )

    raise ValueError(
        f"Unknown instruction '{mnemonic}'"
    )


# ------------------------------------------------------------
# FIRST PASS
# ------------------------------------------------------------

def first_pass(lines):
    labels = {}
    pc = 0

    for line_number, raw_line in enumerate(lines, 1):

        line = clean_line(raw_line)

        if not line:
            continue

        # Allow labels:
        #
        # loop:
        #
        # or:
        #
        # loop: add ...
        while ":" in line:

            label, remainder = line.split(":", 1)

            label = label.strip()

            if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", label):
                raise ValueError(
                    f"Invalid label '{label}' on line {line_number}"
                )

            if label in labels:
                raise ValueError(
                    f"Duplicate label '{label}' on line {line_number}"
                )

            labels[label] = pc

            line = remainder.strip()

            if not line:
                break

        if line:
            pc += 4

    return labels


# ------------------------------------------------------------
# SECOND PASS
# ------------------------------------------------------------

def second_pass(lines, labels):
    machine_code = []

    pc = 0

    for line_number, raw_line in enumerate(lines, 1):

        line = clean_line(raw_line)

        if not line:
            continue

        # Remove labels
        while ":" in line:
            _, line = line.split(":", 1)
            line = line.strip()

        if not line:
            continue

        try:
            instruction = encode_instruction(
                line,
                pc,
                labels
            )

        except Exception as e:
            raise ValueError(
                f"Line {line_number}: {raw_line.strip()}\n"
                f"  {e}"
            )

        machine_code.append(instruction)

        pc += 4

    return machine_code


# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

def main():

    project_root = Path(__file__).resolve().parent

    input_file = project_root / "program.asm"
    output_dir = project_root / "sw" / "hex"
    output_file = output_dir / "program.hex"

    if not input_file.exists():
        print(f"ERROR: Input file not found:")
        print(f"       {input_file}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    with open(input_file, "r") as f:
        lines = f.readlines()

    try:
        labels = first_pass(lines)
        machine_code = second_pass(lines, labels)

    except ValueError as e:
        print("ASSEMBLY ERROR")
        print(e)
        sys.exit(1)

    with open(output_file, "w") as f:
        for instruction in machine_code:
            f.write(f"{instruction:08X}\n")

    print("Assembly successful.")
    print(f"Input : {input_file}")
    print(f"Output: {output_file}")
    print(f"Instructions generated: {len(machine_code)}")

    print()
    print("Labels:")

    for label, address in labels.items():
        print(f"  {label:20s} = 0x{address:016X}")


if __name__ == "__main__":
    main()


