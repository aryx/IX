(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Int32.mli *)

(* two pieces of 16 bits, the high one signed and the low one 0 to
 * 65535, as Int64's: two equal numbers are the same pair, and compare's
 * order on the pairs is the numbers' *)
type int32 = int * int

let sext16 p = ((p land 0xffff) lxor 0x8000) - 0x8000

let zero = (0, 0)
let one = (0, 1)
let minus_one = (-1, 0xffff)
let max_int = (0x7fff, 0xffff)
let min_int = (-0x8000, 0)

(* the low 32 bits of n *)
let of_int n = (sext16 (n asr 16), n land 0xffff)
(* the bits that fit, as OCaml's: all 32 on its 63-bit ints, the low 31
 * on tiny-ml's *)
let to_int (h, l) = (h lsl 16) lor l

(* the low piece's carry into the high one *)
let add (ah, al) (bh, bl) =
  let s = al + bl in
  (sext16 (ah + bh + (s lsr 16)), s land 0xffff)
let lognot (h, l) = (lnot h, l lxor 0xffff)
let neg x = add (lognot x) one
let sub x y = add x (neg y)
(* (the high pieces sign-extended both: so are their and, or, xor) *)
let logand (ah, al) (bh, bl) = (ah land bh, al land bl)
let logor (ah, al) (bh, bl) = (ah lor bh, al lor bl)
let logxor (ah, al) (bh, bl) = (ah lxor bh, al lxor bl)

(* a shift of 16 or more moves a whole piece; less, bits from one piece
 * to the other *)
let shift_left ((h, l) as x) n =
  if n = 0 then x
  else if n >= 16 then (sext16 (l lsl (n - 16)), 0)
  else (sext16 ((h lsl n) lor (l lsr (16 - n))), (l lsl n) land 0xffff)
let shift_right_logical ((h, l) as x) n =
  let h = h land 0xffff in
  if n = 0 then x
  else if n >= 16 then (0, h lsr (n - 16))
  else (h lsr n, (l lsr n) lor ((h lsl (16 - n)) land 0xffff))
let shift_right ((h, l) as x) n =
  if n = 0 then x
  else if n >= 16 then ((if h < 0 then -1 else 0), (h asr (n - 16)) land 0xffff)
  else (h asr n, (l lsr n) lor ((h lsl (16 - n)) land 0xffff))

let equal (x : int32) y = x = y
let compare (x : int32) y = compare x y

(* in decimal: the magnitude, unsigned, divided by 10 a digit at a time,
 * the high piece's remainder carried into the low one *)
let to_string x =
  let rec digits h l acc =
    if h = 0 && l = 0 then acc
    else
      let v = ((h mod 10) * 0x10000) + l in
      digits (h / 10) (v / 10) (string_of_int (v mod 10) ^ acc) in
  if x = zero then "0"
  else if compare x zero < 0 then
    let h, l = neg x in
    "-" ^ digits (h land 0xffff) l ""
  else
    let h, l = x in
    digits h l ""
