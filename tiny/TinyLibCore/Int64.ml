(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Int64.mli *)

(* four pieces of 16 bits, the high one first and signed, the others
 * 0 to 65535: an int has 31 bits. So two equal numbers are the same
 * tuple, and compare's order on the tuples is the numbers' *)
type int64 = int * int * int * int

let sext16 p = ((p land 0xffff) lxor 0x8000) - 0x8000

let zero = (0, 0, 0, 0)
let one = (0, 0, 0, 1)
let minus_one = (-1, 0xffff, 0xffff, 0xffff)
let max_int = (0x7fff, 0xffff, 0xffff, 0xffff)
let min_int = (-0x8000, 0, 0, 0)

let of_int n = let s = if n < 0 then 0xffff else 0 in (sext16 s, s, (n asr 16) land 0xffff, n land 0xffff)
(* the low bits that fit, as OCaml's *)
let to_int (_, b, c, d) = (((b lsl 16) lor c) lsl 16) lor d

(* each piece's carry into the next *)
let add (a3, a2, a1, a0) (b3, b2, b1, b0) =
  let s0 = a0 + b0 in
  let s1 = a1 + b1 + (s0 lsr 16) in
  let s2 = a2 + b2 + (s1 lsr 16) in
  (sext16 (a3 + b3 + (s2 lsr 16)), s2 land 0xffff, s1 land 0xffff, s0 land 0xffff)
(* (the high piece is signed: lnot, land... keep it so) *)
let lognot (a, b, c, d) = (lnot a, b lxor 0xffff, c lxor 0xffff, d lxor 0xffff)
let neg x = add (lognot x) one
let sub x y = add x (neg y)
let succ x = add x one
let pred x = sub x one
let logand (a3, a2, a1, a0) (b3, b2, b1, b0) = (a3 land b3, a2 land b2, a1 land b1, a0 land b0)
let logor (a3, a2, a1, a0) (b3, b2, b1, b0) = (a3 lor b3, a2 lor b2, a1 lor b1, a0 lor b0)
let logxor (a3, a2, a1, a0) (b3, b2, b1, b0) = (a3 lxor b3, a2 lxor b2, a1 lxor b1, a0 lxor b0)
let equal (x : int64) y = x = y
let compare (x : int64) y = compare x y
let abs x = if compare x zero < 0 then neg x else x

(* the bytes, the low first: a product of two is 16 bits, so the
 * columns' sums fit where the pieces' products would not *)
let mul (a3, a2, a1, a0) (b3, b2, b1, b0) =
  let bytes p3 p2 p1 p0 = Array.of_list [ p0 land 0xff; p0 lsr 8; p1 land 0xff; p1 lsr 8; p2 land 0xff; p2 lsr 8; p3 land 0xff; (p3 land 0xffff) lsr 8 ] in
  let a = bytes a3 a2 a1 a0 and b = bytes b3 b2 b1 b0 in
  let r = Array.make 8 0 and carry = ref 0 in
  for k = 0 to 7 do
    let s = ref !carry in
    for i = 0 to k do s := !s + (a.(i) * b.(k - i)) done;
    r.(k) <- !s land 0xff; carry := !s lsr 8
  done;
  let piece k = r.(2 * k) lor (r.((2 * k) + 1) lsl 8) in
  (sext16 (piece 3), piece 2, piece 1, piece 0)

(* the pieces, the low first, unsigned; a shift is of whole pieces,
 * then of bits within them *)
let shifted (a, b, c, d) n f =
  let p = Array.of_list [ d; c; b; a land 0xffff ] in
  let at i = if i >= 0 && i < 4 then p.(i) else 0 in
  let q = Array.init 4 (fun i -> f at i (n / 16) (n mod 16) land 0xffff) in
  (sext16 q.(3), q.(2), q.(1), q.(0))
let shift_right_logical x n = shifted x n (fun at i k s -> (at (i + k) lsr s) lor (at (i + k + 1) lsl (16 - s)))
let shift_left x n = shifted x n (fun at i k s -> (at (i - k) lsl s) lor (at (i - k - 1) lsr (16 - s)))
let shift_right x n = if compare x zero < 0 then lognot (shift_right_logical (lognot x) n) else shift_right_logical x n

(* unsigned: x < y, and the quotient and remainder, a bit at a time
 * (twice a number and a bit added, its bit i), but for two numbers
 * of 30 bits, an int's division *)
let ult x y = compare (logxor x min_int) (logxor y min_int) < 0
let small (a, b, c, _) = a = 0 && b = 0 && c < 0x4000
let udivmod x y =
  let twice (a, b, c, d) bit = (sext16 ((a lsl 1) lor (b lsr 15)), ((b lsl 1) land 0xffff) lor (c lsr 15), ((c lsl 1) land 0xffff) lor (d lsr 15), ((d lsl 1) land 0xffff) lor bit) in
  let bit (a, b, c, d) i = let p = match i / 16 with 0 -> d | 1 -> c | 2 -> b | _ -> a land 0xffff in (p lsr (i mod 16)) land 1 in
  let rec go i q r =
    if i < 0 then q, r
    else
      let r = twice r (bit x i) in
      if ult r y then go (i - 1) (twice q 0) r else go (i - 1) (twice q 1) (sub r y) in
  if small x && small y then of_int (to_int x / to_int y), of_int (to_int x mod to_int y) else go 63 zero zero
(* truncated, as OCaml's: the remainder has the dividend's sign *)
let div x y =
  if y = zero then raise Division_by_zero;
  let q, _ = udivmod (abs x) (abs y) in
  if (compare x zero < 0) <> (compare y zero < 0) then neg q else q
let rem x y =
  if y = zero then raise Division_by_zero;
  let _, r = udivmod (abs x) (abs y) in
  if compare x zero < 0 then neg r else r

(* in decimal; read as OCaml does, in decimal or after 0x, 0o or 0b,
 * a sign before *)
let to_string x =
  (* x, unsigned, divided by 10: each piece's remainder carried into
   * the next *)
  let div10 (a, b, c, d) =
    let a = a land 0xffff in
    let v2 = ((a mod 10) * 0x10000) + b in
    let v1 = ((v2 mod 10) * 0x10000) + c in
    let v0 = ((v1 mod 10) * 0x10000) + d in
    (a / 10, v2 / 10, v1 / 10, v0 / 10), v0 mod 10 in
  let rec digits x acc = if x = zero then acc else let q, r = div10 x in digits q (string_of_int r ^ acc) in
  if x = zero then "0" else if compare x zero < 0 then "-" ^ digits (neg x) "" else digits x ""
let of_string s =
  let n = String.length s in
  let neg_ = n > 0 && s.[0] = '-' in
  let i = if n > 0 && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
  let base, i =
    if i + 1 < n && s.[i] = '0' then
      match s.[i + 1] with 'x' | 'X' -> 16, i + 2 | 'o' | 'O' -> 8, i + 2 | 'b' | 'B' -> 2, i + 2 | _ -> 10, i
    else 10, i in
  let digit c =
    let k = Char.code c in
    if c >= '0' && c <= '9' then k - 48 else if c >= 'a' && c <= 'f' then k - 87 else if c >= 'A' && c <= 'F' then k - 55 else 99 in
  if i >= n then failwith "Int64.of_string";
  let rec go j x =
    if j = n then x
    else if s.[j] = '_' then go (j + 1) x
    else let d = digit s.[j] in if d >= base then failwith "Int64.of_string" else go (j + 1) (add (mul x (of_int base)) (of_int d)) in
  let x = go i zero in
  if neg_ then neg x else x
