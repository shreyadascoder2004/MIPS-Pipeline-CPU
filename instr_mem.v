

module instr_mem #(
    parameter MEM_DEPTH_WORDS = 1024,                       
    parameter ADDR_BITS       = $clog2(MEM_DEPTH_WORDS)    
) (
    input  wire [63:0] addr,         
    output wire [31:0] instr_out      
);

    reg [31:0] mem [0:MEM_DEPTH_WORDS-1];
    integer i;


    wire [ADDR_BITS-1:0] word_idx = addr[ADDR_BITS+1:2];

    assign instr_out = mem[word_idx];

  
    initial begin
        for (i = 0; i < MEM_DEPTH_WORDS; i = i + 1)
            mem[i] = 32'h00000000; 
        $readmemh("C:/Users/shrey/fpga_implementation/MIPS 64 Pipeline Architecture/sw/hex/program.hex", mem);
    end

endmodule
