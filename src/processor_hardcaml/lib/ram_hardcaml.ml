open Hardcaml
open Signal

module I = struct
	type 'a t = {
    clk         : 'a;
    reset       : 'a;
    opcode      : 'a; [@bits 16]
    operand     : 'a; [@bits 16]
    write_data  : 'a; [@bits 16]
    read_enable : 'a;
    write_enable: 'a;
	} [@@deriving sexp_of, hardcaml]
end

module O = struct
	type 'a t = {
    read_data         : 'a; [@bits 16]
    ram_rom_addr_link : 'a; [@bits 16]
	} [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) =

    let ram_op_val = of_int ~width:4 0x4 in
    let rom_op_val = of_int ~width:4 0x3 in
    let reg_op_val = of_int ~width:4 0x9 in
    let pc_op_val = of_int ~width:4 0x7 in

    let ram_write_op_val = of_int ~width:4 0x1 in
    let ram_read_op_val = of_int ~width:4 0x2 in

    (* Break out opcode for clarity *)
    let ram_op_select = (select i.opcode 15 12) in
    let ram_op_operation = (select i.opcode 11 8) in

    (* Implements this logic from verilog *)
    (* if ({ram_op_select, ram_op_operation} == {`ROM_OP, RAM_WRITE}) begin
        addr = opcode[7:0];
    end else if ({ram_op_select, ram_op_operation} == {`ROM_OP, RAM_READ}) begin
        addr = opcode[7:0];    // RAM Location to read the ROM Address from
        addr_2 = operand[7:0]; // RAM Location to store the read value from ROM
    end else begin
        addr = operand[7:0];
    end *)
    let is_ram_write_op = (ram_op_select @: ram_op_operation) ==: (rom_op_val @: ram_write_op_val) in
    let is_ram_read_op = (ram_op_select @: ram_op_operation) ==: (rom_op_val @: ram_read_op_val) in

    let addr = mux2 (is_ram_read_op |: is_ram_write_op) (select i.opcode 7 0) (select i.operand 7 0) in
    let addr_2 = mux2 (is_ram_read_op) (select i.operand 7 0) (zero 8) in

    (* Final mux's to select what the data source and write address is *)
    let data_to_write = mux2 ((ram_op_select @: ram_op_operation) ==: (ram_op_val @: ram_write_op_val)) i.operand i.write_data in
    let write_address = mux2 ((ram_op_select @: ram_op_operation) ==: (rom_op_val @: ram_read_op_val)) addr_2 addr in

    let is_valid_write_op = 
        ((ram_op_select @: ram_op_operation) ==: (ram_op_val @: ram_write_op_val)) |:
        ((ram_op_select @: ram_op_operation) ==: (rom_op_val @: ram_write_op_val)) |:
        ((ram_op_select @: ram_op_operation) ==: (rom_op_val @: ram_read_op_val))  |:
        ((ram_op_select @: ram_op_operation) ==: (reg_op_val @: ram_write_op_val))
    in

    (* the RAM itself, 256 addresses *)
    let memory_outputs =
		multiport_memory 256
		~write_ports:[|
			{ write_clock   = i.clk
			; write_address = write_address
			; write_enable  = i.write_enable &: is_valid_write_op
			; write_data    = data_to_write
			}
		|]
		~read_addresses:[| 
			addr; 
		|]
	in

    (* Read data onto both the RAM output data lines, implements the verilog: *)
    (* assign read_data = (read_enable && (opcode[15:8] == {`RAM_OP, RAM_READ})) ? ram_array[addr] : 16'bz; // RAM -> Output
    assign read_data = (read_enable && (opcode[15:8] == {`REG_OP, RAM_READ})) ? ram_array[addr] : 16'bz; // RAM -> REG
    assign ram_rom_addr_link = (read_enable && (opcode[15:8] == {`ROM_OP, RAM_READ})) ? ram_array[addr] : 16'bz; // ROM[RAM_1] -> RAM_2 (Read ROM from address stored in RAM)
    assign read_data = (read_enable && (opcode[15:12] == `PC_OP)) ? ram_array[addr] : 16'bz; // RAM -> PC *)
    let gated_read_data = mux2 (i.read_enable &: (
        ((ram_op_select @: ram_op_operation) ==: (ram_op_val @: ram_read_op_val)) |:
        ((ram_op_select @: ram_op_operation) ==: (reg_op_val @: ram_read_op_val)) |:
        (ram_op_select ==: pc_op_val)
    )) memory_outputs.(0) (zero 16) in

    let gated_ram_rom_addr_link = mux2 (i.read_enable &: ((ram_op_select @: ram_op_operation) ==: (rom_op_val @: ram_read_op_val)))  memory_outputs.(0) (zero 16) in

    { O.
        read_data = gated_read_data;
        ram_rom_addr_link = gated_ram_rom_addr_link;
    }


(* TEST LAND *)
(* Register module tests below *)

let%expect_test "RAM Module Test" =

    let module Sim = Cyclesim.With_interface (I) (O) in
    let sim = Sim.create create in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    let run opcode operand data write_enable read_enable =
        inputs.opcode       := Bits.of_int ~width:16 opcode;
        inputs.operand      := Bits.of_int ~width:16 operand;
        inputs.write_data   := Bits.of_int ~width:16 data;
        inputs.write_enable := Bits.of_int ~width:1 write_enable;
        inputs.read_enable  := Bits.of_int ~width:1 read_enable;

        Cyclesim.cycle sim;

        Printf.printf "Opcode:%04x Operand:%04x Data:%04x | ReadData:%04x RomLink:%04x\n" 
            opcode 
            operand 
            data
            (Bits.to_int !(outputs.read_data))       
            (Bits.to_int !(outputs.ram_rom_addr_link))
    in

    (* Write 0x1234 into RAM:A (from ROM opcode, RAM addressin opcode) and read back *)
    run 0x310A 0x0000 0x1234 1 0;
    run 0x9200 0x000A 0x0000 0 1;

    (* Write 0xABCD into RAM:0 (from ROM opcode, RAM address in opcode) and read back *)
    run 0x3101 0x0000 0xABCD 1 0;
    run 0x9200 0x0001 0x0000 0 1;

    (* Write 0x4321 into RAM:2 (from REG opcode, RAM address in operand) and read back *)
    run 0x9100 0x0002 0x4321 1 0;
    run 0x9200 0x0002 0x0000 0 1;
    
    (* Try 0x42 read command *)
    run 0x4200 0x0002 0x0000 0 1;
    
    [%expect {|
      Opcode:310a Operand:0000 Data:1234 | ReadData:0000 RomLink:0000
      Opcode:9200 Operand:000a Data:0000 | ReadData:1234 RomLink:0000
      Opcode:3101 Operand:0000 Data:abcd | ReadData:0000 RomLink:0000
      Opcode:9200 Operand:0001 Data:0000 | ReadData:abcd RomLink:0000
      Opcode:9100 Operand:0002 Data:4321 | ReadData:0000 RomLink:0000
      Opcode:9200 Operand:0002 Data:0000 | ReadData:4321 RomLink:0000
      Opcode:4200 Operand:0002 Data:0000 | ReadData:4321 RomLink:0000
      |}]