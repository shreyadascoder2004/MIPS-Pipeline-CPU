// =============================================================
// Testbench   : tb_forwarding_unit
// Tests       : forwarding_unit.v
//
// Checks:
//   1. No hazard -> forward_a=00, forward_b=00.
//   2. EX/MEM hazard on rs -> forward_a=01.
//   3. EX/MEM hazard on rt -> forward_b=01.
//   4. MEM/WB hazard on rs (no EX/MEM match) -> forward_a=10.
//   5. EX/MEM priority over MEM/WB when both match same reg.
//   6. $0 never forwarded even if write_addr coincidentally 0.
//   7. reg_write=0 in producing stage -> no forward even if addr matches.
//   8. valid=0 (bubble) in producing stage -> no forward even if addr matches.
//   9. Independent forward_a and forward_b hazards simultaneously
//      (rs from EX/MEM, rt from MEM/WB).
// =============================================================
`timescale 1ns/1ps

module tb_forwarding_unit;

    reg [4:0] ex_rs_addr, ex_rt_addr;
    reg [4:0] exmem_write_addr, memwb_write_addr;
    reg exmem_reg_write, exmem_valid, memwb_reg_write, memwb_valid;
    wire [1:0] forward_a, forward_b;

    integer errors;

    forwarding_unit dut (
        .ex_rs_addr(ex_rs_addr), .ex_rt_addr(ex_rt_addr),
        .exmem_write_addr(exmem_write_addr), .exmem_reg_write(exmem_reg_write), .exmem_valid(exmem_valid),
        .memwb_write_addr(memwb_write_addr), .memwb_reg_write(memwb_reg_write), .memwb_valid(memwb_valid),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    task chk(input [255:0] name, input [1:0] actual, input [1:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%b got=%b", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %b", name, actual);
        end
    endtask

    initial begin
        errors = 0;

        // ---- 1: no hazard ----
        ex_rs_addr=5'd1; ex_rt_addr=5'd2;
        exmem_write_addr=5'd9; exmem_reg_write=1; exmem_valid=1;
        memwb_write_addr=5'd10; memwb_reg_write=1; memwb_valid=1;
        #1; chk("no hazard forward_a", forward_a, 2'b00);
        chk("no hazard forward_b", forward_b, 2'b00);

        // ---- 2: EX/MEM hazard on rs ----
        exmem_write_addr = 5'd1; // matches ex_rs_addr
        #1; chk("EX/MEM hazard rs -> forward_a", forward_a, 2'b01);

        // ---- 3: EX/MEM hazard on rt ----
        exmem_write_addr = 5'd9; // reset
        exmem_write_addr = 5'd2; // matches ex_rt_addr
        #1; chk("EX/MEM hazard rt -> forward_b", forward_b, 2'b01);

        // ---- 4: MEM/WB hazard on rs, no EX/MEM match ----
        exmem_write_addr = 5'd9; // no match
        memwb_write_addr = 5'd1; // matches ex_rs_addr
        #1; chk("MEM/WB hazard rs -> forward_a", forward_a, 2'b10);

        // ---- 5: EX/MEM priority over MEM/WB ----
        exmem_write_addr = 5'd1; memwb_write_addr = 5'd1; // both match rs
        #1; chk("EX/MEM priority over MEM/WB", forward_a, 2'b01);

        // ---- 6: $0 never forwarded ----
        ex_rs_addr = 5'd0; exmem_write_addr = 5'd0; // "matches" but is $0
        #1; chk("$0 never forwarded (forward_a)", forward_a, 2'b00);
        ex_rs_addr = 5'd1; // restore

        // ---- 7: reg_write=0 blocks forward ----
        exmem_write_addr = 5'd1; exmem_reg_write = 0;
        memwb_write_addr = 5'd9; // no match, so should fall through to 00
        #1; chk("reg_write=0 blocks EX/MEM forward", forward_a, 2'b00);
        exmem_reg_write = 1;

        // ---- 8: valid=0 (bubble) blocks forward ----
        exmem_write_addr = 5'd1; exmem_valid = 0;
        #1; chk("valid=0 blocks EX/MEM forward", forward_a, 2'b00);
        exmem_valid = 1;

        // ---- 9: independent simultaneous hazards ----
        ex_rs_addr = 5'd3; ex_rt_addr = 5'd4;
        exmem_write_addr = 5'd3; exmem_reg_write=1; exmem_valid=1; // rs from EX/MEM
        memwb_write_addr = 5'd4; memwb_reg_write=1; memwb_valid=1; // rt from MEM/WB
        #1;
        chk("simultaneous: forward_a (EX/MEM)", forward_a, 2'b01);
        chk("simultaneous: forward_b (MEM/WB)", forward_b, 2'b10);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
