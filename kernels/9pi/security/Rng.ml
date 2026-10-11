(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Rng.mli *)

let base = 0x104000
let pi1 = Arch.name = "pi1"
let started = ref false

let start () =
  started := true;
  (* (the Pi 1: the first 0x40000 words not given, as Linux asks) *)
  if pi1 then Machine.io_set32 (base + 4) 0x4 0;
  Machine.io_set32 base 0 1

let ready () : bool = if pi1 then Machine.io_get16 (base + 4) true lsr 8 > 0 else Machine.io_get16 (base + 0x24) false land 0xff > 0

let bytes (n : int) : string option =
  if not !started then start ();
  let r = Bytes.create n in
  (* [tries]: the reads of the status since the last word; a million and none: no generator *)
  let rec fill (i : int) (tries : int) : string option =
    if i >= n then Some (Bytes.unsafe_to_string r)
    else if ready () then begin
      let w = Machine.io_get16 (base + (if pi1 then 8 else 0x20)) false in
      Bytes.set r i (Char.chr (w land 0xff));
      if i + 1 < n then Bytes.set r (i + 1) (Char.chr (w lsr 8));
      fill (i + 2) 0
    end
    else if tries > 1000000 then None
    else fill i (tries + 1)
  in
  fill 0 0
