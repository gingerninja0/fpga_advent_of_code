open Hardcaml
open Signal

module I = struct
	type 'a t = {
    clk                 : 'a;
    reset               : 'a;
    addr                : 'a; [@bits 16]
    rom_enable          : 'a;
    rom_read_data_enable: 'a;
    ram_rom_addr_link   : 'a; [@bits 16]
    (* The write port is only to load the program *)
    write_enable        : 'a;
    write_addr          : 'a; [@bits 16]
    write_data          : 'a; [@bits 32]
	} [@@deriving sexp_of, hardcaml]
end

module O = struct
	type 'a t = {
    read_opcode : 'a; [@bits 16]
    read_operand: 'a; [@bits 16]
    read_data   : 'a; [@bits 16]
	} [@@deriving sexp_of, hardcaml]
end

let create (i : Signal.t I.t) = 

    let rom_op_val = of_int ~width:4 0x3 in

    let rom_data_read_op_val = of_int ~width:4 0x1 in
    let rom_data_read_addr_op_val = of_int ~width:4 0x2 in

    (* This reading of a ROM address given from a read at a different ROM address is not realistic as (for now) I assume that this can occur in one clock cylce. I may if I have time remove this by using a register to store the read_opcode and read_operand so that on the next clock cycle the other address can be read. *)
    let read_opcode_wire = wire 16 in
    let read_operand_wire = wire 16 in
    let data_addr = mux2 (read_opcode_wire.:[11, 8] ==: rom_data_read_addr_op_val) i.ram_rom_addr_link read_operand_wire in

    (* ROM definition *)
    (* Write port required to load the program initially, not used after this *)
     let write_port = { Write_port.
        write_clock = i.clk;
        write_address = i.write_addr;
        write_enable = i.write_enable;
        write_data = i.write_data;
    } in
    (* ROM has two read ports to support the ROM[RAM:X] -> RAM:Y operation *)
    let read_outputs = multiport_memory 65536
        ~name:"rom" 
        ~write_ports:[| write_port |] 
        ~read_addresses:[| i.addr; data_addr |]
    in
    let rom_read_1 = read_outputs.(0) in
    let rom_read_2 = read_outputs.(1) in

    (* ROM reads and loop closure back to the above mux2 *)
    let read_opcode = mux2 i.rom_enable (rom_read_1.:[31, 16]) (zero 16) in
    let read_operand = mux2 i.rom_enable (rom_read_1.:[15, 0]) (zero 16) in

    read_opcode_wire <== read_opcode;
    read_operand_wire <== read_operand;

    (* Control logic *)
    let is_read_op = (read_opcode.:[15, 12] ==: rom_op_val) in
    let is_data_read = (read_opcode.:[11, 8] ==: rom_data_read_op_val) in
    let is_data_read_addr = (read_opcode.:[11, 8] ==: rom_data_read_addr_op_val) in

    let gated_read_data = mux2 (i.rom_read_data_enable &: is_read_op &: (is_data_read |: is_data_read_addr)) (rom_read_2.:[15, 0]) (zero 16) in
    
    { O.
        read_opcode = read_opcode;
        read_operand = read_operand;
        read_data = gated_read_data;    
    }


(* TEST LAND *)
(* ROM module tests below *)

let%expect_test "ROM Module Test" =

    let module Sim = Cyclesim.With_interface (I) (O) in
    let sim = Sim.create create in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    (* Helper to load the program into ROM *)
    let load_rom (addr : int) (data : string) =
        inputs.write_enable := Bits.of_int ~width:1 1;
        inputs.write_addr := Bits.of_int ~width:16 addr;
        inputs.write_data := Bits.of_hex ~width:32 data;
        Cyclesim.cycle sim;
        inputs.write_enable := Bits.of_int ~width:1 0
    in

    let run (addr : int) rom_enable rom_read_data_enable ram_rom_addr_link = 
        inputs.addr := Bits.of_int ~width:16 addr;
        inputs.ram_rom_addr_link := Bits.of_int ~width:16 ram_rom_addr_link;
        inputs.rom_enable := Bits.of_int ~width:1 rom_enable;
        inputs.rom_read_data_enable := Bits.of_int ~width:1 rom_read_data_enable;
        
        Cyclesim.cycle sim;

        Printf.printf "Addr:%04x | Opcode:%04x Operand:%04x Data:%04x\n"
            addr
            (Bits.to_int !(outputs.read_opcode))       
            (Bits.to_int !(outputs.read_operand))       
            (Bits.to_int !(outputs.read_data))       
    in

    (* Load ROM with some random data *)
    load_rom 0x0000 "12125656"; 
    load_rom 0x0005 "34347878"; 
    load_rom 0x0001 "12341234"; 
    load_rom 0x0010 "43214321"; 

    (* Load ROM with some real commands *)
    load_rom 0x0020 "32220021"; (* ROM:[RAM:22] -> RAM:21   Get the value at ROM address given by RAM:22 and store in RAM:21 *)
    load_rom 0x0041 "00000042"; (* Value ad ROM:0x41 that will be read (will read 42), the address is simulated to come from ram on the ram_rom_addr_link bus *)

    run 0x0000 1 1 0x0000;
    run 0x0001 1 1 0x0000;
    run 0x0005 1 1 0x0000;
    run 0x0010 1 1 0x0000;
    run 0x0002 1 1 0x0000;

    run 0x0020 1 1 0x0041; (* Will output 0x42 on the data output (assumed 0x41 is address that was stored in RAM:22, and 0x42 would get stored in RAM:21) *)
 
    [%expect {|
      Addr:0000 | Opcode:1212 Operand:5656 Data:0000
      Addr:0001 | Opcode:1234 Operand:1234 Data:0000
      Addr:0005 | Opcode:3434 Operand:7878 Data:0000
      Addr:0010 | Opcode:4321 Operand:4321 Data:0000
      Addr:0002 | Opcode:0000 Operand:0000 Data:0000
      Addr:0020 | Opcode:3222 Operand:0021 Data:0042
      |}]