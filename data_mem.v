// =============================================================
// Module      : data_mem
// Description : Data Memory for MEM stage.
//               - Byte-addressable, internally stored as bytes for
//                 simplicity of partial-width stores.
//               - Combinational read (result available same cycle
//                 as address -- needed for simple MEM-stage timing
//                 and MEM/WB forwarding).
//               - Synchronous write, byte-lane-granular (a 'sb' does
//                 NOT clobber neighboring bytes).
//               - mem_width: 000=byte,001=half,010=word,011=dword
//               - mem_unsigned: 1 = zero-extend load result (lbu/lhu),
//                 0 = sign-extend (lb/lh/lw). ld doesn't need this
//                 (already full 64-bit, mem_unsigned ignored for dword).
//               - Little-endian byte ordering (standard MIPS default
//                 config, and matches typical FPGA BRAM inference).
// =============================================================

module data_mem #(
    parameter MEM_DEPTH_BYTES = 8192,                     // 8KB default
    parameter ADDR_BITS       = $clog2(MEM_DEPTH_BYTES)
) (
    input  wire         clk,
    input  wire [63:0]  addr,
    input  wire [63:0]  write_data,
    input  wire         mem_read,
    input  wire         mem_write,
    input  wire [2:0]   mem_width,     // 000=byte,001=half,010=word,011=dword
    input  wire         mem_unsigned,  // extension mode for loads

    output wire [63:0]  read_data
);

    reg [7:0] mem [0:MEM_DEPTH_BYTES-1];

    wire [ADDR_BITS-1:0] base = addr[ADDR_BITS-1:0];

    // ---- initialize to zero for simulation determinism ----
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH_BYTES; i = i + 1)
            mem[i] = 8'h00;
    end

    // ---- combinational read, width + extension aware ----
    reg [63:0] raw_read;
    always @(*) begin
        case (mem_width)
            3'b000: raw_read = {56'h0, mem[base]};                                   // byte
            3'b001: raw_read = {48'h0, mem[base+1], mem[base]};                      // half
            3'b010: raw_read = {32'h0, mem[base+3], mem[base+2],
                                        mem[base+1], mem[base]};                      // word
            3'b011: raw_read = {mem[base+7], mem[base+6], mem[base+5], mem[base+4],
                                 mem[base+3], mem[base+2], mem[base+1], mem[base]};   // dword
            default: raw_read = 64'h0;
        endcase
    end

    assign read_data = !mem_read ? 64'h0 :
                        (mem_width == 3'b000) ? (mem_unsigned ? {56'h0, raw_read[7:0]}  : {{56{raw_read[7]}},  raw_read[7:0]}) :
                        (mem_width == 3'b001) ? (mem_unsigned ? {48'h0, raw_read[15:0]} : {{48{raw_read[15]}}, raw_read[15:0]}) :
                        (mem_width == 3'b010) ? (mem_unsigned ? {32'h0, raw_read[31:0]} : {{32{raw_read[31]}}, raw_read[31:0]}) :
                        raw_read; // dword: full 64 bits, no extension needed

    // ---- synchronous, byte-lane-granular write ----
    always @(posedge clk) begin
        if (mem_write) begin
            case (mem_width)
                3'b000: begin // byte
                    mem[base] <= write_data[7:0];
                end
                3'b001: begin // half
                    mem[base]   <= write_data[7:0];
                    mem[base+1] <= write_data[15:8];
                end
                3'b010: begin // word
                    mem[base]   <= write_data[7:0];
                    mem[base+1] <= write_data[15:8];
                    mem[base+2] <= write_data[23:16];
                    mem[base+3] <= write_data[31:24];
                end
                3'b011: begin // dword
                    mem[base]   <= write_data[7:0];
                    mem[base+1] <= write_data[15:8];
                    mem[base+2] <= write_data[23:16];
                    mem[base+3] <= write_data[31:24];
                    mem[base+4] <= write_data[39:32];
                    mem[base+5] <= write_data[47:40];
                    mem[base+6] <= write_data[55:48];
                    mem[base+7] <= write_data[63:56];
                end
                default: ;
            endcase
        end
    end

endmodule
