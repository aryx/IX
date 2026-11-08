(* Attributes, OCaml's [@@...] after an item, read and dropped by
 * tiny-ml: show is the file's own, "NO DERIVING", where mini-ml derives
 * one from [@@deriving show] (a type t's is show, another's show_x);
 * what it says is not printed, so that every compiler prints the same *)
let show _ = "NO DERIVING"
[@@warning "-32"]

type t = A | B of int
[@@deriving show]

let f x = x + 1 [@@inline]

let () =
  ignore (show (B (f 1)));
  ignore (show A);
  print_string "ok\n"
