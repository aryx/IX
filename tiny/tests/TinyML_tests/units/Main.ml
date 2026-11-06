(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The other unit of TinyML_test.sh's separate compilation: Shapes's
 * names, its constructors (one as Shapes.Rect), its labels, its
 * exception and its int pair used; a closure of ten names (more than
 * tiny-machine's registers: made blank, then filled); Shapes.Ops's
 * operators, and one of Main's own *)

open Shapes
open Shapes.Ops

let () =
  List.iter (fun b ->
    print_string b.name; print_string " ";
    print_int (area (scaled 2 b.shape)); print_newline ()) boxes;
  print_string (largest boxes).name; print_newline ();
  (try ignore (largest []) with Empty m -> print_string m; print_newline ());
  print_int (area Dot); print_newline ();
  let w, h = sides (Shapes.Rect (4, 7)) in
  print_int (w * h); print_newline ()

let wide a b c d e f g h i j = fun k -> a + b + c + d + e + f + g + h + i + j + k
let () = let f = wide 1 2 3 4 5 6 7 8 9 10 in print_int (f 100); print_newline ()

(* * before +: (its first character's precedence); right to left as @ *)
let ( *| ) a b = a * 10 + b
let () =
  print_int (1 +: Square 2 +: Dot + 2 *| 3); print_newline ();
  print_int !^(Rect (2, 3)); print_newline ();
  print_string ("a" @@@ "b" @@@ "c"); print_newline ()
