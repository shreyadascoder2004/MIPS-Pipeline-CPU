// =============================================================
// Module      : wb_mux
// Description : Final writeback-value selector for the WB stage.
//               mem_to_reg encoding (from control_unit.v):
//                 00 = ALU result
//                 01 = Memory read data
//                 10 = PC+4 (jal / jalr link value)
//                 11 = HI/LO result (mfhi/mflo)
// =============================================================

module wb_mux (
    input  wire [63:0] alu_result,
    input  wire [63:0] mem_read_data,
    input  wire [63:0] pc_plus4,
    input  wire [63:0] hilo_result,
    input  wire [1:0]  mem_to_reg,

    output reg  [63:0] write_back_data
);

    always @(*) begin
        case (mem_to_reg)
            2'b00:   write_back_data = alu_result;
            2'b01:   write_back_data = mem_read_data;
            2'b10:   write_back_data = pc_plus4;
            2'b11:   write_back_data = hilo_result;
            default: write_back_data = alu_result;
        endcase
    end

endmodule
