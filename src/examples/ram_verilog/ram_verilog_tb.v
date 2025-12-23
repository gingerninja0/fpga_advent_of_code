`timescale 1ns / 1ps  // Set time units

// RAM Testbench: iverilog -o ram_sim ram_verilog.v ram_verilog_tb.v &&  vvp ram_sim

module pc_verilog_tb;


    // Inputs are registers (reg) because we drive them
    reg clk;
    reg reset;
    reg [15:0] opcode;
    reg [15:0] operand;
    reg [15:0] write_data;
    wire [15:0] read_data;

    wire [7:0] addr;
    assign addr = operand[7:0];

    // Instantiate the Unit Under Test (UUT)
    ram_verilog uut (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .operand(operand),
        .write_data(write_data),
        .read_data(read_data)
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

        // Write 10 to address 1
        @(negedge clk); 
        opcode = 16'b0100_0001_0000_0000;
        operand = 16'b0000_0000_0000_0001;
        write_data = 16'd10;

        // Read 10 from address 1
        @(negedge clk); 
        opcode = 16'b0100_0010_0000_0000;
        operand = 16'b0000_0000_0000_0001;
        write_data = 16'd0;

        // Write 16 to address 2
        @(negedge clk); 
        opcode = 16'b0100_0001_0000_0000;
        operand = 16'b0000_0000_0000_0010;
        write_data = 16'd16;

        // Read 16 from address 2
        @(negedge clk); 
        opcode = 16'b0100_0010_0000_0000;
        operand = 16'b0000_0000_0000_0010;
        write_data = 16'd0;

        // Read 10 from address 1
        @(negedge clk); 
        opcode = 16'b0100_0010_0000_0000;
        operand = 16'b0000_0000_0000_0001;
        write_data = 16'd0;

        #100;

        // End simulation
        $display("Simulation finished.");
        $finish;
    end

    // Monitor the changes in the console
    initial begin
        $monitor("Time=%t | Operator=%h | Read Data=%h | Write Data=%h | Address=%h", $time, opcode[15:8], read_data, write_data, addr);
    end

endmodule