

module pc (
    input  wire        clk,
    input  wire         rst_n,       
    input  wire         pc_write_en,  // 1 = update PC, 0 = hold (stall)
    input  wire [63:0]  pc_next,      // next PC value
    output reg  [63:0]  pc_out        // current PC value
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_out <= 64'h0000000000000000;
        else if (pc_write_en)
            pc_out <= pc_next;
       
    end

endmodule
