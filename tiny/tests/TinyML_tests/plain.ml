(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* forgotten.ml with nothing to forget: an annotation of any type where
 * it has a capability's, no coercion, a type under its one name. *)
type shape = Dot | Line of (int * int) list
let rec count (ps : (int * int) list) = match ps with [] -> 0 | _ :: l -> 1 + count l
let size (s : shape) = match s with Dot -> 1 | Line ps -> count ps
let twice (caps : 'a) (n : int) = n + n
let run (caps : 'b) n = print_int (twice caps n)
let () = run () (size (Line [ 1, 2; 3, 4 ]) + size Dot)
