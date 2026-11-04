(* 56934c32: a let is an order; the quiet cases *)
let rec concat_map (f : 'a -> 'b list) (l : 'a list) : 'b list =
  match l with
  | [] -> []
  | a :: l -> let r = f a in r @ concat_map f l

let frame : string ref = ref ""

let instr (s : string) : string list =
  if s = "TEXT" then (frame := s; [ s ]) else [ !frame ^ s ]

let pure (s : string) : int = String.length s

let () =
  List.iter print_string (concat_map instr [ "TEXT"; "RET" ]);
  (* (pure operands; && an order; a function not run where written) *)
  let n = pure "a" + pure "b" in
  if instr "x" <> [] && instr "y" <> [] then print_int n;
  List.iter (fun (s : string) -> print_string s) (instr "z")
