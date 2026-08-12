// =============================================================
// Testbench   : tb_if_id_reg
// Tests       : if_id_reg.v
//
// Checks:
//   1. Async reset forces NOP + valid=0.
//   2. Normal operation: instruction and PC+4 latch through on
//      each clock edge, valid=1.
//   3. Stall holds current output unchanged (no bubble inserted).
//   4. Flush forces NOP + valid=0 regardless of input.
//   5. Flush takes priority over stall when both asserted same cycle.
// =============================================================
`timescale 1ns/1ps

module tb_if_id_reg;

    reg         clk, rst_n, stall, flush;
    reg  [31:0] instr_in;
    reg  [63:0] pc_plus4_in;
    wire [31:0] instr_out;
    wire [63:0] pc_plus4_out;
    wire        valid_out;

    integer errors;

    if_id_reg dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (stall),
        .flush        (flush),
        .instr_in     (instr_in),
        .pc_plus4_in  (pc_plus4_in),
        .instr_out    (instr_out),
        .pc_plus4_out (pc_plus4_out),
        .valid_out    (valid_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check_equal(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin
                $display("FAIL: %0s expected=%h got=%h", name, exp, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %h", name, actual);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0; stall = 0; flush = 0;
        instr_in = 32'hAAAAAAAA; pc_plus4_in = 64'hAAAA_AAAA_AAAA_AAAA;

        @(negedge clk);
        // ---- Check 1: reset state ----
        check_equal("reset instr_out", instr_out, 32'h0);
        check_equal("reset pc_plus4_out", pc_plus4_out, 64'h0);
        check_equal("reset valid_out", valid_out, 1'b0);

        rst_n = 1;

        // ---- Check 2: normal latch-through ----
        instr_in = 32'h20010005;
        pc_plus4_in = 64'h4;
        @(negedge clk);
        check_equal("normal instr_out", instr_out, 32'h20010005);
        check_equal("normal pc_plus4_out", pc_plus4_out, 64'h4);
        check_equal("normal valid_out", valid_out, 1'b1);

        instr_in = 32'h20020003;
        pc_plus4_in = 64'h8;
        @(negedge clk);
        check_equal("normal2 instr_out", instr_out, 32'h20020003);
        check_equal("normal2 pc_plus4_out", pc_plus4_out, 64'h8);

        // ---- Check 3: stall holds previous values ----
        stall = 1;
        instr_in = 32'hFFFFFFFF;      // should NOT propagate
        pc_plus4_in = 64'hFFFF_FFFF;  // should NOT propagate
        @(negedge clk);
        check_equal("stall instr_out (held)", instr_out, 32'h20020003);
        check_equal("stall pc_plus4_out (held)", pc_plus4_out, 64'h8);
        check_equal("stall valid_out (held)", valid_out, 1'b1);
        stall = 0;

        // ---- Check 4: flush forces NOP ----
        instr_in = 32'h12345678;
        pc_plus4_in = 64'h100;
        flush = 1;
        @(negedge clk);
        check_equal("flush instr_out", instr_out, 32'h0);
        check_equal("flush pc_plus4_out", pc_plus4_out, 64'h0);
        check_equal("flush valid_out", valid_out, 1'b0);
        flush = 0;

        // restore normal to prove flush was transient
        instr_in = 32'hDEADBEEF;
        pc_plus4_in = 64'h200;
        @(negedge clk);
        check_equal("post-flush instr_out", instr_out, 32'hDEADBEEF);
        check_equal("post-flush valid_out", valid_out, 1'b1);

        // ---- Check 5: flush priority over stall ----
        stall = 1;
        flush = 1;
        instr_in = 32'hCAFEBABE; // irrelevant either way, output must be NOP
        pc_plus4_in = 64'h300;
        @(negedge clk);
        check_equal("flush+stall instr_out", instr_out, 32'h0);
        check_equal("flush+stall valid_out", valid_out, 1'b0);
        stall = 0;
        flush = 0;

        if (errors == 0)
            $display("\n==== ALL TESTS PASSED ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);

        $finish;
    end

    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
