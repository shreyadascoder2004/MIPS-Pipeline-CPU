// =============================================================
// Testbench   : tb_branch_unit
// Tests       : branch_unit.v
//
// Checks:
//   1.  beq taken (equal values).
//   2.  beq not taken (unequal values).
//   3.  bne taken (unequal values).
//   4.  bne not taken (equal values).
//   5.  blez taken on zero.
//   6.  blez taken on negative.
//   7.  blez not taken on positive.
//   8.  bgtz taken on positive.
//   9.  bgtz not taken on zero.
//   10. bltz taken on negative.
//   11. bltz not taken on zero.
//   12. bgez taken on zero.
//   13. bgez taken on positive.
//   14. bgez not taken on negative.
//   15. branch_en=0 forces branch_taken=0 even if condition true.
//   16. target address calculation: positive offset.
//   17. target address calculation: negative offset (backward branch).
// =============================================================
`timescale 1ns/1ps

module tb_branch_unit;

    reg [63:0] rs_val, rt_val, pc_plus4, imm_sext;
    reg [2:0] branch_type;
    reg branch_en;
    wire branch_taken;
    wire [63:0] branch_target;

    integer errors;

    branch_unit dut (
        .rs_val(rs_val), .rt_val(rt_val), .branch_type(branch_type),
        .branch_en(branch_en), .pc_plus4(pc_plus4), .imm_sext(imm_sext),
        .branch_taken(branch_taken), .branch_target(branch_target)
    );

    task chk(input [255:0] name, input actual, input exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%b got=%b", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %b", name, actual);
        end
    endtask
    task chkN(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    initial begin
        errors = 0;
        branch_en = 1; pc_plus4 = 64'h100; imm_sext = 64'h0;

        // ---- beq ----
        branch_type = 3'b000; rs_val=64'd5; rt_val=64'd5;
        #1; chk("beq taken (equal)", branch_taken, 1);
        rs_val=64'd5; rt_val=64'd6;
        #1; chk("beq not taken (unequal)", branch_taken, 0);

        // ---- bne ----
        branch_type = 3'b001; rs_val=64'd5; rt_val=64'd6;
        #1; chk("bne taken (unequal)", branch_taken, 1);
        rs_val=64'd5; rt_val=64'd5;
        #1; chk("bne not taken (equal)", branch_taken, 0);

        // ---- blez ----
        branch_type = 3'b010;
        rs_val = 64'd0;
        #1; chk("blez taken (zero)", branch_taken, 1);
        rs_val = 64'hFFFFFFFFFFFFFFFF; // -1
        #1; chk("blez taken (negative)", branch_taken, 1);
        rs_val = 64'd1;
        #1; chk("blez not taken (positive)", branch_taken, 0);

        // ---- bgtz ----
        branch_type = 3'b011;
        rs_val = 64'd1;
        #1; chk("bgtz taken (positive)", branch_taken, 1);
        rs_val = 64'd0;
        #1; chk("bgtz not taken (zero)", branch_taken, 0);

        // ---- bltz ----
        branch_type = 3'b100;
        rs_val = 64'hFFFFFFFFFFFFFFFF; // -1
        #1; chk("bltz taken (negative)", branch_taken, 1);
        rs_val = 64'd0;
        #1; chk("bltz not taken (zero)", branch_taken, 0);

        // ---- bgez ----
        branch_type = 3'b101;
        rs_val = 64'd0;
        #1; chk("bgez taken (zero)", branch_taken, 1);
        rs_val = 64'd5;
        #1; chk("bgez taken (positive)", branch_taken, 1);
        rs_val = 64'hFFFFFFFFFFFFFFFF; // -1
        #1; chk("bgez not taken (negative)", branch_taken, 0);

        // ---- branch_en gating ----
        branch_type = 3'b000; rs_val=64'd5; rt_val=64'd5; branch_en=0;
        #1; chk("branch_en=0 forces not-taken", branch_taken, 0);
        branch_en = 1;

        // ---- target address: positive offset ----
        pc_plus4 = 64'h1000; imm_sext = 64'd4; // offset=4 words -> 16 bytes
        #1; chkN("target addr positive offset", branch_target, 64'h1010);

        // ---- target address: negative offset (backward branch) ----
        pc_plus4 = 64'h1000; imm_sext = 64'hFFFFFFFFFFFFFFFE; // -2 words -> -8 bytes
        #1; chkN("target addr negative offset", branch_target, 64'hFF8);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
