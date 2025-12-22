`timescale 1ns / 1ps  // Set time units

// PC Testbench: iverilog -o pc_sim pc_verilog.v pc_verilog_tb.v &&  vvp pc_sim

module pc_verilog_tb;


    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    reg [15:0] op, operand;
    reg [3:0] flags;
    wire [15:0] pc_val;

    // Instantiate the Unit Under Test (UUT)
    pc_verilog uut (
        .clk(clk),
        .reset(reset),
        .op(op),
        .operand(operand),
        .flags(flags),
        .pc(pc_val)
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

        // Let program counter advance a bit
        @(negedge clk); 
        @(negedge clk); 
        @(negedge clk); 
        // Advance PC by 3

        // Jump (unconditional) (absolute)
        op = 16'h7000;
        operand = 16'h0000;
        @(negedge clk); 
        op = 0;
        operand = 0;

        // Let program counter advance a bit
        @(negedge clk); 
        @(negedge clk); 
        @(negedge clk);  
        // Advance PC by 3


        // Jump Zero (absolute)
        flags = 4'b0001;
        op = 16'h7200;
        operand = 16'h0100;
        @(negedge clk); 
        op = 0;
        operand = 0;

        // Let program counter advance a bit
        @(negedge clk); 
        @(negedge clk); 
        @(negedge clk);  
        // Advance PC by 3


        // Jump Carry (absolute)
        flags = 4'b0010;
        op = 16'h7100;
        operand = 16'h0200;
        @(negedge clk); 
        op = 0;
        operand = 0;

        // Let program counter advance a bit
        @(negedge clk); 
        @(negedge clk); 
        @(negedge clk);  
        // Advance PC by 3


        // Jump Zero (absolute) (Intended to fail, won't jump to 0x0300)
        flags = 4'b0000;
        op = 16'h7200;
        operand = 16'h0300;
        @(negedge clk); 
        op = 0;
        operand = 0;

        // Let program counter advance a bit
        @(negedge clk); 
        @(negedge clk); 
        @(negedge clk);  
        // Advance PC by 3

        #100;

        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("Time=%t | PC Value=%h | Flags=%h | Jump to=%h", $time, pc_val, flags, operand);
    end

endmodule