// =============================================================
// Testbench   : tb_hazard_detection_unit
// Tests       : hazard_detection_unit.v
//
// Checks:
//   1. No hazard -> pc_write_en=1, if_id_stall=0, id_ex_flush=0.
//   2. Load-use hazard on rs -> stall asserted correctly.
//   3. Load-use hazard on rt -> stall asserted correctly.
//   4. Not a load (mem_read=0) even with matching reg -> no stall.
//   5. Load's dest is $0 -> no stall (can't hazard on $0).
//   6. mult_div_busy alone (no load-use) -> stall asserted.
//   7. Both load-use and mult_div_busy -> stall still asserted (OR).
//   8. Load-use with dest NOT matching either rs or rt -> no stall.
// =============================================================
`timescale 1ns/1ps

module tb_hazard_detection_unit;

    reg idex_mem_read, idex_reg_write, mult_div_busy, id_is_branch_or_jr;
    reg [4:0] idex_rt_addr, idex_write_addr, id_rs_addr, id_rt_addr;
    wire pc_write_en, if_id_stall, id_ex_flush;

    integer errors;

    hazard_detection_unit dut (
        .idex_mem_read(idex_mem_read), .idex_reg_write(idex_reg_write),
        .idex_rt_addr(idex_rt_addr), .idex_write_addr(idex_write_addr),
        .id_rs_addr(id_rs_addr), .id_rt_addr(id_rt_addr),
        .id_is_branch_or_jr(id_is_branch_or_jr),
        .mult_div_busy(mult_div_busy),
        .pc_write_en(pc_write_en), .if_id_stall(if_id_stall), .id_ex_flush(id_ex_flush)
    );

    task chk(input [255:0] name, input actual, input exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%b got=%b", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %b", name, actual);
        end
    endtask

    initial begin
        errors = 0;

        // ---- 1: no hazard ----
        idex_mem_read=0; idex_reg_write=0; idex_rt_addr=5'd0; idex_write_addr=5'd0;
        id_rs_addr=5'd1; id_rt_addr=5'd2; id_is_branch_or_jr=0; mult_div_busy=0;
        #1;
        chk("no hazard: pc_write_en", pc_write_en, 1);
        chk("no hazard: if_id_stall", if_id_stall, 0);
        chk("no hazard: id_ex_flush", id_ex_flush, 0);

        // ---- 2: load-use on rs ----
        idex_mem_read=1; idex_rt_addr=5'd1; id_rs_addr=5'd1; id_rt_addr=5'd2;
        #1;
        chk("load-use rs: pc_write_en", pc_write_en, 0);
        chk("load-use rs: if_id_stall", if_id_stall, 1);
        chk("load-use rs: id_ex_flush", id_ex_flush, 1);

        // ---- 3: load-use on rt ----
        idex_mem_read=1; idex_rt_addr=5'd2; id_rs_addr=5'd9; id_rt_addr=5'd2;
        #1;
        chk("load-use rt: if_id_stall", if_id_stall, 1);

        // ---- 4: not a load, matching reg -> no stall ----
        idex_mem_read=0; idex_rt_addr=5'd1; id_rs_addr=5'd1; id_rt_addr=5'd2;
        #1;
        chk("not a load: if_id_stall", if_id_stall, 0);

        // ---- 5: load dest is $0 -> no stall ----
        idex_mem_read=1; idex_rt_addr=5'd0; id_rs_addr=5'd0; id_rt_addr=5'd0;
        #1;
        chk("load dest $0: if_id_stall", if_id_stall, 0);

        // ---- 6: mult_div_busy alone ----
        idex_mem_read=0; idex_rt_addr=5'd0; id_rs_addr=5'd1; id_rt_addr=5'd2; mult_div_busy=1;
        #1;
        chk("mult_div_busy: pc_write_en", pc_write_en, 0);
        chk("mult_div_busy: if_id_stall", if_id_stall, 1);

        // ---- 7: both hazards simultaneously ----
        idex_mem_read=1; idex_rt_addr=5'd1; id_rs_addr=5'd1; id_rt_addr=5'd2; mult_div_busy=1;
        #1;
        chk("both hazards: if_id_stall", if_id_stall, 1);
        mult_div_busy = 0;

        // ---- 8: load-use, dest matches neither rs nor rt ----
        idex_mem_read=1; idex_rt_addr=5'd9; id_rs_addr=5'd1; id_rt_addr=5'd2;
        #1;
        chk("load, no reg match: if_id_stall", if_id_stall, 0);

        // ---- 9: branch dependency hazard on rs ----
        idex_mem_read=0; idex_reg_write=1; idex_write_addr=5'd1;
        id_rs_addr=5'd1; id_rt_addr=5'd2; id_is_branch_or_jr=1;
        #1;
        chk("branch dep rs: if_id_stall", if_id_stall, 1);
        chk("branch dep rs: pc_write_en", pc_write_en, 0);

        // ---- 10: branch dependency hazard on rt ----
        idex_write_addr=5'd2;
        #1;
        chk("branch dep rt: if_id_stall", if_id_stall, 1);

        // ---- 11: branch dependency, but idex doesn't write a reg -> no stall ----
        idex_reg_write=0; idex_write_addr=5'd1;
        #1;
        chk("branch dep, no reg_write: if_id_stall", if_id_stall, 0);
        idex_reg_write=1;

        // ---- 12: branch dependency, but id instr is NOT a branch/jr -> no stall ----
        idex_write_addr=5'd1; id_is_branch_or_jr=0;
        #1;
        chk("dep exists but not branch: if_id_stall", if_id_stall, 0);
        id_is_branch_or_jr=1;

        // ---- 13: branch dependency, dest is $0 -> no stall ----
        idex_write_addr=5'd0;
        #1;
        chk("branch dep dest $0: if_id_stall", if_id_stall, 0);

        // ---- 14: branch dependency, no address match -> no stall ----
        idex_write_addr=5'd9;
        #1;
        chk("branch dep no match: if_id_stall", if_id_stall, 0);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
