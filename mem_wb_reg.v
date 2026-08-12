// =============================================================
// Module      : mem_wb_reg
// Description : Pipeline register between MEM and WB stages.
//               Last pipeline register in the pipeline -- carries
//               everything WB needs to select and commit the final
//               register-file write.
//
//               mem_to_reg (carried through from ID, unchanged by
//               MEM/EX) selects among: ALU result / memory read data
//               / PC+4 (jal) / HI/LO result in the WB-stage mux.
//
//               No flush needed in principle (nothing after WB to
//               squash), but included for reset-symmetry and so a
//               stall bubble injected upstream naturally drains to
//               a harmless all-zero WB with reg_write=0.
// =============================================================

module mem_wb_reg (
    input  wire        clk,
    input  wire         rst_n,
    input  wire         stall,
    input  wire         flush,

    // ---- control in ----
    input  wire [1:0]   mem_to_reg_in,
    input  wire         reg_write_in,

    // ---- data in ----
    input  wire [63:0]  alu_result_in,
    input  wire [63:0]  mem_read_data_in,
    input  wire [63:0]  pc_plus4_in,
    input  wire [63:0]  hilo_result_in,
    input  wire [4:0]   write_addr_in,
    input  wire          valid_in,

    // ---- control out ----
    output reg  [1:0]   mem_to_reg_out,
    output reg          reg_write_out,

    // ---- data out ----
    output reg  [63:0]  alu_result_out,
    output reg  [63:0]  mem_read_data_out,
    output reg  [63:0]  pc_plus4_out,
    output reg  [63:0]  hilo_result_out,
    output reg  [4:0]   write_addr_out,
    output reg           valid_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_to_reg_out    <= 2'b00;
            reg_write_out     <= 1'b0;
            alu_result_out    <= 64'h0;
            mem_read_data_out <= 64'h0;
            pc_plus4_out      <= 64'h0;
            hilo_result_out   <= 64'h0;
            write_addr_out    <= 5'b0;
            valid_out         <= 1'b0;
        end
        else if (flush) begin
            mem_to_reg_out    <= 2'b00;
            reg_write_out     <= 1'b0;
            alu_result_out    <= 64'h0;
            mem_read_data_out <= 64'h0;
            pc_plus4_out      <= 64'h0;
            hilo_result_out   <= 64'h0;
            write_addr_out    <= 5'b0;
            valid_out         <= 1'b0;
        end
        else if (stall) begin
            // hold
        end
        else begin
            mem_to_reg_out    <= mem_to_reg_in;
            reg_write_out     <= reg_write_in;
            alu_result_out    <= alu_result_in;
            mem_read_data_out <= mem_read_data_in;
            pc_plus4_out      <= pc_plus4_in;
            hilo_result_out   <= hilo_result_in;
            write_addr_out    <= write_addr_in;
            valid_out         <= valid_in;
        end
    end

endmodule
