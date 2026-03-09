`timescale 1ns / 1ps
//=============================================================
// Module : program_counter
// Description : 32-bit Program Counter.
//               - Resets to 0x00000000 on active-low rst_n.
//               - Holds value when stall is asserted.
//               - Updates to pc_in on every rising clock edge
//                 when not stalled.
//=============================================================

module program_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,       // active-high stall (from hazard unit)
    input  wire [31:0] pc_in,       // next PC value (from PC-select mux)
    output reg  [31:0] pc_out       // current PC
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pc_out <= 32'h0000_0000;
    else if (!stall)
        pc_out <= pc_in;
    // else: hold pc_out (stall)
end

endmodule
