(* another unit's inline records: built, matched, a field written *)

let run (i : Insn.t) =
  (match i with Insn.Branch b -> b.taken <- b.target > 16 | _ -> ());
  match i with
  | Insn.Mov { rd; _ } | Insn.Add { rd; _ } -> rd
  | Insn.Branch { target; _ } -> target
  | Insn.Nop -> -1

let () =
  List.iter (fun w ->
    let i = Insn.decode w in
    let r = run i in
    print_string (Insn.show i ^ " -> " ^ string_of_int r); print_newline ())
    [ 0x1234; 0x2567; 0x3010; 0x3020; 0 ];
  print_string (Insn.show (Insn.Add { rm = 3; rn = 2; rd = 1 })); print_newline ()
