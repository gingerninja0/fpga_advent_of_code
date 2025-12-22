`timescale 1ns / 1ps  // Set time units

// ALU and Register Testbench: iverilog -o alu_sim alu_verilog.v alu_register_verilog_tb.v dual_read_register_verilog.v alu_register_verilog.v && vvp alu_sim

module alu_verilog_tb;

    localparam OP_ADD = 8'h10;
    localparam OP_SUB = 8'h11;
    localparam OP_AND = 8'h12;
    localparam OP_OR  = 8'h13;
    localparam OP_XOR = 8'h14;

    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    reg [15:0] main_operator;
    reg [15:0] main_operand;
    wire [15:0] reg_read_data;   
    wire [3:0] alu_flags;


    // Instantiate the Unit Under Test (UUT)
    alu_register_verilog uut (
        .clk(clk),
        .reset(reset),
        .operator(main_operator),
        .operand(main_operand),
        .reg_read_data(reg_read_data),
        .alu_flags(alu_flags)
    );

    // Generate the clock signal (toggle every 5ns for a 10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;

        // Wait 20ns, then release reset
        #20 reset = 0;

        // Load register 1 with data
        @(negedge clk); 
        main_operator = 16'b0010_0001_0000_0001;
        main_operand = 16'd4; // decimal 2
        
        // Load register 2 with data
        @(negedge clk); 
        main_operator = 16'b0010_0001_0000_0010;
        main_operand = 16'd5; // decimal 3

        // Generate ALU operator and operand as if it came from ROM
        @(negedge clk);     
        main_operator = {OP_ADD, 4'h0, 4'h3}; // Add R3
        main_operand =  16'b0001_0010_0000_0001; // R2 R1

        // Read the result from register 3
        @(negedge clk);
        main_operator = 16'b0010_0010_0000_0011;
        main_operand =  16'b0000_0000_0000_0000; // R2 R1

        // Generate ALU operator and operand as if it came from ROM
        @(negedge clk);     
        main_operator = {OP_XOR, 4'h0, 4'h3}; // XOR R3
        main_operand =  16'b0000_0010_0000_0001; // R2 R1

        // Read the result from register 3
        @(negedge clk);
        main_operator = 16'b0010_0010_0000_0011;
        main_operand =  16'b0000_0000_0000_0000; // R2 R1

        #50;

        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("Time=%t | Reset=%b | Op=%h | Out=%d | Flags=%b", $time, reset, main_operator, reg_read_data, alu_flags);
    end

endmodule