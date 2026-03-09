`timescale 1ns / 1ps
//=============================================================
// Module : pc_increment
// Description : Computes PC + 4.
//               Also reused as the branch-target adder in
//               the Decode stage via a separate instance.
// Fix applied : Removed trailing comma from parameter list.
//=============================================================

module pc_increment #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] pc,
    output wire [WIDTH-1:0] pc_next
);

assign pc_next = pc + 32'd4;

endmodule
