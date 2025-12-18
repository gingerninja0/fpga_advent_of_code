open Hardcaml
open Signal

(* --- 1. Define the Hardware --- *)

module I = struct
  type 'a t = {
    clock : 'a;
    clear : 'a;
    enable : 'a;
  } [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    (* FIX: Added [@bits 8] so Hardcaml expects an 8-bit signal *)
    count : 'a[@bits 8];
  } [@@deriving sexp_of, hardcaml]
end

(* Circuit definition *)
let create (i : Signal.t I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  
  let count = 
    reg_fb spec ~enable:i.enable ~width:8 ~f:(fun d -> 
      d +:. 1
    ) 
  in
  
  { O.count }

(* --- 2. Simulation Demo --- *)

let simulate () =
  Printf.printf "--- Starting Simulation ---\n";
  
  let module Sim = Cyclesim.With_interface(I)(O) in
  let sim = Sim.create create in
  
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  let print_state step =
    let count_val = Bits.to_int !(outputs.count) in
    Printf.printf "Step %d: Count = %d\n" step count_val
  in

  Cyclesim.reset sim;
  
  inputs.enable := Bits.vdd;
  
  for i = 1 to 5 do
    Cyclesim.cycle sim;
    print_state i
  done;
  Printf.printf "--- Simulation Complete ---\n\n"

(* --- 3. Verilog Generation Demo --- *)

let generate_verilog () =
  Printf.printf "--- Generating Verilog ---\n";
  
  let module Circuit = Circuit.With_interface(I)(O) in
  let circuit = Circuit.create_exn ~name:"my_counter" create in
  
  Rtl.print Verilog circuit

(* --- Main Entry Point --- *)
let () =
  simulate ();
  generate_verilog ()