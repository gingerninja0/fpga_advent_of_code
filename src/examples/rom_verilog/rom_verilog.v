// Module configuration
`define ROM_MSB 31
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define ROM_OP 4'b0011 // The top nibble of operator byte determines if ROM operation

// Define the module
module  rom_verilog (
    input wire [`MSB:0] addr,   // 16 bit ROM addressing
    output reg [`MSB:0] read_operator, // Read the operator (upper 16 bits)
    output reg [`MSB:0] read_operand // Read the operand (lower 16 bits)
);

    reg [`ROM_MSB:0] rom_array [0:`MSB]; // 32 bit ROM (to store the operator and operand)

    // Load memory contents from program file
    initial begin
        $readmemh("program.mem", rom_array);
    end

    always @(*) begin
        read_operator = rom_array[addr][31:16];
        read_operand = rom_array[addr][15:0];
    end
    
endmodule