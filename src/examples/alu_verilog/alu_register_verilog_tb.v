`timescale 1ns / 1ps  // Set time units



module alu_verilog_tb;

    localparam OP_ADD = 8'h00;
    localparam OP_SUB = 8'h01;
    localparam OP_AND = 8'h02;
    localparam OP_OR  = 8'h03;
    localparam OP_XOR = 8'h04;

    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    reg [15:0] main_operator;
    reg [15:0] main_operand;
    reg [15:0] alu_op;
    reg [15:0] reg_write_data;
    wire [15:0] reg_read_data;    
    
    // Outputs are wires because we observe them
    reg [3:0] alu_addr_1, alu_addr_2, alu_addr_3;
    reg alu_start;

    wire [3:0] alu_flags;
    wire alu_busy;

    reg [15:0] operator;
    reg [15:0] operand;


    // Instantiate the Unit Under Test (UUT)
    alu_register_verilog uut (
        .clk(clk),
        .reset(reset),
        .op(alu_op),
        .reg_write_data(reg_write_data),
        .reg_read_data(reg_read_data),
        .alu_addr_1(alu_addr_1),
        .alu_addr_2(alu_addr_2),
        .alu_addr_3(alu_addr_3),
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

        // Load register 1 with data (2)
        @(negedge clk); 
        main_operator = 16'b0001_0001_0000_0001;
        main_operand = 16'd4; // decimal 2
        alu_op = main_operator;
        alu_addr_3 = main_operator[3:0];
        reg_write_data = main_operand; // Load immediate (for now, I may make this a RAM address instead)

        
        // Load register 2 with data (3)
        @(negedge clk); 
        main_operator = 16'b0001_0001_0000_0010;
        main_operand = 16'd4; // decimal 3
        alu_op = main_operator;
        alu_addr_3 = main_operator[3:0];
        reg_write_data = main_operand; // Load immediate (for now, I may make this a RAM address instead)

        // Generate ALU operator and operand as if it came from ROM
        @(negedge clk);     
        main_operator = {OP_SUB, 4'h0, 4'h3}; // Add R3
        main_operand =  16'b0000_0010_0000_0001; // R2 R1

        alu_op = main_operator;
        alu_addr_3 = main_operator[3:0];
        alu_addr_2 = main_operand[11:8];
        alu_addr_1 = main_operand[3:0];


        // Read the result
        @(negedge clk);
        main_operator = 16'b0001_0010_0000_0011;
        // main_operand =  16'b0000_0000_0000_0011; // R2 R1

        alu_op = main_operator;
        alu_addr_3 = main_operator[3:0];

        // Generate ALU operator and operand as if it came from ROM
        @(negedge clk);     
        main_operator = {OP_ADD, 4'h0, 4'h3}; // Add R3
        main_operand =  16'b0000_0010_0000_0001; // R2 R1

        alu_op = main_operator;
        alu_addr_3 = main_operator[3:0];
        alu_addr_2 = main_operand[11:8];
        alu_addr_1 = main_operand[3:0];


        // Read the result
        @(negedge clk);
        main_operator = 16'b0001_0010_0000_0011;
        // main_operand =  16'b0000_0000_0000_0011; // R2 R1

        alu_op = main_operator;
        alu_addr_3 = main_operator[3:0];

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