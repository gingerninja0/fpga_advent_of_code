// Module configuration
`define ROM_MSB 31
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define ROM_OP 4'b0011 // The top nibble of operator byte determines if ROM operation

// Define the module
module  rom_verilog (
    input wire [`MSB:0] addr,   // 16 bit ROM addressing
    input wire rom_enable,
    input wire rom_read_data_enable,
    output reg [`MSB:0] read_opcode, // Read the operator (upper 16 bits)
    output reg [`MSB:0] read_operand, // Read the operand (lower 16 bits)
    output reg [`MSB:0] read_data
);
    localparam ROM_DATA_READ = 4'h1;


    reg [`ROM_MSB:0] rom_array [0:256]; // 32 bit ROM (to store the operator and operand)

    integer i;

    // Load memory contents from program file
    initial begin
        
        for (i = 0; i < `DATA_WIDTH; i = i + 1) rom_array[i] = 32'h0;
        
        // Load your program
        $readmemh("program.mem", rom_array);
    end

    always @(*) begin
        if (rom_enable) begin
            read_opcode = rom_array[addr][31:16];
            read_operand = rom_array[addr][15:0];
        end

        if (rom_read_data_enable && (read_opcode[15:8] == {`ROM_OP, ROM_DATA_READ})) begin
            read_data = rom_array[read_operand];
        end else begin
            read_data = 16'bz; 
        end
    end
    
endmodule