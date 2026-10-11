(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* tiny-machine's memory, for a program built by OCaml: what
 * TinyGraphics.ml and the programs over it ask of a machine, so that
 * they run on the host too, where they are tested first
 * (plan_tiny_windows.md). On tiny-machine these names are externals,
 * functions of C (TinyKernel/runtime.c's peekb and pokeb) and of
 * assembly (TinyKernel/draw.tm's rows); tiny-ml reads `open TinyMemory`
 * and leaves it. Here they are an array's, of the machine's 16 MB, an
 * address the same number in both: the screen's 640 by 480 bytes are at
 * 0xf00000, and [ppm] writes them as tiny-machine -screen does. *)

let mem = Bytes.make 0x1000000 '\000'
let peekb a = Char.code (Bytes.get mem a)
let pokeb a v = Bytes.set mem a (Char.chr (v land 255))

(* a row's n bytes: copied from the first (as draw.tm's loop: not
 * Bytes.blit, which looks which way to go), filled with a colour, and
 * given a colour where the mask's byte is not 0 *)
let row_copy dst src n = for i = 0 to n - 1 do pokeb (dst + i) (peekb (src + i)) done
let row_fill dst colour n = Bytes.fill mem dst n (Char.chr (colour land 255))
let row_mask dst colour mask n = for i = 0 to n - 1 do if peekb (mask + i) <> 0 then pokeb (dst + i) colour done

(* a byte's colour: Plan 9's table, TinyMachine.ml's formula (which says
 * what it is) *)
let colour i =
  let r = i lsr 6 and v = (i lsr 4) land 3 in
  let j = (i - v + r) land 15 in
  let g = j lsr 2 and b = j land 3 in
  let den = max r (max g b) in
  if den = 0 then [ 17 * v; 17 * v; 17 * v ]
  else let num = 17 * ((4 * den) + v) in [ r * num / den; g * num / den; b * num / den ]

(* the screen as a PPM, the bytes tiny-machine -screen writes *)
let ppm () =
  let b = Buffer.create 1000000 in
  Buffer.add_string b "P6\n640 480\n255\n";
  for i = 0 to (640 * 480) - 1 do List.iter (fun c -> Buffer.add_char b (Char.chr c)) (colour (peekb (0xf00000 + i))) done;
  Buffer.contents b
