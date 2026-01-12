open Hardcaml
open Signal

module I = struct
type 'a t = {
	clk                : 'a;
	reset              : 'a;
	rom_write_enable   : 'a;
	rom_write_addr     : 'a; [@bits 16]
	rom_write_data     : 'a; [@bits 32]
} [@@deriving sexp_of, hardcaml]
end

module O = struct
type 'a t = {
	data_output         : 'a; [@bits 16]
	current_state_output: 'a; [@bits 3]
	pc_output           : 'a; [@bits 16]
	opcode_bus_output   : 'a; [@bits 16]
	operand_bus_output  : 'a; [@bits 16]
	data_bus_output     : 'a; [@bits 16]
	flags_bus_output    : 'a; [@bits 4]
} [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) =

	(* Unpack inputs as some of these were causing issues during development *)
	let { 
		I.clk; 
		reset; 
		rom_write_enable; 
		rom_write_addr; 
		rom_write_data 
		} = i in

	let spec = Reg_spec.create ~clock:clk ~reset:reset () in

	(* State machine (0:START, 1:S1, 2:S2, 3:S3) *)
	(* Incremented by the clock signal and disabled when the reset is high so that the state machine doesn't increment when loading the program into ROM *)
	let current_state = wire 3 in
	let next_state = mux current_state [
		of_int ~width:3 1; 
		of_int ~width:3 2; 
		of_int ~width:3 3; 
		of_int ~width:3 0; 
	] in
	current_state <== reg spec ~enable:(~: reset) next_state;

	let start = current_state ==:. 0 in
	let s1    = current_state ==:. 1 in
	let s2    = current_state ==:. 2 in
	let s3    = current_state ==:. 3 in

	(* Buses to link between modules *)
	let opcode_bus = wire 16 in
	let operand_bus = wire 16 in
	let data_bus = wire 16 in
	let flags_bus = wire 4 in

	(* Break out these important sections of the opcode to make the X_enable logic operations neater *)
	let opcode_top_byte = opcode_bus.:[15, 8] in
	let opcode_top_nibble = opcode_bus.:[15, 12] in

	(* Control logic, instead of the if-elseif-else chain from the processor_verilog *)
	(* These control which module is writing to a bus (data_bus, opcode_bus, or operand_bus) *)
	
	(* ALU *)
	let alu_bus_enable = 
		(s1 &: (opcode_top_byte ==:. 0x22)) |: 
		(s1 &: (opcode_top_byte ==:. 0x91))
	in

	let alu_write_enable =
		(s1 &: (opcode_top_byte ==:. 0x92)) |: 
		(s2 &: (opcode_top_nibble ==:. 0x1))
	in

	(* ROM *)
	let rom_bus_enable = 
		(s1 &: (opcode_top_byte ==:. 0x31)) |: 
		(s1 &: (opcode_top_byte ==:. 0x32))
	in

	(* RAM *)
	let ram_bus_enable = 
		(s1 &: (opcode_top_byte ==:. 0x42)) |: 
		(s1 &: (opcode_top_byte ==:. 0x92)) |: 
		(s3 &: (opcode_top_nibble ==:. 0x7))
	in

	let ram_write_enable = 
		(s1 &: (opcode_top_byte ==:. 0x41)) |: 
		(s1 &: (opcode_top_byte ==:. 0x31)) |: 
		(s1 &: (opcode_top_byte ==:. 0x91)) |: 
		(s1 &: (opcode_top_byte ==:. 0x32))
	in

	(* Modules *)

	let ram = Ram_hardcaml.create {
		clk; 
		reset;
		opcode = opcode_bus; 
		operand = operand_bus;
		write_data = data_bus;
		read_enable = ram_bus_enable |: (s1 &: (opcode_top_byte ==:. 0x32));
		write_enable = ram_write_enable;
	} in

	let alu = Alu_register_hardcaml.create {
		clk; 
		reset;
		opcode = opcode_bus; 
		operand = operand_bus;
		reg_write_data = data_bus;
		read_enable = alu_bus_enable;
		write_enable = alu_write_enable;
	} in
	flags_bus <== alu.flags;

	let pc = Pc_hardcaml.create {
		clk; 
		reset;
		pc_enable = s3; (* PC only depends on what the state is, not what the opcode is, as at the end of each cycle of the state machine the PC needs to change (increment or jump) *)
		opcode = opcode_bus; 
		operand = operand_bus;
		data = data_bus; 
		flags = flags_bus;
		read_enable = vdd; 
	} in

	let rom = Rom_hardcaml.create {
		clk; 
		reset;
		addr = pc.pc;
		rom_enable = start |: rom_bus_enable;
		rom_read_data_enable = rom_bus_enable;
		ram_rom_addr_link = ram.ram_rom_addr_link;
		write_enable = rom_write_enable;
		write_addr = rom_write_addr;
		write_data = rom_write_data;
	} in
	(* After reading the line of ROM, the opcode and operand are stored for the one cycle of the state machine *)
	opcode_bus <== reg spec ~enable:(start &: (~: reset)) rom.read_opcode;
	operand_bus <== reg spec ~enable:(start &: (~: reset)) rom.read_operand;

	(* Select which module is writing to the data bus *)
	(* In verilog I abused the tristate buffer, which cannot be done in Hardcaml, must use mux's *)
	let data_bus_select = priority_select [
		{ valid = start; value = pc.pc };
		{ valid = alu_bus_enable; value = alu.reg_read_data };
		{ valid = rom_bus_enable; value = rom.read_data };
		{ valid = ram_bus_enable; value = ram.read_data };
	] in
	data_bus <== mux2 data_bus_select.valid data_bus_select.value (zero 16);

	(* Output to user, to simulate sending an output to an HMI, triggered on s1 and held in a register until another value is outputted *)
	let data_out_en = s1 &: (
		(opcode_top_byte ==:. 0x22) |: (opcode_top_byte ==:. 0x42)
	) in
	let data_out_reg = reg spec ~enable:data_out_en data_bus in

	{ O.
		data_output          = data_out_reg;
		current_state_output = current_state;
		pc_output            = pc.pc;
		opcode_bus_output    = opcode_bus;
		operand_bus_output   = operand_bus;
		data_bus_output      = data_bus;
		flags_bus_output     = flags_bus;
	}


(* TEST LAND *)
(* Processor tests below *)

let%expect_test "Processor Test - Fibonacci" =

	let iterations = Bits.of_int ~width:32 35 in (* SET NUMBER OF ITERATIONS HERE *)

	let module Sim = Cyclesim.With_interface (I) (O) in
	let sim = Sim.create create in
	let inputs = Cyclesim.inputs sim in
	let outputs = Cyclesim.outputs sim in

	(* Function to load the program into ROM, the input *)
	let load_rom (addr : int) (data : int) =
		inputs.rom_write_enable := Bits.vdd;
		inputs.rom_write_addr := Bits.of_int ~width:16 addr;
		inputs.rom_write_data := Bits.of_int ~width:32 data;
		Cyclesim.cycle sim;
		inputs.rom_write_enable := Bits.gnd
	in

	(* Hold reset HIGH when loading program so the state machine does not cycle *)
	inputs.reset := Bits.vdd;

	(* PROGRAM START BELOW *)

	(* Fibonacci sequence example program *)
	load_rom 0x0000 0x3101_000a; (* Load RAM1 with value from ROM addr 10 *)
	load_rom 0x0001 0x3102_000b; (* Load RAM2 with value from ROM addr 11 *)
	load_rom 0x0002 0x9201_0001; (* Load RAM1 into R1 *)
	load_rom 0x0003 0x9202_0002; (* Load RAM2 into R2 *)
	(* Start of Loop *)
	load_rom 0x0004 0x1001_0102; (* R1 + R2 = R1 *)
	load_rom 0x0005 0x2201_0000; (* R1 => Out *)
	load_rom 0x0006 0x1002_0102; (* R1 + R2 = R2 *)
	load_rom 0x0007 0x2202_0000; (* R2 => Out *)
	load_rom 0x0008 0xf000_0004; (* Jump immediate back to start of loop at addr 4 *)
	(* End of loop *)
	load_rom 0x0009 0x0000_0000;
	load_rom 0x000a 0x0000_0001; (* RAM1 Val *)
	load_rom 0x000b 0x0000_0001; (* RAM2 Val *)

	(* PROGRAM END *)

	(* After program has been loaded, release the reset to make the processor ready to run *)
	inputs.reset := Bits.gnd;

	(* Print statement function for testing, may be changed depending on the program being run *)
	let print_status () =
		let state_idx = Bits.to_int !(outputs.current_state_output) in
		let states = [| "START"; "S1"; "S2"; "S3" |] in
		Printf.printf "State:%-5s | PC:%04x | Opcode:%04x | Operand:%04x | Data bus:%04x | Out (hex):%04x | Out (int):%d \n"
		states.(state_idx)
		(Bits.to_int !(outputs.pc_output))
		(Bits.to_int !(outputs.opcode_bus_output))
		(Bits.to_int !(outputs.operand_bus_output))
		(Bits.to_int !(outputs.data_bus_output))
		(Bits.to_int !(outputs.data_output))
		(Bits.to_int !(outputs.data_output))
	in

	(* Run Program for a set number of iterations *)
	(* There are 4 states per instruction, so we multiply the number of iterations by 4 so that the iterations corresponds to the number of instructions to run *)
	for _ = 0 to 4*(Bits.to_int iterations)-1 do

		print_status ();

		(* Used to halt the program if there is an exit condition reached *)
		if (Bits.to_int !(outputs.opcode_bus_output) = 0) && (Bits.to_int !(outputs.pc_output) > 0)
			then failwith "Halted";

		(* Cycle the clock to increment time, this increments the state machine by 1 *)
		Cyclesim.cycle sim

	done;

	(* Match test result *)
	[%expect {|
   State:START | PC:0000 | Opcode:0000 | Operand:0000 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S1    | PC:0000 | Opcode:3101 | Operand:000a | Data bus:0001 | Out (hex):0000 | Out (int):0
   State:S2    | PC:0000 | Opcode:3101 | Operand:000a | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S3    | PC:0000 | Opcode:3101 | Operand:000a | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:START | PC:0001 | Opcode:3101 | Operand:000a | Data bus:0001 | Out (hex):0000 | Out (int):0
   State:S1    | PC:0001 | Opcode:3102 | Operand:000b | Data bus:0001 | Out (hex):0000 | Out (int):0
   State:S2    | PC:0001 | Opcode:3102 | Operand:000b | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S3    | PC:0001 | Opcode:3102 | Operand:000b | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:START | PC:0002 | Opcode:3102 | Operand:000b | Data bus:0002 | Out (hex):0000 | Out (int):0
   State:S1    | PC:0002 | Opcode:9201 | Operand:0001 | Data bus:0001 | Out (hex):0000 | Out (int):0
   State:S2    | PC:0002 | Opcode:9201 | Operand:0001 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S3    | PC:0002 | Opcode:9201 | Operand:0001 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:START | PC:0003 | Opcode:9201 | Operand:0001 | Data bus:0003 | Out (hex):0000 | Out (int):0
   State:S1    | PC:0003 | Opcode:9202 | Operand:0002 | Data bus:0001 | Out (hex):0000 | Out (int):0
   State:S2    | PC:0003 | Opcode:9202 | Operand:0002 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S3    | PC:0003 | Opcode:9202 | Operand:0002 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:START | PC:0004 | Opcode:9202 | Operand:0002 | Data bus:0004 | Out (hex):0000 | Out (int):0
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0000 | Out (int):0
   State:START | PC:0005 | Opcode:1001 | Operand:0102 | Data bus:0005 | Out (hex):0000 | Out (int):0
   State:S1    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0002 | Out (hex):0000 | Out (int):0
   State:S2    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0002 | Out (int):2
   State:S3    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0002 | Out (int):2
   State:START | PC:0006 | Opcode:2201 | Operand:0000 | Data bus:0006 | Out (hex):0002 | Out (int):2
   State:S1    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0002 | Out (int):2
   State:S2    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0002 | Out (int):2
   State:S3    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0002 | Out (int):2
   State:START | PC:0007 | Opcode:1002 | Operand:0102 | Data bus:0007 | Out (hex):0002 | Out (int):2
   State:S1    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0003 | Out (hex):0002 | Out (int):2
   State:S2    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:S3    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:START | PC:0008 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0003 | Out (int):3
   State:S1    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:S2    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:S3    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:START | PC:0004 | Opcode:f000 | Operand:0004 | Data bus:0004 | Out (hex):0003 | Out (int):3
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0003 | Out (int):3
   State:START | PC:0005 | Opcode:1001 | Operand:0102 | Data bus:0005 | Out (hex):0003 | Out (int):3
   State:S1    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0005 | Out (hex):0003 | Out (int):3
   State:S2    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0005 | Out (int):5
   State:S3    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0005 | Out (int):5
   State:START | PC:0006 | Opcode:2201 | Operand:0000 | Data bus:0006 | Out (hex):0005 | Out (int):5
   State:S1    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0005 | Out (int):5
   State:S2    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0005 | Out (int):5
   State:S3    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0005 | Out (int):5
   State:START | PC:0007 | Opcode:1002 | Operand:0102 | Data bus:0007 | Out (hex):0005 | Out (int):5
   State:S1    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0005 | Out (int):5
   State:S2    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:S3    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:START | PC:0008 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0008 | Out (int):8
   State:S1    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:S2    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:S3    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:START | PC:0004 | Opcode:f000 | Operand:0004 | Data bus:0004 | Out (hex):0008 | Out (int):8
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0008 | Out (int):8
   State:START | PC:0005 | Opcode:1001 | Operand:0102 | Data bus:0005 | Out (hex):0008 | Out (int):8
   State:S1    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:000d | Out (hex):0008 | Out (int):8
   State:S2    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):000d | Out (int):13
   State:S3    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):000d | Out (int):13
   State:START | PC:0006 | Opcode:2201 | Operand:0000 | Data bus:0006 | Out (hex):000d | Out (int):13
   State:S1    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):000d | Out (int):13
   State:S2    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):000d | Out (int):13
   State:S3    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):000d | Out (int):13
   State:START | PC:0007 | Opcode:1002 | Operand:0102 | Data bus:0007 | Out (hex):000d | Out (int):13
   State:S1    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0015 | Out (hex):000d | Out (int):13
   State:S2    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:S3    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:START | PC:0008 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0015 | Out (int):21
   State:S1    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:S2    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:S3    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:START | PC:0004 | Opcode:f000 | Operand:0004 | Data bus:0004 | Out (hex):0015 | Out (int):21
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0015 | Out (int):21
   State:START | PC:0005 | Opcode:1001 | Operand:0102 | Data bus:0005 | Out (hex):0015 | Out (int):21
   State:S1    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0022 | Out (hex):0015 | Out (int):21
   State:S2    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0022 | Out (int):34
   State:S3    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0022 | Out (int):34
   State:START | PC:0006 | Opcode:2201 | Operand:0000 | Data bus:0006 | Out (hex):0022 | Out (int):34
   State:S1    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0022 | Out (int):34
   State:S2    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0022 | Out (int):34
   State:S3    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0022 | Out (int):34
   State:START | PC:0007 | Opcode:1002 | Operand:0102 | Data bus:0007 | Out (hex):0022 | Out (int):34
   State:S1    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0037 | Out (hex):0022 | Out (int):34
   State:S2    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:S3    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:START | PC:0008 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0037 | Out (int):55
   State:S1    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:S2    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:S3    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:START | PC:0004 | Opcode:f000 | Operand:0004 | Data bus:0004 | Out (hex):0037 | Out (int):55
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0037 | Out (int):55
   State:START | PC:0005 | Opcode:1001 | Operand:0102 | Data bus:0005 | Out (hex):0037 | Out (int):55
   State:S1    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0059 | Out (hex):0037 | Out (int):55
   State:S2    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0059 | Out (int):89
   State:S3    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):0059 | Out (int):89
   State:START | PC:0006 | Opcode:2201 | Operand:0000 | Data bus:0006 | Out (hex):0059 | Out (int):89
   State:S1    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0059 | Out (int):89
   State:S2    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0059 | Out (int):89
   State:S3    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):0059 | Out (int):89
   State:START | PC:0007 | Opcode:1002 | Operand:0102 | Data bus:0007 | Out (hex):0059 | Out (int):89
   State:S1    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0090 | Out (hex):0059 | Out (int):89
   State:S2    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:S3    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:START | PC:0008 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0090 | Out (int):144
   State:S1    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:S2    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:S3    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:START | PC:0004 | Opcode:f000 | Operand:0004 | Data bus:0004 | Out (hex):0090 | Out (int):144
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0090 | Out (int):144
   State:START | PC:0005 | Opcode:1001 | Operand:0102 | Data bus:0005 | Out (hex):0090 | Out (int):144
   State:S1    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:00e9 | Out (hex):0090 | Out (int):144
   State:S2    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):00e9 | Out (int):233
   State:S3    | PC:0005 | Opcode:2201 | Operand:0000 | Data bus:0000 | Out (hex):00e9 | Out (int):233
   State:START | PC:0006 | Opcode:2201 | Operand:0000 | Data bus:0006 | Out (hex):00e9 | Out (int):233
   State:S1    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):00e9 | Out (int):233
   State:S2    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):00e9 | Out (int):233
   State:S3    | PC:0006 | Opcode:1002 | Operand:0102 | Data bus:0000 | Out (hex):00e9 | Out (int):233
   State:START | PC:0007 | Opcode:1002 | Operand:0102 | Data bus:0007 | Out (hex):00e9 | Out (int):233
   State:S1    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0179 | Out (hex):00e9 | Out (int):233
   State:S2    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:S3    | PC:0007 | Opcode:2202 | Operand:0000 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:START | PC:0008 | Opcode:2202 | Operand:0000 | Data bus:0008 | Out (hex):0179 | Out (int):377
   State:S1    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:S2    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:S3    | PC:0008 | Opcode:f000 | Operand:0004 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:START | PC:0004 | Opcode:f000 | Operand:0004 | Data bus:0004 | Out (hex):0179 | Out (int):377
   State:S1    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:S2    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0179 | Out (int):377
   State:S3    | PC:0004 | Opcode:1001 | Operand:0102 | Data bus:0000 | Out (hex):0179 | Out (int):377
   |}]
	