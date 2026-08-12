// =============================================================
// Testbench   : tb_id_forward_mux
// Tests       : id_forward_mux.v
//
// Checks:
//   1. No hazard -> passes through register-file values.
//   2. EX/MEM hazard on rs -> forwards exmem_result.
//   3. EX/MEM hazard on rt -> forwards exmem_result.
//   4. MEM/WB hazard on rs (no EX/MEM match) -> forwards memwb_result.
//   5. EX/MEM priority over MEM/WB.
//   6. $0 never forwarded.
//   7. reg_write=0 blocks forward.
//   8. valid=0 blocks forward.
//   9. Independent simultaneous hazards on rs and rt.
// =============================================================
`timescale 1ns/1ps

module tb_id_forward_mux;

    reg [4:0] id_rs_addr, id_rt_addr;
    reg [63:0] regfile_rs_val, regfile_rt_val;
    reg [4:0] exmem_write_addr, memwb_write_addr;
    reg exmem_reg_write, exmem_valid, memwb_reg_write, memwb_valid;
    reg [63:0] exmem_result, memwb_result;
    wire [63:0] rs_val_fwd, rt_val_fwd;

    integer errors;

    id_forward_mux dut (
        .id_rs_addr(id_rs_addr), .id_rt_addr(id_rt_addr),
        .regfile_rs_val(regfile_rs_val), .regfile_rt_val(regfile_rt_val),
        .exmem_write_addr(exmem_write_addr), .exmem_reg_write(exmem_reg_write), .exmem_valid(exmem_valid),
        .exmem_result(exmem_result),
        .memwb_write_addr(memwb_write_addr), .memwb_reg_write(memwb_reg_write), .memwb_valid(memwb_valid),
        .memwb_result(memwb_result),
        .rs_val_fwd(rs_val_fwd), .rt_val_fwd(rt_val_fwd)
    );

    task chk(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    initial begin
        errors = 0;

        // ---- 1: no hazard ----
        id_rs_addr=5'd1; id_rt_addr=5'd2;
        regfile_rs_val=64'd100; regfile_rt_val=64'd200;
        exmem_write_addr=5'd9; exmem_reg_write=1; exmem_valid=1; exmem_result=64'd999;
        memwb_write_addr=5'd10; memwb_reg_write=1; memwb_valid=1; memwb_result=64'd888;
        #1;
        chk("no hazard rs_val_fwd", rs_val_fwd, 64'd100);
        chk("no hazard rt_val_fwd", rt_val_fwd, 64'd200);

        // ---- 2: EX/MEM hazard on rs ----
        exmem_write_addr = 5'd1;
        #1; chk("EX/MEM hazard rs", rs_val_fwd, 64'd999);

        // ---- 3: EX/MEM hazard on rt ----
        exmem_write_addr = 5'd9;
        exmem_write_addr = 5'd2;
        #1; chk("EX/MEM hazard rt", rt_val_fwd, 64'd999);

        // ---- 4: MEM/WB hazard on rs, no EX/MEM match ----
        exmem_write_addr = 5'd9;
        memwb_write_addr = 5'd1;
        #1; chk("MEM/WB hazard rs", rs_val_fwd, 64'd888);

        // ---- 5: EX/MEM priority ----
        exmem_write_addr = 5'd1; memwb_write_addr = 5'd1;
        #1; chk("EX/MEM priority", rs_val_fwd, 64'd999);

        // ---- 6: $0 never forwarded ----
        id_rs_addr = 5'd0; exmem_write_addr = 5'd0;
        #1; chk("$0 never forwarded", rs_val_fwd, regfile_rs_val);
        id_rs_addr = 5'd1;

        // ---- 7: reg_write=0 blocks ----
        exmem_write_addr = 5'd1; exmem_reg_write = 0; memwb_write_addr = 5'd9;
        #1; chk("reg_write=0 blocks", rs_val_fwd, regfile_rs_val);
        exmem_reg_write = 1;

        // ---- 8: valid=0 blocks ----
        exmem_write_addr = 5'd1; exmem_valid = 0;
        #1; chk("valid=0 blocks", rs_val_fwd, regfile_rs_val);
        exmem_valid = 1;

        // ---- 9: simultaneous independent hazards ----
        id_rs_addr=5'd3; id_rt_addr=5'd4;
        exmem_write_addr=5'd3; exmem_reg_write=1; exmem_valid=1; exmem_result=64'd333;
        memwb_write_addr=5'd4; memwb_reg_write=1; memwb_valid=1; memwb_result=64'd444;
        #1;
        chk("simultaneous rs (EX/MEM)", rs_val_fwd, 64'd333);
        chk("simultaneous rt (MEM/WB)", rt_val_fwd, 64'd444);

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
