(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Untag's integers (ssa/Untag.mli): bytes read and stored at computed
 * indexes, shifts by constants of negative and large values, masks, sums
 * of untagged and tagged values, near an int's bound and past it (a sum
 * of two tagged values wraps; of untagged ones never needed to); one
 * kept across a call and an allocation (a slot the collector does not
 * scan); the same answers at -O0, which tags them all *)

let b = Bytes.init 256 (fun i -> Char.chr ((i * 7 + 3) land 255))
let out = Bytes.make 64 '.'
let f x = x + 1

let () =
  (* a span's pixel: two shifts, two masks, a byte as an index *)
  let s = ref 0 in
  for i = 0 to 999 do
    let xf = (i * 98765) - 40_000_000 in
    let spot = ((xf asr 10) land 192) + ((xf asr 16) land 63) in
    s := !s + Char.code (Bytes.unsafe_get b (Char.code (Bytes.unsafe_get b spot)))
  done;
  Printf.printf "%d\n" !s;
  (* shifts of negative values, by 1 and by much *)
  List.iter (fun x -> Printf.printf "%d %d %d %d\n" (x asr 1) (x asr 7) (x asr 29) ((x asr 3) land 1023)) [ -1; -2; -12345; 1000000007; -1000000007; 0; 77 ];
  (* masks past 8 bits, a constant the instruction cannot hold *)
  List.iter (fun x -> Printf.printf "%d %d\n" ((x asr 2) land 4032) ((x asr 1) land 0x3ffff)) [ 123456789; -987654; 1 ];
  (* sums: untagged (small), tagged plus untagged, minus *)
  let t = ref max_int in
  for i = 0 to 9 do
    let c = Char.code (Bytes.get b i) in
    let u = (i asr 1) + c in
    t := !t + u - ((i * 3) land 15);
    Bytes.set out i (Char.chr (((c asr 1) + (u land 7)) land 255))
  done;
  Printf.printf "%d %s\n" (!t - max_int) (Bytes.sub_string out 0 10);
  (* an untagged value kept across a call and an allocation *)
  let k = (12345678 asr 4) land 255 in
  let l = List.init 1000 (fun i -> [| i; f i |]) in
  let m = (k lsl 2) + Char.code (Bytes.get b k) in
  Printf.printf "%d %d %d\n" k m (List.length l);
  (* checked bytes at untagged indexes, one out of bounds *)
  (try Printf.printf "%d\n" (Char.code (Bytes.get b ((300 asr 1) land 511)))
   with Invalid_argument _ -> print_endline "out");
  (try Printf.printf "%d\n" (Char.code (Bytes.get b ((900 asr 1) land 511)))
   with Invalid_argument _ -> print_endline "out")
