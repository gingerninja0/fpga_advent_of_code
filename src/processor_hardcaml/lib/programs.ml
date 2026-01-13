type instruction = { 
  addr : int; 
  data : int 
}

let fibonacci = [|

	{ addr = 0x0000; data = 0x3101_000a }; (* Load RAM1 with value from ROM addr 10 *)
	{ addr = 0x0001; data = 0x3102_000b }; (* Load RAM2 with value from ROM addr 11 *)
	{ addr = 0x0002; data = 0x9201_0001 }; (* Load RAM1 into R1 *)
	{ addr = 0x0003; data = 0x9202_0002 }; (* Load RAM2 into R2 *)
	(* Start of Loop *)
	{ addr = 0x0004; data = 0x1001_0102 }; (* R1 + R2 = R1 *)
	{ addr = 0x0005; data = 0x2201_0000 }; (* R1 => Out *)
	{ addr = 0x0006; data = 0x1002_0102 }; (* R1 + R2 = R2 *)
	{ addr = 0x0007; data = 0x2202_0000 }; (* R2 => Out *)
	{ addr = 0x0008; data = 0xf000_0004 }; (* Jump immediate back to start of loop at addr 4 *)
	(* End of loop *)
	{ addr = 0x0009; data = 0x0000_0000 };
	{ addr = 0x000a; data = 0x0000_0001 }; (* RAM1 Val *)
	{ addr = 0x000b; data = 0x0000_0001 }; (* RAM2 Val *)
	
|]

