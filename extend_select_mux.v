// =============================================================
// Module      : extend_select_mux
// Description : Selects between sign_extend.v and zero_extend.v
//               outputs based on ext_ctrl (from control_unit.v):
//                 00 = sign-extend (arithmetic immediates, loads/stores)
//                 01 = zero-extend (andi/ori/xori)
//                 10 = lui mode (sign_extend.v's lui_mode output)
//               sign_extend.v's lui_mode input must be driven
//               externally as (ext_ctrl == 2'b10) by the caller --
//               this mux just picks which extended value continues
//               downstream.
// =============================================================

module extend_select_mux (
    input  wire [63:0] sign_ext_out,   // from sign_extend.v (lui_mode already applied upstream)
    input  wire [63:0] zero_ext_out,   // from zero_extend.v
    input  wire [1:0]  ext_ctrl,

    output reg  [63:0] imm_selected
);

    always @(*) begin
        case (ext_ctrl)
            2'b01:   imm_selected = zero_ext_out;
            2'b00,
            2'b10:   imm_selected = sign_ext_out; // both plain-sign and lui modes
                                                    // come from sign_extend.v; its
                                                    // own lui_mode input picks
                                                    // between them internally
            default: imm_selected = sign_ext_out;
        endcase
    end

endmodule
