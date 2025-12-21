`timescale 1ns / 1ps  // Set time units

module alu_verilog_tb;

    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    reg [7:0] a;
    reg [7:0] b;
    reg [7:0] op;    
    
    // Outputs are wires because we observe them
    wire [7:0] c;
    wire [3:0] flags;


    // Instantiate the Unit Under Test (UUT)
    alu_verilog uut (
        .clk(clk),
        .reset(reset),
        .a(a),
        .b(b),
        .op(op),
        .c(c),
        .flags(flags)
    );

    // Generate the clock signal (toggle every 5ns for a 10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        a = 8'b11111111; // Example input A
        b = 8'b00000001; // Example input B
        op = 8'b00000000; // Example operation code (addition)

        // Wait 20ns, then release reset
        #20 reset = 0;

        // Let the counter run for 20ns
        #10;

        
        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("At time %t, reset = %b, a=%d, b=%d, op=%d, result= %d, flags= %b", $time, reset, a, b, op, c, flags);
    end

endmodule