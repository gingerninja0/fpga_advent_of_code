open Hardcaml
open Signal

module I = struct
	type 'a t = {
    clk         : 'a;
    reset       : 'a;
    pc_enable   : 'a;
    opcode      : 'a; [@bits 16]
    operand     : 'a; [@bits 16]
    data        : 'a; [@bits 16]
    flags       : 'a; [@bits 4] (* O|N|C|Z *)
    read_enable : 'a;
	} [@@deriving sexp_of, hardcaml]
end

module O = struct
	type 'a t = {
    pc : 'a; [@bits 16]
	} [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) = 

    let pc_ram_op_val = 0x7 in
    let pc_rom_op_val = 0xF in

    let pc_op_select = i.opcode.:[15, 12] in
    let pc_op_operation = i.opcode.:[11, 8] in

    (* Break out the flags for clarity *)
    let z = i.flags.:(0) in
    let c = i.flags.:(1) in
    let n = i.flags.:(2) in
    let o = i.flags.:(3) in

    (* Writing to RAM from ROM (RAM Address in opcode) *)
    let is_ram_op = pc_op_select ==:. pc_ram_op_val in
    let jump_target_data = mux2 is_ram_op i.data i.operand in

    (* Jump if instruction is a jump from RAM OR a jump from ROM *)
    let is_jump_instruction = is_ram_op |: (pc_op_select ==:. pc_rom_op_val) in

    (* Equivalent to the case in verilog, used to select the type of jump and returns if that jump is valid (if the flag from the ALU indicates the jump should occur) *)
    let jump_condition_mux = mux pc_op_operation [
        vdd;           (* 0: JMP  (Always) *)
        z;             (* 1: JMPZ *)
        c;             (* 2: JMPC *)
        n;             (* 3: JMPN *)
        o;             (* 4: JMPO *)
        ~: z;          (* 5: JMPNZ *)
        ~: c;          (* 6: JMPNC *)
        ~: n;          (* 7: JMPNN *)
    ] in

    let current_pc = wire 16 in
    let pc_plus_1 = current_pc +:. 1 in

    (* Equivalent to (from verilog): *)
    (* if (pc_enable) begin
                if ((pc_op_select == `PC_RAM_OP) || (pc_op_select == `PC_ROM_OP)) begin *)
    let next_pc = 
        mux2 is_jump_instruction 
            (mux2 jump_condition_mux jump_target_data pc_plus_1) 
            pc_plus_1 (* This is the default case from verilog, increment the program counter even if conditional jump fails (condition was false) *)
    in
    
    (* PC value register *)
    let spec = Reg_spec.create ~clock:i.clk () 
             |> Reg_spec.override ~clear:i.reset in
    let pc_reg = reg spec ~enable:i.pc_enable next_pc in

    (* Set the pc value to the value from the register *)
    current_pc <== pc_reg;

    let gated_pc_register = mux2 i.read_enable pc_reg (zero 16) in

    { O.
		pc = gated_pc_register;
	}


(* TEST LAND *)
(* Program Counter (PC) module tests below *)

let%expect_test "PC Test" =

    let module Sim = Cyclesim.With_interface (I) (O) in
    let sim = Sim.create create in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    let step pc_enable read_enable opcode operand data flags =
        inputs.pc_enable := Bits.of_int ~width:1  pc_enable;
        inputs.read_enable := Bits.of_int ~width:1  read_enable;
        inputs.opcode := Bits.of_int ~width:16 opcode;
        inputs.operand := Bits.of_int ~width:16 operand;
        inputs.data := Bits.of_int ~width:16 data;
        inputs.flags := Bits.of_int ~width:4  flags;

        Cyclesim.cycle sim;

        Printf.printf "Op:%04x | PC Out:%04x\n" 
            opcode (Bits.to_int !(outputs.pc))
        in

    (* Initial Reset to ensure state of the system is "clean"*)
    inputs.reset := Bits.vdd;
    Cyclesim.cycle sim;
    inputs.reset := Bits.gnd;

    (* Standard PC increments *)
    step 1 1 0x0000 0x0000 0x0000 0b0000;
    step 1 1 0x0000 0x0000 0x0000 0b0000;

    (* ROM jumps reading from operand *)

    (* Unconditional jump to 0x20 *)
    step 1 1 0xF000 0x0020 0x0000 0b0000;
    
    (* Jump zero to 0x40 (zero flag true) *)
    step 1 1 0xF100 0x0040 0x0000 0b0001;
    
    (* Jump zero to 0x50 (zero flag false), should increment to 0x41*)
    step 1 1 0xF100 0x0050 0x0000 0b0000;

    (* RAM jumps reading from data bus *)    

    (* Unconditional jump to 0x100 *)
    step 1 1 0x7000 0x0000 0x0100 0b0000;

    (* Jump zero to 0x40 (zero flag true) *)
    step 1 1 0x7100 0x0000 0x0040 0b0001;

    (* Read disabled, pc returned as zero *)
    step 1 0 0x0000 0x0000 0x0000 0b0000;

    (* Read enabled, should read 0x42 *)
    step 1 1 0x0000 0x0000 0x0000 0b0000;

    [%expect {|
      Op:0000 | PC Out:0001 
      Op:0000 | PC Out:0002
      Op:f000 | PC Out:0020
      Op:f100 | PC Out:0040
      Op:f100 | PC Out:0041
      Op:7000 | PC Out:0100
      Op:7100 | PC Out:0040
      Op:0000 | PC Out:0000
      Op:0000 | PC Out:0042
      |}]