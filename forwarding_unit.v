// =============================================================
// Module      : forwarding_unit
// Description : Resolves RAW data hazards for the EX-stage ALU
//               operands by detecting when a prior in-flight
//               instruction (currently in EX/MEM or MEM/WB) will
//               write the same register that the CURRENT EX-stage
//               instruction needs to read.
//
//               This unit does NOT handle load-use hazards -- a
//               load result is not yet available when the dependent
//               instruction is in EX (it's still in MEM), so no
//               forwarding path exists for that case. That is
//               handled by hazard_detection_unit.v via a pipeline
//               stall instead.
//
//               Priority: EX/MEM (more recently produced) wins over
//               MEM/WB when both would otherwise match. This is
//               correct because EX/MEM holds the result of the
//               instruction immediately preceding MEM/WB's -- i.e.
//               the most up-to-date value for that register.
//
// Forward select encoding (for both forward_a and forward_b):
//   00 = no forwarding -- use the ID/EX-stage register value
//   01 = forward from EX/MEM.alu_result
//   10 = forward from MEM/WB writeback value (post WB-mux)
// =============================================================

module forwarding_unit (
    // current EX-stage instruction's source register addresses
    input  wire [4:0] ex_rs_addr,
    input  wire [4:0] ex_rt_addr,

    // EX/MEM stage (one instruction ahead in the pipeline)
    input  wire [4:0] exmem_write_addr,
    input  wire        exmem_reg_write,
    input  wire        exmem_valid,

    // MEM/WB stage (two instructions ahead)
    input  wire [4:0] memwb_write_addr,
    input  wire        memwb_reg_write,
    input  wire        memwb_valid,

    output reg  [1:0] forward_a,  // for rs operand
    output reg  [1:0] forward_b   // for rt operand
);

    always @(*) begin
        // ---- forward_a (rs) ----
        if (exmem_reg_write && exmem_valid && (exmem_write_addr != 5'd0) &&
            (exmem_write_addr == ex_rs_addr))
            forward_a = 2'b01;
        else if (memwb_reg_write && memwb_valid && (memwb_write_addr != 5'd0) &&
                 (memwb_write_addr == ex_rs_addr))
            forward_a = 2'b10;
        else
            forward_a = 2'b00;

        // ---- forward_b (rt) ----
        if (exmem_reg_write && exmem_valid && (exmem_write_addr != 5'd0) &&
            (exmem_write_addr == ex_rt_addr))
            forward_b = 2'b01;
        else if (memwb_reg_write && memwb_valid && (memwb_write_addr != 5'd0) &&
                 (memwb_write_addr == ex_rt_addr))
            forward_b = 2'b10;
        else
            forward_b = 2'b00;
    end

endmodule
