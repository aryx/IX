(* ssa/Cse and ssa/Licm (-O3): their answers the same as without them,
 * on what each must leave alone *)

(* a division in a loop that runs no turn: not made before it *)
let no_turn (a : int) (b : int) =
  let s = ref 0 in
  for _i = 1 to 0 do s := !s + (a / b) done;
  !s

(* an invariant of the inner loop, then of the outer *)
let nested (n : int) (k : int) =
  let s = ref 0 in
  for i = 0 to n - 1 do
    for j = 0 to n - 1 do s := !s + ((k * 3) + (i * n)) + j done
  done;
  !s

(* the same text on two paths: one value where one dominates *)
let twice (x : int) (b : bool) =
  let y = (x * 5) + 1 in
  if b then y + ((x * 5) + 1) else (x * 5) - 1

(* a field read twice with a store between: read again *)
type cell = { mutable v : int }
let reread (c : cell) =
  let a = c.v + 1 in
  c.v <- 10;
  a + (c.v + 1)

(* the handler sees the value of before the raise *)
let handled (x : int) =
  let r = ref 0 in
  (try
     r := (x * 7) + 1;
     if x > 2 then raise Exit;
     r := 0
   with Exit -> r := !r + (x * 7) + 1);
  !r

(* floats: one product made once, the loop's invariant out of it *)
let floats (a : float) (n : int) =
  let s = ref 0. in
  for i = 1 to n do s := !s +. (a *. 2.) +. float_of_int i done;
  !s +. (a *. 2.)

(* a Float.Array's double read and stored at each turn, at the same
 * index: neither out of the loop (rebirth's state) *)
let accumulate (a : Float.Array.t) (n : int) =
  for _i = 1 to n do Float.Array.set a 0 (Float.Array.get a 0 +. 1.5) done;
  Float.Array.get a 0

let () =
  Printf.printf "%d %d\n" (no_turn 1 0) (nested 10 4);
  Printf.printf "%d %d\n" (twice 3 true) (twice 3 false);
  Printf.printf "%d %d %d\n" (reread { v = 1 }) (handled 1) (handled 5);
  Printf.printf "%.1f %.1f\n" (floats 1.5 4)
    (accumulate (Float.Array.make 2 1.) 4)
