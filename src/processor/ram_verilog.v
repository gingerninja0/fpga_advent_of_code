// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define RAM_OP 4'b0100 // The top nibble of operator byte determines if RAM operation

// Define the module
module  ram_verilog (
    input wire clk,
    input wire reset,
    input wire [`MSB:0] opcode, // This is the opcode code sent to every module, used here to determine the mode of operation
    input wire [`MSB:0] operand, // 8 bit RAM address (we don't need that much)
    input wire [`MSB:0] write_data,
    output reg [`MSB:0] read_data
);

    localparam RAM_WRITE = 4'h1;
    localparam RAM_READ = 4'h2;

    reg [0:7] ram_array [`MSB:0]; // 16 bit RAM (to store the operator and operand)

    wire [3:0] ram_op_select; 
    wire [3:0] ram_op_operation;
    wire [7:0] addr;

    assign ram_op_select = opcode[15:12];
    assign ram_op_operation = opcode[11:8];

    assign addr = operand[7:0];

    always @(posedge clk or posedge reset) begin
        case({ram_op_select, ram_op_operation})
            {`RAM_OP, RAM_WRITE}: begin
                ram_array[addr] <= write_data;
                read_data <= `DATA_WIDTH'b0; // Ensure the read data is cleared when writing, makes it act like single port RAM
            end
            {`RAM_OP, RAM_READ}: begin
                read_data <= ram_array[addr]; 
            end
            default: begin
                read_data <= `DATA_WIDTH'b0; // Clear output for all other opcodes
            end
        endcase
    end
    
endmodule