let day_1_part_1 = [|

  	{ addr = 0x0000; data = 0xf000_0008 }; (* 0: JMP 0x0008                Where the code actually starts, below is Constants *)
    { addr = 0x0001; data = 0x0000_0000 }; (* 1: HALT                      Halt if jump fails for any reason        *)
    (* Constants, stored in RAM:1X *)
    { addr = 0x0002; data = 0x0000_0032 }; (* 2: 50d                       50d - Initial dial value of 50d (0x32)   *)
    { addr = 0x0003; data = 0x0000_0001 }; (* 3: 1d *)
    { addr = 0x0004; data = 0x0000_0064 }; (* 4: 100d *)
    { addr = 0x0005; data = 0x0000_0063 }; (* 5: 99d *)
    { addr = 0x0006; data = 0x0000_0000 }; (* 6: 0d *)
    { addr = 0x0007; data = 0x0000_0402 }; (* 7: 1026d                     Address of the first value of the input data, stored in data.mem now at 0x0402 *)
    
    (* FIRST LINE OF CODE - Line 7 *)
    (* Load constants into RAM:1X *)
    { addr = 0x0008; data = 0x3110_0002 }; (* 8: LOAD RAM:10 ROM:02        50d in RAM:10 *)
    { addr = 0x0009; data = 0x3111_0003 }; (* 9: LOAD RAM:11 ROM:03        1d in RAM:11 *)
    { addr = 0x000a; data = 0x3112_0004 }; (* a: LOAD RAM:12 ROM:04        100d in RAM:12 *)
    { addr = 0x000b; data = 0x3113_0005 }; (* b: LOAD RAM:13 ROM:05        99d in RAM:13 *)
    { addr = 0x000c; data = 0x3114_0006 }; (* c: LOAD RAM:14 ROM:06        0d in RAM:14 *)
    
    (* Load constants into REGs *)
    { addr = 0x000d; data = 0x9200_0010 }; (* d: LOAD REG:00 ROM:10        50d in REG:0, Current dial val, not really a constant... *)
    { addr = 0x000e; data = 0x9201_0011 }; (* e: LOAD REG:01 RAM:11        1d in REG:1 *)
    { addr = 0x000f; data = 0x9202_0012 }; (* f: LOAD REG:02 RAM:12        100d in REG:2 *)
    { addr = 0x0010; data = 0x9203_0013 }; (* 10: LOAD REG:03 RAM:13       99d in REG:3 *)
    { addr = 0x0011; data = 0x9204_0014 }; (* 11: LOAD REG:04 RAM:14       0d in REG:4  *)
    
    (* Load variables into RAM:2X *)
    { addr = 0x0012; data = 0x3120_0006 }; (* 12: LOAD RAM:20 ROM:06       Initialise 0d in RAM:21, to count the number of zeros (the output of the challenge) *)
    { addr = 0x0013; data = 0x3121_0006 }; (* 13: LOAD RAM:21 ROM:06       RAM:21 to store the current value from the list (initialised to zero for clarity) *)
    { addr = 0x0014; data = 0x3122_0007 }; (* 14: LOAD RAM:22 ROM:07       Address of first input value in RAM:22, this gets iterated by the program to read the list *)
    { addr = 0x0015; data = 0x3123_0400 }; (* 15: LOAD RAM:23 ROM:400      Length of data input, given from the preprocessing of the data, stored in data.mem now at 0x0400 *)
    
    (* Load variables into REGs *)
    { addr = 0x0016; data = 0x9208_0023 }; (* 16: LOAD REG:8 RAM:23        [Length of input] in REG:8 from RAM:01 (Will be decremented to count position in input) *)
    { addr = 0x0017; data = 0x9209_0020 }; (* 17: LOAD REG:9 RAM:20        REG:9 to store 0 count (Output of program) Initialised to 0d (Where the result will be stored) *)
    { addr = 0x0018; data = 0x920a_0022 }; (* 18: LOAD REG:a RAM:22        Address of first input value in REG:a from RAM:22 (Will be iterated to read through list) *)
    { addr = 0x0019; data = 0x920b_0021 }; (* 19: LOAD REG:b RAM:21        REG:b to store current input value (From ROM[RAM] -> RAM operation) *)
    
    (* Main Loop Start *)
    { addr = 0x001a; data = 0x0F00_0000 }; (* 1a: OUT 08                   Display current position in the loop for debugging, replace with 0F00_0000 for no-op, 2208_0000 to display loop iteration *)
    
    (* Get next value from list and add to the dial_val (REG:00) *)
    { addr = 0x001b; data = 0x3222_0021 }; (* 1b: ROM:[RAM:22] -> RAM:21   Get the value at ROM address given by RAM:22 and store in RAM:21 *)
    { addr = 0x001c; data = 0x920b_0021 }; (* 1c: LOAD REG:b RAM:21        Put the input_val in REG:b for the addition *)
    { addr = 0x001d; data = 0x1000_0b00 }; (* 1d: ADD REG:0 = REG:0 + REG:b (dial_val = dial_val + input_val) Update dial value from current input_val from the input array *)
    
    (* Update the address pointer *)
    { addr = 0x001e; data = 0x100a_010a }; (* 1e: ADD REG:a = REG:a + REG:1    Increment the input array address pointer *)
    { addr = 0x001f; data = 0x910a_0022 }; (* 1f: LOAD RAM:22 REG:a        Update RAM:22 with the incremented address pointer for the next loop *)
    
    (* Decrement the length of input to act as iteration variable *)
    { addr = 0x0020; data = 0x1108_0108 }; (* 20: SUB REG:8 = REG:8 - REG:1    Subtract 1 from the input array length to track position in list *)
    
    (* Underflow check *)
    (* while (dial_val + 0 < 0) *)
    (*    dial_val = 100 + dial_val *)
    (* end_while *)
    (* Start of underflow loop *)
    { addr = 0x0021; data = 0x100f_0400 }; (* 21: ADD REG:F = REG:0 + REG:4 (TEMP = dial_val + 0) To update the flags to check if its negative, dummy result stored in REG:f (TEMP) *)
    { addr = 0x0022; data = 0xf700_0025 }; (* 22: JMPNN 25                 JMPNN Jump if not negative (positive), check if we need to run the underflow loop, if not then this will be true and we will jump over it *)
    { addr = 0x0023; data = 0x1000_0200 }; (* 23: ADD REG:0 = REG:0 + REG:2 (dial_val = dial_val + 100) *)
    { addr = 0x0024; data = 0xf000_0021 }; (* 24: JMP 21                   If the exit condition is not met, we loop again, jump to start of loop *)
    
    (* End of underflow loop *)
    (* Overflow check *)
    (* while (99 - dial_val < 0) *)
    (*    dial_val = dial_val - 100 *)
    (* end_while *)
    (* Start of overflow loop *)
    { addr = 0x0025; data = 0x110f_0003 }; (* 25: SUB REG:F = REG:3 - REG:0 (TEMP = 99 - dial_val) To update the flags to check if its negative, dummy result stored in REG:f (TEMP) *)
    { addr = 0x0026; data = 0xf700_0029 }; (* 26: JMPNN 29                 JMPNN Jump if not negative (positive), check if we need to run the underflow loop, if not then this will be true and we will jump over it *)
    { addr = 0x0027; data = 0x1100_0200 }; (* 27: ADD REG:0 = REG:0 - REG:2 (dial_val = dial_val - 100) *)
    { addr = 0x0028; data = 0xf000_0025 }; (* 28: JMP 25                   If the exit condition is not met, we loop again, jump to start of loop *)
    
    (* End of overflow loop *)
    (* Increment the output variable by 1 if the dial value is zero *)
    { addr = 0x0029; data = 0x100f_0004 }; (* 29: ADD REG:F = REG:0 + REG:4 (TEMP = dial_val + 0) To update the flags to check for zero result *)
    { addr = 0x002a; data = 0xf500_002c }; (* 2a: JMPNZ                    If the result is not zero, skip incrementing the result value, if the result is zero then the increment is performed *)
    { addr = 0x002b; data = 0x1009_0901 }; (* 2b: ADD REG:9 = REG:9 + REG:1 (result_val = result_val + 1) Increment the output variable when the result is zero *)
    
    (* Check loop condition and exit *)
    { addr = 0x002c; data = 0x100f_0804 }; (* 2c: ADD REG:F = REG:8 + REG:4 (TEMP = loop_index + 0) To update flags to check for zero result to exit the loop *)
    { addr = 0x002d; data = 0xf100_002f }; (* 2d: JMPZ 2f                  Jump to end of program if the loop_index equals zero to display thr result and exit the program *)
    { addr = 0x002e; data = 0xf000_001a }; (* 2e: JMP 1a                   Jump to the start of the loop *)
    
    (* Main Loop End *)
    { addr = 0x002f; data = 0x2209_0000 }; (* 2f: Output the result value *)
    { addr = 0x0030; data = 0x0000_0000 }; (* 30: HALT END PROGRAM *)

|]
