`timescale 1ns / 1ps  // Set time units

// Processor Testbench: iverilog -o processor_sim *.v && vvp processor_sim
// This must be run form the processor/ folder

module processor_verilog_tb;


    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    wire [15:0] data_output;


    // Instantiate the Unit Under Test (UUT)
    processor_verilog uut (
        .clk(clk),
        .reset(reset),
        .data_output(data_output)
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

        #100;

        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("Time=%t | Data bus value=%h", $time, data_output);
    end

endmodule