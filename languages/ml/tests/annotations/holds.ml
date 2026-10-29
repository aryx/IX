(* The checked annotations where they hold (Annotations.mli): OCaml
 * reads [@tailcall] as its own and ignores [@@tailrec] and
 * [@@zero_alloc]; mini-ml checks them all (-O3). A loop of a million
 * turns, two functions calling each other, a local loop over a list;
 * loops over an array of ints, of floats, over a string's bytes, one
 * calling another [@@zero_alloc] and raising, and both annotations on
 * one function; [@inline] on a small function and a bigger one; a
 * float sum kept a double ([@@unboxed_float]). *)
let rec sum i acc = if i = 0 then acc else sum (i - 1) (acc + i) [@@tailrec]

let rec even n = if n = 0 then true else (odd [@tailcall]) (n - 1)
and odd n = if n = 0 then false else (even [@tailcall]) (n - 1)

let count l =
  let rec go l n = match l with [] -> n | _ :: t -> go t (n + 1) [@@tailrec] in
  go l 0

let sum_array (a : int array) =
  let s = ref 0 in
  for i = 0 to Array.length a - 1 do s := !s + a.(i) done;
  !s [@@zero_alloc]

(* a float kept a double (Unbox), never boxed: the result an int *)
let floor_mean (a : float array) =
  let s = ref 0.0 in
  for i = 0 to Array.length a - 1 do s := !s +. a.(i) done;
  int_of_float (!s /. float_of_int (Array.length a)) [@@zero_alloc]

let is_digit (c : char) = c >= '0' && c <= '9' [@@zero_alloc]

(* the first digit's index, Not_found raised (made beforehand); go
 * given s, not capturing it, which would make a closure (refused/'s
 * closure.ml) *)
let first_digit (s : string) =
  let rec go (s : string) i =
    if i = String.length s then raise Not_found
    else if is_digit s.[i] then i
    else go s (i + 1) [@@tailrec] [@@zero_alloc]
  in
  go s 0 [@@zero_alloc]

(* [@inline], OCaml's place and after the binding: mix is over -O3's
 * 24 nodes (under 32), inlined all the same *)
let[@inline] twice (x : int) = x + x

let mix (a : int) b =
  let x = (a * 31) + b in
  let y = (x lxor (x lsr 7)) * 17 in
  (y lxor (y lsl 3)) land 0xffff [@@inline]

(* [@@unboxed_float]: the sum a double in a register around the loop,
 * left as an int *)
let mean (a : float array) =
  let s = ref 0.0 [@@unboxed_float] in
  for i = 0 to Array.length a - 1 do s := !s +. a.(i) done;
  int_of_float (!s /. float_of_int (Array.length a))

let () =
  Printf.printf "%d\n" (sum 1000000 0);
  Printf.printf "%b %b\n" (even 100000) (odd 7);
  Printf.printf "%d\n" (count [ 1; 2; 3 ]);
  Printf.printf "%d %d\n" (sum_array [| 1; 2; 3 |]) (floor_mean [| 1.5; 2.5; 4.0 |]);
  Printf.printf "%d %b\n" (first_digit "ab7c")
    (try ignore (first_digit "abc"); false with Not_found -> true);
  Printf.printf "%d %d\n" (twice 21) (mix 3 4);
  Printf.printf "%d\n" (mean [| 1.5; 2.5; 5.0 |])
