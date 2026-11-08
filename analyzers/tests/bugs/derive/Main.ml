(* mini-analyze -bugs below a [@@deriving show]: a report says its line
 * in this file, not in the text mlpp rewrote (the printers put after
 * the type) *)
type t = A | B of int * string
[@@deriving show]

let frame : string ref = ref ""
let instr (s : string) : string list =
  if s = "T" then (frame := s; [ s ]) else [ !frame ^ s ]

(* both operands with an effect, on line 12 *)
let both () = instr "T" @ instr "x"

let () = List.iter print_string (both ()); print_string (show (B (1, "x")))
