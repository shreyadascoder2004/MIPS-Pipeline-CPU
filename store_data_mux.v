// =============================================================
// Module      : store_data_mux
// Description : Selects the value to be written by a store
//               instruction (sb/sh/sw/sd). This is ALWAYS the
//               (forwarded) rt register value -- stores never use
//               the ALU result or immediate as their data source in
//               this ISA, only as the address (rs + imm, computed
//               by the ALU separately).
//
//               Reuses the SAME forward_b select signal that
//               ex_forward_mux.v uses for the ALU's rt operand,
//               because the hazard conditions are identical: a
//               store's rt and an R-type instruction's rt operand
//               have the same forwarding requirement (freshest
//               available value for that register). This is why
//               store_data_mux.v takes rt_fwd directly from
//               ex_forward_mux.v's output rather than recomputing
//               forwarding logic independently.
// =============================================================

module store_data_mux (
    input  wire [63:0] rt_fwd,        // from ex_forward_mux.v output
    output wire [63:0] store_data
);

    assign store_data = rt_fwd;

endmodule
