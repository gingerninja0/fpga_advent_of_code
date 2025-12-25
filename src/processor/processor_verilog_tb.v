`timescale 1ns / 1ps  // Set time units

// Processor Testbench: iverilog -o processor_sim *.v && vvp processor_sim
// This must be run form the processor/ folder

module processor_verilog_tb;


    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    wire [15:0] data_output;
    wire [15:0] opcode_bus_output;
    wire [15:0] operand_bus_output;
    wire [2:0] current_state;
    wire [15:0] pc_output;


    // Instantiate the Unit Under Test (UUT)
    processor_verilog uut (
        .clk(clk),
        .reset(reset),
        .data_output(data_output),
        .current_state_output(current_state),
        .pc_output(pc_output),
        .opcode_bus_output(opcode_bus_output),
        .operand_bus_output(operand_bus_output)
    );

    // Generate the clock signal (toggle every 5ns for a 10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;

        // Wait 20ns, then release reset
        #20 reset = 0;
        @(negedge clk); 

        #300;

        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("Time=%t | PC=%h | STATE=%h | Data bus value=%h | opcode=%h | operand=%h", $time, pc_output, current_state, data_output, opcode_bus_output, operand_bus_output);
    end

endmodule