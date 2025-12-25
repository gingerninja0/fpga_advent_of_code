// Module configuration
`define DATA_WIDTH 16
`define MSB (`DATA_WIDTH - 1)
`define CARRY_BIT `DATA_WIDTH

`define RAM_OP 4'b0100 // The top nibble of operator byte determines if RAM operation
`define ROM_OP 4'b0011 // The top nibble of operator byte determines if ROM operation
`define REG_OP 4'b1001 // The top nibble of operator byte determines if ALU/REG operation


// Define the module
module  ram_verilog (
    input wire clk,
    input wire reset,
    input wire [`MSB:0] opcode, // This is the opcode code sent to every module, used here to determine the mode of operation
    input wire [`MSB:0] operand, // 8 bit RAM address (we don't need that much)
    input wire [`MSB:0] write_data,
    input wire read_enable,
    input wire write_enable,
    output wire [`MSB:0] read_data
);
    localparam RAM_WRITE = 4'h1;
    localparam RAM_READ = 4'h2;

    reg [`MSB:0] ram_array [0:255]; // 16 bit RAM (to store the operator and operand)
    reg [`MSB:0] data; // Data storage inside the RAM module
    wire [3:0] ram_op_select; 
    wire [3:0] ram_op_operation;
    reg [7:0] addr;

    assign ram_op_select = opcode[15:12];
    assign ram_op_operation = opcode[11:8];

    // Writing to RAM from ROM (RAM Address in opcode)
    always @(*) begin
        if ({ram_op_select} == {`ROM_OP}) begin
            addr = opcode[7:0];
        end else begin
            addr = operand[7:0];
        end
    end



    always @(posedge clk) begin
        if (write_enable) begin
            case({ram_op_select, ram_op_operation})
                {`RAM_OP, RAM_WRITE}: ram_array[addr] <= operand;
                {`ROM_OP, RAM_WRITE}: ram_array[addr] <= write_data;
                {`REG_OP, RAM_WRITE}: ram_array[addr] <= write_data;
            endcase
        end
    end

    // // 1. Debug the WRITE process
    // always @(*) begin
    //     case({ram_op_select, ram_op_operation})
    //         8'b0011_0001: begin
    //             if (write_enable) begin
    //                 $display("TIME=%0t | RAM WRITE | Addr:%h | Data:%h", $time, addr, ram_array[addr]);
    //             end
    //         end
    //     endcase
    // end

    // // 2. Debug the READ process
    // always @(*) begin
    //     if (read_enable) begin
    //         $display("TIME=%0t | RAM READ ATTEMPT | Op:%h | Addr:%h | ValueInMem:%h", 
    //                   $time, opcode, addr, ram_array[addr]);
    //     end
    // end

    assign read_data = (read_enable && (opcode[15:8] == 8'h42)) ? ram_array[addr] : 16'bz; // RAM -> Output
    assign read_data = (read_enable && (opcode[15:8] == 8'h92)) ? ram_array[addr] : 16'bz; // RAM -> REG
    
endmodule