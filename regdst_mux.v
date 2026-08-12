// =============================================================
// Module      : regdst_mux
// Description : Selects the destination register field for
//               writeback: rd (R-type) or rt (I-type).
// =============================================================

module regdst_mux (
    input  wire [4:0] rt_addr,
    input  wire [4:0] rd_addr,
    input  wire         reg_dst,   // 0 = rt, 1 = rd
    output wire [4:0]  write_addr
);

    assign write_addr = reg_dst ? rd_addr : rt_addr;

endmodule
