// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define ALU_OP 4'b0001 // The top nibble of operator byte determines if ALU operation (where all 3 addresses are used)

// Define the module
module  alu_verilog (
    input wire clk,        // Clock signal
    input wire reset,      // Reset signal (active high)
    input wire [`MSB:0] opcode,   // 8-bit opcode-code for the ALU operation selection
    input wire [`MSB:0] a, // DATA_WIDTH input A
    input wire [`MSB:0] b, // DATA_WIDTH input B
    output reg [`MSB:0] c, // DATA_WIDTH output C (reg stores the value)
    output reg [3:0] flags // 4-bit flags (O|N|C|Z)
);

    reg [`DATA_WIDTH:0] operation_result; // Holding register of the operation to set flags at the same time as the output register

    wire [3:0] alu_op_select; // Select register operation (so it can be used in combination with the ALU)
    wire [3:0] alu_op_operation; // Select register operation (so it can be used in combination with the ALU)

    assign alu_op_select = opcode[15:12];
    assign alu_op_operation = opcode[11:8];

    // This block triggers every time clk goes from 0 to 1
    // or reset goes from 0 to 1 (asynchronous reset)
    always @(*) begin // May need to make this combinatorial (via always @(*) begin...)

        if (reset) begin
            c = `DATA_WIDTH'b0;
            flags = 4'b0001; // By default the ALU result is 0, therefore the flags should reflect this
            operation_result = `DATA_WIDTH'b0;
        end else begin
            case({alu_op_select, alu_op_operation})
                {`ALU_OP, 4'b0000}: operation_result = a + b;  // Addition
                {`ALU_OP, 4'b0001}: operation_result = a - b;  // Subtraction
                {`ALU_OP, 4'b0010}: operation_result = a & b;  // Bitwise AND
                {`ALU_OP, 4'b0011}: operation_result = a | b;  // Bitwise OR
                {`ALU_OP, 4'b0100}: operation_result = a ^ b;  // Bitwise XOR
                {`ALU_OP, 4'b0101}: operation_result = ~a;     // Bitwise NOT A
                {`ALU_OP, 4'b0110}: operation_result = a << 1; // Logical left shift A (MAY NOT WORK)
                {`ALU_OP, 4'b0111}: operation_result = a >> 1; // Logical right shift A (MAY NOT WORK)
                {`ALU_OP, 4'b1000}: operation_result = a * b;  // Multiplication (Not realistic, unless we consider it combinatorial multiplication)
                default: operation_result = `DATA_WIDTH'b0;
            endcase

            c = operation_result[`MSB:0];

            // Update flags
            if (alu_op_select == `ALU_OP) begin
                // Only update flags if it's an actual ALU operation
                flags[0] = (operation_result[`MSB:0] == `DATA_WIDTH'b0) ? 1'b1 : 1'b0; // Result is zero
                flags[1] = operation_result[`CARRY_BIT]; // Operation resulted in a carry
                flags[2] = operation_result[`MSB]; // Sign bit
                flags[3] = (a[`MSB] == b[`MSB]) && (operation_result[`MSB] != a[`MSB]); // Overflow, resulting sign bit does not match inputs (addition resulted in "negative", or subtraction resulted in "positive" due to overflow)
            end else begin
                // For other operations, hold the flags at the previous state
            end
            
        end
    end
    
endmodule