// A dual read register

// OPERATIONS
`define READ_OP 8'b0010_0010
`define WRITE_OP 8'b0010_0001
`define ALU_OP 4'b0001 // The top nibble of operator byte determines if ALU operation (where all 3 addresses are used)

// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)

`define N_REG 16
`define N_REG_1 (`N_REG - 1)

// Module definition
module dual_read_register_verilog (
    input wire clk,
    input wire reset,
    input wire [`MSB:0] opcode, // This is the opcode code sent to every module, used here to determine the mode of operation
    input wire [3:0] addr_1, addr_2, addr_3,    
    input wire [`MSB:0] write_data,
    output wire [`MSB:0] read_data_1, read_data_2, read_data_reg
);
    reg [`MSB:0] registers[0:`N_REG_1] ; // 16 registers (4-bit address)

    integer i; // For the reset loop

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < `N_REG; i = i + 1) begin
                registers[i] <= `DATA_WIDTH'b0;
            end
        end
        else if ((opcode[15:12] == `ALU_OP) || (opcode[15:8] == `WRITE_OP)) begin
            registers[addr_3] <= write_data;
        end
    end

    assign read_data_1 = (opcode[15:12] == `ALU_OP) ? registers[addr_1] : `DATA_WIDTH'b0;
    assign read_data_2 = (opcode[15:12] == `ALU_OP) ? registers[addr_2] : `DATA_WIDTH'b0;

    assign read_data_reg = (opcode[15:8] == `READ_OP) ? registers[addr_3] : `DATA_WIDTH'b0; // To read the register contents (separate to the ALU, so technically this is a tripple read, however only single or dual read is used at one time)
    

endmodule