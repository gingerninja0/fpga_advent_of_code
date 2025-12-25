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
    output wire [`MSB:0] data_output,
    output wire [2:0] current_state_output,
    output wire [`MSB:0] pc_output,
    output wire [`MSB:0] opcode_bus_output,
    output wire [`MSB:0] operand_bus_output
);

    // Store data before ALU operations (after register reads)
    wire [`MSB:0] opcode_bus;
    wire [`MSB:0] operand_bus;
    wire [`MSB:0] data_bus;
    wire [3:0] flags_bus;

    // Control wires
    reg alu_read_enable, pc_read_enable, ram_read_enable, pc_enable, rom_enable;

    // Connect the internal data_bus to the external output wire
    assign data_output = data_bus;
    assign opcode_bus_output = opcode_bus;
    assign operand_bus_output = operand_bus;
    
    // Modules
    alu_register_verilog alu(
        .clk(clk),
        .reset(reset),
        .opcode(opcode_bus),
        .operand(operand_bus),
        .reg_read_data(data_bus),
        .alu_flags(flags_bus),
        .read_enable(alu_read_enable)
    );

    pc_verilog pc(
        .clk(clk),
        .reset(reset),
        .pc_enable(pc_enable),
        .opcode(opcode_bus),
        .operand(operand_bus),
        .flags(flags_bus),
        .pc(data_bus),
        .read_enable(pc_read_enable),
        .pc_debug_output(pc_output)
    );

    ram_verilog ram(
        .clk(clk),
        .reset(reset),
        .opcode(opcode_bus),
        .operand(operand_bus),
        .write_data(data_bus),
        .read_data(data_bus),
        .read_enable(ram_read_enable)
    );

    rom_verilog rom(
        .addr(data_bus),
        .rom_enable(rom_enable),
        .read_opcode(opcode_bus),
        .read_operand(operand_bus)
    );


    // Fetch-Decode-Execute State Machine

    localparam START = 3'd0;
    localparam S1    = 3'd1;
    localparam S2    = 3'd2;
    localparam S3    = 3'd3;
    localparam S4    = 3'd4;
    reg [2:0] current_state, next_state;

    assign current_state_output = current_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= START;
        end else begin
            current_state <= next_state;
        end
    end

    always @* begin
        next_state = current_state; // Default to staying in the current state
        case (current_state)
            START: begin
                next_state = S1;
            end
            S1: begin
                next_state = S2;
            end
            S2: begin
                next_state = S3;
            end
            S3: begin
                next_state = S4;
            end
            S4: begin
                next_state = START;
            end
            default: begin
                next_state = START; // Handle unexpected states
            end
        endcase
    end

    always @* begin
        // Zero all control lines after clock cycle
        pc_read_enable = 1'b0;
        pc_enable = 1'b0;
        alu_read_enable = 1'b0;
        ram_read_enable = 1'b0;
        rom_enable = 1'b0;

        case (current_state)
            START: begin
                pc_read_enable = 1'b1;
                rom_enable = 1'b1;
            end
            S1: begin
                if (opcode_bus[15:8] == 8'b0010_0010) begin
                    alu_read_enable = 1'b1;
                end
                else if (opcode_bus[15:8] == 8'b0100_0010) begin
                    ram_read_enable = 1'b1;
                end
            end
            S2: begin
                
            end
            S3: begin
                
            end
            S4: begin
                pc_enable = 1'b1;
            end
        endcase
    end

endmodule



