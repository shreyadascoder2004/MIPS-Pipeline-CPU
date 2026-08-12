// =============================================================
// Module      : id_ex_reg
// Description : Pipeline register between ID and EX stages.
//
//               Carries every control signal produced by
//               control_unit.v + alu_control.v (already resolved
//               in ID -- EX does no further decoding), plus all
//               operand data EX/MEM/WB will need.
//
//               Control:
//                 - stall : hold contents (rare for ID/EX in a
//                   MIPS pipeline outside mult/div busy stall --
//                   most stalls freeze IF/ID and insert a bubble
//                   HERE instead, i.e. flush is what's typically
//                   asserted on THIS register during a load-use
//                   hazard, not stall). Included for completeness
//                   / mult-div busy-stall symmetry.
//                 - flush : force a "bubble" -- all side-effect
//                   control signals (reg_write, mem_read, mem_write,
//                   branch, jump, jump_link, is_mult_div) are zeroed,
//                   valid=0. This is how a load-use hazard bubble or
//                   a branch-taken flush is actually injected into
//                   the pipeline.
//
//               Async reset also forces a full bubble.
// =============================================================

module id_ex_reg (
    input  wire        clk,
    input  wire         rst_n,
    input  wire         stall,
    input  wire         flush,

    // ---- control signals in (from control_unit.v / alu_control.v) ----
    input  wire         reg_dst_in,
    input  wire         alu_src_in,
    input  wire [1:0]   mem_to_reg_in,
    input  wire         reg_write_in,
    input  wire         mem_read_in,
    input  wire         mem_write_in,
    input  wire         branch_in,
    input  wire [2:0]   branch_type_in,
    input  wire         jump_in,
    input  wire         jump_link_in,
    input  wire         jump_reg_in,
    input  wire [4:0]   alu_ctrl_in,
    input  wire         alu_width64_in,
    input  wire [2:0]   mem_width_in,
    input  wire         mem_unsigned_in,
    input  wire         is_mult_div_in,
    input  wire         mult_div_signed_in,
    input  wire         mult_div_is_divide_in,  // 1=div/ddiv/divu/ddivu, 0=mult/dmult/multu/dmultu
    input  wire         hilo_sel_hi_in,          // for mfhi/mflo: 1=select HI, 0=select LO
    input  wire         hi_write_in,             // mthi: direct write to HI
    input  wire         lo_write_in,             // mtlo: direct write to LO

    // ---- data in ----
    input  wire [63:0]  read_data1_in,
    input  wire [63:0]  read_data2_in,
    input  wire [63:0]  imm_ext_in,
    input  wire [63:0]  pc_plus4_in,
    input  wire [4:0]   rs_addr_in,
    input  wire [4:0]   rt_addr_in,
    input  wire [4:0]   rd_addr_in,
    input  wire [5:0]   shamt_in,
    input  wire          valid_in,

    // ---- control signals out ----
    output reg          reg_dst_out,
    output reg          alu_src_out,
    output reg  [1:0]   mem_to_reg_out,
    output reg          reg_write_out,
    output reg          mem_read_out,
    output reg          mem_write_out,
    output reg          branch_out,
    output reg  [2:0]   branch_type_out,
    output reg          jump_out,
    output reg          jump_link_out,
    output reg          jump_reg_out,
    output reg  [4:0]   alu_ctrl_out,
    output reg          alu_width64_out,
    output reg  [2:0]   mem_width_out,
    output reg          mem_unsigned_out,
    output reg          is_mult_div_out,
    output reg          mult_div_signed_out,
    output reg          mult_div_is_divide_out,
    output reg          hilo_sel_hi_out,
    output reg          hi_write_out,
    output reg          lo_write_out,

    // ---- data out ----
    output reg  [63:0]  read_data1_out,
    output reg  [63:0]  read_data2_out,
    output reg  [63:0]  imm_ext_out,
    output reg  [63:0]  pc_plus4_out,
    output reg  [4:0]   rs_addr_out,
    output reg  [4:0]   rt_addr_out,
    output reg  [4:0]   rd_addr_out,
    output reg  [5:0]   shamt_out,
    output reg           valid_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_dst_out      <= 1'b0;
            alu_src_out      <= 1'b0;
            mem_to_reg_out   <= 2'b00;
            reg_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            branch_out       <= 1'b0;
            branch_type_out  <= 3'b000;
            jump_out         <= 1'b0;
            jump_link_out    <= 1'b0;
            jump_reg_out     <= 1'b0;
            alu_ctrl_out     <= 5'b00000;
            alu_width64_out  <= 1'b0;
            mem_width_out    <= 3'b000;
            mem_unsigned_out <= 1'b0;
            is_mult_div_out  <= 1'b0;
            mult_div_signed_out <= 1'b1;
            mult_div_is_divide_out <= 1'b0;
            hilo_sel_hi_out  <= 1'b0;
            hi_write_out     <= 1'b0;
            lo_write_out     <= 1'b0;
            read_data1_out   <= 64'h0;
            read_data2_out   <= 64'h0;
            imm_ext_out      <= 64'h0;
            pc_plus4_out     <= 64'h0;
            rs_addr_out      <= 5'b0;
            rt_addr_out      <= 5'b0;
            rd_addr_out      <= 5'b0;
            shamt_out        <= 6'b0;
            valid_out        <= 1'b0;
        end
        else if (flush) begin
            // Bubble: zero every side-effect-causing control signal.
            reg_dst_out      <= 1'b0;
            alu_src_out      <= 1'b0;
            mem_to_reg_out   <= 2'b00;
            reg_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            branch_out       <= 1'b0;
            branch_type_out  <= 3'b000;
            jump_out         <= 1'b0;
            jump_link_out    <= 1'b0;
            jump_reg_out     <= 1'b0;
            alu_ctrl_out     <= 5'b00000;
            alu_width64_out  <= 1'b0;
            mem_width_out    <= 3'b000;
            mem_unsigned_out <= 1'b0;
            is_mult_div_out  <= 1'b0;
            mult_div_signed_out <= 1'b1;
            mult_div_is_divide_out <= 1'b0;
            hilo_sel_hi_out  <= 1'b0;
            hi_write_out     <= 1'b0;
            lo_write_out     <= 1'b0;
            // Data fields don't need clearing for correctness (control
            // signals gate their use) but zero them for clean waveforms.
            read_data1_out   <= 64'h0;
            read_data2_out   <= 64'h0;
            imm_ext_out      <= 64'h0;
            pc_plus4_out     <= 64'h0;
            rs_addr_out      <= 5'b0;
            rt_addr_out      <= 5'b0;
            rd_addr_out      <= 5'b0;
            shamt_out        <= 6'b0;
            valid_out        <= 1'b0;
        end
        else if (stall) begin
            // hold: do nothing, all outputs retain value
        end
        else begin
            reg_dst_out      <= reg_dst_in;
            alu_src_out      <= alu_src_in;
            mem_to_reg_out   <= mem_to_reg_in;
            reg_write_out    <= reg_write_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            branch_out       <= branch_in;
            branch_type_out  <= branch_type_in;
            jump_out         <= jump_in;
            jump_link_out    <= jump_link_in;
            jump_reg_out     <= jump_reg_in;
            alu_ctrl_out     <= alu_ctrl_in;
            alu_width64_out  <= alu_width64_in;
            mem_width_out    <= mem_width_in;
            mem_unsigned_out <= mem_unsigned_in;
            is_mult_div_out  <= is_mult_div_in;
            mult_div_signed_out <= mult_div_signed_in;
            mult_div_is_divide_out <= mult_div_is_divide_in;
            hilo_sel_hi_out  <= hilo_sel_hi_in;
            hi_write_out     <= hi_write_in;
            lo_write_out     <= lo_write_in;
            read_data1_out   <= read_data1_in;
            read_data2_out   <= read_data2_in;
            imm_ext_out      <= imm_ext_in;
            pc_plus4_out     <= pc_plus4_in;
            rs_addr_out      <= rs_addr_in;
            rt_addr_out      <= rt_addr_in;
            rd_addr_out      <= rd_addr_in;
            shamt_out        <= shamt_in;
            valid_out        <= valid_in;
        end
    end

endmodule
