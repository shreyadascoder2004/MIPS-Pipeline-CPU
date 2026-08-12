// =============================================================
// Module      : mips64_top
// Description : Top-level 5-stage MIPS64-style pipeline.
//               IF -> ID -> EX -> MEM -> WB
//
//               This is the Vivado synthesis TOP module. All 25
//               sub-modules are instantiated directly here (flat
//               structure), matching the project's build convention.
//
//               Stage boundaries are marked by comments. Signal
//               naming convention: <stage>_<signal> for stage-local
//               wires, <stageA>_<stageB>_<signal> is avoided in favor
//               of just using the pipeline register's own out ports
//               directly (e.g. idex_reg_write_out) to avoid renaming
//               churn.
// =============================================================

module mips64_top #(
    parameter IMEM_DEPTH_WORDS = 1024,
    parameter DMEM_DEPTH_BYTES = 8192
) (
    input  wire clk,
    input  wire rst_n
);

    // =========================================================
    // ============ IF STAGE ==================================
    // =========================================================

    wire [63:0] if_pc_out;
    wire [63:0] if_pc_next;
    wire        if_pc_write_en;
    wire [31:0] if_instr_out;
    wire [63:0] if_pc_plus4 = if_pc_out + 64'd4;

    pc u_pc (
        .clk(clk), .rst_n(rst_n),
        .pc_write_en(if_pc_write_en),
        .pc_next(if_pc_next),
        .pc_out(if_pc_out)
    );

    instr_mem #(.MEM_DEPTH_WORDS(IMEM_DEPTH_WORDS)) u_instr_mem (
        .addr(if_pc_out),
        .instr_out(if_instr_out)
    );

    // pc_src_mux, branch_unit and jump_unit outputs (from ID stage,
    // since branches/jumps resolve there) feed back here -- declared
    // now, driven later once ID stage wires exist (Verilog allows
    // forward wire references within a single module).
    wire        id_branch_taken;
    wire [63:0] id_branch_target;
    wire [63:0] id_jump_target;
    wire        id_jump;
    wire        id_jump_reg;

    pc_src_mux u_pc_src_mux (
        .pc_plus4(if_pc_plus4),
        .branch_target(id_branch_target),
        .jump_target(id_jump_target),
        .branch_taken(id_branch_taken),
        .jump(id_jump),
        .jump_reg(id_jump_reg),
        .pc_next(if_pc_next)
    );

    // Hazard-driven flush for a taken branch/jump: squash the
    // instruction that was speculatively fetched into IF/ID.
    //
    // CRITICAL: pcsrc_change must NOT fire while hz_if_id_stall is
    // active for THIS SAME instruction (branch-dependency hazard).
    // Without this gate, a branch depending on its immediately
    // preceding instruction would resolve one cycle too early using
    // a stale (not-yet-forwarded) operand, racing against the stall
    // that's supposed to delay it -- id_branch_taken/id_jump can
    // still be combinationally "true" from stale data during the
    // stall cycle even though the branch hasn't actually been
    // correctly evaluated yet. Gating on !hz_if_id_stall ensures the
    // branch/jump is only allowed to actually change the PC on a
    // cycle where the pipeline is NOT stalling this instruction --
    // i.e. after the stall has let the producer reach EX/MEM and
    // id_forward_mux.v supplies the correct forwarded value.
    wire pcsrc_change = (id_branch_taken || id_jump || id_jump_reg) && !hz_if_id_stall;

    // =========================================================
    // ============ IF/ID PIPELINE REGISTER ====================
    // =========================================================

    wire        hz_pc_write_en, hz_if_id_stall, hz_id_ex_flush;

    assign if_pc_write_en = hz_pc_write_en;

    wire [31:0] ifid_instr_out;
    wire [63:0] ifid_pc_plus4_out;
    wire        ifid_valid_out;

    if_id_reg u_if_id_reg (
        .clk(clk), .rst_n(rst_n),
        .stall(hz_if_id_stall),
        .flush(pcsrc_change),          // taken branch/jump squashes IF/ID
        .instr_in(if_instr_out),
        .pc_plus4_in(if_pc_plus4),
        .instr_out(ifid_instr_out),
        .pc_plus4_out(ifid_pc_plus4_out),
        .valid_out(ifid_valid_out)
    );

    // =========================================================
    // ============ ID STAGE ===================================
    // =========================================================

    // ---- instruction field decode (pure wire slicing) ----
    wire [5:0]  id_opcode      = ifid_instr_out[31:26];
    wire [4:0]  id_rs          = ifid_instr_out[25:21];
    wire [4:0]  id_rt          = ifid_instr_out[20:16];
    wire [4:0]  id_rd          = ifid_instr_out[15:11];
    wire [4:0]  id_shamt_field = ifid_instr_out[10:6];
    wire [5:0]  id_funct       = ifid_instr_out[5:0];
    wire [15:0] id_imm16       = ifid_instr_out[15:0];
    wire [25:0] id_jump_index  = ifid_instr_out[25:0];

    // ---- main control unit ----
    wire        id_reg_dst, id_alu_src, id_reg_write, id_mem_read, id_mem_write;
    wire        id_branch_en, id_jump_c, id_jump_link, id_jump_reg_c;
    wire        id_alu_width64, id_mem_unsigned, id_is_mult_div, id_mult_div_signed;
    wire        id_illegal_instr;
    wire [1:0]  id_mem_to_reg, id_ext_ctrl;
    wire [2:0]  id_branch_type, id_alu_op, id_mem_width;

    control_unit u_control_unit (
        .opcode(id_opcode), .funct(id_funct), .rt_field(id_rt),
        .reg_dst(id_reg_dst), .alu_src(id_alu_src), .mem_to_reg(id_mem_to_reg),
        .reg_write(id_reg_write), .mem_read(id_mem_read), .mem_write(id_mem_write),
        .branch(id_branch_en), .branch_type(id_branch_type),
        .jump(id_jump_c), .jump_link(id_jump_link), .jump_reg(id_jump_reg_c),
        .alu_op(id_alu_op), .alu_width64(id_alu_width64), .ext_ctrl(id_ext_ctrl),
        .mem_width(id_mem_width), .mem_unsigned(id_mem_unsigned),
        .is_mult_div(id_is_mult_div), .mult_div_signed(id_mult_div_signed),
        .illegal_instr(id_illegal_instr)
    );

    assign id_jump      = id_jump_c;      // drive IF-stage forward-declared wire
    assign id_jump_reg   = id_jump_reg_c;

    // ---- register file ----
    wire [63:0] id_read_data1, id_read_data2;
    wire        wb_reg_write;
    wire [4:0]  wb_write_addr;
    wire [63:0] wb_write_back_data;

    reg_file u_reg_file (
        .clk(clk), .rst_n(rst_n),
        .read_addr1(id_rs), .read_addr2(id_rt),
        .read_data1(id_read_data1), .read_data2(id_read_data2),
        .write_en(wb_reg_write), .write_addr(wb_write_addr), .write_data(wb_write_back_data)
    );

    // ---- sign/zero extend ----
    wire [63:0] id_sign_ext_out, id_zero_ext_out, id_imm_selected;
    wire        id_lui_mode = (id_ext_ctrl == 2'b10);

    sign_extend u_sign_extend (.imm_in(id_imm16), .lui_mode(id_lui_mode), .ext_out(id_sign_ext_out));
    zero_extend u_zero_extend (.imm_in(id_imm16), .ext_out(id_zero_ext_out));
    extend_select_mux u_extend_select_mux (
        .sign_ext_out(id_sign_ext_out), .zero_ext_out(id_zero_ext_out),
        .ext_ctrl(id_ext_ctrl), .imm_selected(id_imm_selected)
    );

    // ---- ALU control (resolves exact ALU opcode already in ID) ----
    wire [4:0] id_alu_ctrl;
    wire       id_opcode_lsb = id_opcode[0];

    alu_control u_alu_control (
        .alu_op(id_alu_op), .funct(id_funct), .opcode_lsb(id_opcode_lsb),
        .alu_ctrl(id_alu_ctrl)
    );

    // ---- shift-amount select (fixed shamt field vs variable rs[5:0]) ----
    // *v-suffix funct codes: sllv=000100 srlv=000110 srav=000111
    //                        dsllv=010100 dsrlv=010110 dsrav=010111
    wire id_is_variable_shift = (id_opcode == 6'b000000) &&
                                 ( (id_funct == 6'b000100) || (id_funct == 6'b000110) ||
                                   (id_funct == 6'b000111) || (id_funct == 6'b010100) ||
                                   (id_funct == 6'b010110) || (id_funct == 6'b010111) );

    // ---- shift-amount resolution (ID stage) ----
    // For variable shifts (sllv/srlv/srav/dsllv/dsrlv/dsrav), the shift
    // amount comes from rs[5:0] -- and must use the FORWARDED rs value
    // (id_rs_val_fwd), not the raw register-file read, for the same
    // reason branches need forwarded operands. For fixed shifts, the
    // instruction's own shamt field is used. This resolution happens
    // HERE (in ID) and the result rides through ID/EX as idex_shamt_out
    // -- there is no separate "is_variable_shift" flag needed downstream
    // because the correct 6-bit value is already selected before EX.
    wire [5:0] id_shamt_resolved;
    shamt_select_mux u_shamt_select_mux (
        .instr_shamt(id_shamt_field), .rs_val(id_rs_val_fwd),
        .is_variable_shift(id_is_variable_shift), .shamt_out(id_shamt_resolved)
    );

    // ---- ID-stage forwarding mux (for branch comparator + jr target) ----
    wire [63:0] exmem_alu_result_fwd;   // from EX/MEM reg, declared later
    wire        exmem_reg_write_fwd;
    wire        exmem_valid_fwd;
    wire [4:0]  exmem_write_addr_fwd;
    wire [63:0] memwb_wb_data_fwd;      // from MEM/WB reg (post WB mux), declared later
    wire        memwb_reg_write_fwd;
    wire        memwb_valid_fwd;
    wire [4:0]  memwb_write_addr_fwd;

    wire [63:0] id_rs_val_fwd, id_rt_val_fwd;

    id_forward_mux u_id_forward_mux (
        .id_rs_addr(id_rs), .id_rt_addr(id_rt),
        .regfile_rs_val(id_read_data1), .regfile_rt_val(id_read_data2),
        .exmem_write_addr(exmem_write_addr_fwd), .exmem_reg_write(exmem_reg_write_fwd),
        .exmem_valid(exmem_valid_fwd), .exmem_result(exmem_alu_result_fwd),
        .memwb_write_addr(memwb_write_addr_fwd), .memwb_reg_write(memwb_reg_write_fwd),
        .memwb_valid(memwb_valid_fwd), .memwb_result(memwb_wb_data_fwd),
        .rs_val_fwd(id_rs_val_fwd), .rt_val_fwd(id_rt_val_fwd)
    );

    // ---- branch resolution (ID stage) ----
    branch_unit u_branch_unit (
        .rs_val(id_rs_val_fwd), .rt_val(id_rt_val_fwd),
        .branch_type(id_branch_type), .branch_en(id_branch_en),
        .pc_plus4(ifid_pc_plus4_out), .imm_sext(id_sign_ext_out),
        .branch_taken(id_branch_taken), .branch_target(id_branch_target)
    );

    // ---- jump target (j/jal region-jump or jr/jalr register-sourced) ----
    jump_unit u_jump_unit (
        .pc_plus4(ifid_pc_plus4_out), .instr_index(id_jump_index),
        .rs_val(id_rs_val_fwd),
        .jump(id_jump_c), .jump_reg(id_jump_reg_c),
        .jump_target(id_jump_target)
    );

    // ---- RegDst mux (destination register selection) ----
    wire [4:0] id_write_addr;
    regdst_mux u_regdst_mux (
        .rt_addr(id_rt), .rd_addr(id_rd), .reg_dst(id_reg_dst),
        .write_addr(id_write_addr)
    );

    // ---- mult/div sub-decode (derived directly from funct; narrow-
    //      purpose signals not worth adding to control_unit.v's
    //      already-large port list) ----
    // is_divide: funct bit[1] distinguishes div-family from mult-family
    // within the mult/div funct group (see docs/ISA.md): 011000=mult,
    // 011001=multu, 011010=div, 011011=divu, 011100=dmult, 011101=dmultu,
    // 011110=ddiv, 011111=ddivu.
    wire id_mult_div_is_divide = id_funct[1];

    // hilo_sel_hi: for mfhi/mflo (funct 010000/010010), select HI (1)
    // vs LO (0).
    wire id_hilo_sel_hi = (id_funct == 6'b010000); // F_MFHI

    // mthi/mtlo: direct HI/LO writes from rs (funct 010001/010011).
    // Only meaningful when opcode is R-type; guarded accordingly.
    wire id_hi_write = (id_opcode == 6'b000000) && (id_funct == 6'b010001); // F_MTHI
    wire id_lo_write = (id_opcode == 6'b000000) && (id_funct == 6'b010011); // F_MTLO

    // ---- hazard detection (load-use, branch-dependency, mult/div busy) ----
    wire idex_mem_read_fwd, idex_reg_write_fwd;
    wire [4:0] idex_rt_addr_fwd, idex_write_addr_fwd;
    wire mult_div_busy_fwd;
    wire id_is_branch_or_jr = id_branch_en || id_jump_reg_c;

    hazard_detection_unit u_hazard_detection_unit (
        .idex_mem_read(idex_mem_read_fwd), .idex_reg_write(idex_reg_write_fwd),
        .idex_rt_addr(idex_rt_addr_fwd), .idex_write_addr(idex_write_addr_fwd),
        .id_rs_addr(id_rs), .id_rt_addr(id_rt),
        .id_is_branch_or_jr(id_is_branch_or_jr),
        .mult_div_busy(mult_div_busy_fwd),
        .pc_write_en(hz_pc_write_en), .if_id_stall(hz_if_id_stall), .id_ex_flush(hz_id_ex_flush)
    );

    // =========================================================
    // ============ ID/EX PIPELINE REGISTER ====================
    // =========================================================

    wire idex_reg_dst_out, idex_alu_src_out, idex_reg_write_out, idex_mem_read_out, idex_mem_write_out;
    wire idex_branch_out, idex_jump_out, idex_jump_link_out, idex_jump_reg_out;
    wire idex_alu_width64_out, idex_mem_unsigned_out, idex_is_mult_div_out, idex_mult_div_signed_out;
    wire idex_mult_div_is_divide_out, idex_hilo_sel_hi_out;
    wire idex_hi_write_out, idex_lo_write_out;
    wire idex_valid_out;
    wire [1:0] idex_mem_to_reg_out;
    wire [2:0] idex_branch_type_out, idex_mem_width_out;
    wire [4:0] idex_alu_ctrl_out, idex_rs_addr_out, idex_rt_addr_out, idex_rd_addr_out;
    wire [5:0] idex_shamt_out;
    wire [63:0] idex_read_data1_out, idex_read_data2_out, idex_imm_ext_out, idex_pc_plus4_out;

    // id_ex_flush is asserted for load-use/branch-dep stalls AND for a
    // taken branch/jump (pcsrc_change) -- BUT NOT for mult/div busy.
    // During a mult/div busy stall, the instruction already sitting in
    // ID/EX (the one being computed by hilo_unit) must be HELD, not
    // flushed or re-latched -- flushing it would erase the very
    // instruction whose result we're waiting for; re-latching it (the
    // old bug) would silently overwrite it with whatever is stalled
    // behind it in ID, corrupting the in-flight computation. So:
    //   - hz_if_id_stall (asserted for ALL THREE hazard cases) holds
    //     IF/ID for load-use, branch-dep, AND mult/div busy alike.
    //   - id_ex STALL (not flush) must ALSO be asserted specifically
    //     during mult/div busy, to hold the mult/div instruction in
    //     place while hilo_unit works.
    //   - id_ex FLUSH covers load-use and branch-dep bubbles (where the
    //     ID/EX slot legitimately becomes empty for one cycle) and
    //     taken branch/jump squashes.
    wire idex_stall_combined  = mult_div_busy_fwd;
    wire idex_flush_combined  = (hz_id_ex_flush && !mult_div_busy_fwd) || pcsrc_change;

    id_ex_reg u_id_ex_reg (
        .clk(clk), .rst_n(rst_n),
        .stall(idex_stall_combined),
        .flush(idex_flush_combined),
        .reg_dst_in(id_reg_dst), .alu_src_in(id_alu_src), .mem_to_reg_in(id_mem_to_reg),
        .reg_write_in(id_reg_write), .mem_read_in(id_mem_read), .mem_write_in(id_mem_write),
        .branch_in(id_branch_en), .branch_type_in(id_branch_type),
        .jump_in(id_jump_c), .jump_link_in(id_jump_link), .jump_reg_in(id_jump_reg_c),
        .alu_ctrl_in(id_alu_ctrl), .alu_width64_in(id_alu_width64),
        .mem_width_in(id_mem_width), .mem_unsigned_in(id_mem_unsigned),
        .is_mult_div_in(id_is_mult_div), .mult_div_signed_in(id_mult_div_signed),
        .mult_div_is_divide_in(id_mult_div_is_divide), .hilo_sel_hi_in(id_hilo_sel_hi),
        .hi_write_in(id_hi_write), .lo_write_in(id_lo_write),
        .read_data1_in(id_rs_val_fwd), .read_data2_in(id_rt_val_fwd),
        .imm_ext_in(id_imm_selected), .pc_plus4_in(ifid_pc_plus4_out),
        .rs_addr_in(id_rs), .rt_addr_in(id_rt), .rd_addr_in(id_rd),
        .shamt_in(id_shamt_resolved), .valid_in(ifid_valid_out),

        .reg_dst_out(idex_reg_dst_out), .alu_src_out(idex_alu_src_out), .mem_to_reg_out(idex_mem_to_reg_out),
        .reg_write_out(idex_reg_write_out), .mem_read_out(idex_mem_read_out), .mem_write_out(idex_mem_write_out),
        .branch_out(idex_branch_out), .branch_type_out(idex_branch_type_out),
        .jump_out(idex_jump_out), .jump_link_out(idex_jump_link_out), .jump_reg_out(idex_jump_reg_out),
        .alu_ctrl_out(idex_alu_ctrl_out), .alu_width64_out(idex_alu_width64_out),
        .mem_width_out(idex_mem_width_out), .mem_unsigned_out(idex_mem_unsigned_out),
        .is_mult_div_out(idex_is_mult_div_out), .mult_div_signed_out(idex_mult_div_signed_out),
        .mult_div_is_divide_out(idex_mult_div_is_divide_out), .hilo_sel_hi_out(idex_hilo_sel_hi_out),
        .hi_write_out(idex_hi_write_out), .lo_write_out(idex_lo_write_out),
        .read_data1_out(idex_read_data1_out), .read_data2_out(idex_read_data2_out),
        .imm_ext_out(idex_imm_ext_out), .pc_plus4_out(idex_pc_plus4_out),
        .rs_addr_out(idex_rs_addr_out), .rt_addr_out(idex_rt_addr_out), .rd_addr_out(idex_rd_addr_out),
        .shamt_out(idex_shamt_out), .valid_out(idex_valid_out)
    );

    // drive hazard-unit forward-declared wires now that ID/EX outputs exist
    assign idex_mem_read_fwd   = idex_mem_read_out;
    assign idex_reg_write_fwd  = idex_reg_write_out;
    assign idex_rt_addr_fwd    = idex_rt_addr_out;

    // idex_write_addr_fwd needs the SAME RegDst resolution that will
    // happen for this instruction once it's actually in EX -- but
    // RegDst only depends on rd/rt/reg_dst, all of which already rode
    // through ID/EX, so we can resolve it right here for hazard-unit
    // purposes without waiting for the EX-stage regdst_mux instance.
    wire [4:0] idex_write_addr_precompute;
    regdst_mux u_regdst_mux_idex_precompute (
        .rt_addr(idex_rt_addr_out), .rd_addr(idex_rd_addr_out), .reg_dst(idex_reg_dst_out),
        .write_addr(idex_write_addr_precompute)
    );
    assign idex_write_addr_fwd = idex_write_addr_precompute;

    // =========================================================
    // ============ EX STAGE ===================================
    // =========================================================

    // ---- EX-stage forwarding (for ALU operands) ----
    wire [1:0] ex_forward_a, ex_forward_b;

    forwarding_unit u_forwarding_unit (
        .ex_rs_addr(idex_rs_addr_out), .ex_rt_addr(idex_rt_addr_out),
        .exmem_write_addr(exmem_write_addr_fwd), .exmem_reg_write(exmem_reg_write_fwd),
        .exmem_valid(exmem_valid_fwd),
        .memwb_write_addr(memwb_write_addr_fwd), .memwb_reg_write(memwb_reg_write_fwd),
        .memwb_valid(memwb_valid_fwd),
        .forward_a(ex_forward_a), .forward_b(ex_forward_b)
    );

    wire [63:0] ex_rs_fwd, ex_rt_fwd;

    ex_forward_mux u_ex_forward_mux (
        .idex_read_data1(idex_read_data1_out), .idex_read_data2(idex_read_data2_out),
        .exmem_result(exmem_alu_result_fwd), .memwb_result(memwb_wb_data_fwd),
        .forward_a(ex_forward_a), .forward_b(ex_forward_b),
        .rs_fwd(ex_rs_fwd), .rt_fwd(ex_rt_fwd)
    );

    // ---- ALUSrc mux ----
    wire [63:0] ex_alu_operand_b;
    alusrc_mux u_alusrc_mux (
        .reg_val(ex_rt_fwd), .imm_ext(idex_imm_ext_out), .alu_src(idex_alu_src_out),
        .alu_operand_b(ex_alu_operand_b)
    );

    // ---- ALU ----
    wire [63:0] ex_alu_result;
    wire        ex_alu_zero, ex_alu_overflow;

    alu u_alu (
        .operand_a(ex_rs_fwd), .operand_b(ex_alu_operand_b),
        .alu_ctrl(idex_alu_ctrl_out), .width32(~idex_alu_width64_out),
        .shamt_in(idex_shamt_out),
        .result(ex_alu_result), .zero(ex_alu_zero), .overflow(ex_alu_overflow)
    );

    // ---- store-data forwarding (value to write for sb/sh/sw/sd) ----
    wire [63:0] ex_store_data;
    store_data_mux u_store_data_mux (.rt_fwd(ex_rt_fwd), .store_data(ex_store_data));

    // ---- destination register (RegDst already resolved once for
    //      hazard-unit lookahead; resolve again here for the actual
    //      EX-stage datapath value that continues to EX/MEM) ----
    wire [4:0] ex_write_addr;
    regdst_mux u_regdst_mux_ex (
        .rt_addr(idex_rt_addr_out), .rd_addr(idex_rd_addr_out), .reg_dst(idex_reg_dst_out),
        .write_addr(ex_write_addr)
    );

    // ---- HI/LO multiply/divide unit ----
    // start pulses for exactly one cycle: the cycle idex_is_mult_div_out
    // first becomes true for a NEW instruction. We detect "new" by also
    // requiring the unit not already be busy (busy stays high across
    // the multi-cycle op, and the hazard unit stalls the pipeline for
    // the whole duration, so idex_is_mult_div_out stays asserted on the
    // SAME stalled instruction the entire time -- start must pulse only
    // once, on the first such cycle).
    wire hilo_busy;
    reg  hilo_start_prev_busy;
    wire hilo_start = idex_is_mult_div_out && !hilo_busy && !hilo_start_prev_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) hilo_start_prev_busy <= 1'b0;
        else        hilo_start_prev_busy <= hilo_busy || hilo_start;
    end

    wire [63:0] hilo_hi_out, hilo_lo_out;
    hilo_unit u_hilo_unit (
        .clk(clk), .rst_n(rst_n),
        .start(hilo_start), .is_divide(idex_mult_div_is_divide_out),
        .is_signed(idex_mult_div_signed_out), .width64(idex_alu_width64_out),
        .operand_a(ex_rs_fwd), .operand_b(ex_rt_fwd),
        .hi_write(idex_hi_write_out), .lo_write(idex_lo_write_out),
        .hi_write_data(ex_rs_fwd), .lo_write_data(ex_rs_fwd),
        .busy(hilo_busy), .done(), .hi_out(hilo_hi_out), .lo_out(hilo_lo_out)
    );

    assign mult_div_busy_fwd = hilo_busy;

    // HI/LO result selection for mfhi/mflo (mem_to_reg==11): LO for
    // mflo, HI for mfhi -- resolved via idex_hilo_sel_hi_out, which
    // rode through ID/EX alongside the rest of this instruction's
    // control bundle.
    wire [63:0] ex_hilo_result = idex_hilo_sel_hi_out ? hilo_hi_out : hilo_lo_out;

    // =========================================================
    // ============ EX/MEM PIPELINE REGISTER ===================
    // =========================================================

    wire [1:0]  exmem_mem_to_reg_out;
    wire        exmem_reg_write_out2, exmem_mem_read_out, exmem_mem_write_out, exmem_jump_link_out, exmem_valid_out2;
    wire [2:0]  exmem_mem_width_out;
    wire        exmem_mem_unsigned_out;
    wire [63:0] exmem_alu_result_out, exmem_write_data_out, exmem_pc_plus4_out;
    wire [4:0]  exmem_write_addr_out;

    ex_mem_reg u_ex_mem_reg (
        .clk(clk), .rst_n(rst_n),
        .stall(1'b0), .flush(1'b0),
        .mem_to_reg_in(idex_mem_to_reg_out), .reg_write_in(idex_reg_write_out),
        .mem_read_in(idex_mem_read_out), .mem_write_in(idex_mem_write_out),
        .mem_width_in(idex_mem_width_out), .mem_unsigned_in(idex_mem_unsigned_out),
        .jump_link_in(idex_jump_link_out),
        .alu_result_in(ex_alu_result), .write_data_in(ex_store_data),
        .pc_plus4_in(idex_pc_plus4_out), .write_addr_in(ex_write_addr), .valid_in(idex_valid_out),

        .mem_to_reg_out(exmem_mem_to_reg_out), .reg_write_out(exmem_reg_write_out2),
        .mem_read_out(exmem_mem_read_out), .mem_write_out(exmem_mem_write_out),
        .mem_width_out(exmem_mem_width_out), .mem_unsigned_out(exmem_mem_unsigned_out),
        .jump_link_out(exmem_jump_link_out),
        .alu_result_out(exmem_alu_result_out), .write_data_out(exmem_write_data_out),
        .pc_plus4_out(exmem_pc_plus4_out), .write_addr_out(exmem_write_addr_out), .valid_out(exmem_valid_out2)
    );

    // drive the forward-declared EX/MEM forwarding wires
    assign exmem_alu_result_fwd = exmem_alu_result_out;
    assign exmem_reg_write_fwd  = exmem_reg_write_out2;
    assign exmem_valid_fwd      = exmem_valid_out2;
    assign exmem_write_addr_fwd = exmem_write_addr_out;

    // =========================================================
    // ============ MEM STAGE ==================================
    // =========================================================

    wire [63:0] mem_read_data;

    data_mem #(.MEM_DEPTH_BYTES(DMEM_DEPTH_BYTES)) u_data_mem (
        .clk(clk), .addr(exmem_alu_result_out), .write_data(exmem_write_data_out),
        .mem_read(exmem_mem_read_out), .mem_write(exmem_mem_write_out),
        .mem_width(exmem_mem_width_out), .mem_unsigned(exmem_mem_unsigned_out),
        .read_data(mem_read_data)
    );

    // =========================================================
    // ============ MEM/WB PIPELINE REGISTER ===================
    // =========================================================

    wire [1:0]  memwb_mem_to_reg_out;
    wire        memwb_reg_write_out2, memwb_valid_out2;
    wire [63:0] memwb_alu_result_out, memwb_mem_read_data_out, memwb_pc_plus4_out, memwb_hilo_result_out;
    wire [4:0]  memwb_write_addr_out;

    mem_wb_reg u_mem_wb_reg (
        .clk(clk), .rst_n(rst_n),
        .stall(1'b0), .flush(1'b0),
        .mem_to_reg_in(exmem_mem_to_reg_out), .reg_write_in(exmem_reg_write_out2),
        .alu_result_in(exmem_alu_result_out), .mem_read_data_in(mem_read_data),
        .pc_plus4_in(exmem_pc_plus4_out), .hilo_result_in(ex_hilo_result),
        .write_addr_in(exmem_write_addr_out), .valid_in(exmem_valid_out2),

        .mem_to_reg_out(memwb_mem_to_reg_out), .reg_write_out(memwb_reg_write_out2),
        .alu_result_out(memwb_alu_result_out), .mem_read_data_out(memwb_mem_read_data_out),
        .pc_plus4_out(memwb_pc_plus4_out), .hilo_result_out(memwb_hilo_result_out),
        .write_addr_out(memwb_write_addr_out), .valid_out(memwb_valid_out2)
    );

    // =========================================================
    // ============ WB STAGE ===================================
    // =========================================================

    wb_mux u_wb_mux (
        .alu_result(memwb_alu_result_out), .mem_read_data(memwb_mem_read_data_out),
        .pc_plus4(memwb_pc_plus4_out), .hilo_result(memwb_hilo_result_out),
        .mem_to_reg(memwb_mem_to_reg_out), .write_back_data(wb_write_back_data)
    );

    assign wb_reg_write  = memwb_reg_write_out2;
    assign wb_write_addr = memwb_write_addr_out;

    // drive the forward-declared MEM/WB forwarding wires
    assign memwb_wb_data_fwd    = wb_write_back_data;
    assign memwb_reg_write_fwd  = memwb_reg_write_out2;
    assign memwb_valid_fwd      = memwb_valid_out2;
    assign memwb_write_addr_fwd = memwb_write_addr_out;

endmodule
