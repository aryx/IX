(* 56934c32^, lib_core/List.ml: f a @ concat_map f l, its right side
 * first (OCaml's and mini-ml's order), where OCaml's own List binds f a
 * first; mini-ld's f kept a function's frame in a reference, each RETURN
 * took the next one's when built by mini-ml *)
let rec concat_map (f : 'a -> 'b list) (l : 'a list) : 'b list =
  match l with
  | [] -> []
  | a :: l -> f a @ concat_map f l

let frame : string ref = ref ""

let instr (s : string) : string list =
  if s = "TEXT" then (frame := s; [ s ]) else [ !frame ^ s ]

let () = List.iter print_string (concat_map instr [ "TEXT"; "RET" ])
