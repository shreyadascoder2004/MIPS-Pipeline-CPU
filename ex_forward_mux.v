// =============================================================
// Module      : ex_forward_mux
// Description : Applies the forward_a / forward_b select signals
//               (from forwarding_unit.v) to choose each ALU
//               operand's actual source value:
//                 00 = ID/EX stage value (no hazard)
//                 01 = EX/MEM stage result (forward from 1 ahead)
//                 10 = MEM/WB stage result (forward from 2 ahead)
//
//               Produces the FORWARDED register values (rs_fwd,
//               rt_fwd) -- these then still need to pass through
//               alusrc_mux.v (which picks between rt_fwd and the
//               immediate) before reaching the ALU's B input. The
//               ALU's A input uses rs_fwd directly (no immediate
//               option for operand A in this ISA).
// =============================================================

module ex_forward_mux (
    input  wire [63:0] idex_read_data1,  // rs, raw from ID/EX register
    input  wire [63:0] idex_read_data2,  // rt, raw from ID/EX register

    input  wire [63:0] exmem_result,     // EX/MEM ALU result
    input  wire [63:0] memwb_result,     // MEM/WB post-WB-mux value

    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,

    output reg  [63:0] rs_fwd,
    output reg  [63:0] rt_fwd
);

    always @(*) begin
        case (forward_a)
            2'b01:   rs_fwd = exmem_result;
            2'b10:   rs_fwd = memwb_result;
            default: rs_fwd = idex_read_data1;
        endcase

        case (forward_b)
            2'b01:   rt_fwd = exmem_result;
            2'b10:   rt_fwd = memwb_result;
            default: rt_fwd = idex_read_data2;
        endcase
    end

endmodule
