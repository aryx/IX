(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* C's math functions on doubles (Lower's float_calls, ssa's Unbox):
 * each of one argument, and pow, atan2 and fmod of two in their order,
 * in a loop where doubles and words stay live across the call (Alloc's
 * clobbers), its result summed as a double and kept in a block; the
 * same in a function with a handler (the runtime's on blocks), and the
 * primitives as values; printed to 9 digits (the C library's and
 * glibc's may differ in a last bit; log 0 is nan by ix's, bugs/goken.md) *)

let ones = [ "exp", exp; "log", log; "log10", log10; "sqrt", sqrt; "sin", sin; "cos", cos; "tan", tan;
             "asin", asin; "acos", acos; "atan", atan; "sinh", sinh; "cosh", cosh; "tanh", tanh ]

let show name (x : float) = Printf.printf "%s %.9g\n" name x

(* the doubles a, s and the word n live across each call *)
let sums () =
  let s = ref 0.0 and n = ref 0 and kept = ref [] in
  for i = 1 to 8 do
    let a = float_of_int i *. 0.1 in
    let e = exp a in
    let l = log (a +. 1.0) in
    let p = a ** 1.5 in
    let t = atan2 a (1.0 -. a) in
    let m = mod_float (a *. 10.0) 3.0 in
    s := !s +. e +. l +. p +. t +. m +. sqrt a +. tanh (a -. 0.5) +. a;
    n := !n + i;
    kept := e :: !kept
  done;
  show "sums" !s;
  Printf.printf "n %d\n" !n;
  List.iter (show "kept") !kept

(* (a handler: Unbox leaves the function's floats in blocks) *)
let guarded x = try exp x +. x ** 2.0 +. cos x with Not_found -> 0.0

let () =
  List.iter (fun (name, f) -> List.iter (fun x -> show name (f x)) [ 0.5; 0.25; 1.0; 0.75; 0.125 ]) ones;
  List.iter (fun (x, y) -> show "pow" (x ** y); show "atan2" (atan2 x y); show "fmod" (mod_float x y))
    [ 2.0, 10.0; 10.0, 2.0; -3.0, 2.0; 0.5, -1.5; 7.5, 2.25 ];
  show "exp inf" (exp infinity);
  show "exp -inf" (exp neg_infinity);
  show "sqrt 0" (sqrt 0.0);
  sums ();
  show "guarded" (guarded 1.25);
  show "map" (List.fold_left ( +. ) 0.0 (List.map exp [ 0.1; 0.2; 0.3 ]))
