// =============================================================
// Module      : hazard_detection_unit
// Description : Detects hazards that CANNOT be resolved by
//               forwarding alone and require a pipeline stall.
//
//               Case 1 -- Load-use hazard:
//                 The instruction currently in ID/EX is a load
//                 (mem_read=1). Its result is not available until
//                 the end of MEM, so if the instruction currently in
//                 ID (about to enter EX next cycle) needs that value
//                 as rs or rt, we cannot forward it in time -- must
//                 stall one cycle. After the stall, the value CAN be
//                 forwarded from EX/MEM (this unit only buys the one
//                 cycle; forwarding_unit.v handles the rest).
//
//               Case 2 -- Branch/jr dependency hazard:
//                 A branch (or jr/jalr) is being decoded in ID and
//                 needs a fresh rs (and rt, for beq/bne) value THIS
//                 cycle. If the instruction currently in ID/EX (one
//                 stage ahead, about to enter EX) will write that
//                 same register, no forwarding path can supply it in
//                 time -- forwarding into ID only reaches back to
//                 EX/MEM and MEM/WB, not ID/EX (whose ALU result
//                 doesn't exist until next cycle). Stall one cycle
//                 to let the producer reach EX/MEM, where it becomes
//                 forwardable to the branch comparator.
//
//               Case 3 -- Multiply/Divide busy:
//                 The HI/LO multi-cycle unit is busy computing a
//                 mult/div/dmult/ddiv result. Freeze the entire
//                 pipeline upstream of EX until it completes.
//
//               Outputs (consumed by pc.v, if_id_reg.v, id_ex_reg.v):
//                 pc_write_en = 0  -> freeze PC
//                 if_id_stall = 1  -> freeze IF/ID (hold current instr)
//                 id_ex_flush = 1  -> insert bubble into ID/EX
//
//               Branch/jump misprediction flushing is handled by a
//               SEPARATE signal path (driven by the branch comparator
//               in the ID stage top module), not by this unit -- that
//               is a control hazard, not a data hazard, and the two
//               are kept orthogonal so they can be OR'd together
//               cleanly at the pc.v / if_id_reg.v inputs upstream.
// =============================================================

module hazard_detection_unit (
    // ID/EX stage: instruction that just entered EX (or is about to)
    input  wire         idex_mem_read,     // is it a load?
    input  wire         idex_reg_write,    // does it write a GPR at all?
    input  wire [4:0]   idex_rt_addr,      // load's destination register
    input  wire [4:0]   idex_write_addr,   // general destination register (RegDst-resolved)

    // ID stage: instruction currently being decoded
    input  wire [4:0]   id_rs_addr,
    input  wire [4:0]   id_rt_addr,
    input  wire         id_is_branch_or_jr, // branch, jr, or jalr (needs fresh rs/rt THIS cycle)

    // multi-cycle mult/div busy signal (from hilo_unit.v, built later)
    input  wire         mult_div_busy,

    output wire         pc_write_en,   // 0 = stall PC
    output wire         if_id_stall,   // 1 = hold IF/ID contents
    output wire         id_ex_flush    // 1 = insert bubble into ID/EX
);

    wire load_use_hazard;
    wire branch_dependency_hazard;

    assign load_use_hazard = idex_mem_read &&
                              ( (idex_rt_addr == id_rs_addr) ||
                                (idex_rt_addr == id_rt_addr) ) &&
                              (idex_rt_addr != 5'd0); // $0 can't be a real hazard target

    // Branch/jr/jalr in ID needs a FRESH value for rs (and rt, for
    // beq/bne) this very cycle. The forwarding_unit.v/id-stage
    // forwarding mux can supply values from EX/MEM and MEM/WB, but
    // NOT from ID/EX (that instruction's ALU result doesn't exist
    // until it reaches EX next cycle). So if the ID/EX instruction
    // will write a register that this branch reads, we must stall
    // one cycle to let it advance into EX/MEM where it becomes
    // forwardable.
    assign branch_dependency_hazard = id_is_branch_or_jr && idex_reg_write &&
                              ( (idex_write_addr == id_rs_addr) ||
                                (idex_write_addr == id_rt_addr) ) &&
                              (idex_write_addr != 5'd0);

    wire stall_needed = load_use_hazard || branch_dependency_hazard || mult_div_busy;

    assign pc_write_en = !stall_needed;
    assign if_id_stall = stall_needed;
    assign id_ex_flush = stall_needed;

endmodule
