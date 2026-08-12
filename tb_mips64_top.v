// =============================================================
// Testbench   : tb_mips64_top
// Tests       : mips64_top.v -- full pipeline integration.
//
// Structure: staged test phases, each loading a different hex
// program into instruction memory and checking final register/
// memory state after the program has fully drained through the
// pipeline. Each phase is self-contained (uses $readmemh to
// reload instr_mem for that phase, then pulses reset).
//
// Phase 1: simple sequential program, no hazards (NOP-padded)
// Phase 2: back-to-back dependent instructions (forwarding)
// Phase 3: load-use hazard (stall required)
// Phase 4: branch taken/not-taken + forwarding into comparator
// Phase 5: branch-dependency hazard (branch reads ID/EX producer)
// Phase 6: multiply + mflo (multi-cycle stall)
// Phase 7: unconditional jump
// Phase 8: combined program (broader sanity check)
// =============================================================
`timescale 1ns/1ps

module tb_mips64_top;

    reg clk, rst_n;
    integer errors;
    integer cycle_count;

    mips64_top #(.IMEM_DEPTH_WORDS(256), .DMEM_DEPTH_BYTES(1024)) dut (
        .clk(clk), .rst_n(rst_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // cycle counter, for performance visibility during integration
    // testing (a real perf-counter module comes later in the project)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_count <= 0;
        else        cycle_count <= cycle_count + 1;
    end

    // ---- convenience: read a GPR through the register file's
    // internal array via hierarchical reference (simulation-only
    // visibility, not synthesizable, used purely for checking) ----
    function [63:0] get_reg(input [4:0] idx);
        get_reg = dut.u_reg_file.regs[idx];
    endfunction

    function [63:0] get_mem_dword(input [31:0] byte_addr);
        get_mem_dword = { dut.u_data_mem.mem[byte_addr+7], dut.u_data_mem.mem[byte_addr+6],
                           dut.u_data_mem.mem[byte_addr+5], dut.u_data_mem.mem[byte_addr+4],
                           dut.u_data_mem.mem[byte_addr+3], dut.u_data_mem.mem[byte_addr+2],
                           dut.u_data_mem.mem[byte_addr+1], dut.u_data_mem.mem[byte_addr] };
    endfunction

    task chk(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin
                $display("FAIL: %0s expected=%0d (0x%h) got=%0d (0x%h)", name, exp, exp, actual, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %0d (0x%h)", name, actual, actual);
            end
        end
    endtask

    // Reload instruction memory with a new program and pulse reset.
    task load_and_reset(input [255:0] hexfile);
        integer i;
        begin
            // clear to NOP first so stale instructions from a previous
            // phase never leak into a shorter program
            for (i = 0; i < 256; i = i + 1)
                dut.u_instr_mem.mem[i] = 32'h00000000;
            $readmemh(hexfile, dut.u_instr_mem.mem);

            rst_n = 0;
            @(negedge clk);
            @(negedge clk);
            rst_n = 1;
        end
    endtask

    // Run for N cycles (simple fixed-cycle drain; each program is
    // short enough that a generous fixed budget safely covers full
    // drain through all 5 stages plus any stalls).
    task run_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(negedge clk);
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0;
        @(negedge clk);

        // =====================================================
        // PHASE 1: Simple sequential program, no hazards
        // =====================================================
        $display("\n---- PHASE 1: Simple sequential (no hazards) ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test1_simple.hex");
        run_cycles(20);
        chk("P1: $1 = 10", get_reg(1), 64'd10);
        chk("P1: $2 = 20", get_reg(2), 64'd20);
        chk("P1: $3 = $1+$2 = 30", get_reg(3), 64'd30);
        chk("P1: $4 = $2-$1 = 10", get_reg(4), 64'd10);

        // =====================================================
        // PHASE 2: Back-to-back dependent instructions (forwarding)
        // =====================================================
        $display("\n---- PHASE 2: Forwarding (back-to-back dependencies) ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test2_forwarding.hex");
        run_cycles(20);
        chk("P2: $1 = 5", get_reg(1), 64'd5);
        chk("P2: $2 = 7", get_reg(2), 64'd7);
        chk("P2: $3 = $1+$2 = 12 (EX/MEM fwd both operands)", get_reg(3), 64'd12);
        chk("P2: $4 = $3+$1 = 17 (EX/MEM fwd $3)", get_reg(4), 64'd17);
        chk("P2: $5 = $4-$2 = 10 (MEM/WB fwd $4)", get_reg(5), 64'd10);

        // =====================================================
        // PHASE 3: Load-use hazard
        // =====================================================
        $display("\n---- PHASE 3: Load-use hazard (stall required) ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test3_load_use.hex");
        run_cycles(20);
        chk("P3: $1 = 100", get_reg(1), 64'd100);
        chk("P3: mem[0] = 100 (word store)", get_mem_dword(0) & 64'hFFFFFFFF, 64'd100);
        chk("P3: $2 = mem[0] = 100 (load)", get_reg(2), 64'd100);
        chk("P3: $3 = $2+$2 = 200 (load-use stall then fwd)", get_reg(3), 64'd200);

        // =====================================================
        // PHASE 4: Branch resolution + forwarding into comparator
        // =====================================================
        $display("\n---- PHASE 4: Branch taken, forwarding into comparator ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test4_branch.hex");
        run_cycles(20);
        chk("P4: $1 = 5", get_reg(1), 64'd5);
        chk("P4: $2 = 5", get_reg(2), 64'd5);
        chk("P4: $3 unwritten (skipped by taken branch)", get_reg(3), 64'd0);
        chk("P4: $4 = 42 (branch target reached)", get_reg(4), 64'd42);

        // =====================================================
        // PHASE 5: Branch-dependency hazard
        // =====================================================
        $display("\n---- PHASE 5: Branch-dependency hazard (stall before branch) ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test5_branch_dep.hex");
        run_cycles(20);
        chk("P5: $5 = $1+$1 = 20", get_reg(5), 64'd20);
        chk("P5: $6 unwritten (skipped by taken branch)", get_reg(6), 64'd0);
        chk("P5: $7 = 77 (branch target reached, correct despite dependency)", get_reg(7), 64'd77);

        // =====================================================
        // PHASE 6: Multiply + mflo (multi-cycle stall)
        // =====================================================
        $display("\n---- PHASE 6: Multiply/HI-LO (multi-cycle busy stall) ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test6_multdiv.hex");
        run_cycles(100); // generous budget: mult is multi-cycle + early-exit variable
        chk("P6: $1 = 6", get_reg(1), 64'd6);
        chk("P6: $2 = 7", get_reg(2), 64'd7);
        chk("P6: $9 = 1 (post-mult instr still executes correctly)", get_reg(9), 64'd1);
        chk("P6: $3 = LO = 6*7 = 42 (mflo after busy stall)", get_reg(3), 64'd42);

        // =====================================================
        // PHASE 7: Unconditional jump
        // =====================================================
        $display("\n---- PHASE 7: Unconditional jump ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test7_jump.hex");
        run_cycles(20);
        chk("P7: $1 = 1 (before jump)", get_reg(1), 64'd1);
        chk("P7: $2 = 55 (jump target reached, skipped instrs not executed)", get_reg(2), 64'd55);

        // =====================================================
        // PHASE 8: Combined program
        // =====================================================
        $display("\n---- PHASE 8: Combined program (sum 1..5, store/load-use) ----");
        load_and_reset("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/test8_combined.hex");
        run_cycles(30);
        chk("P8: $1 = sum(1..5) = 15", get_reg(1), 64'd15);
        chk("P8: mem[8] = 15", get_mem_dword(8) & 64'hFFFFFFFF, 64'd15);
        chk("P8: $3 = mem[8] = 15 (load-use)", get_reg(3), 64'd15);
        chk("P8: $4 = $3+$3 = 30 (load-use stall then fwd)", get_reg(4), 64'd30);

        // =====================================================
        // SUMMARY
        // =====================================================
        if (errors == 0)
            $display("\n==== ALL INTEGRATION TESTS PASSED (total cycles simulated: %0d) ====", cycle_count);
        else
            $display("\n==== %0d INTEGRATION TEST(S) FAILED ====", errors);

        $finish;
    end

    initial begin
        #100000;
        $display("ERROR: Integration testbench timeout");
        $finish;
    end

endmodule
