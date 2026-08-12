// =============================================================
// Testbench   : tb_extend
// Tests       : sign_extend.v, zero_extend.v
//
// Checks:
//   1. sign_extend: positive imm (MSB=0) -> zero-fill upper bits.
//   2. sign_extend: negative imm (MSB=1) -> one-fill upper bits.
//   3. sign_extend: imm=0 -> result=0.
//   4. sign_extend lui_mode: positive value -> shifted into [31:16],
//      zero-extended to 64 (since bit31 of the 32b result = 0).
//   5. sign_extend lui_mode: value with bit15=1 -> after shifting
//      into [31:16], bit31=1, so result sign-extends with 1s in
//      [63:32]. (This is the subtle MIPS64 lui behavior.)
//   6. zero_extend: positive imm -> zero-fill upper bits (same as sign).
//   7. zero_extend: negative-looking imm (MSB=1) -> STILL zero-fill,
//      no sign propagation (this is the key differentiator vs sign_extend).
// =============================================================
`timescale 1ns/1ps

module tb_extend;

    reg  [15:0] imm_in;
    reg         lui_mode;
    wire [63:0] sext_out;
    wire [63:0] zext_out;

    integer errors;

    sign_extend u_sext (.imm_in(imm_in), .lui_mode(lui_mode), .ext_out(sext_out));
    zero_extend u_zext (.imm_in(imm_in), .ext_out(zext_out));

    task check_equal(input [255:0] name, input [63:0] actual, input [63:0] exp);
        begin
            if (actual !== exp) begin
                $display("FAIL: %0s expected=%h got=%h", name, exp, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %h", name, actual);
            end
        end
    endtask

    initial begin
        errors = 0;

        // ---- Check 1: sign_extend positive ----
        imm_in = 16'h1234; lui_mode = 0;
        #1;
        check_equal("sign_extend positive", sext_out, 64'h0000000000001234);

        // ---- Check 2: sign_extend negative ----
        imm_in = 16'hFFFE; lui_mode = 0; // -2
        #1;
        check_equal("sign_extend negative (-2)", sext_out, 64'hFFFFFFFFFFFFFFFE);

        // ---- Check 3: sign_extend zero ----
        imm_in = 16'h0000; lui_mode = 0;
        #1;
        check_equal("sign_extend zero", sext_out, 64'h0000000000000000);

        // ---- Check 4: lui_mode, bit15=0 (positive after shift) ----
        imm_in = 16'h1234; lui_mode = 1;
        // 32-bit result = 0x12340000, bit31=0 -> zero-extend upper 32
        #1;
        check_equal("lui positive imm", sext_out, 64'h0000000012340000);

        // ---- Check 5: lui_mode, bit15=1 (negative after shift) ----
        imm_in = 16'h8001; lui_mode = 1;
        // 32-bit result = 0x80010000, bit31=1 -> sign-extend upper 32 with 1s
        #1;
        check_equal("lui negative-shifted imm", sext_out, 64'hFFFFFFFF80010000);

        // ---- Check 6: zero_extend positive ----
        imm_in = 16'h1234;
        #1;
        check_equal("zero_extend positive", zext_out, 64'h0000000000001234);

        // ---- Check 7: zero_extend with MSB=1, NO sign propagation ----
        imm_in = 16'hFFFE;
        #1;
        check_equal("zero_extend MSB=1 (no sign prop)", zext_out, 64'h000000000000FFFE);

        if (errors == 0)
            $display("\n==== ALL TESTS PASSED ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);

        $finish;
    end

endmodule
