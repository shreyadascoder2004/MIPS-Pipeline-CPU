// =============================================================
// Testbench   : tb_jump_unit
// Tests       : jump_unit.v
//
// Checks:
//   1. j-style target: upper bits from pc_plus4, lower from index<<2.
//   2. jal-style target: same computation as j (jump_reg=0).
//   3. jr-style target: rs_val passed through directly.
//   4. jump_reg takes priority over jump when both somehow asserted
//      (shouldn't happen in practice -- control unit never sets both
//      -- but the mux priority should still be well-defined).
// =============================================================
`timescale 1ns/1ps

module tb_jump_unit;

    reg [63:0] pc_plus4, rs_val;
    reg [25:0] instr_index;
    reg jump, jump_reg;
    wire [63:0] jump_target;

    integer errors;

    jump_unit dut (
        .pc_plus4(pc_plus4), .instr_index(instr_index), .rs_val(rs_val),
        .jump(jump), .jump_reg(jump_reg), .jump_target(jump_target)
    );

    task chk(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    initial begin
        errors = 0;

        // ---- 1: j-style target ----
        pc_plus4 = 64'h0000000000001004; instr_index = 26'h0000010; // index=16 -> <<2 = 64
        jump = 1; jump_reg = 0; rs_val = 64'hDEADBEEF;
        #1; chk("j target", jump_target, 64'h0000000000000040);

        // ---- 2: jal-style (same calc, jump still 1 jump_reg still 0) ----
        pc_plus4 = 64'h0000000010000004; instr_index = 26'h3FFFFFF; // max index
        #1; chk("jal target (max index)", jump_target, {pc_plus4[63:28], instr_index, 2'b00});

        // ---- 3: jr-style ----
        jump = 0; jump_reg = 1; rs_val = 64'h0000000000401234;
        #1; chk("jr target = rs_val", jump_target, 64'h0000000000401234);

        // ---- 4: jump_reg priority ----
        jump = 1; jump_reg = 1; rs_val = 64'hABCDEF0123456789;
        #1; chk("jump_reg priority over jump", jump_target, 64'hABCDEF0123456789);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
