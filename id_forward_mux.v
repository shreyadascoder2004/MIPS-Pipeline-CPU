// =============================================================
// Module      : id_forward_mux
// Description : Supplies "fresh" rs/rt values to the ID-stage
//               branch comparator (branch_unit.v) and jump unit
//               (jump_unit.v's jr/jalr path), forwarding from
//               EX/MEM and MEM/WB when the register file's stored
//               value would be stale.
//
//               This is DIFFERENT from forwarding_unit.v, which
//               feeds the EX-stage ALU operands. This unit feeds
//               the ID stage instead, which is why it can only
//               reach back to EX/MEM and MEM/WB (not ID/EX -- see
//               hazard_detection_unit.v's branch_dependency_hazard,
//               which stalls for the one case this mux cannot cover).
//
//               Priority: EX/MEM wins over MEM/WB (same rule as
//               forwarding_unit.v, same reasoning: more recent
//               producer).
//
//               Also forwards from the register-file's own
//               same-cycle write-first bypass implicitly -- that's
//               already handled inside reg_file.v itself, so this
//               mux only needs to consider EX/MEM and MEM/WB.
// =============================================================

module id_forward_mux (
    input  wire [4:0]  id_rs_addr,
    input  wire [4:0]  id_rt_addr,

    input  wire [63:0] regfile_rs_val,   // raw register-file read (may be stale)
    input  wire [63:0] regfile_rt_val,

    input  wire [4:0]  exmem_write_addr,
    input  wire         exmem_reg_write,
    input  wire         exmem_valid,
    input  wire [63:0] exmem_result,     // EX/MEM ALU result

    input  wire [4:0]  memwb_write_addr,
    input  wire         memwb_reg_write,
    input  wire         memwb_valid,
    input  wire [63:0] memwb_result,     // MEM/WB post-WB-mux value

    output reg  [63:0] rs_val_fwd,
    output reg  [63:0] rt_val_fwd
);

    always @(*) begin
        // ---- rs ----
        if (exmem_reg_write && exmem_valid && (exmem_write_addr != 5'd0) &&
            (exmem_write_addr == id_rs_addr))
            rs_val_fwd = exmem_result;
        else if (memwb_reg_write && memwb_valid && (memwb_write_addr != 5'd0) &&
                 (memwb_write_addr == id_rs_addr))
            rs_val_fwd = memwb_result;
        else
            rs_val_fwd = regfile_rs_val;

        // ---- rt ----
        if (exmem_reg_write && exmem_valid && (exmem_write_addr != 5'd0) &&
            (exmem_write_addr == id_rt_addr))
            rt_val_fwd = exmem_result;
        else if (memwb_reg_write && memwb_valid && (memwb_write_addr != 5'd0) &&
                 (memwb_write_addr == id_rt_addr))
            rt_val_fwd = memwb_result;
        else
            rt_val_fwd = regfile_rt_val;
    end

endmodule
