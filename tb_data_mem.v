// =============================================================
// Testbench   : tb_data_mem
// Tests       : data_mem.v
//
// Checks:
//   1.  Store byte, read back byte (unsigned).
//   2.  Store byte with high bit set, read back signed (sign-extend).
//   3.  Store byte with high bit set, read back unsigned (zero-extend).
//   4.  Store half, read back correctly (little-endian byte order).
//   5.  Store word, read back correctly, sign-extended.
//   6.  Store word (negative value), read back sign-extended to 64b.
//   7.  Store word, read back unsigned (lwu-style, zero-extend).
//   8.  Store dword, read back full 64 bits unchanged.
//   9.  Byte-lane write granularity: sb does not clobber neighbors.
//   10. mem_read=0 -> read_data forced to 0 regardless of contents.
//   11. mem_write=0 -> no write occurs even with valid write_data.
// =============================================================
`timescale 1ns/1ps

module tb_data_mem;

    reg         clk;
    reg  [63:0] addr, write_data;
    reg         mem_read, mem_write, mem_unsigned;
    reg  [2:0]  mem_width;
    wire [63:0] read_data;

    integer errors;

    data_mem #(.MEM_DEPTH_BYTES(1024)) dut (
        .clk(clk), .addr(addr), .write_data(write_data),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_width(mem_width), .mem_unsigned(mem_unsigned),
        .read_data(read_data)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task chk(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    initial begin
        errors = 0;
        mem_read = 0; mem_write = 0; addr = 0; write_data = 0;
        mem_width = 3'b000; mem_unsigned = 0;
        @(negedge clk);

        // ---- 1: store byte, read unsigned small value ----
        addr = 64'd0; write_data = 64'h5A; mem_width = 3'b000; mem_write = 1;
        @(negedge clk); mem_write = 0;
        mem_read = 1; mem_unsigned = 1;
        #1; chk("byte store/read (0x5A)", read_data, 64'h5A);

        // ---- 2: byte with MSB set, signed read ----
        addr = 64'd1; write_data = 64'hFE; mem_width = 3'b000; mem_write = 1; mem_read=0;
        @(negedge clk); mem_write = 0;
        mem_read = 1; mem_unsigned = 0;
        #1; chk("byte 0xFE signed read (-2)", read_data, 64'hFFFFFFFFFFFFFFFE);

        // ---- 3: same byte, unsigned read ----
        mem_unsigned = 1;
        #1; chk("byte 0xFE unsigned read", read_data, 64'h00000000000000FE);

        // ---- 4: store half, little-endian check ----
        addr = 64'd10; write_data = 64'h1234; mem_width = 3'b001; mem_write = 1; mem_read=0;
        @(negedge clk); mem_write = 0;
        mem_read = 1; mem_unsigned = 1;
        #1; chk("half store/read (0x1234)", read_data, 64'h1234);

        // ---- 5: store word, sign-extend (positive) ----
        addr = 64'd20; write_data = 64'h0000ABCD; mem_width = 3'b010; mem_write = 1; mem_read=0;
        @(negedge clk); mem_write = 0;
        mem_read = 1; mem_unsigned = 0;
        #1; chk("word store/read positive", read_data, 64'h0000ABCD);

        // ---- 6: store word negative, sign-extend to 64 ----
        addr = 64'd30; write_data = 64'hFFFFFFFF; mem_width = 3'b010; mem_write = 1; mem_read=0;
        @(negedge clk); mem_write = 0;
        mem_read = 1; mem_unsigned = 0;
        #1; chk("word store/read (-1) sign-ext", read_data, 64'hFFFFFFFFFFFFFFFF);

        // ---- 7: same word, unsigned read (zero-extend) ----
        mem_unsigned = 1;
        #1; chk("word 0xFFFFFFFF unsigned read", read_data, 64'h00000000FFFFFFFF);

        // ---- 8: store dword, full 64-bit round trip ----
        addr = 64'd40; write_data = 64'hDEADBEEFCAFEBABE; mem_width = 3'b011; mem_write = 1; mem_read=0;
        @(negedge clk); mem_write = 0;
        mem_read = 1;
        #1; chk("dword store/read full 64b", read_data, 64'hDEADBEEFCAFEBABE);

        // ---- 9: byte-lane granularity: sb doesn't clobber neighbors ----
        addr = 64'd50; write_data = 64'hFFFFFFFF; mem_width = 3'b010; mem_write = 1; mem_read=0;
        @(negedge clk); mem_write = 0; // word of all-1s at addr 50
        addr = 64'd51; write_data = 64'h00; mem_width = 3'b000; mem_write = 1; // overwrite byte at 51 with 0
        @(negedge clk); mem_write = 0;
        addr = 64'd50; mem_read = 1; mem_width = 3'b010; mem_unsigned = 1;
        #1; chk("byte-lane write preserves neighbors", read_data, 64'h00000000FFFF00FF);

        // ---- 10: mem_read=0 forces read_data=0 ----
        addr = 64'd0; mem_read = 0; mem_width = 3'b000;
        #1; chk("mem_read=0 forces zero output", read_data, 64'h0);

        // ---- 11: mem_write=0 -> no write occurs ----
        addr = 64'd100; write_data = 64'hABCD; mem_width = 3'b010; mem_write = 0; mem_read = 0;
        @(negedge clk);
        mem_read = 1; mem_unsigned = 1;
        #1; chk("mem_write=0 no-op (still zero)", read_data, 64'h0);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    initial begin #1000; $display("ERROR: timeout"); $finish; end

endmodule
