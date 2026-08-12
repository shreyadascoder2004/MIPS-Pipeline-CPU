// =============================================================
// Module      : reg_file
// Description : 32 x 64-bit General Purpose Register file.
//               - $0 is hardwired to zero (writes to it are dropped).
//               - 2 combinational read ports (rs, rt) for ID stage.
//               - 1 synchronous write port (WB stage).
//               - Write-first internal bypass: if WB writes to the
//                 same register ID is reading THIS cycle, the read
//                 port immediately returns the new write_data value
//                 instead of stale stored data. This removes a
//                 same-cycle WB->ID hazard case that would otherwise
//                 require the external forwarding unit to handle it
//                 (and MIPS register files are conventionally built
//                 this way for exactly that reason).
// =============================================================

module reg_file (
    input  wire        clk,
    input  wire         rst_n,        // used only to zero-init for sim determinism

    input  wire [4:0]   read_addr1,   // rs
    input  wire [4:0]   read_addr2,   // rt
    output wire [63:0]  read_data1,
    output wire [63:0]  read_data2,

    input  wire         write_en,     // from WB stage
    input  wire [4:0]   write_addr,
    input  wire [63:0]  write_data
);

    reg [63:0] regs [0:31];
    integer k;

    // ---- Synchronous write ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 32; k = k + 1)
                regs[k] <= 64'h0;
        end
        else if (write_en && (write_addr != 5'd0)) begin
            regs[write_addr] <= write_data;
        end
    end

    // ---- Combinational reads with write-first bypass ----
    assign read_data1 = (read_addr1 == 5'd0) ? 64'h0 :
                         (write_en && (write_addr == read_addr1)) ? write_data :
                         regs[read_addr1];

    assign read_data2 = (read_addr2 == 5'd0) ? 64'h0 :
                         (write_en && (write_addr == read_addr2)) ? write_data :
                         regs[read_addr2];

endmodule
