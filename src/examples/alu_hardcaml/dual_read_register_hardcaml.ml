open Hardcaml
open Signal

module I = struct
	type 'a t = {
		clk       	: 'a;
		reset     	: 'a;
		opcode    	: 'a; [@bits 16]
		addr_1    	: 'a; [@bits 4]
		addr_2    	: 'a; [@bits 4]
		addr_3    	: 'a; [@bits 4]
		write_data	: 'a; [@bits 16]
		write_enable: 'a; 
	} [@@deriving sexp_of, hardcaml]
end

module O = struct
	type 'a t = {
		read_data_1		: 'a; [@bits 16]
		read_data_2		: 'a; [@bits 16]
		read_data_reg	: 'a; [@bits 16] (*This breaks the dual read declaration, I'll try and remove it later*)
	} [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) =

	let read_op_val = 0x22 in
	let read_ram_op_val = 0x92 in
	let write_ram_op_val = 0x91 in
	let alu_op_val = 0x1 in
	
	(* Write *)
	let is_alu_op = (select i.opcode 15 12) ==: (of_int ~width:4 alu_op_val) in (* Verilog: (op[15:12] == `ALU_OP) *)
	let is_ram_read_op = (select i.opcode 15 8) ==: (of_int ~width:8 read_ram_op_val) in (* Verilog: (op[15:8] == `READ_RAM_OP) *)
	(* OR conditions together so write is triggered for either operation *)
	let write_op = i.write_enable &: (is_alu_op |: is_ram_read_op) in

	(* Read *)
	let is_read_op = (select i.opcode 15 8) ==: (of_int ~width:8 read_op_val) in (* Verilog: (op[15:8] == 'READ_OP) *)
	let is_ram_write_op = (select i.opcode 15 8) ==: (of_int ~width:8 write_ram_op_val) in (* Verilog: (op[15:8] == 'WRITE_RAM_OP) *)
	(* OR conditions together so read is triggered for either operation *)
	let read_op = is_read_op |: is_ram_write_op in

	let memory_outputs =
		multiport_memory 16
		~write_ports:[|
			{ write_clock   = i.clk
			; write_address = i.addr_3   (* alu result to addr_3 *)
			; write_enable  = write_op         
			; write_data    = i.write_data (* Data from ALU result or RAM load *)
			}
		|]
		~read_addresses:[| 
			i.addr_1; 
			i.addr_2; 
			i.addr_3  (* May remove in future, used to perform a REG:X reading into RAM:YY *)
		|]
	in

	(* Reads depend on opcode, block data from register unless these flags are active *)
	let gated_read_1 = mux2 is_alu_op memory_outputs.(0) (zero 16) in
	let gated_read_2 = mux2 is_alu_op memory_outputs.(1) (zero 16) in
	let gated_read_reg = mux2 read_op memory_outputs.(2) (zero 16) in

	(* Set outputs (gated to depend on opcode) *)
	{ O.
		read_data_1   = gated_read_1;
		read_data_2   = gated_read_2;
		read_data_reg = gated_read_reg;
	}


(* TEST LAND *)
(* Register module tests below *)

let%expect_test "REG Test" =

	let module Sim = Cyclesim.With_interface (I) (O) in
	let sim = Sim.create create in
	let inputs = Cyclesim.inputs sim in
	let outputs = Cyclesim.outputs sim in

	let run opcode addr_1 addr_2 addr_3 data write_enable =
		inputs.opcode      := Bits.of_int ~width:16 opcode;
		inputs.addr_1      := Bits.of_int ~width:4  addr_1;
		inputs.addr_2      := Bits.of_int ~width:4  addr_2;
		inputs.addr_3      := Bits.of_int ~width:4  addr_3;
		inputs.write_data  := Bits.of_int ~width:16 data;
		inputs.write_enable:= Bits.of_bool  write_enable;

		inputs.clk := Bits.vdd;
		Cyclesim.cycle sim;
		inputs.clk := Bits.gnd;
		Cyclesim.cycle sim;

		Printf.printf "opcode:%04x addr_1:%d addr_2:%d addr_3:%d | REG:1:%d REG:2:%d R_Reg:%d\n" 
		opcode addr_1 addr_2 addr_3
		(Bits.to_int !(outputs.read_data_1))       
		(Bits.to_int !(outputs.read_data_2)) 
		(Bits.to_int !(outputs.read_data_reg))
	in

	(* Test cases *)
	(* The opcode is the full 16 bits even though in this module the addresses are assumed to have been split out in a higher level, therefore 0x00 must be appended to the opcode to make it 16 bits *)

	(* Write and then read 15 in REG:1*)
	run 0x9200 0 0 1 15 true; 
	run 0x2200 0 0 1 0 false; 

	(* Write 10 to REG:2 *)
	run 0x9200 0 0 2 10 true;

	(* Pretend we did an ALU operation (REG:1 + REG:2 = REG:3) *)
	run 0x1000 1 2 3 25 true; (* 10 + 15 = 25 *)
	run 0x2200 0 0 3 0 false;  (* Read REG:3 to see if the result (25) has been stored *)
	
	[%expect {|
   opcode:9200 addr_1:0 addr_2:0 addr_3:1 | REG:1:0 REG:2:0 R_Reg:0
   opcode:2200 addr_1:0 addr_2:0 addr_3:1 | REG:1:0 REG:2:0 R_Reg:15
   opcode:9200 addr_1:0 addr_2:0 addr_3:2 | REG:1:0 REG:2:0 R_Reg:0
   opcode:1000 addr_1:1 addr_2:2 addr_3:3 | REG:1:15 REG:2:10 R_Reg:0
   opcode:2200 addr_1:0 addr_2:0 addr_3:3 | REG:1:0 REG:2:0 R_Reg:25
   |}]