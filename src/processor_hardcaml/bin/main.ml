open Hardcaml

(* Run using: 

dune build bin/main.exe && dune exec bin/main.exe

*)

(* The simulated processor itself *)
module Processor = Processor_hardcaml_lib.Processor_hardcaml

(* Where the programs and associated input data is stored *)
module Programs = Processor_hardcaml_lib.Programs
module Data = Processor_hardcaml_lib.Data

let run_program program_name program data iterations = 

	let module Sim = Cyclesim.With_interface (Processor.I) (Processor.O) in

	(* So we know what program is being run... *)
	Printf.printf "Running: %s\n" program_name;

	let sim = Sim.create Processor.create in
	let inputs = Cyclesim.inputs sim in
	let outputs = Cyclesim.outputs sim in

	(* Better way to load the program*)
	(* Hold reset HIGH when loading program so the state machine does not cycle *)
	inputs.reset := Bits.vdd;
	
	(* Load the program into ROM *)
	Array.iter (fun (instr : Programs.instruction) ->
		inputs.rom_write_enable := Bits.vdd;
		inputs.rom_write_addr := Bits.of_int ~width:16 instr.addr;
		inputs.rom_write_data := Bits.of_int ~width:32 instr.data;
		Cyclesim.cycle sim;
		inputs.rom_write_enable := Bits.gnd;
	) program;

	(* Load any data associated with the program, stored separately to the program for clarity, as in verilog *)
	Array.iter (fun (data : Data.data) ->
		inputs.rom_write_enable := Bits.vdd;
		inputs.rom_write_addr := Bits.of_int ~width:16 data.addr;
		inputs.rom_write_data := Bits.of_int ~width:32 data.data;
		Cyclesim.cycle sim;
		inputs.rom_write_enable := Bits.gnd;
	) data;
	
	(* After program has been loaded, release the reset to make the processor ready to run *)
	inputs.reset := Bits.gnd;

	(* If the program is to run for many iterations (such as the Advent of Code solutions), we want to have a high limit on the iterations, so it gets set to the max_int value. Otherwise the iterations value is used to count the number of instructions to execute (multiplied by 4 to get the number of cycles of the state machine to execute) *)
	let iterations = if iterations = -1 then Int.max_int else 4 * iterations in

	try
		for _ = 0 to iterations-1 do
			Cyclesim.cycle sim;

			if (Bits.to_int !(outputs.data_out_en) = 1) then
				Printf.printf "Output: Hex:0x%04x | Decimal:%d\n" 
				(Bits.to_int !(outputs.data_output)) 
				(Bits.to_int !(outputs.data_output));

			(* Halt operation (0x0000_0000), exit program *)
			if (Bits.to_int !(outputs.opcode_bus_output) = 0) && (Bits.to_int !(outputs.current_state_output) = 0) then begin
				Printf.printf "Halt command reached, exiting\n";
				raise Exit
		end
		done;
		Printf.printf "Max iterations reached: %d, exiting\n" iterations;
	with Exit -> ()


let () =
	(* run_program "Fibonacci" Programs.fibonacci Data.none (35); *)
	run_program "Day 1 Part 1" Programs.day_1_part_1 Data.day_1_data (-1)