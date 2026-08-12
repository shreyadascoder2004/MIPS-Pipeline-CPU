// =============================================================
// Testbench   : tb_alu_control
// Tests       : alu_control.v
// =============================================================
`timescale 1ns/1ps

module tb_alu_control;

    reg  [2:0] alu_op;
    reg  [5:0] funct;
    reg        opcode_lsb;
    wire [4:0] alu_ctrl;

    integer errors;

    alu_control dut (
        .alu_op(alu_op), .funct(funct), .opcode_lsb(opcode_lsb),
        .alu_ctrl(alu_ctrl)
    );

    task check(input [255:0] name, input [4:0] exp);
        begin
            if (alu_ctrl !== exp) begin
                $display("FAIL: %0s expected=%b got=%b", name, exp, alu_ctrl);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %b", name, alu_ctrl);
            end
        end
    endtask

    initial begin
        errors = 0;
        opcode_lsb = 0; funct = 6'b0;

        // add-family
        alu_op = 3'b000; #1; check("add-family -> ADD", 5'b00000);

        // branch
        alu_op = 3'b001; #1; check("branch -> SUB", 5'b00001);

        // andi/ori/xori
        alu_op = 3'b011; #1; check("andi -> AND", 5'b00010);
        alu_op = 3'b100; #1; check("ori -> OR", 5'b00011);
        alu_op = 3'b101; #1; check("xori -> XOR", 5'b00100);

        // slti/sltiu
        alu_op = 3'b110; opcode_lsb = 0; #1; check("slti -> SLT", 5'b00110);
        alu_op = 3'b110; opcode_lsb = 1; #1; check("sltiu -> SLTU", 5'b00111);

        // lui
        alu_op = 3'b111; #1; check("lui -> LUI_PASS", 5'b01011);

        // R-type funct decode
        alu_op = 3'b010;
        funct = 6'b100000; #1; check("funct add -> ADD", 5'b00000);
        funct = 6'b100010; #1; check("funct sub -> SUB", 5'b00001);
        funct = 6'b101100; #1; check("funct dadd -> ADD", 5'b00000);
        funct = 6'b101110; #1; check("funct dsub -> SUB", 5'b00001);
        funct = 6'b100100; #1; check("funct and -> AND", 5'b00010);
        funct = 6'b100101; #1; check("funct or -> OR", 5'b00011);
        funct = 6'b100110; #1; check("funct xor -> XOR", 5'b00100);
        funct = 6'b100111; #1; check("funct nor -> NOR", 5'b00101);
        funct = 6'b101010; #1; check("funct slt -> SLT", 5'b00110);
        funct = 6'b101011; #1; check("funct sltu -> SLTU", 5'b00111);
        funct = 6'b000000; #1; check("funct sll -> SLL", 5'b01000);
        funct = 6'b000100; #1; check("funct sllv -> SLL", 5'b01000);
        funct = 6'b111000; #1; check("funct dsll -> SLL", 5'b01000);
        funct = 6'b000010; #1; check("funct srl -> SRL", 5'b01001);
        funct = 6'b111010; #1; check("funct dsrl -> SRL", 5'b01001);
        funct = 6'b000011; #1; check("funct sra -> SRA", 5'b01010);
        funct = 6'b111011; #1; check("funct dsra -> SRA", 5'b01010);

        if (errors == 0)
            $display("\n==== ALL TESTS PASSED ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);

        $finish;
    end

endmodule
