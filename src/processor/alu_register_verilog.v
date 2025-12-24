// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define ALU_OP 4'b0001 // The top nibble of opcode byte determines if ALU operation (where all 3 addresses are used)

module alu_register_verilog (

    input wire clk,
    input wire reset,

    // Interface
    input wire [`MSB:0] opcode,
    input wire [`MSB:0] operand,
    output wire [`MSB:0] reg_read_data,
    input wire read_enable,

    // ALU operations
    output wire [3:0] alu_flags
);

    // Store data before ALU operations (after register reads)
    wire [`MSB:0] reg_a_data;
    wire [`MSB:0] reg_b_data;
    wire [`MSB:0] alu_result;   // Output from ALU
    wire [`MSB:0] reg_out_port; // Output from Register for reading

    wire [3:0] alu_addr_1, alu_addr_2, alu_addr_3; // [addr_3] = [addr_2] [.] [addr_1]

    assign alu_addr_1 = operand[3:0];
    assign alu_addr_2 = operand[11:8];
    assign alu_addr_3 = opcode[3:0];

    wire [`MSB:0] reg_write_data;

    assign reg_write_data = operand; // Write immediate for now NEED TO UPDATE THIS

    // Logic to select what data gets written to the register
    // If the opcode indicates an ALU operation, we write the ALU result.
    // Otherwise, we write the external reg_write_data.
    wire [`MSB:0] final_write_data;
    assign final_write_data = (opcode[15:12] == `ALU_OP) ? alu_result : reg_write_data;

    // External read output shows whatever is on Port 1
    assign reg_read_data = read_enable ? reg_out_port : 16'bz;
    
    // Define register
    dual_read_register_verilog register(
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .addr_1(alu_addr_1),
        .addr_2(alu_addr_2),
        .addr_3(alu_addr_3),
        .write_data(final_write_data),
        .read_data_1(reg_a_data),
        .read_data_2(reg_b_data),
        .read_data_reg(reg_out_port)
    );

    alu_verilog alu(
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .a(reg_a_data),
        .b(reg_b_data),
        .c(alu_result),
        .flags(alu_flags)
    );
    
endmodule



