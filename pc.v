// =============================================================
// Module      : pc
// Description : 64-bit Program Counter register for IF stage.
//               - Async active-low reset to 0x0000000000000000
//               - Holds value when pc_write_en = 0 (stall: load-use
//                 hazard, mult/div busy, etc.)
//               - next-PC selection (PC+4 / branch target / jump
//                 target / jr target) is done in the IF-stage mux,
//                 outside this module, and presented on pc_next.
// =============================================================

module pc (
    input  wire        clk,
    input  wire         rst_n,        // async active-low reset
    input  wire         pc_write_en,  // 1 = update PC, 0 = hold (stall)
    input  wire [63:0]  pc_next,      // next PC value
    output reg  [63:0]  pc_out        // current PC value
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_out <= 64'h0000000000000000;
        else if (pc_write_en)
            pc_out <= pc_next;
        // else: hold (stall)
    end

endmodule
