// =============================================================
// Testbench   : tb_if_stage
// Tests       : pc.v + instr_mem.v together, standing in for the
//               IF stage before pipeline registers exist.
//
// Checks:
//   1. Reset drives PC to 0.
//   2. PC increments by 4 each cycle (no stall) via external +4 mux
//      modeled directly in this TB (the real +4/branch mux is a
//      later module — here we just drive pc_next = pc_out + 4
//      to prove pc.v + instr_mem.v behave correctly together).
//   3. Correct instruction word appears at each PC value, matched
//      against the known contents of if_test.hex.
//   4. pc_write_en = 0 correctly freezes PC (stall behavior).
//   5. A branch/jump-style asynchronous PC load works (pc_next
//      driven to an arbitrary target) and instr_mem returns the
//      right word for that address.
// =============================================================
`timescale 1ns/1ps

module tb_if_stage;

    reg         clk;
    reg         rst_n;
    reg         pc_write_en;
    reg  [63:0] pc_next_override;   // used to force jump/branch targets
    reg         use_override;
    wire [63:0] pc_out;
    wire [31:0] instr_out;

    // Expected instruction words loaded from if_test.hex (mirrored here
    // for self-checking without re-parsing the hex file in the TB).
    reg [31:0] expected [0:3];

    integer errors;
    integer i;

    // ---------------- DUT instantiation ----------------
    pc u_pc (
        .clk         (clk),
        .rst_n       (rst_n),
        .pc_write_en (pc_write_en),
        .pc_next     (use_override ? pc_next_override : (pc_out + 64'd4)),
        .pc_out      (pc_out)
    );

    instr_mem #(.MEM_DEPTH_WORDS(1024)) u_imem (
        .addr      (pc_out),
        .instr_out (instr_out)
    );

    // ---------------- Clock ----------------
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz, 10ns period

    // ---------------- Load known program into IMEM for this TB ----------------
    // Overrides the default $readmemh path load in instr_mem's initial
    // block by reloading via hierarchical reference after that block runs.
    initial begin
        expected[0] = 32'h20010005; // addi $1,$0,5
        expected[1] = 32'h20020003; // addi $2,$0,3
        expected[2] = 32'h00221820; // add  $3,$1,$2
        expected[3] = 32'h00000000; // nop
        #1; // let instr_mem's initial $readmemh run first
        $readmemh("sw/hex/if_test.hex", u_imem.mem);
    end

    // ---------------- Test sequence ----------------
    initial begin
        errors = 0;
        rst_n = 0;
        pc_write_en = 1;
        use_override = 0;
        pc_next_override = 64'd0;

        // Hold reset for 2 cycles
        @(negedge clk);
        @(negedge clk);
        if (pc_out !== 64'h0) begin
            $display("FAIL: PC not held at 0 during reset. pc_out=%h", pc_out);
            errors = errors + 1;
        end

        // ---- Check 1: reset value ----
        // pc_out is already 0 while rst_n=0 (checked above). Confirm it
        // immediately, THEN release reset right before the loop below
        // walks PC through 0,4,8,12 on successive edges.
        if (pc_out !== 64'h0) begin
            $display("FAIL: PC after reset expected 0, got %h", pc_out);
            errors = errors + 1;
        end else begin
            $display("PASS: PC correctly reset to 0");
        end
        rst_n = 1;

        // ---- Check 2: sequential fetch, PC increments by 4, correct instr ----
        // pc_out/instr_out are still at their reset-held values (PC=0) right
        // now, since rst_n was just released combinationally and no posedge
        // has occurred yet with rst_n=1. Sample PC=0 first, THEN clock.
        for (i = 0; i < 4; i = i + 1) begin
            if (instr_out !== expected[i]) begin
                $display("FAIL: at PC=%0d expected instr=%h got=%h", i*4, expected[i], instr_out);
                errors = errors + 1;
            end else begin
                $display("PASS: PC=%0d instr=%h matches expected", i*4, instr_out);
            end
            @(posedge clk); // advance PC to next value
            #1;             // let combinational instr_mem settle
        end

        // ---- Check 3: stall freezes PC ----
        pc_write_en = 0;
        begin : stall_check
            reg [63:0] pc_before;
            pc_before = pc_out;
            @(negedge clk);
            @(negedge clk);
            if (pc_out !== pc_before) begin
                $display("FAIL: PC changed during stall. before=%h after=%h", pc_before, pc_out);
                errors = errors + 1;
            end else begin
                $display("PASS: PC correctly held during stall at %h", pc_out);
            end
        end
        pc_write_en = 1;

        // ---- Check 4: branch/jump-style async target load ----
        use_override = 1;
        pc_next_override = 64'd8; // jump to instruction index 2 (add $3,$1,$2)
        @(negedge clk);
        use_override = 0;
        if (pc_out !== 64'd8) begin
            $display("FAIL: jump target not loaded. expected 8 got %h", pc_out);
            errors = errors + 1;
        end else if (instr_out !== expected[2]) begin
            $display("FAIL: instr at jumped PC=8 expected=%h got=%h", expected[2], instr_out);
            errors = errors + 1;
        end else begin
            $display("PASS: jump to PC=8 fetched correct instruction %h", instr_out);
        end

        // ---------------- Summary ----------------
        if (errors == 0)
            $display("\n==== ALL TESTS PASSED ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);

        $finish;
    end

    // Safety timeout
    initial begin
        #1000;
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule
