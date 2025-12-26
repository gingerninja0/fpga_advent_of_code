// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define PC_RAM_OP 4'b0111 // PC to Jump from RAM data (at address)
`define PC_ROM_OP 4'b1111 // PC to Jump from ROM data (immediate)

// Define the module
module  pc_verilog (
    input wire clk,
    input wire reset,
    input wire pc_enable,
    input wire [`MSB:0] opcode,
    input wire [`MSB:0] operand,
    input wire [`MSB:0] data,
    input wire [3:0] flags, // ALU flags for branching (X|X|C|Z)
    input wire read_enable,
    output wire [`MSB:0] pc, // Program counter value
    output wire [`MSB:0] pc_debug_output
);

    localparam PC_JMP = 4'h0;
    localparam PC_JMPZ = 4'h1;
    localparam PC_JMPC = 4'h2;
    localparam PC_JMPN = 4'h3;
    localparam PC_JMPO = 4'h4;
    localparam PC_JMP_REL = 4'h5;
    localparam PC_JMPZ_REL = 4'h6;
    localparam PC_JMPC_REL = 4'h7;
    localparam PC_JMPN_REL = 4'h8;
    localparam PC_JMPO_REL = 4'h9;

    wire [3:0] pc_op_select; // Select register operation (so it can be used in combination with the ALU)
    wire [3:0] pc_op_operation; // Select register operation (so it can be used in combination with the ALU)

    assign pc_op_select = opcode[15:12];
    assign pc_op_operation = opcode[11:8];

    reg [`MSB:0] pc_register;

    assign pc = read_enable ? pc_register : 16'bz;
    assign pc_debug_output = pc_register;

    reg [`MSB:0] jump_val;

    // Writing to RAM from ROM (RAM Address in opcode)
    always @(*) begin
        if ({pc_op_select} == `PC_RAM_OP) begin
            jump_val = data;
        end else begin
            jump_val = operand;
        end
    end

    always@(posedge clk) begin

        if (reset) begin
            pc_register <= 0;
        end else begin
            if (pc_enable) begin
                if ((pc_op_select == `PC_RAM_OP) || (pc_op_select == `PC_ROM_OP)) begin

                    case(pc_op_operation)
                        PC_JMP: pc_register <= jump_val;
                        PC_JMPZ: pc_register <= (flags[0] == 1'b1) ? jump_val : pc_register + 1'b1;
                        PC_JMPC: pc_register <= (flags[1] == 1'b1) ? jump_val : pc_register + 1'b1;
                        PC_JMPN: pc_register <= (flags[2] == 1'b1) ? jump_val : pc_register + 1'b1;
                        PC_JMPO: pc_register <= (flags[3] == 1'b1) ? jump_val : pc_register + 1'b1;
                        PC_JMP_REL: pc_register <= pc_register + jump_val;
                        PC_JMPZ_REL: pc_register <= (flags[0] == 1'b1) ? pc_register + jump_val : pc_register + 1'b1;
                        PC_JMPC_REL: pc_register <= (flags[1] == 1'b1) ? pc_register + jump_val : pc_register + 1'b1;
                        PC_JMPN_REL: pc_register <= (flags[2] == 1'b1) ? pc_register + jump_val : pc_register + 1'b1;
                        PC_JMPO_REL: pc_register <= (flags[3] == 1'b1) ? pc_register + jump_val : pc_register + 1'b1;
                        default: pc_register <= pc_register + 1'b1;
                    endcase

                end else begin
                    // The endless passage of time towards order...
                    // (The program counter increases every clock cycle)
                    pc_register <= pc_register + 1'b1;
                end
            end
        end

    end



    
endmodule