// =============================================================
// Module      : ex_mem_reg
// Description : Pipeline register between EX and MEM stages.
//
//               Carries the ALU result (or HI/LO result, or the
//               branch/jump target for a "resolved-late" corner
//               case -- NOTE: in our design branches resolve in ID,
//               so this register does NOT carry branch-decision
//               info; it only needs to pass through what MEM/WB
//               stages need).
//
//               EX stage has already: computed the ALU result,
//               selected forwarded operands (via the forwarding
//               unit feeding the ALU inputs -- forwarding muxes
//               live in the EX-stage top module, upstream of this
//               register, not inside it).
//
//               Control:
//                 - flush: needed for the exception/illegal-instr
//                   path later; zeroes side-effect signals.
//                 - No stall input: by pipeline design, once an
//                   instruction is in EX, MEM never needs to stall
//                   the stage behind it for THIS register specifically
//                   in our hazard scheme (load-use stalls happen in
//                   ID/EX insertion, mult/div busy stall freezes
//                   earlier stages) -- included anyway for symmetry
//                   and to support future extensions (e.g. memory
//                   stage stall on a cache miss if ever added).
// =============================================================

module ex_mem_reg (
    input  wire        clk,
    input  wire         rst_n,
    input  wire         stall,
    input  wire         flush,

    // ---- control in ----
    input  wire [1:0]   mem_to_reg_in,
    input  wire         reg_write_in,
    input  wire         mem_read_in,
    input  wire         mem_write_in,
    input  wire [2:0]   mem_width_in,
    input  wire         mem_unsigned_in,
    input  wire         jump_link_in,

    // ---- data in ----
    input  wire [63:0]  alu_result_in,
    input  wire [63:0]  write_data_in,   // store data (from rt, post-forwarding)
    input  wire [63:0]  pc_plus4_in,     // for jal writeback
    input  wire [4:0]   write_addr_in,   // destination register (post RegDst mux)
    input  wire          valid_in,

    // ---- control out ----
    output reg  [1:0]   mem_to_reg_out,
    output reg          reg_write_out,
    output reg          mem_read_out,
    output reg          mem_write_out,
    output reg  [2:0]   mem_width_out,
    output reg          mem_unsigned_out,
    output reg          jump_link_out,

    // ---- data out ----
    output reg  [63:0]  alu_result_out,
    output reg  [63:0]  write_data_out,
    output reg  [63:0]  pc_plus4_out,
    output reg  [4:0]   write_addr_out,
    output reg           valid_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_to_reg_out   <= 2'b00;
            reg_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            mem_width_out    <= 3'b000;
            mem_unsigned_out <= 1'b0;
            jump_link_out    <= 1'b0;
            alu_result_out   <= 64'h0;
            write_data_out   <= 64'h0;
            pc_plus4_out     <= 64'h0;
            write_addr_out   <= 5'b0;
            valid_out        <= 1'b0;
        end
        else if (flush) begin
            mem_to_reg_out   <= 2'b00;
            reg_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            mem_width_out    <= 3'b000;
            mem_unsigned_out <= 1'b0;
            jump_link_out    <= 1'b0;
            alu_result_out   <= 64'h0;
            write_data_out   <= 64'h0;
            pc_plus4_out     <= 64'h0;
            write_addr_out   <= 5'b0;
            valid_out        <= 1'b0;
        end
        else if (stall) begin
            // hold
        end
        else begin
            mem_to_reg_out   <= mem_to_reg_in;
            reg_write_out    <= reg_write_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            mem_width_out    <= mem_width_in;
            mem_unsigned_out <= mem_unsigned_in;
            jump_link_out    <= jump_link_in;
            alu_result_out   <= alu_result_in;
            write_data_out   <= write_data_in;
            pc_plus4_out     <= pc_plus4_in;
            write_addr_out   <= write_addr_in;
            valid_out        <= valid_in;
        end
    end

endmodule
