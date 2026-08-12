// =============================================================
// Module      : hilo_unit
// Description : Multi-cycle HI/LO multiply/divide unit for EX stage.
//
//               MULTIPLY: shift-add multiplier with EARLY EXIT.
//                 Each cycle, if the current bit of the (shifting)
//                 multiplier is 1, add the (shifting) multiplicand
//                 into the accumulator. The unit tracks the index of
//                 the highest remaining set bit in the multiplier
//                 and terminates as soon as no set bits remain
//                 (rather than always running the full operand
//                 width), so operands with few set bits finish
//                 faster. Latency is therefore DATA-DEPENDENT but
//                 fully deterministic for a given operand pair
//                 (same inputs -> same cycle count, every time --
//                 this is what the testbench checks).
//
//               DIVIDE: restoring division, bit-serial, FIXED
//                 latency (width cycles). Early-exit division is
//                 algorithmically possible but significantly more
//                 complex to get correct (dynamic quotient-digit
//                 selection); fixed-latency restoring division is
//                 the standard, verifiable choice and is noted here
//                 explicitly so the asymmetry with the multiplier
//                 is understood, not accidental.
//
//               Width: controlled by width64 (0 = 32-bit operands
//               and results, sign/zero-extended appropriately to
//               64-bit HI/LO storage; 1 = full 64-bit operands).
//
//               Sign: controlled by is_signed (1 = mult/div,
//               0 = multu/divu).
//
//               Interface (level-based start/busy/done):
//                 start  : pulse high for 1 cycle to begin an
//                          operation (operand_a, operand_b, width64,
//                          is_signed, is_divide must be valid that
//                          same cycle).
//                 busy   : high while the operation is in progress
//                          (feeds hazard_detection_unit.mult_div_busy
//                          to stall the pipeline).
//                 done   : pulses high for exactly 1 cycle when the
//                          result becomes valid in hi_out/lo_out.
//
//               mfhi/mflo/mthi/mtlo are handled OUTSIDE this module
//               (in the EX-stage top level): mfhi/mflo just read
//               hi_out/lo_out combinationally; mthi/mtlo write them
//               via hi_write/lo_write below.
// =============================================================

