// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define PC_OP 4'b0111 // The top nibble of operator byte determines if PC operation

// Define the module
module  pc_verilog (
    input wire clk,
    input wire reset,
    input wire pc_enable,
    input wire [`MSB:0] opcode,
    input wire [`MSB:0] operand,
    input wire [3:0] flags, // ALU flags for branching (X|X|C|Z)
    input wire read_enable,
    output wire [`MSB:0] pc, // Program counter value
    output wire [`MSB:0] pc_debug_output
);

    localparam PC_JMP = 4'h0;
    localparam PC_JMPC = 4'h1;
    localparam PC_JMPZ = 4'h2;
    localparam PC_JMP_REL = 4'h3;
    localparam PC_JMPC_REL = 4'h4;
    localparam PC_JMPZ_REL = 4'h5;

    wire [3:0] pc_op_select; // Select register operation (so it can be used in combination with the ALU)
    wire [3:0] pc_op_operation; // Select register operation (so it can be used in combination with the ALU)

    assign pc_op_select = opcode[15:12];
    assign pc_op_operation = opcode[11:8];

    reg [`MSB:0] pc_register;

    assign pc = read_enable ? pc_register : 16'bz;
    assign pc_debug_output = pc_register;

    always@(posedge clk) begin

        if (reset) begin
            pc_register <= 0;
        end else begin
            if (pc_op_select == `PC_OP) begin

                case(pc_op_operation)
                    PC_JMP: pc_register <= operand;
                    PC_JMPC: pc_register <= (flags[1] == 1'b1) ? operand : pc_register + 1'b1;
                    PC_JMPZ: pc_register <= (flags[0] == 1'b1) ? operand : pc_register + 1'b1;
                    PC_JMP_REL: pc_register <= pc_register + operand;
                    PC_JMPC_REL: pc_register <= (flags[1] == 1'b1) ? pc_register + operand : pc_register + 1'b1;
                    PC_JMPZ_REL: pc_register <= (flags[0] == 1'b1) ? pc_register + operand : pc_register + 1'b1;
                    default: pc_register <= pc_register + 1'b1;
                endcase

            end else begin
                // The endless passage of time towards order...
                // (The program counter increases every clock cycle)
                pc_register <= pc_register + 1'b1;
            end
        end

    end



    
endmodule