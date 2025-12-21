// Module configuration
`define DATA_WIDTH 8
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH


// Define the module
module  alu_verilog (
    input wire clk,        // Clock signal
    input wire reset,      // Reset signal (active high)
    input wire [7:0] op,   // 8-bit op-code for the ALU operation selection
    input wire [`MSB:0] a, // DATA_WIDTH input A (reg stores the value)
    input wire [`MSB:0] b, // DATA_WIDTH input B (reg stores the value)
    output reg [`MSB:0] c, // DATA_WIDTH output C (reg stores the value)
    output reg [3:0] flags // 4-bit flags (X|X|C|Z) (to two are spare for now)
);

    reg [`DATA_WIDTH:0] operation_result; // Holding register of the operation to set flags at the same time as the output register

    // This block triggers every time clk goes from 0 to 1
    // or reset goes from 0 to 1 (asynchronous reset)
    always @(posedge clk or posedge reset) begin // May need to make this combinatorial (via always @(*) begin...)
        if (reset) begin
            c <= `DATA_WIDTH'b0; // Reset output to 0
            flags <= 4'b0; // Reset flags to 0
        end else begin
            case(op)
                // Also set carry flag after each operation
                8'b00000000: operation_result = a + b; // Addition
                8'b00000001: operation_result = a - b; // Subtraction
                8'b00000010: operation_result = a & b; // Bitwise AND
                8'b00000011: operation_result = a | b; // Bitwise OR
                8'b00000100: operation_result = a ^ b; // Bitwise XOR
                8'b00000101: operation_result = ~a;    // Bitwise NOT A
                8'b00000110: operation_result = a << 1; // Logical left shift A
                8'b00000111: operation_result = a >> 1; // Logical right shift A
                8'b00001000: operation_result = a * b; // Multiplication
                default: operation_result = `DATA_WIDTH'b0;
            endcase

            c <= operation_result[`MSB:0];

            // Update flags
            flags[0] <= (operation_result[`MSB:0] == `DATA_WIDTH'b0) ? 1'b1 : 1'b0;
            flags[1] <= operation_result[`CARRY_BIT];
            
        end
    end
    
endmodule