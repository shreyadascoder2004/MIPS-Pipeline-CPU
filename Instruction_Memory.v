`timescale 1ns / 1ps
//=============================================================
// Module : instruction_memory
// Description : Read-only instruction memory.
//               - Loaded from "instructions.mem" at sim start.
//               - Combinational (asynchronous) read.
//               - Word-aligned: index = pc_addr[9:2].
//               - Supports 256 x 32-bit words (1 KB).
//=============================================================

module instruction_memory #(
    parameter MEM_DEPTH = 256
)(
    input  wire        rst_n,
    input  wire [31:0] pc_addr,
    output reg  [31:0] instruction
);

reg [31:0] inst_mem [0:MEM_DEPTH-1];

// Load program at simulation start
initial begin
    $readmemh("instructions.mem", inst_mem);
end

// Asynchronous read; output NOP on reset
always @(*) begin
    if (!rst_n)
        instruction = 32'b0;
    else
        instruction = inst_mem[pc_addr[9:2]];
end

endmodule
