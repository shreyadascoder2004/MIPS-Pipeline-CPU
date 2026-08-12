// =============================================================
// Module      : if_id_reg
// Description : Pipeline register between IF and ID stages.
//
//               Carries:
//                 - the fetched 32-bit instruction
//                 - PC+4 (64-bit) -- needed in ID for jal link value
//                   and for branch-target address computation
//                 - a valid bit -- cleared on flush so a squashed
//                   instruction can never cause a register write,
//                   memory write, or branch in a later stage
//
//               Control:
//                 - stall   : hold current contents (load-use hazard,
//                             mult/div busy stall). Bubble is NOT
//                             inserted; the same instruction stays
//                             latched here and is re-presented to ID
//                             next cycle once the hazard clears.
//                 - flush   : force NOP + valid=0 (taken branch/jump
//                             misprediction recovery). Takes priority
//                             over stall.
//
//               Async reset also forces NOP + valid=0.
// =============================================================

module if_id_reg (
    input  wire        clk,
    input  wire         rst_n,

    input  wire         stall,        // hold current IF/ID contents
    input  wire         flush,        // squash: force NOP, valid=0

    input  wire [31:0]  instr_in,     // from instr_mem
    input  wire [63:0]  pc_plus4_in,  // from IF stage adder

    output reg  [31:0]  instr_out,
    output reg  [63:0]  pc_plus4_out,
    output reg           valid_out
);

    localparam [31:0] NOP_INSTR = 32'h00000000; // sll $0,$0,$0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_out    <= NOP_INSTR;
            pc_plus4_out <= 64'h0;
            valid_out    <= 1'b0;
        end
        else if (flush) begin
            instr_out    <= NOP_INSTR;
            pc_plus4_out <= 64'h0;
            valid_out    <= 1'b0;
        end
        else if (stall) begin
            // hold: explicitly do nothing (all outputs retain value)
        end
        else begin
            instr_out    <= instr_in;
            pc_plus4_out <= pc_plus4_in;
            valid_out    <= 1'b1;
        end
    end

endmodule
