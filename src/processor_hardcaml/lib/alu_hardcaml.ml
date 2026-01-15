open Hardcaml
open Signal

module I = struct
	type 'a t = {
		clk    : 'a;			(* Used only to update flags register *)
		reset  : 'a;
		opcode : 'a; [@bits 16]
		a      : 'a; [@bits 16]
		b      : 'a; [@bits 16]
	} [@@deriving sexp_of, hardcaml]
end

module O = struct
	type 'a t = {
		c      : 'a; [@bits 16]
		flags  : 'a; [@bits 4]  (* O|N|C|Z *) (* Overflow|Negative|Carry|Zero *)
	} [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) =

	(* Split opcode to ALU module selection and ALU operation *)
	let alu_op_select = i.opcode.:[15, 12] in
	let alu_op_operation = i.opcode.:[11, 8] in

	(* 17 bit inputs for flag updating (for carry flag) *)
	let a17 = uresize i.a 17 in
	let b17 = uresize i.b 17 in

	(* multiplexer instead of case statements from verilog, a bit different. Also no tri-state buffers allowed *)
	(* Lower byte of opcode to determine the operation*)
	let operation_result = mux alu_op_operation [
		a17 +: b17; 					(* 0000 *)
		a17 -: b17; 					(* 0001 *)
		uresize (i.a &: i.b) 17; 		(* 0010 *)
		uresize (i.a |: i.b) 17; 		(* 0011 *)
		uresize (i.a ^: i.b) 17; 		(* 0100 *)
		uresize (~: (i.a)) 17; 			(* 0101 *)
		uresize (sll i.a 1) 17; 		(* 0110 *)
		uresize (srl i.a 1) 17; 		(* 0111 *)
		uresize (i.a *: i.b) 17;		(* 1000 *)
		zero 17;                        (* 1001: Default for all other opcodes *)
	] in

	(* Set 16 bit output value (c) *)
	let c_out = operation_result.:[15, 0] in

	(* Upper byte of opcode selects alu module *)
	let is_alu_op_flag = alu_op_select ==:. 0x0001 in

	(* Update flags *)
	let z = c_out ==:. 0 in                 (* Zero Flag *)
	let c = operation_result.:(16) in   	(* Carry Flag (bit 17) *)
	let n = c_out.:(15) in                  (* Negative Flag (MSB) *)

	(* Overflow, resulting sign bit does not match inputs (addition resulted in "negative", or subtraction resulted in "positive" due to overflow) *)
	let o = (msb i.a ==: msb i.b) &: (msb c_out <>: msb i.a) in (* Note equal: <>: *)

	(* Only update flags if it is an ALU operation, otherwise keep the flags as they were. Do this using a register to hold the current state of the flags and update when the is_alu_op_flag is active. On reset the ALU result will be zero, reset flags to 0001 to reflect this *)
	let spec = 
      Reg_spec.create ~clock:i.clk ()
      |> Reg_spec.override ~clear:i.reset ~clear_to:(of_int ~width:4 1)
    in

    let current_flags = reg spec ~enable:is_alu_op_flag (o @: n @: c @: z) in

	(* Set outputs *)
	{ O.c = c_out; O.flags = current_flags }


(* TEST LAND *)
(* ALU module tests below *)

let%expect_test "ALU Operations Test" =

	let module Sim = Cyclesim.With_interface (I) (O) in
	let sim = Sim.create create in
	let inputs = Cyclesim.inputs sim in
	let outputs = Cyclesim.outputs sim in

	let run a b op =
		inputs.a := Bits.of_int ~width:16 a;
		inputs.b := Bits.of_int ~width:16 b;
		inputs.opcode := Bits.of_int ~width:16 op;
		Cyclesim.cycle sim;

		Printf.printf "A:%d B:%d | C (unsigned):%d | C (signed):%d | Flags:%s\n" 
			a 
			b 
			(Bits.to_int !(outputs.c))       
			(Bits.to_sint !(outputs.c)) 
			(Bits.to_string !(outputs.flags))
	in

	(* Test cases *)

	(*Flags: [O|N|C|Z]*) (*Overflow|Negative|Carry|Zero*)
	run 10 (-20) 0x1000; (*Add 10 + (-20) = -10 (flags: 0100) *)
	run 5 5 0x1100;		 (*Sub 5 - 5 = 0 (flags: 0001) *)
	run (-5) 5 0x1100;   (*Sub (-5) - 5 = -10 (flags: 0100)*)
	run 65535 1 0x1000;  (*Add 65535 + 1 = 0 (flags: 0011)*)
	run 32767 1 0x1000;  (*Add 32767 + 1 = 32768 (flags: 1100)*)

	[%expect {|
   A:10 B:-20 | C (unsigned):65526 | C (signed):-10 | Flags:0100
   A:5 B:5 | C (unsigned):0 | C (signed):0 | Flags:0001
   A:-5 B:5 | C (unsigned):65526 | C (signed):-10 | Flags:0100
   A:65535 B:1 | C (unsigned):0 | C (signed):0 | Flags:0011
   A:32767 B:1 | C (unsigned):32768 | C (signed):-32768 | Flags:1100
   |}]