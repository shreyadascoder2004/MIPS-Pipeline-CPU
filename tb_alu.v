// =============================================================
// Testbench   : tb_alu
// Tests       : alu.v
//
// Checks:
//   1-2.  ADD 64-bit, and 32-bit mode with sign-extend of result.
//   3-4.  SUB 64-bit, and 32-bit mode.
//   5.    Signed overflow detection on 32-bit ADD.
//   6.    AND is width-agnostic (full 64b) even with width32=1.
//   7.    OR full 64-bit.
//   8.    XOR full 64-bit.
//   9.    NOR full 64-bit.
//   10.   SLT signed, negative vs positive.
//   11.   SLTU unsigned, large unsigned value comparison.
//   12.   SLL 64-bit shift.
//   13.   SLL 32-bit mode shift with sign-extend of result.
//   14.   SRL logical right shift (zero-fill).
//   15.   SRA arithmetic right shift (sign-fill) on negative value.
//   16.   SRA 32-bit mode on negative 32-bit value.
//   17.   zero flag asserted when result is 0.
//   18.   zero flag deasserted when result is nonzero.
//   19.   LUI_PASS passes operand_b through unchanged.
// =============================================================
`timescale 1ns/1ps

module tb_alu;

    reg  [63:0] operand_a, operand_b;
    reg  [4:0]  alu_ctrl;
    reg         width32;
    reg  [5:0]  shamt_in;
    wire [63:0] result;
    wire        zero;
    wire        overflow;

    integer errors;

    alu dut (
        .operand_a(operand_a), .operand_b(operand_b),
        .alu_ctrl(alu_ctrl), .width32(width32), .shamt_in(shamt_in),
        .result(result), .zero(zero), .overflow(overflow)
    );

    task check_result(input [255:0] name, input [63:0] exp);
        begin
            if (result !== exp) begin
                $display("FAIL: %0s expected=%h got=%h", name, exp, result);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %h", name, result);
            end
        end
    endtask

    task check_bit(input [255:0] name, input actual, input exp);
        begin
            if (actual !== exp) begin
                $display("FAIL: %0s expected=%b got=%b", name, exp, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %b", name, actual);
            end
        end
    endtask

    initial begin
        errors = 0;
        shamt_in = 6'd0;

        // ---- 1: ADD 64-bit ----
        operand_a = 64'd10; operand_b = 64'd20; alu_ctrl = 5'b00000; width32 = 0;
        #1; check_result("ADD 64b (10+20)", 64'd30);

        // ---- 2: ADD 32-bit mode, sign-extend ----
        // 0xFFFFFFFF (32b -1) + 1 = 0 in 32-bit math; result sign-extends 0 -> 0
        operand_a = 64'h00000000FFFFFFFF; operand_b = 64'h1; width32 = 1;
        #1; check_result("ADD 32b mode wraps, result=0", 64'h0);

        // 32-bit add producing negative result -> must sign-extend to 64
        operand_a = 64'd5; operand_b = 64'hFFFFFFFFFFFFFFFB; width32 = 1; // b32 = -5
        #1; check_result("ADD 32b mode (5 + -5)", 64'h0);

        operand_a = 64'd3; operand_b = 64'hFFFFFFFFFFFFFFFD; width32 = 1; // b32=-3, 3+(-3)=0... use different
        operand_a = 64'd2; operand_b = 64'hFFFFFFFFFFFFFFFB; width32 = 1; // b32=-5, 2+(-5)=-3
        #1; check_result("ADD 32b mode (2 + -5 = -3, sign-ext)", 64'hFFFFFFFFFFFFFFFD);

        // ---- 3: SUB 64-bit ----
        operand_a = 64'd50; operand_b = 64'd20; alu_ctrl = 5'b00001; width32 = 0;
        #1; check_result("SUB 64b (50-20)", 64'd30);

        // ---- 4: SUB 32-bit mode ----
        operand_a = 64'd5; operand_b = 64'd10; width32 = 1;
        #1; check_result("SUB 32b mode (5-10=-5, sign-ext)", 64'hFFFFFFFFFFFFFFFB);

        // ---- 5: overflow on 32-bit ADD ----
        operand_a = 64'h000000007FFFFFFF; operand_b = 64'h1; alu_ctrl = 5'b00000; width32 = 1;
        #1; check_bit("ADD 32b overflow (MAX_INT32+1)", overflow, 1'b1);

        operand_a = 64'd1; operand_b = 64'd1; width32 = 1;
        #1; check_bit("ADD 32b no overflow (1+1)", overflow, 1'b0);

        // ---- 6: AND width-agnostic even with width32=1 ----
        operand_a = 64'hFFFFFFFF00000000; operand_b = 64'hFFFFFFFFFFFFFFFF;
        alu_ctrl = 5'b00010; width32 = 1;
        #1; check_result("AND width-agnostic (upper bits preserved)", 64'hFFFFFFFF00000000);

        // ---- 7: OR ----
        operand_a = 64'h00000000000000F0; operand_b = 64'h000000000000000F;
        alu_ctrl = 5'b00011; width32 = 0;
        #1; check_result("OR", 64'hFF);

        // ---- 8: XOR ----
        operand_a = 64'hFFFFFFFFFFFFFFFF; operand_b = 64'h00000000000000FF;
        alu_ctrl = 5'b00100;
        #1; check_result("XOR", 64'hFFFFFFFFFFFFFF00);

        // ---- 9: NOR ----
        operand_a = 64'h0; operand_b = 64'h0; alu_ctrl = 5'b00101;
        #1; check_result("NOR(0,0)", 64'hFFFFFFFFFFFFFFFF);

        // ---- 10: SLT signed ----
        operand_a = 64'hFFFFFFFFFFFFFFFF; operand_b = 64'h1; // -1 < 1
        alu_ctrl = 5'b00110; width32 = 0;
        #1; check_result("SLT signed (-1 < 1)", 64'h1);

        // ---- 11: SLTU unsigned ----
        operand_a = 64'hFFFFFFFFFFFFFFFF; operand_b = 64'h1; // huge unsigned, not < 1
        alu_ctrl = 5'b00111;
        #1; check_result("SLTU unsigned (huge < 1? no)", 64'h0);

        // ---- 12: SLL 64-bit ----
        operand_a = 64'h0; operand_b = 64'h1; shamt_in = 6'd4; alu_ctrl = 5'b01000; width32 = 0;
        #1; check_result("SLL 64b (1<<4)", 64'h10);

        // ---- 13: SLL 32-bit mode, sign-extend ----
        operand_b = 64'h0000000040000000; shamt_in = 6'd1; width32 = 1; // 0x40000000 << 1 = 0x80000000 (negative in 32b)
        #1; check_result("SLL 32b mode sign-extends negative result", 64'hFFFFFFFF80000000);

        // ---- 14: SRL logical (zero-fill) ----
        operand_b = 64'hFFFFFFFFFFFFFFFF; shamt_in = 6'd4; alu_ctrl = 5'b01001; width32 = 0;
        #1; check_result("SRL zero-fill", 64'h0FFFFFFFFFFFFFFF);

        // ---- 15: SRA arithmetic (sign-fill), 64-bit negative ----
        operand_b = 64'hFFFFFFFFFFFFFFF0; shamt_in = 6'd4; alu_ctrl = 5'b01010; width32 = 0;
        #1; check_result("SRA sign-fill 64b", 64'hFFFFFFFFFFFFFFFF);

        // ---- 16: SRA 32-bit mode on negative value ----
        operand_b = 64'h00000000F0000000; shamt_in = 6'd4; width32 = 1;
        #1; check_result("SRA 32b mode negative", 64'hFFFFFFFFFF000000);

        // ---- 17/18: zero flag ----
        operand_a = 64'd5; operand_b = 64'd5; alu_ctrl = 5'b00001; width32 = 0; // SUB, 5-5=0
        #1; check_bit("zero flag asserted (5-5=0)", zero, 1'b1);

        operand_a = 64'd5; operand_b = 64'd3; alu_ctrl = 5'b00001; width32 = 0; // 5-3=2
        #1; check_bit("zero flag deasserted (5-3=2)", zero, 1'b0);

        // ---- 19: LUI_PASS ----
        operand_b = 64'hFFFFFFFF12340000; alu_ctrl = 5'b01011;
        #1; check_result("LUI_PASS passthrough", 64'hFFFFFFFF12340000);

        if (errors == 0)
            $display("\n==== ALL TESTS PASSED ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);

        $finish;
    end

endmodule
