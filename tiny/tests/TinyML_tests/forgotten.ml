(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* What tiny-ml reads and forgets (TinyML_test.sh, its last check): ix's
 * capabilities, an object's type in an annotation or declared under a
 * name, and a coercion to one; and a type's second name. The code is
 * forgotten.ml's twin's, plain.ml, to the byte, for both machines.
 * Not OCaml's to build: its Cap is not here. *)
type caps = < Cap.fork; Cap.exec; Cap.stdout; .. >
type shape = Dot | Line of points
and points = (int * int) list
let rec count (ps : points) = match ps with [] -> 0 | _ :: l -> 1 + count l
let size (s : shape) = match s with Dot -> 1 | Line ps -> count ps
let twice (caps : caps) (n : int) = n + n
let run (caps : < Cap.stdout; .. >) n = print_int (twice (caps :> caps) n)
let () = run () (size (Line [ 1, 2; 3, 4 ]) + size Dot)
