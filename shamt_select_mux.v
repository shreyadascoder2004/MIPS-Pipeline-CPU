// =============================================================
// Module      : shamt_select_mux
// Description : Selects the ALU's shift-amount input: either the
//               instruction's fixed 5-bit shamt field (sll/srl/sra/
//               dsll/dsrl/dsra) or the low bits of the rs register
//               value (sllv/srlv/srav/dsllv/dsrlv/dsrav -- "variable"
//               shift instructions).
//
//               is_variable_shift is derived from the funct field by
//               the caller (control logic) -- true for the *v-suffix
//               funct codes (see docs/ISA.md: sllv/srlv/srav/dsllv/
//               dsrlv/dsrav).
//
//               For variable shifts, rs_val[5:0] is used regardless
//               of 32/64-bit mode; alu.v itself only consults the
//               low 5 bits (shamt32) when width32=1, so passing the
//               full 6 bits here is always safe.
// =============================================================

module shamt_select_mux (
    input  wire [4:0]  instr_shamt,      // instruction[10:6]
    input  wire [63:0] rs_val,           // for variable shifts
    input  wire         is_variable_shift,

    output wire [5:0]  shamt_out
);

    assign shamt_out = is_variable_shift ? rs_val[5:0] : {1'b0, instr_shamt};

endmodule
