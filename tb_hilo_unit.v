// =============================================================
// Testbench   : tb_hilo_unit
// Tests       : hilo_unit.v
//
// Checks:
//   1.  Unsigned 32-bit multiply: small values.
//   2.  Signed 32-bit multiply: negative x positive.
//   3.  Signed 32-bit multiply: negative x negative (result positive).
//   4.  Multiply by zero -> immediate-ish finish, result 0.
//   5.  Early-exit determinism: same sparse operand always takes
//       the same (smaller) cycle count vs a dense operand.
//   6.  Unsigned 64-bit multiply.
//   7.  Unsigned 32-bit divide: exact division.
//   8.  Unsigned 32-bit divide: with remainder.
//   9.  Signed 32-bit divide: negative dividend.
//   10. busy signal is high during operation, low when idle/done.
//   11. mthi/mtlo direct write when idle.
// =============================================================
`timescale 1ns/1ps

module tb_hilo_unit;

    reg clk, rst_n, start, is_divide, is_signed, width64;
    reg [63:0] operand_a, operand_b;
    reg hi_write, lo_write;
    reg [63:0] hi_write_data, lo_write_data;
    wire busy, done;
    wire [63:0] hi_out, lo_out;

    integer errors;
    integer cyc_count;

    hilo_unit dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .is_divide(is_divide), .is_signed(is_signed), .width64(width64),
        .operand_a(operand_a), .operand_b(operand_b),
        .hi_write(hi_write), .lo_write(lo_write),
        .hi_write_data(hi_write_data), .lo_write_data(lo_write_data),
        .busy(busy), .done(done), .hi_out(hi_out), .lo_out(lo_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task chk(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    // Runs an operation, waits for done, returns cycle count taken
    task run_op(
        input        p_divide, input p_signed, input p_width64,
        input [63:0] a, input [63:0] b,
        output [63:0] hi_r, output [63:0] lo_r, output integer cycles
    );
        begin
            @(negedge clk);
            is_divide = p_divide; is_signed = p_signed; width64 = p_width64;
            operand_a = a; operand_b = b;
            start = 1;
            @(negedge clk);
            start = 0;
            cycles = 0;
            while (!done) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            hi_r = hi_out; lo_r = lo_out;
        end
    endtask

    reg [63:0] hi_r, lo_r;
    integer c1, c2;

    initial begin
        errors = 0;
        rst_n = 0; start = 0; is_divide=0; is_signed=0; width64=0;
        operand_a=0; operand_b=0; hi_write=0; lo_write=0;
        hi_write_data=0; lo_write_data=0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // ---- 1: unsigned 32-bit multiply ----
        run_op(0, 0, 0, 64'd6, 64'd7, hi_r, lo_r, c1);
        chk("unsigned mult 6*7 lo", lo_r, 64'd42);
        chk("unsigned mult 6*7 hi", hi_r, 64'd0);

        // ---- 2: signed 32-bit multiply, neg x pos ----
        // -3 * 5 = -15
        run_op(0, 1, 0, 64'hFFFFFFFFFFFFFFFD, 64'd5, hi_r, lo_r, c1);
        chk("signed mult -3*5 lo", lo_r, 64'hFFFFFFFFFFFFFFF1); // -15
        chk("signed mult -3*5 hi", hi_r, 64'hFFFFFFFFFFFFFFFF); // sign-extended hi

        // ---- 3: signed 32-bit multiply, neg x neg ----
        // -3 * -5 = 15
        run_op(0, 1, 0, 64'hFFFFFFFFFFFFFFFD, 64'hFFFFFFFFFFFFFFFB, hi_r, lo_r, c1);
        chk("signed mult -3*-5 lo", lo_r, 64'd15);
        chk("signed mult -3*-5 hi", hi_r, 64'd0);

        // ---- 4: multiply by zero ----
        run_op(0, 0, 0, 64'd12345, 64'd0, hi_r, lo_r, c1);
        chk("mult by zero lo", lo_r, 64'd0);
        chk("mult by zero hi", hi_r, 64'd0);
        if (c1 > 2) begin
            $display("FAIL: mult-by-zero should finish almost immediately, took %0d cycles", c1);
            errors = errors + 1;
        end else $display("PASS: mult-by-zero fast path, %0d cycles", c1);

        // ---- 5: early-exit determinism (sparse vs dense operand) ----
        // sparse: multiplier = 1 (only bit 0 set) -> should be fast
        run_op(0, 0, 0, 64'd100, 64'd1, hi_r, lo_r, c1);
        chk("sparse mult 100*1", lo_r, 64'd100);
        // dense: multiplier = 0xFFFFFFFF (all bits set) -> should take longer
        run_op(0, 0, 0, 64'd3, 64'h00000000FFFFFFFF, hi_r, lo_r, c2);
        chk("dense mult 3*0xFFFFFFFF lo", lo_r, (64'd3 * 64'h00000000FFFFFFFF) & 64'hFFFFFFFFFFFFFFFF);
        if (c2 <= c1) begin
            $display("FAIL: dense operand (%0d cyc) should take longer than sparse (%0d cyc)", c2, c1);
            errors = errors + 1;
        end else $display("PASS: early-exit confirmed: sparse=%0d cyc, dense=%0d cyc", c1, c2);
        // re-run sparse to confirm determinism (same cycle count every time)
        run_op(0, 0, 0, 64'd100, 64'd1, hi_r, lo_r, c2);
        if (c2 !== c1) begin
            $display("FAIL: non-deterministic cycle count for identical operands: %0d vs %0d", c1, c2);
            errors = errors + 1;
        end else $display("PASS: deterministic cycle count for repeated identical op (%0d cyc)", c1);

        // ---- 6: unsigned 64-bit multiply ----
        run_op(0, 0, 1, 64'd1000000, 64'd1000000, hi_r, lo_r, c1);
        chk("64b mult 1e6*1e6 lo", lo_r, 64'd1000000000000);
        chk("64b mult 1e6*1e6 hi", hi_r, 64'd0);

        // ---- 7: unsigned divide exact ----
        run_op(1, 0, 0, 64'd20, 64'd4, hi_r, lo_r, c1);
        chk("unsigned div 20/4 quotient(lo)", lo_r, 64'd5);
        chk("unsigned div 20/4 remainder(hi)", hi_r, 64'd0);

        // ---- 8: unsigned divide with remainder ----
        run_op(1, 0, 0, 64'd23, 64'd5, hi_r, lo_r, c1);
        chk("unsigned div 23/5 quotient", lo_r, 64'd4);
        chk("unsigned div 23/5 remainder", hi_r, 64'd3);

        // ---- 9: signed divide, negative dividend ----
        // -23 / 5 = -4 remainder -3 (MIPS truncating division convention)
        run_op(1, 1, 0, 64'hFFFFFFFFFFFFFFE9, 64'd5, hi_r, lo_r, c1); // -23
        chk("signed div -23/5 quotient", lo_r, 64'hFFFFFFFFFFFFFFFC); // -4
        chk("signed div -23/5 remainder", hi_r, 64'hFFFFFFFFFFFFFFFD); // -3

        // ---- 10: busy signal ----
        @(negedge clk);
        is_divide=0; is_signed=0; width64=0; operand_a=64'd9; operand_b=64'd9;
        start = 1;
        @(negedge clk);
        start = 0;
        if (busy !== 1'b1) begin $display("FAIL: busy should be 1 during op"); errors=errors+1; end
        else $display("PASS: busy=1 during operation");
        while (!done) @(negedge clk);
        @(negedge clk); // one more cycle after done pulse
        if (busy !== 1'b0) begin $display("FAIL: busy should be 0 after done"); errors=errors+1; end
        else $display("PASS: busy=0 after completion");

        // ---- 11: mthi/mtlo direct write ----
        @(negedge clk);
        hi_write = 1; hi_write_data = 64'hAAAA;
        lo_write = 1; lo_write_data = 64'hBBBB;
        @(negedge clk);
        hi_write = 0; lo_write = 0;
        chk("mthi direct write", hi_out, 64'hAAAA);
        chk("mtlo direct write", lo_out, 64'hBBBB);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    initial begin #100000; $display("ERROR: timeout"); $finish; end

endmodule
