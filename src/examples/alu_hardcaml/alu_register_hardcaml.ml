open Hardcaml
open Signal

module I = struct
  type 'a t = {
    clk     		: 'a;
    reset   		: 'a;
    opcode  		: 'a; [@bits 16]
    operand 		: 'a; [@bits 16]
	reg_write_data	: 'a; [@bits 16]
	read_enable		: 'a; 
	write_enable	: 'a;
  } [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    reg_read_data : 'a; [@bits 16]
    flags         : 'a; [@bits 4]
  } [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) = 

	let alu_op_val = 0x1 in

	let alu_result = wire 16 in (* Required so the register "final_write_data" is not a circular dependency (assigned after register is defined, but must be declared here for register instantiation) *)

	(* [addr_3] = [addr_2] [.] [addr_1] *)
	let addr_1 = i.operand.:[3, 0] in
	let addr_2 = i.operand.:[11, 8] in
	let addr_3 = i.opcode.:[3, 0] in

	(* Logic to select what data gets written to the register If the opcode indicates an ALU operation, we write the ALU result. Otherwise, we write the external reg_write_data. *)
	let is_alu_op = (select i.opcode 15 12) ==: (of_int ~width:4 alu_op_val) in 
	let final_write_data = mux2 is_alu_op alu_result i.reg_write_data in

	let register = Dual_read_register_hardcaml.create {
		clk				= i.clk;
		reset			= i.reset;
		opcode			= i.opcode;
		addr_1			= addr_1;
		addr_2			= addr_2;
		addr_3			= addr_3;
		write_data		= final_write_data;
		write_enable	= i.write_enable;
	} in

	let alu = Alu_hardcaml.create {
		clk		= i.clk;
		reset	= i.reset;
		opcode	= i.opcode;
		a		= register.read_data_1;
		b		= register.read_data_2;
	} in

	alu_result <== alu.c; (* Assign the alu result to the variable defined previously which avoids the circular dependency *)

	(* Used to output the result to the data bus when triggered by read_enable *)
	let gated_reg_read_data = mux2 i.read_enable register.read_data_reg (zero 16) in

	{ O.
		reg_read_data   = gated_reg_read_data;
		flags   		= alu.flags;
	}
	

(* TEST LAND *)
(* ALU and Dual Read Register combined module tests below *)

let%expect_test "ALU&Register Operations Test" =

	let module Sim = Cyclesim.With_interface (I) (O) in
	let sim = Sim.create create in
	let inputs = Cyclesim.inputs sim in
	let outputs = Cyclesim.outputs sim in

	let run opcode operand data read_en write_en =
		inputs.opcode := Bits.of_int ~width:16 opcode;
		inputs.operand := Bits.of_int ~width:16 operand;
		inputs.reg_write_data := Bits.of_int ~width:16 data;
		inputs.read_enable := Bits.of_int ~width:1 read_en;
		inputs.write_enable := Bits.of_int ~width:1 write_en;

		Cyclesim.cycle sim;

		Printf.printf "Op:%04x | Data Out:%d | Flags:%s\n" 
			opcode
			(Bits.to_sint !(outputs.reg_read_data))
			(Bits.to_string !(outputs.flags))
		in

	(* Initial reset to ensure alu is in the initial state (forces flags to be 0001 as initial state) *)
	inputs.reset := Bits.vdd;
	Cyclesim.cycle sim;
	inputs.reset := Bits.gnd;

	(* Write 10 into REG:1 and display this to check write successful *)
	run 0x9201 0x0000 10 0 1;
	run 0x2201 0x0000 0 1 0;

	(* Write 20 into REG:2 and display this to check write successful *)
	run 0x9202 0x0000 20 0 1;
	run 0x2202 0x0000 0 1 0;

	(* ADD: REG:3 = REG:2 + REG:1 (30 = 20 + 10) and display this to check calculation successful *)
	run 0x1003 0x0201 0 0 1;
	run 0x2203 0x0000 0 1 0;

	(* SUB: REG:3 = REG:2 - REG:1 (30 = 20 + 10) and display this to check calculation successful *)
	run 0x1103 0x0102 0 0 1;
	run 0x2203 0x0000 0 1 0;

	(* Check that flags reset to zero when zero result (REG:4 = REG:4 + REG:4 (0 = 0 + 0)) *)
	run 0x1004 0x0404 0 0 1;

	(* SUB: REG:3 = REG:1 - REG:2 (-10 = 10 - 20) and display this to check calculation successful *)
	run 0x1103 0x0201 0 0 1;
	run 0x2203 0x0000 0 1 0;

	[%expect {|
   Op:9201 | Data Out:0 | Flags:0001
   Op:2201 | Data Out:10 | Flags:0001
   Op:9202 | Data Out:0 | Flags:0001
   Op:2202 | Data Out:20 | Flags:0001
   Op:1003 | Data Out:0 | Flags:0000
   Op:2203 | Data Out:30 | Flags:0000
   Op:1103 | Data Out:0 | Flags:0000
   Op:2203 | Data Out:10 | Flags:0000
   Op:1004 | Data Out:0 | Flags:0001
   Op:1103 | Data Out:0 | Flags:1110
   Op:2203 | Data Out:-10 | Flags:1110
   |}]
		