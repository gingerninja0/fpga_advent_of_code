// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

// CHANGE TO DUAL READ TO AVOID THE STATE MACHINE

module alu_register_verilog (

    input wire clk,
    input wire reset,

    // Interface
    input wire [`MSB:0] op,
    input wire [`MSB:0] reg_write_data, 
    output wire [`MSB:0] reg_read_data,

    // ALU operations
    input wire [3:0] alu_addr_1, alu_addr_2, alu_addr_3, // [addr_3] = [addr_2] [.] [addr_1]
    output wire [3:0] alu_flags
);

    // Store data before ALU operations (after register reads)
    wire [`MSB:0] reg_a_data;
    wire [`MSB:0] reg_b_data;
    wire [`MSB:0] alu_result;   // Output from ALU
    wire [`MSB:0] reg_out_port; // Output from Register for reading

    // Logic to select what data gets written to the register
    // If the op code indicates an ALU operation, we write the ALU result.
    // Otherwise, we write the external reg_write_data.
    wire [`MSB:0] final_write_data;
    assign final_write_data = (op[15:12] == 4'b0000) ? alu_result : reg_write_data;

    // External read output shows whatever is on Port 1
    assign reg_read_data = reg_out_port;
    
    // Define register
    dual_read_register_verilog register(
        .clk(clk),
        .reset(reset),
        .op(op),
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
        .op(op),
        .a(reg_a_data),
        .b(reg_b_data),
        .c(alu_result),
        .flags(alu_flags)
    );
    
endmodule



