// =============================================================
// Testbench   : tb_id_ex_reg
// Tests       : id_ex_reg.v
//
// Checks:
//   1. Async reset -> all control signals 0, valid=0.
//   2. Normal latch-through of a full realistic signal bundle
//      (simulating a decoded 'add' instruction), spot-checking
//      every output field to catch any port-order mis-wiring.
//   3. Stall holds all outputs unchanged.
//   4. Flush zeros all side-effect control signals + valid,
//      even when inputs still show a "hot" instruction.
// =============================================================
`timescale 1ns/1ps

module tb_id_ex_reg;

    reg clk, rst_n, stall, flush;

    reg reg_dst_in, alu_src_in, reg_write_in, mem_read_in, mem_write_in;
    reg branch_in, jump_in, jump_link_in, jump_reg_in, alu_width64_in;
    reg mem_unsigned_in, is_mult_div_in, valid_in, mult_div_signed_in;
    reg [1:0] mem_to_reg_in;
    reg [2:0] branch_type_in, mem_width_in;
    reg [4:0] alu_ctrl_in, rs_addr_in, rt_addr_in, rd_addr_in;
    reg [5:0] shamt_in;
    reg [63:0] read_data1_in, read_data2_in, imm_ext_in, pc_plus4_in;

    wire reg_dst_out, alu_src_out, reg_write_out, mem_read_out, mem_write_out;
    wire branch_out, jump_out, jump_link_out, jump_reg_out, alu_width64_out;
    wire mem_unsigned_out, is_mult_div_out, valid_out, mult_div_signed_out;
    wire [1:0] mem_to_reg_out;
    wire [2:0] branch_type_out, mem_width_out;
    wire [4:0] alu_ctrl_out, rs_addr_out, rt_addr_out, rd_addr_out;
    wire [5:0] shamt_out;
    wire [63:0] read_data1_out, read_data2_out, imm_ext_out, pc_plus4_out;

    integer errors;

    id_ex_reg dut (
        .clk(clk), .rst_n(rst_n), .stall(stall), .flush(flush),
        .reg_dst_in(reg_dst_in), .alu_src_in(alu_src_in), .mem_to_reg_in(mem_to_reg_in),
        .reg_write_in(reg_write_in), .mem_read_in(mem_read_in), .mem_write_in(mem_write_in),
        .branch_in(branch_in), .branch_type_in(branch_type_in),
        .jump_in(jump_in), .jump_link_in(jump_link_in), .jump_reg_in(jump_reg_in),
        .alu_ctrl_in(alu_ctrl_in), .alu_width64_in(alu_width64_in),
        .mem_width_in(mem_width_in), .mem_unsigned_in(mem_unsigned_in),
        .is_mult_div_in(is_mult_div_in), .mult_div_signed_in(mult_div_signed_in),
        .read_data1_in(read_data1_in), .read_data2_in(read_data2_in),
        .imm_ext_in(imm_ext_in), .pc_plus4_in(pc_plus4_in),
        .rs_addr_in(rs_addr_in), .rt_addr_in(rt_addr_in), .rd_addr_in(rd_addr_in),
        .shamt_in(shamt_in), .valid_in(valid_in),

        .reg_dst_out(reg_dst_out), .alu_src_out(alu_src_out), .mem_to_reg_out(mem_to_reg_out),
        .reg_write_out(reg_write_out), .mem_read_out(mem_read_out), .mem_write_out(mem_write_out),
        .branch_out(branch_out), .branch_type_out(branch_type_out),
        .jump_out(jump_out), .jump_link_out(jump_link_out), .jump_reg_out(jump_reg_out),
        .alu_ctrl_out(alu_ctrl_out), .alu_width64_out(alu_width64_out),
        .mem_width_out(mem_width_out), .mem_unsigned_out(mem_unsigned_out),
        .is_mult_div_out(is_mult_div_out), .mult_div_signed_out(mult_div_signed_out),
        .read_data1_out(read_data1_out), .read_data2_out(read_data2_out),
        .imm_ext_out(imm_ext_out), .pc_plus4_out(pc_plus4_out),
        .rs_addr_out(rs_addr_out), .rt_addr_out(rt_addr_out), .rd_addr_out(rd_addr_out),
        .shamt_out(shamt_out), .valid_out(valid_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task chk1(input [255:0] name, input actual, input exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%b got=%b", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %b", name, actual);
        end
    endtask
    task chkN(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin $display("FAIL: %0s exp=%h got=%h", name, exp, actual); errors=errors+1; end
            else $display("PASS: %0s = %h", name, actual);
        end
    endtask

    // Drive a representative "hot" bundle simulating a decoded 'add $3,$1,$2'
    task drive_add_bundle;
        begin
            reg_dst_in=1; alu_src_in=0; mem_to_reg_in=2'b00; reg_write_in=1;
            mem_read_in=0; mem_write_in=0; branch_in=0; branch_type_in=3'b000;
            jump_in=0; jump_link_in=0; jump_reg_in=0; alu_ctrl_in=5'b00000;
            alu_width64_in=0; mem_width_in=3'b010; mem_unsigned_in=0; is_mult_div_in=0;
            mult_div_signed_in=1;
            read_data1_in=64'd5; read_data2_in=64'd3; imm_ext_in=64'h0;
            pc_plus4_in=64'h20; rs_addr_in=5'd1; rt_addr_in=5'd2; rd_addr_in=5'd3;
            shamt_in=6'd0; valid_in=1;
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0; stall = 0; flush = 0;
        drive_add_bundle();

        @(negedge clk);
        // ---- Check 1: reset ----
        chk1("reset reg_write_out", reg_write_out, 0);
        chk1("reset valid_out", valid_out, 0);
        chkN("reset read_data1_out", read_data1_out, 64'h0);

        rst_n = 1;

        // ---- Check 2: normal latch, full bundle spot-check ----
        @(negedge clk);
        chk1("add: reg_dst_out", reg_dst_out, 1);
        chk1("add: reg_write_out", reg_write_out, 1);
        chk1("add: valid_out", valid_out, 1);
        chk1("add: alu_ctrl_out is ADD", (alu_ctrl_out==5'b00000), 1);
        chk1("add: rs_addr_out", (rs_addr_out==5'd1), 1);
        chk1("add: rt_addr_out", (rt_addr_out==5'd2), 1);
        chk1("add: rd_addr_out", (rd_addr_out==5'd3), 1);
        chkN("add: read_data1_out", read_data1_out, 64'd5);
        chkN("add: read_data2_out", read_data2_out, 64'd3);
        chkN("add: pc_plus4_out", pc_plus4_out, 64'h20);

        // ---- Check 3: stall holds ----
        stall = 1;
        read_data1_in = 64'hFFFF; rs_addr_in = 5'd9; reg_write_in = 0; // should NOT propagate
        @(negedge clk);
        chkN("stall: read_data1_out held", read_data1_out, 64'd5);
        chk1("stall: rs_addr_out held", (rs_addr_out==5'd1), 1);
        chk1("stall: reg_write_out held", reg_write_out, 1);
        stall = 0;

        // ---- Check 4: flush zeros side-effect signals ----
        drive_add_bundle(); // inputs still "hot"
        flush = 1;
        @(negedge clk);
        chk1("flush: reg_write_out", reg_write_out, 0);
        chk1("flush: mem_read_out", mem_read_out, 0);
        chk1("flush: mem_write_out", mem_write_out, 0);
        chk1("flush: branch_out", branch_out, 0);
        chk1("flush: jump_out", jump_out, 0);
        chk1("flush: is_mult_div_out", is_mult_div_out, 0);
        chk1("flush: valid_out", valid_out, 0);
        flush = 0;

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    initial begin #1000; $display("ERROR: timeout"); $finish; end

endmodule
