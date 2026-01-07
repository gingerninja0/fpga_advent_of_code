open Hardcaml
open Signal

module I = struct
	type 'a t = {
    clk                  : 'a;
    reset                : 'a;
    addr                 : 'a; [@bits 16]
    rom_enable           : 'a;
    rom_read_data_enable : 'a;
    ram_rom_addr_link    : 'a; [@bits 16]
	} [@@deriving sexp_of, hardcaml]
end

module O = struct
	type 'a t = {
    read_opcode : 'a; [@bits 16]
    read_operand: 'a; [@bits 16]
    read_data   : 'a; [@bits 16]
	} [@@deriving sexp_of, hardcaml]
end

