`timescale 1ns / 1ps
//=============================================================
// Module : MIPS_Top_tb  (Testbench)
//
// Fixes applied vs original Testbench.v:
//   1. DUT module name corrected to MIPS_Top (matches Top.v).
//   2. $dumpvars references correct module name MIPS_Top_tb.
//   3. Monitor extended to show simulation time clearly.
//   4. Simulation runs for 200 cycles (2000 ns at 10 ns period).
//=============================================================

module MIPS_Top_tb;

parameter DATA_WIDTH = 32;
parameter CLK_PERIOD = 10;      // 100 MHz

reg clk;
reg rst_n;

wire [DATA_WIDTH-1:0] instructionF;

//=============================================================
// DUT
//=============================================================

MIPS_Top #(
    .DATA_WIDTH(DATA_WIDTH)
) DUT (
    .i_clk         (clk),
    .i_reset_n     (rst_n),
    .o_instructionF(instructionF)
);

//=============================================================
// Clock generation (100 MHz)
//=============================================================

initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

//=============================================================
// Reset sequence
//=============================================================

initial begin
    rst_n = 1'b0;
    @(posedge clk);
    @(posedge clk);
    #1;
    rst_n = 1'b1;
end

//=============================================================
// Simulation timeout
//=============================================================

initial begin
    #(CLK_PERIOD * 200);
    $display("Simulation complete at %0t ns", $time);
    $finish;
end

//=============================================================
// Monitor — prints instruction in IF each cycle
//=============================================================

initial begin
    $display("╔══════════════════════════════════════╗");
    $display("║   MIPS 5-Stage Pipeline Simulation   ║");
    $display("╚══════════════════════════════════════╝");
    $display("Time(ns)\tIF Instruction");
    $monitor("%0t\t\t%h", $time, instructionF);
end

//=============================================================
// Waveform dump
//=============================================================

initial begin
    $dumpfile("mips_pipeline.vcd");
    $dumpvars(0, MIPS_Top_tb);
end

endmodule
