// =============================================================
// Testbench   : tb_muxes
// Tests       : regdst_mux.v, alusrc_mux.v, ex_forward_mux.v,
//               wb_mux.v, pc_src_mux.v, extend_select_mux.v,
//               shamt_select_mux.v
// =============================================================
`timescale 1ns/1ps

module tb_muxes;

    integer errors;

    task chk(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    // ---------------- regdst_mux ----------------
    reg [4:0] rd_rt_in, rd_rd_in;
    reg rd_sel;
    wire [4:0] rd_out;
    regdst_mux u_regdst (.rt_addr(rd_rt_in), .rd_addr(rd_rd_in), .reg_dst(rd_sel), .write_addr(rd_out));

    // ---------------- alusrc_mux ----------------
    reg [63:0] as_reg_in, as_imm_in;
    reg as_sel;
    wire [63:0] as_out;
    alusrc_mux u_alusrc (.reg_val(as_reg_in), .imm_ext(as_imm_in), .alu_src(as_sel), .alu_operand_b(as_out));

    // ---------------- ex_forward_mux ----------------
    reg [63:0] efm_idex1, efm_idex2, efm_exmem, efm_memwb;
    reg [1:0] efm_fa, efm_fb;
    wire [63:0] efm_rs, efm_rt;
    ex_forward_mux u_efm (
        .idex_read_data1(efm_idex1), .idex_read_data2(efm_idex2),
        .exmem_result(efm_exmem), .memwb_result(efm_memwb),
        .forward_a(efm_fa), .forward_b(efm_fb),
        .rs_fwd(efm_rs), .rt_fwd(efm_rt)
    );

    // ---------------- wb_mux ----------------
    reg [63:0] wb_alu, wb_mem, wb_pc4, wb_hilo;
    reg [1:0] wb_sel;
    wire [63:0] wb_out;
    wb_mux u_wb (.alu_result(wb_alu), .mem_read_data(wb_mem), .pc_plus4(wb_pc4),
                 .hilo_result(wb_hilo), .mem_to_reg(wb_sel), .write_back_data(wb_out));

    // ---------------- pc_src_mux ----------------
    reg [63:0] ps_pc4, ps_branch, ps_jump;
    reg ps_btaken, ps_jump_en, ps_jr;
    wire [63:0] ps_out;
    pc_src_mux u_ps (.pc_plus4(ps_pc4), .branch_target(ps_branch), .jump_target(ps_jump),
                      .branch_taken(ps_btaken), .jump(ps_jump_en), .jump_reg(ps_jr), .pc_next(ps_out));

    // ---------------- extend_select_mux ----------------
    reg [63:0] esm_sign, esm_zero;
    reg [1:0] esm_ctrl;
    wire [63:0] esm_out;
    extend_select_mux u_esm (.sign_ext_out(esm_sign), .zero_ext_out(esm_zero), .ext_ctrl(esm_ctrl), .imm_selected(esm_out));

    // ---------------- shamt_select_mux ----------------
    reg [4:0] sh_instr_shamt;
    reg [63:0] sh_rs;
    reg sh_var;
    wire [5:0] sh_out;
    shamt_select_mux u_sh (.instr_shamt(sh_instr_shamt), .rs_val(sh_rs), .is_variable_shift(sh_var), .shamt_out(sh_out));

    initial begin
        errors = 0;

        // ---- regdst_mux ----
        rd_rt_in = 5'd2; rd_rd_in = 5'd3;
        rd_sel = 0; #1; chk("regdst rt select", {59'b0, rd_out}, 64'd2);
        rd_sel = 1; #1; chk("regdst rd select", {59'b0, rd_out}, 64'd3);

        // ---- alusrc_mux ----
        as_reg_in = 64'd50; as_imm_in = 64'd99;
        as_sel = 0; #1; chk("alusrc reg select", as_out, 64'd50);
        as_sel = 1; #1; chk("alusrc imm select", as_out, 64'd99);

        // ---- ex_forward_mux ----
        efm_idex1 = 64'd10; efm_idex2 = 64'd20; efm_exmem = 64'd30; efm_memwb = 64'd40;
        efm_fa = 2'b00; efm_fb = 2'b00;
        #1; chk("efm no-fwd rs", efm_rs, 64'd10); chk("efm no-fwd rt", efm_rt, 64'd20);
        efm_fa = 2'b01; efm_fb = 2'b10;
        #1; chk("efm rs<-EXMEM", efm_rs, 64'd30); chk("efm rt<-MEMWB", efm_rt, 64'd40);

        // ---- wb_mux ----
        wb_alu=64'd1; wb_mem=64'd2; wb_pc4=64'd3; wb_hilo=64'd4;
        wb_sel=2'b00; #1; chk("wb ALU", wb_out, 64'd1);
        wb_sel=2'b01; #1; chk("wb MEM", wb_out, 64'd2);
        wb_sel=2'b10; #1; chk("wb PC+4", wb_out, 64'd3);
        wb_sel=2'b11; #1; chk("wb HILO", wb_out, 64'd4);

        // ---- pc_src_mux ----
        ps_pc4=64'h100; ps_branch=64'h200; ps_jump=64'h300;
        ps_btaken=0; ps_jump_en=0; ps_jr=0;
        #1; chk("pcsrc sequential", ps_out, 64'h100);
        ps_btaken=1;
        #1; chk("pcsrc branch", ps_out, 64'h200);
        ps_jump_en=1; // jump should override branch
        #1; chk("pcsrc jump overrides branch", ps_out, 64'h300);
        ps_jump_en=0; ps_jr=1;
        #1; chk("pcsrc jr (jump_target=rs)", ps_out, 64'h300);

        // ---- extend_select_mux ----
        esm_sign = 64'hAAAA; esm_zero = 64'hBBBB;
        esm_ctrl = 2'b00; #1; chk("esm sign mode", esm_out, 64'hAAAA);
        esm_ctrl = 2'b01; #1; chk("esm zero mode", esm_out, 64'hBBBB);
        esm_ctrl = 2'b10; #1; chk("esm lui mode (via sign_ext_out)", esm_out, 64'hAAAA);

        // ---- shamt_select_mux ----
        sh_instr_shamt = 5'd7; sh_rs = 64'h3F; // rs[5:0]=0x3F=63
        sh_var = 0; #1; chk("shamt fixed", {58'b0,sh_out}, 64'd7);
        sh_var = 1; #1; chk("shamt variable (rs[5:0])", {58'b0,sh_out}, 64'd63);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