module hilo_unit (
    input  wire         clk,
    input  wire         rst_n,

    input  wire         start,        // pulse to begin mult/div
    input  wire         is_divide,    // 0 = multiply, 1 = divide
    input  wire         is_signed,
    input  wire         width64,      // 0 = 32-bit operands, 1 = 64-bit
    input  wire [63:0]  operand_a,
    input  wire [63:0]  operand_b,

    input  wire         hi_write,     // mthi: direct write to HI
    input  wire         lo_write,     // mtlo: direct write to LO
    input  wire [63:0]  hi_write_data,
    input  wire [63:0]  lo_write_data,

    output wire         busy,
    output reg           done,
    output reg  [63:0]  hi_out,
    output reg  [63:0]  lo_out
);

    localparam S_IDLE    = 2'b00;
    localparam S_MULT    = 2'b01;
    localparam S_DIV     = 2'b10;
    localparam S_FINISH  = 2'b11;

    reg [1:0]  state;
    reg [6:0]  width_bits;      // 32 or 64, as a count
    reg [6:0]  cycle_count;     // used differently by mult (early-exit index) vs div (fixed counter)

    reg        result_negative_mult; // sign of final product (signed mode)
    reg        quotient_negative;    // sign of quotient (signed divide)
    reg        remainder_negative;   // sign of remainder (signed divide)

    // ---- Working registers (sized for the max width we support: 64b operands -> 128b product) ----
    reg [127:0] acc;            // multiplier accumulator (used by MULTIPLY only)
    reg [63:0]  multiplicand;   // shifting multiplicand (mult) / divisor (div)
    reg [63:0]  abs_a, abs_b;   // absolute values of operands (for signed ops)
    reg [63:0]  div_remainder;  // restoring-divide remainder register
    reg [63:0]  div_quotient;   // restoring-divide quotient register (shifts left, LSB filled each cycle)

    assign busy = (state != S_IDLE);

    // ---- helper: find highest set bit index in a 64-bit value (for mult early-exit) ----
    function [6:0] highest_set_bit;
        input [63:0] val;
        integer i;
        begin
            highest_set_bit = 7'd0;
            for (i = 63; i >= 0; i = i - 1)
                if (val[i] && (highest_set_bit == 7'd0) && (i != 0 || val[0]))
                    highest_set_bit = i[6:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            done         <= 1'b0;
            hi_out       <= 64'h0;
            lo_out       <= 64'h0;
            acc          <= 128'h0;
            multiplicand <= 64'h0;
            cycle_count  <= 7'h0;
            width_bits   <= 7'h0;
            div_remainder <= 64'h0;
            div_quotient  <= 64'h0;
        end
        else begin
            done <= 1'b0; // default: done is a 1-cycle pulse

            // ---- direct HI/LO writes (mthi/mtlo) -- allowed only when idle ----
            if (state == S_IDLE && hi_write) hi_out <= hi_write_data;
            if (state == S_IDLE && lo_write) lo_out <= lo_write_data;

            case (state)

                S_IDLE: begin
                    if (start) begin
                        width_bits <= width64 ? 7'd64 : 7'd32;

                        // absolute-value operands for signed ops (sign restored at finish)
                        if (is_signed && !is_divide) begin
                            abs_a <= (width64 ? operand_a[63] : operand_a[31]) ? (~operand_a + 64'h1) : operand_a;
                            abs_b <= (width64 ? operand_b[63] : operand_b[31]) ? (~operand_b + 64'h1) : operand_b;
                            result_negative_mult <=
                                (width64 ? operand_a[63] : operand_a[31]) ^
                                (width64 ? operand_b[63] : operand_b[31]);
                        end else begin
                            abs_a <= operand_a;
                            abs_b <= operand_b;
                            result_negative_mult <= 1'b0;
                        end

                        if (is_signed && is_divide) begin
                            quotient_negative  <= (width64 ? operand_a[63] : operand_a[31]) ^
                                                  (width64 ? operand_b[63] : operand_b[31]);
                            remainder_negative <= (width64 ? operand_a[63] : operand_a[31]);
                        end

                        if (!is_divide) begin
                            // ---- MULTIPLY setup ----
                            acc          <= 128'h0;
                            state        <= S_MULT;
                            cycle_count  <= 7'h0; // will be set to highest_set_bit next cycle via combinational read below
                        end else begin
                            // ---- DIVIDE setup ----
                            // remainder starts at 0; quotient field starts holding
                            // |dividend|. div_width_bits determines how many bits
                            // wide the working quotient/remainder fields are (32
                            // or 64) so the restoring-subtract compares at the
                            // correct bit position regardless of operand width.
                            div_remainder <= 64'h0;
                            div_quotient  <= is_signed ?
                                             ((width64 ? operand_a[63] : operand_a[31]) ? (~operand_a + 64'h1) : operand_a) :
                                             operand_a;
                            multiplicand  <= is_signed ?
                                            ((width64 ? operand_b[63] : operand_b[31]) ? (~operand_b + 64'h1) : operand_b) :
                                            operand_b;
                            cycle_count   <= 7'd64; // ALWAYS 64 cycles: restoring
                                // division needs the full 64-bit shift-register
                                // width to correctly process operands regardless
                                // of their nominal 32/64-bit width (the extra
                                // leading cycles for a 32-bit operand simply shift
                                // through leading zeros harmlessly). This is why
                                // divide is documented as FIXED latency, unlike
                                // the multiplier's data-dependent early exit.
                            state         <= S_DIV;
                        end
                    end
                end

                S_MULT: begin: mult_case
                    reg [63:0] mcand;
                    reg [63:0] mplier;
                    reg [6:0]  top_bit;
                    mcand  = abs_a;
                    mplier = abs_b;
                    top_bit = highest_set_bit(mplier);

                    if (mplier == 64'h0) begin
                        // multiplier is zero -> product is zero, finish immediately
                        acc   <= 128'h0;
                        state <= S_FINISH;
                    end else begin
                        // Standard shift-add: process from bit 0 upward each cycle,
                        // but stop once we've passed the highest set bit (early exit).
                        // We implement this by shifting the multiplier right each
                        // cycle and the multiplicand left each cycle, adding when
                        // multiplier LSB=1, and terminating when the *remaining*
                        // multiplier value becomes 0 (which happens at or before
                        // top_bit+1 cycles -- fewer cycles for sparse operands).
                        if (mplier[0])
                            acc <= acc + ({64'h0, mcand} << cycle_count);

                        if ((mplier >> 1) == 64'h0) begin
                            // no bits left after this one -> next cycle can finish
                            state <= S_FINISH;
                        end else begin
                            abs_b       <= mplier >> 1;
                            cycle_count <= cycle_count + 7'd1;
                        end
                    end
                end

                S_DIV: begin: div_case
                    // Classic restoring division on a {remainder(64b):quotient(64b)}
                    // pair, shifted left together each cycle as one 128-bit unit.
                    // The remainder is compared against the divisor (both held in
                    // the SAME 64-bit width) after each shift -- this works
                    // correctly for both 32-bit and 64-bit operands because
                    // unused upper bits of the operands are already zero
                    // (operands were absolute-valued into 64-bit regs at setup,
                    // and a 32-bit dividend/divisor simply has zero upper bits,
                    // so the restoring compare naturally produces zero quotient
                    // bits until the true low-order bits are reached).
                    reg [64:0] shifted_rem; // 65 bits: room for the carry-in bit from quotient MSB
                    reg [63:0] new_quot;
                    reg [64:0] trial;

                    shifted_rem = {div_remainder[63:0], div_quotient[63]}; // shift remainder left, bring in quotient MSB
                    new_quot    = div_quotient << 1;
                    trial       = {1'b0, shifted_rem[63:0]} - {1'b0, multiplicand};

                    if (!trial[64]) begin
                        // no borrow -> subtraction succeeded, quotient bit = 1
                        div_remainder <= trial[63:0];
                        div_quotient  <= new_quot | 64'h1;
                    end else begin
                        // borrow -> restore (keep shifted remainder), quotient bit = 0
                        div_remainder <= shifted_rem[63:0];
                        div_quotient  <= new_quot;
                    end

                    if (cycle_count == 7'd1)
                        state <= S_FINISH;
                    else
                        cycle_count <= cycle_count - 7'd1;
                end

                S_FINISH: begin
                    if (!is_divide) begin: mult_finish_blk
                        // acc holds the 128-bit product (unsigned magnitude);
                        // restore sign if needed.
                        reg [127:0] signed_prod;
                        signed_prod = result_negative_mult ? (~acc + 128'h1) : acc;
                        hi_out <= signed_prod[127:64];
                        lo_out <= signed_prod[63:0];
                    end else begin: div_finish_blk
                        // div_quotient/div_remainder hold the final unsigned
                        // magnitude results; restore sign if needed.
                        reg [63:0] q, r;
                        q = div_quotient;
                        r = div_remainder;
                        lo_out <= (is_signed && quotient_negative)  ? (~q + 64'h1) : q;
                        hi_out <= (is_signed && remainder_negative) ? (~r + 64'h1) : r;
                    end
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
