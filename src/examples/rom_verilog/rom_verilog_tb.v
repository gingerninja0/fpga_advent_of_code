`timescale 1ns / 1ps  // Set time units

// ROM Testbench

module rom_verilog_tb;


    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    reg [15:0] address;
    wire [15:0] read_operator, read_operand;

    // Instantiate the Unit Under Test (UUT)
    rom_verilog uut (
        .addr(address),
        .read_operator(read_operator),
        .read_operand(read_operand)
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

        address = 15'h0000;
        @(negedge clk); 

        address = 15'h0001;
        @(negedge clk); 

        address = 15'h0002;
        @(negedge clk); 

        address = 15'h0003;
        @(negedge clk); 

        address = 15'h0004;
        @(negedge clk); 

        address = 15'h0005;
        @(negedge clk); 


        #100;

        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("Time=%t | Address=%h | OPERAND=%h | OPERATOR=%h", $time, address, read_operator, read_operand);
    end

endmodule