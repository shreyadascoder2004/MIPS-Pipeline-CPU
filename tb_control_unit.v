// =============================================================
// Testbench   : tb_control_unit
// Tests       : control_unit.v
//
// Strategy: for each instruction class, drive opcode/funct/rt_field
// and check the specific signals that matter for that class (not
// every signal every time -- irrelevant signals are don't-cares by
// design, e.g. mem_width during an R-type add).
// =============================================================
`timescale 1ns/1ps

module tb_control_unit;

    reg  [5:0] opcode, funct;
    reg  [4:0] rt_field;

    wire reg_dst, alu_src, reg_write, mem_read, mem_write, branch;
    wire jump, jump_link, jump_reg, alu_width64, mem_unsigned, is_mult_div, illegal_instr, mult_div_signed;
    wire [1:0] mem_to_reg, ext_ctrl;
    wire [2:0] branch_type, alu_op, mem_width;

    integer errors;

    control_unit dut (
        .opcode(opcode), .funct(funct), .rt_field(rt_field),
        .reg_dst(reg_dst), .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .branch(branch), .branch_type(branch_type),
        .jump(jump), .jump_link(jump_link), .jump_reg(jump_reg),
        .alu_op(alu_op), .alu_width64(alu_width64), .ext_ctrl(ext_ctrl),
        .mem_width(mem_width), .mem_unsigned(mem_unsigned),
        .is_mult_div(is_mult_div), .mult_div_signed(mult_div_signed), .illegal_instr(illegal_instr)
    );

    task check_bit(input [255:0] name, input actual, input exp);
        begin
            if (actual !== exp) begin
                $display("FAIL: %0s expected=%b got=%b", name, exp, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %b", name, actual);
            end
        end
    endtask

    task check_vec(input [255:0] name, input [2:0] actual, input [2:0] exp);
        begin
            if (actual !== exp) begin
                $display("FAIL: %0s expected=%b got=%b", name, exp, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %b", name, actual);
            end
        end
    endtask

    initial begin
        errors = 0;
        rt_field = 5'b0;

        // ---- add (R-type, funct=100000) ----
        opcode = 6'b000000; funct = 6'b100000;
        #1;
        check_bit("add: reg_dst",   reg_dst, 1);
        check_bit("add: reg_write", reg_write, 1);
        check_bit("add: alu_src",   alu_src, 0);
        check_vec("add: alu_op",    alu_op, 3'b010);
        check_bit("add: alu_width64 (32b op)", alu_width64, 0);
        check_bit("add: illegal", illegal_instr, 0);

        // ---- dadd (R-type, funct=101100) ----
        opcode = 6'b000000; funct = 6'b101100;
        #1;
        check_bit("dadd: reg_write", reg_write, 1);
        check_bit("dadd: alu_width64", alu_width64, 1);

        // ---- jr (R-type, funct=001000) ----
        opcode = 6'b000000; funct = 6'b001000;
        #1;
        check_bit("jr: jump_reg", jump_reg, 1);
        check_bit("jr: reg_write", reg_write, 0);

        // ---- jalr (R-type, funct=001001) ----
        opcode = 6'b000000; funct = 6'b001001;
        #1;
        check_bit("jalr: jump_reg", jump_reg, 1);
        check_bit("jalr: jump_link", jump_link, 1);
        check_bit("jalr: reg_write", reg_write, 1);

        // ---- mult (R-type, funct=011000) ----
        opcode = 6'b000000; funct = 6'b011000;
        #1;
        check_bit("mult: is_mult_div", is_mult_div, 1);
        check_bit("mult: reg_write (goes to HI/LO not GPR)", reg_write, 0);
        check_bit("mult: alu_width64", alu_width64, 0);
        check_bit("mult: mult_div_signed", mult_div_signed, 1);

        // ---- multu (R-type, funct=011001) ----
        opcode = 6'b000000; funct = 6'b011001;
        #1;
        check_bit("multu: mult_div_signed", mult_div_signed, 0);

        // ---- dmult (R-type, funct=011100) ----
        opcode = 6'b000000; funct = 6'b011100;
        #1;
        check_bit("dmult: is_mult_div", is_mult_div, 1);
        check_bit("dmult: alu_width64", alu_width64, 1);

        // ---- mfhi (R-type, funct=010000) ----
        opcode = 6'b000000; funct = 6'b010000;
        #1;
        check_bit("mfhi: reg_write", reg_write, 1);
        check_vec("mfhi: mem_to_reg (HI/LO sel=11)", {1'b0, mem_to_reg}, 3'b011);

        // ---- addi ----
        opcode = 6'b001000; funct = 6'bxxxxxx;
        #1;
        check_bit("addi: alu_src", alu_src, 1);
        check_bit("addi: reg_write", reg_write, 1);
        check_bit("addi: alu_width64", alu_width64, 0);
        check_vec("addi: alu_op (add class)", alu_op, 3'b000);

        // ---- daddi ----
        opcode = 6'b011000;
        #1;
        check_bit("daddi: alu_width64", alu_width64, 1);

        // ---- andi ----
        opcode = 6'b001100;
        #1;
        check_bit("andi: alu_src", alu_src, 1);
        check_vec("andi: ext_ctrl (zero-extend)", {1'b0, ext_ctrl}, 3'b001);

        // ---- lui ----
        opcode = 6'b001111;
        #1;
        check_vec("lui: ext_ctrl (lui mode)", {1'b0, ext_ctrl}, 3'b010);
        check_bit("lui: reg_write", reg_write, 1);

        // ---- lw ----
        opcode = 6'b100011;
        #1;
        check_bit("lw: mem_read", mem_read, 1);
        check_bit("lw: reg_write", reg_write, 1);
        check_vec("lw: mem_to_reg (mem sel=01)", {1'b0, mem_to_reg}, 3'b001);
        check_vec("lw: mem_width (word)", mem_width, 3'b010);
        check_bit("lw: mem_unsigned", mem_unsigned, 0);

        // ---- lbu ----
        opcode = 6'b100100;
        #1;
        check_vec("lbu: mem_width (byte)", mem_width, 3'b000);
        check_bit("lbu: mem_unsigned", mem_unsigned, 1);

        // ---- ld ----
        opcode = 6'b110111;
        #1;
        check_vec("ld: mem_width (dword)", mem_width, 3'b011);

        // ---- sw ----
        opcode = 6'b101011;
        #1;
        check_bit("sw: mem_write", mem_write, 1);
        check_bit("sw: reg_write", reg_write, 0);
        check_vec("sw: mem_width (word)", mem_width, 3'b010);

        // ---- beq ----
        opcode = 6'b000100;
        #1;
        check_bit("beq: branch", branch, 1);
        check_vec("beq: branch_type", branch_type, 3'b000);

        // ---- bne ----
        opcode = 6'b000101;
        #1;
        check_vec("bne: branch_type", branch_type, 3'b001);

        // ---- bltz (REGIMM, rt=00000) ----
        opcode = 6'b000001; rt_field = 5'b00000;
        #1;
        check_bit("bltz: branch", branch, 1);
        check_vec("bltz: branch_type", branch_type, 3'b100);
        check_bit("bltz: illegal", illegal_instr, 0);

        // ---- bgez (REGIMM, rt=00001) ----
        opcode = 6'b000001; rt_field = 5'b00001;
        #1;
        check_vec("bgez: branch_type", branch_type, 3'b101);

        // ---- REGIMM with invalid rt_field -> illegal ----
        opcode = 6'b000001; rt_field = 5'b00010;
        #1;
        check_bit("regimm invalid rt: illegal_instr", illegal_instr, 1);
        rt_field = 5'b0;

        // ---- j ----
        opcode = 6'b000010;
        #1;
        check_bit("j: jump", jump, 1);
        check_bit("j: jump_link", jump_link, 0);
        check_bit("j: reg_write", reg_write, 0);

        // ---- jal ----
        opcode = 6'b000011;
        #1;
        check_bit("jal: jump", jump, 1);
        check_bit("jal: jump_link", jump_link, 1);
        check_bit("jal: reg_write", reg_write, 1);
        check_vec("jal: mem_to_reg (PC+4 sel=10)", {1'b0, mem_to_reg}, 3'b010);

        // ---- illegal opcode ----
        opcode = 6'b111100; // unassigned
        #1;
        check_bit("illegal opcode: illegal_instr", illegal_instr, 1);
        check_bit("illegal opcode: reg_write stays 0 (safe default)", reg_write, 0);

        if (errors == 0)
            $display("\n==== ALL TESTS PASSED ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);

        $finish;
    end

endmodule
