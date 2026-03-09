`timescale 1ns / 1ps
//=============================================================
// File    : Supporting_Modules.v
// Contains: sign_extend, shift_left2, jump_shift,
//           mux2 (parameterised), mux3
//
// These are the supporting modules referenced in Top.v.
// All port names and widths match exactly what Top.v expects.
//=============================================================


//-------------------------------------------------------------
// sign_extend
// Sign-extends a 16-bit immediate to 32 bits.
//-------------------------------------------------------------
module sign_extend (
    input  wire [15:0] in,
    output wire [31:0] out
);
    assign out = {{16{in[15]}}, in};
endmodule


//-------------------------------------------------------------
// shift_left2
// Shifts a 32-bit value left by 2 bits (multiply by 4).
// Used to convert branch word-offset to byte-offset.
//-------------------------------------------------------------
module shift_left2 (
    input  wire [31:0] in,
    output wire [31:0] out
);
    assign out = {in[29:0], 2'b00};
endmodule


//-------------------------------------------------------------
// jump_shift
// Builds the 32-bit J-type jump target address:
//   { PC+4[31:28], instr[25:0], 2'b00 }
//-------------------------------------------------------------
module jump_shift (
    input  wire [31:0] pc_plus4,    // PC+4 from ID stage
    input  wire [25:0] jump_addr,   // instruction[25:0]
    output wire [31:0] jump_target
);
    assign jump_target = {pc_plus4[31:28], jump_addr, 2'b00};
endmodule


//-------------------------------------------------------------
// mux2  (parameterised width, default 32-bit)
// 2-to-1 multiplexer.
//-------------------------------------------------------------
module mux2 #(
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] in0,
    input  wire [DATA_WIDTH-1:0] in1,
    input  wire                  sel,
    output wire [DATA_WIDTH-1:0] out
);
    assign out = sel ? in1 : in0;
endmodule


//-------------------------------------------------------------
// mux3  (32-bit only)
// 3-to-1 multiplexer used for forwarding paths in EX stage.
//   sel = 2'b00 → in0 (register file)
//   sel = 2'b01 → in1 (WB result)
//   sel = 2'b10 → in2 (MEM ALU result)
//-------------------------------------------------------------
module mux3 (
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    input  wire [31:0] in2,
    input  wire [1:0]  sel,
    output reg  [31:0] out
);
    always @(*) begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            default: out = in0;
        endcase
    end
endmodule
