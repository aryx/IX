(* mini-analyze -dead on [@@deriving show]: the printers the deriver
 * makes (show_mode, pp_mode, show_cmd, pp_cmd) are not the author's, and
 * the show_cmd written before the types, for a compiler without
 * deriving, is shadowed by the derived one: none is said dead. What is,
 * is said at its line in this file, not in the rewritten text *)
let show_cmd _ = "NO DERIVING"
[@@warning "-32"]

type mode = Read | Write
and cmd = Run of string * mode
[@@deriving show]

let unused x = x + 1

let () = print_string (show_cmd (Run ("ls", Read)))
