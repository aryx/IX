(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Emit's products by a constant (a power of 2 a shift of the word
 * without its tag, another the constant in the instruction) of
 * negative, zero and large values, either side; and -x and abs x of
 * doubles (Unbox's: arm64's FNEGD and FABSD, arm's sign bit in memory),
 * of -0, infinities and nan, their sign bits printed; the same answers
 * at -O0 *)

let sign (x : float) : int = Int64.to_int (Int64.shift_right_logical (Int64.bits_of_float x) 63)

let () =
  List.iter
    (fun x ->
      Printf.printf "%d %d %d %d %d %d %d %d\n" (x * 1) (x * 2) (4 * x) (x * 64) (x * 0) (x * 3) (100 * x) (x * 127))
    [ 0; 1; -1; 7; -12345; 1000003; -1000003; 4194303 ];
  (* a matrix's place, 4 r + c *)
  let m = Array.make 16 0 in
  for r = 0 to 3 do
    for c = 0 to 3 do
      m.((4 * r) + c) <- (10 * r) + c
    done
  done;
  Array.iter (Printf.printf "%d ") m;
  print_newline ();
  let xs = [| 0.; -0.; 1.5; -2.25; infinity; neg_infinity; nan; -. nan |] in
  for i = 0 to Array.length xs - 1 do
    let x = xs.(i) *. 1. in
    let n = -.x and a = Float.abs x in
    (* read as doubles (a sum, a comparison), then printed (boxed) *)
    let s = n +. a and bigger = Float.abs x > Float.abs (x -. 1.) in
    let g x = if Float.is_nan x then "nan" else Printf.sprintf "%g" x in
    Printf.printf "%s %d %s %d %s %b\n" (g n) (sign n) (g a) (sign a) (g s) bigger
  done;
  (* a loop's: the largest absolute value, the pivot's choice *)
  let v = [| 3.; -7.5; 2.; -0.5; 7.25 |] in
  let p = ref 0 in
  for k = 1 to Array.length v - 1 do
    if Float.abs v.(k) > Float.abs v.(!p) then p := k
  done;
  Printf.printf "%d\n" !p
