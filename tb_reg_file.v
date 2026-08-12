// =============================================================
// Testbench   : tb_reg_file
// Tests       : reg_file.v
//
// Checks:
//   1. Reset zeros all registers.
//   2. Basic write then read (different cycle).
//   3. $0 always reads zero, even after attempted write.
//   4. Two simultaneous reads (rs, rt) return correct independent values.
//   5. Write-first bypass: write and read same register same cycle
//      returns new data, not stale data.
//   6. Bypass does NOT trigger when write_en=0.
//   7. Bypass does NOT trigger for unrelated read address.
// =============================================================
`timescale 1ns/1ps

module tb_reg_file;

    reg         clk, rst_n;
    reg  [4:0]  read_addr1, read_addr2;
    reg         write_en;
    reg  [4:0]  write_addr;
    reg  [63:0] write_data;
    wire [63:0] read_data1, read_data2;

    integer errors;

    reg_file dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .read_addr1 (read_addr1),
        .read_addr2 (read_addr2),
        .read_data1 (read_data1),
        .read_data2 (read_data2),
        .write_en   (write_en),
        .write_addr (write_addr),
        .write_data (write_data)
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
        rst_n = 0; write_en = 0; write_addr = 0; write_data = 0;
        read_addr1 = 0; read_addr2 = 0;

        @(negedge clk);
        // ---- Check 1: reset zeros everything ----
        read_addr1 = 5'd10; read_addr2 = 5'd20;
        #1;
        check_equal("reset reg10", read_data1, 64'h0);
        check_equal("reset reg20", read_data2, 64'h0);

        rst_n = 1;

        // ---- Check 2: write then read on a later cycle ----
        write_en = 1; write_addr = 5'd5; write_data = 64'hDEADBEEFCAFEF00D;
        @(negedge clk); // write commits on this posedge (sampled at negedge after)
        write_en = 0;
        read_addr1 = 5'd5;
        #1;
        check_equal("write-then-read reg5", read_data1, 64'hDEADBEEFCAFEF00D);

        // ---- Check 3: $0 always zero, even if written ----
        write_en = 1; write_addr = 5'd0; write_data = 64'hFFFFFFFFFFFFFFFF;
        read_addr1 = 5'd0;
        #1;
        check_equal("write to $0 during write (bypass path)", read_data1, 64'h0);
        @(negedge clk);
        write_en = 0;
        #1;
        check_equal("$0 after attempted write", read_data1, 64'h0);

        // ---- Check 4: two independent simultaneous reads ----
        write_en = 1; write_addr = 5'd7; write_data = 64'h1111111111111111;
        @(negedge clk);
        write_en = 1; write_addr = 5'd8; write_data = 64'h2222222222222222;
        @(negedge clk);
        write_en = 0;
        read_addr1 = 5'd7; read_addr2 = 5'd8;
        #1;
        check_equal("dual read reg7", read_data1, 64'h1111111111111111);
        check_equal("dual read reg8", read_data2, 64'h2222222222222222);

        // ---- Check 5: write-first bypass, same cycle write+read ----
        write_en = 1; write_addr = 5'd7; write_data = 64'hABCDEF0123456789;
        read_addr1 = 5'd7; // reading the SAME register being written, same cycle
        #1;
        check_equal("bypass same-cycle write+read", read_data1, 64'hABCDEF0123456789);
        @(negedge clk);
        write_en = 0;

        // ---- Check 6: bypass inactive when write_en=0 ----
        write_en = 0; write_addr = 5'd7; write_data = 64'h9999999999999999; // should NOT apply
        read_addr1 = 5'd7;
        #1;
        check_equal("no bypass when write_en=0", read_data1, 64'hABCDEF0123456789); // prior value

        // ---- Check 7: bypass doesn't leak to unrelated read address ----
        write_en = 1; write_addr = 5'd7; write_data = 64'h5555555555555555;
        read_addr1 = 5'd8; // different register
        #1;
        check_equal("no bypass leak to reg8", read_data1, 64'h2222222222222222);
        @(negedge clk);
        write_en = 0;

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
