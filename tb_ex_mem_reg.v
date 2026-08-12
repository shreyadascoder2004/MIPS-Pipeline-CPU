// =============================================================
// Testbench   : tb_ex_mem_reg
// Tests       : ex_mem_reg.v
//   1. Reset -> all control 0, valid=0.
//   2. Normal latch-through, spot-check full bundle.
//   3. Stall holds.
//   4. Flush zeros side-effect signals + valid.
// =============================================================
`timescale 1ns/1ps

module tb_ex_mem_reg;

    reg clk, rst_n, stall, flush;
    reg [1:0] mem_to_reg_in;
    reg reg_write_in, mem_read_in, mem_write_in, mem_unsigned_in, jump_link_in, valid_in;
    reg [2:0] mem_width_in;
    reg [63:0] alu_result_in, write_data_in, pc_plus4_in;
    reg [4:0] write_addr_in;

    wire [1:0] mem_to_reg_out;
    wire reg_write_out, mem_read_out, mem_write_out, mem_unsigned_out, jump_link_out, valid_out;
    wire [2:0] mem_width_out;
    wire [63:0] alu_result_out, write_data_out, pc_plus4_out;
    wire [4:0] write_addr_out;

    integer errors;

    ex_mem_reg dut (
        .clk(clk), .rst_n(rst_n), .stall(stall), .flush(flush),
        .mem_to_reg_in(mem_to_reg_in), .reg_write_in(reg_write_in),
        .mem_read_in(mem_read_in), .mem_write_in(mem_write_in),
        .mem_width_in(mem_width_in), .mem_unsigned_in(mem_unsigned_in),
        .jump_link_in(jump_link_in),
        .alu_result_in(alu_result_in), .write_data_in(write_data_in),
        .pc_plus4_in(pc_plus4_in), .write_addr_in(write_addr_in), .valid_in(valid_in),

        .mem_to_reg_out(mem_to_reg_out), .reg_write_out(reg_write_out),
        .mem_read_out(mem_read_out), .mem_write_out(mem_write_out),
        .mem_width_out(mem_width_out), .mem_unsigned_out(mem_unsigned_out),
        .jump_link_out(jump_link_out),
        .alu_result_out(alu_result_out), .write_data_out(write_data_out),
        .pc_plus4_out(pc_plus4_out), .write_addr_out(write_addr_out), .valid_out(valid_out)
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

    task drive_bundle;
        begin
            mem_to_reg_in=2'b00; reg_write_in=1; mem_read_in=0; mem_write_in=0;
            mem_width_in=3'b010; mem_unsigned_in=0; jump_link_in=0;
            alu_result_in=64'd42; write_data_in=64'd7; pc_plus4_in=64'h50;
            write_addr_in=5'd8; valid_in=1;
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0; stall = 0; flush = 0;
        drive_bundle();

        @(negedge clk);
        chk1("reset reg_write_out", reg_write_out, 0);
        chk1("reset valid_out", valid_out, 0);
        chkN("reset alu_result_out", alu_result_out, 64'h0);

        rst_n = 1;
        @(negedge clk);
        chk1("normal reg_write_out", reg_write_out, 1);
        chk1("normal valid_out", valid_out, 1);
        chkN("normal alu_result_out", alu_result_out, 64'd42);
        chkN("normal write_data_out", write_data_out, 64'd7);
        chk1("normal write_addr_out", (write_addr_out==5'd8), 1);
        chkN("normal pc_plus4_out", pc_plus4_out, 64'h50);

        stall = 1;
        alu_result_in = 64'd999; write_addr_in = 5'd31;
        @(negedge clk);
        chkN("stall alu_result_out held", alu_result_out, 64'd42);
        chk1("stall write_addr_out held", (write_addr_out==5'd8), 1);
        stall = 0;

        drive_bundle();
        flush = 1;
        @(negedge clk);
        chk1("flush reg_write_out", reg_write_out, 0);
        chk1("flush mem_read_out", mem_read_out, 0);
        chk1("flush mem_write_out", mem_write_out, 0);
        chk1("flush valid_out", valid_out, 0);
        flush = 0;

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    initial begin #1000; $display("ERROR: timeout"); $finish; end

endmodule
