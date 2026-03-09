`timescale 1ns / 1ps
//=============================================================
// Module : register_file
// Description : 32 x 32-bit MIPS general-purpose register file.
//               - $0 (register 0) is hardwired to zero.
//               - Synchronous write on rising edge when we=1.
//               - Asynchronous read with write-bypass (forwarding
//                 within the same cycle to avoid an extra stall).
//=============================================================

module register_file #(
    parameter DATA_WIDTH = 32,
    parameter REG_COUNT  = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Read ports (ID stage)
    input  wire [4:0]             rs,
    input  wire [4:0]             rt,

    // Write port (WB stage)
    input  wire [4:0]             rd,   // destination register
    input  wire                   we,   // write enable
    input  wire [DATA_WIDTH-1:0]  wd,   // write data

    output wire [DATA_WIDTH-1:0]  rd1,  // rs read data
    output wire [DATA_WIDTH-1:0]  rd2   // rt read data
);

reg [DATA_WIDTH-1:0] reg_array [0:REG_COUNT-1];

integer i;

// Synchronous write; synchronous reset of all registers
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < REG_COUNT; i = i + 1)
            reg_array[i] <= {DATA_WIDTH{1'b0}};
    end
    else if (we && (rd != 5'b00000)) begin
        reg_array[rd] <= wd;
    end
end

// Asynchronous read with write-bypass and $0 guard
assign rd1 = (rs == 5'b00000)       ? {DATA_WIDTH{1'b0}} :
             (we && rd == rs)        ? wd                 :
                                       reg_array[rs];

assign rd2 = (rt == 5'b00000)       ? {DATA_WIDTH{1'b0}} :
             (we && rd == rt)        ? wd                 :
                                       reg_array[rt];

endmodule
