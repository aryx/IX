(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Systimer.mli *)

type t = {
  mutable now : int;             (* microseconds, 64 bits *)
  mutable cs : int;              (* the matched compares, bits 0-3 *)
  compare : int array;
  line : int -> bool -> unit;
}

let create ~line = { now = 0; cs = 0; compare = Array.make 4 0; line }

(* the lines, from CS: compare n is interrupt n *)
let lines t = for n = 0 to 3 do t.line n (t.cs land (1 lsl n) <> 0) done

(* time advanced by [us]: a compare between the old low word and the
 * new one (modulo 2^32) matches *)
let advance t us =
  if us > 0 then begin
    let lo0 = t.now land 0xffffffff in
    t.now <- t.now + us;
    for n = 0 to 3 do
      (* (unsigned: under js_of_ocaml an int is the 32 bits, and d may be
       * negative there) *)
      let d = Bits.mask32 (t.compare.(n) - lo0 - 1) in
      if Bits.ult32 d us then t.cs <- t.cs lor (1 lsl n)
    done;
    lines t
  end

(* the microseconds to the next compare *)
let until_next t =
  let lo = t.now land 0xffffffff in
  (* The distances are words without a sign. Under js_of_ocaml, where an
   * int is the 32 bits, a compare behind the clock (the three no kernel
   * sets: 0) is a negative int, and "min acc d" then chose it: every
   * wait for an interrupt skipped a microsecond where it could skip ten
   * thousand, and a kernel with nothing to do ran its idle loop for the
   * whole of the host's time (mini-9pi with rio waiting: 5.8 of the 6
   * million instructions of a second, 0.5 natively). At most 2^30 here.
   * old: let d = (c - lo) land 0xffffffff in if d = 0 then acc else min acc d *)
  let far = 1 lsl 30 in
  Array.fold_left (fun acc c ->
    let d = Bits.mask32 (c - lo) in
    if d = 0 || not (Bits.ult32 d acc) then acc else d) far t.compare

let read t off _ =
  match off with
  | 0x0 -> t.cs
  | 0x4 -> t.now land 0xffffffff
  (* (no high word under js_of_ocaml: lsr 32 is lsr 0 there) *)
  | 0x8 -> if Bits.native then (t.now lsr 32) land 0xffffffff else 0
  | 0xc | 0x10 | 0x14 | 0x18 -> t.compare.((off - 0xc) / 4)
  | _ -> 0

let write t off _ v =
  match off with
  | 0x0 -> t.cs <- t.cs land lnot v; lines t          (* 1s clear the matches *)
  | 0xc | 0x10 | 0x14 | 0x18 -> t.compare.((off - 0xc) / 4) <- v land 0xffffffff
  | _ -> ()

let device t = { Memory.read = read t; write = write t }

let now t = t.now
