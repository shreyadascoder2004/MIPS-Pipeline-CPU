// =============================================================
// Testbench   : tb_mem_wb_reg
// Tests       : mem_wb_reg.v
//   1. Reset -> control 0, valid=0.
//   2. Normal latch-through, full bundle spot-check.
//   3. Stall holds.
//   4. Flush zeros reg_write + valid.
// =============================================================
`timescale 1ns/1ps

module tb_mem_wb_reg;

    reg clk, rst_n, stall, flush;
    reg [1:0] mem_to_reg_in;
    reg reg_write_in, valid_in;
    reg [63:0] alu_result_in, mem_read_data_in, pc_plus4_in, hilo_result_in;
    reg [4:0] write_addr_in;

    wire [1:0] mem_to_reg_out;
    wire reg_write_out, valid_out;
    wire [63:0] alu_result_out, mem_read_data_out, pc_plus4_out, hilo_result_out;
    wire [4:0] write_addr_out;

    integer errors;

    mem_wb_reg dut (
        .clk(clk), .rst_n(rst_n), .stall(stall), .flush(flush),
        .mem_to_reg_in(mem_to_reg_in), .reg_write_in(reg_write_in),
        .alu_result_in(alu_result_in), .mem_read_data_in(mem_read_data_in),
        .pc_plus4_in(pc_plus4_in), .hilo_result_in(hilo_result_in),
        .write_addr_in(write_addr_in), .valid_in(valid_in),

        .mem_to_reg_out(mem_to_reg_out), .reg_write_out(reg_write_out),
        .alu_result_out(alu_result_out), .mem_read_data_out(mem_read_data_out),
        .pc_plus4_out(pc_plus4_out), .hilo_result_out(hilo_result_out),
        .write_addr_out(write_addr_out), .valid_out(valid_out)
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
            mem_to_reg_in=2'b01; reg_write_in=1;
            alu_result_in=64'd10; mem_read_data_in=64'd99;
            pc_plus4_in=64'h60; hilo_result_in=64'd0;
            write_addr_in=5'd15; valid_in=1;
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0; stall = 0; flush = 0;
        drive_bundle();

        @(negedge clk);
        chk1("reset reg_write_out", reg_write_out, 0);
        chk1("reset valid_out", valid_out, 0);

        rst_n = 1;
        @(negedge clk);
        chk1("normal reg_write_out", reg_write_out, 1);
        chk1("normal valid_out", valid_out, 1);
        chkN("normal mem_read_data_out", mem_read_data_out, 64'd99);
        chkN("normal alu_result_out", alu_result_out, 64'd10);
        chk1("normal write_addr_out", (write_addr_out==5'd15), 1);
        chk1("normal mem_to_reg_out", (mem_to_reg_out==2'b01), 1);

        stall = 1;
        mem_read_data_in = 64'd777;
        @(negedge clk);
        chkN("stall mem_read_data_out held", mem_read_data_out, 64'd99);
        stall = 0;

        drive_bundle();
        flush = 1;
        @(negedge clk);
        chk1("flush reg_write_out", reg_write_out, 0);
        chk1("flush valid_out", valid_out, 0);
        flush = 0;

        if (errors == 0) $display("\n==== ALL TESTS PASSED ====");
        else $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    initial begin #1000; $display("ERROR: timeout"); $finish; end

endmodule
