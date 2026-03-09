`timescale 1ns / 1ps
//=============================================================
// Module : data_memory
// Description : 256-word (1 KB) synchronous-write,
//               asynchronous-read data RAM.
//               - MemWriteM : enable write on rising clock edge.
//               - MemReadM  : gate read output (now driven from
//                             Top.v via MemReadM signal).
//               - Word-aligned: address index = addr[9:2].
//
// Fix applied : MemReadM is now properly used to gate output.
//               Reset uses synchronous clear on posedge (safer).
//=============================================================

module data_memory #(
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 256
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  MemWriteM,
    input  wire                  MemReadM,
    input  wire [DATA_WIDTH-1:0] WriteDataM,
    input  wire [DATA_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] ReadDataM
);

reg [DATA_WIDTH-1:0] data_mem [0:MEM_DEPTH-1];

integer i;

// Synchronous write; synchronous reset
always @(posedge clk) begin
    if (!rst_n) begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            data_mem[i] <= {DATA_WIDTH{1'b0}};
    end
    else if (MemWriteM) begin
        data_mem[addr[9:2]] <= WriteDataM;
    end
end

// Asynchronous (combinational) read, gated by MemReadM
assign ReadDataM = MemReadM ? data_mem[addr[9:2]] : {DATA_WIDTH{1'b0}};

endmodule
