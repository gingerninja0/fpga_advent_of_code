// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define ALU_OP 4'b0001 // The top nibble of operator byte determines if ALU operation (where all 3 addresses are used)
`define ROM_OP 4'b0011 // The top nibble of operator byte determines if ROM operation
`define RAM_OP 4'b0100 // The top nibble of operator byte determines if RAM operation
`define PC_OP 4'b0111 // The top nibble of operator byte determines if PC operation


module processor_verilog (

    input wire clk,
    input wire reset,

    // Interface
    output wire [`MSB:0] data_output
);

    // Store data before ALU operations (after register reads)
    wire [`MSB:0] opcode_bus;
    wire [`MSB:0] operand_bus;
    reg [`MSB:0] data_bus;
    wire [`MSB:0] alu_out;  
    wire [`MSB:0] pc_out;  
    wire [`MSB:0] ram_out;
    wire [3:0] flags_bus;

    // Connect the internal data_bus to the external output wire
    assign data_output = data_bus;

    // Line 68 is likely around here:
    always @(*) begin
        case (opcode_bus[15:12])
            4'b0001: data_bus = alu_out;
            4'b0100: data_bus = ram_out;
            default: data_bus = pc_out;
        endcase
    end
    
    // Modules
    alu_register_verilog alu(
        .clk(clk),
        .reset(reset),
        .opcode(opcode_bus),
        .operand(operand_bus),
        .reg_read_data(alu_out),
        .alu_flags(flags_bus)
    );

    pc_verilog pc(
        .clk(clk),
        .reset(reset),
        .opcode(opcode_bus),
        .operand(operand_bus),
        .flags(flags_bus),
        .pc(data_bus)
    );

    ram_verilog ram(
        .clk(clk),
        .reset(reset),
        .opcode(opcode_bus),
        .operand(operand_bus),
        .write_data(data_bus),
        .read_data(data_bus)
    );

    rom_verilog rom(
        .addr(data_bus),
        .read_opcode(opcode_bus),
        .read_operand(operand_bus)
    );


    // Fetch-Decode-Execute State Machine

    // Do things



endmodule



