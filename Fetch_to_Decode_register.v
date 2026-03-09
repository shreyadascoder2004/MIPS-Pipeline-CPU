`timescale 1ns / 1ps
//=============================================================
// Module : fetch_decode  (IF/ID Pipeline Register)
// Description : Latches instruction and PC+4 from IF stage.
//               - flush : inserts NOP (zero instruction).
//               - stall : holds current values.
//               - Normal: latches new instruction & PC+4.
//=============================================================

module fetch_decode (
    input  wire        clk,
    input  wire        rst_n,

    // Hazard control
    input  wire        stall,           // hold current values
    input  wire        flush,           // insert NOP

    // From IF stage
    input  wire [31:0] instruction_in,
    input  wire [31:0] pc_plus4_in,

    // To ID stage
    output reg  [31:0] instruction_out,
    output reg  [31:0] pc_plus4_out
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        instruction_out <= 32'b0;
        pc_plus4_out    <= 32'b0;
    end
    else if (flush) begin           // flush overrides stall
        instruction_out <= 32'b0;
        pc_plus4_out    <= 32'b0;
    end
    else if (!stall) begin
        instruction_out <= instruction_in;
        pc_plus4_out    <= pc_plus4_in;
    end
    // else stall: hold previous values
end

endmodule
