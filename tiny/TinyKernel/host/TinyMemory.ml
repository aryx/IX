(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* tiny-machine's memory, for a program built by OCaml: what
 * TinyKernelGraphics.ml and the programs over it ask of a machine, so that
 * they run on the host too, where they are tested first
 * (plan_tiny_windows.md). On tiny-machine these names are externals,
 * functions of C (TinyKernel/runtime.c's peekb and pokeb) and of
 * assembly (TinyKernel/draw.tm's rows); tiny-ml reads `open TinyMemory`
 * and leaves it. Here they are an array's, of the machine's 16 MB, an
 * address the same number in both: the screen's 1024 by 768 bytes are at
 * 0xf00000, and [ppm] writes them as tiny-machine -screen does. *)

let mem = Bytes.make 0x1000000 '\000'
let peekb a = Char.code (Bytes.get mem a)
let pokeb a v = Bytes.set mem a (Char.chr (v land 255))

(* a row's n bytes: copied from the first (as draw.tm's loop: not
 * Bytes.blit, which looks which way to go), filled with a colour, and
 * given a colour where the mask's byte is not 0 *)
let row_copy dst src n = for i = 0 to n - 1 do pokeb (dst + i) (peekb (src + i)) done
let row_fill dst colour n = Bytes.fill mem dst n (Char.chr (colour land 255))
let row_mask dst colour mask n =
  for i = 0 to n - 1 do
    if peekb (mask + i) <> 0 then pokeb (dst + i) colour
  done

(* a row's n bytes mixed by a mask's levels: where the mask's byte is
 * not 0, the byte of the table's row of its level (its two high bits)
 * that the pixel's colour is *)
let row_mix dst table mask n =
  for i = 0 to n - 1 do
    let m = peekb (mask + i) in
    if m <> 0 then
      pokeb (dst + i) (peekb (table + ((m lsr 6) * 256) + peekb (dst + i)))
  done

(* a text's n characters from dst, in an image [width] wide, through the
 * font's mask (1024 wide, character c at column 8c), as draw.tm's: in a
 * colour, or mixed by a table (glyphs_mixed) *)
let each_glyph row dst width font s n =
  for i = 0 to n - 1 do
    let c = Char.code s.[i] in
    let c = if c > 127 then 63 else c in
    for k = 0 to 15 do
      row (dst + (8 * i) + (k * width)) (font + (k * 1024) + (8 * c))
    done
  done
let glyphs dst width colour font s n =
  each_glyph (fun d m -> row_mask d colour m 8) dst width font s n
let glyphs_mixed dst width table font s n =
  each_glyph (fun d m -> row_mix d table m 8) dst width font s n

(* A colour's mixes, at at: 4 rows of 256 bytes, row l's byte k the
 * colour nearest to l thirds of the ink and the rest of colour k (row
 * 0 k, row 3 the ink), the palette's red, green and blue (3 bytes a
 * colour) at palette. Nearest by the squares of the differences, among
 * the 16 a colour can be near: for each q = 4 den + v (den the largest
 * of a colour's two-bit red, green and blue, v how bright), the one
 * whose parts are the mix's rounded, its largest 17 q; q below 4, the
 * grey 17 q. The same as a search of the 256 but for ties (the first q
 * of the least kept), in a sixteenth of the time. *)
let mix_table at ink palette =
  let c k i = peekb (palette + (3 * k) + i) in
  let nearest r g b =
    let best = ref 0 and dist = ref max_int in
    for q = 0 to 15 do
      let den = q lsr 2 and v = q land 3 and top = 17 * q in
      let part x = if den = 0 then 0 else min den (((x * den) + (top / 2)) / top) in
      let pr = part r and pg = part g and pb = part b in
      let i = (pr * 64) + (v * 16) + (((pg * 4) + pb + v - pr) land 15) in
      let d = ((c i 0 - r) * (c i 0 - r)) + ((c i 1 - g) * (c i 1 - g))
              + ((c i 2 - b) * (c i 2 - b)) in
      if d < !dist then (best := i; dist := d)
    done;
    !best
  in
  for l = 0 to 3 do
    for k = 0 to 255 do
      let part i = ((l * c ink i) + ((3 - l) * c k i) + 1) / 3 in
      pokeb (at + (l * 256) + k)
        (if l = 0 then k else if l = 3 then ink
         else nearest (part 0) (part 1) (part 2))
    done
  done

(* a string's n bytes from off, to memory at dst; and memory's n bytes
 * at a, as a string *)
let row_bytes s off dst n = Bytes.blit_string s off mem dst n
let row_string a n = Bytes.sub_string mem a n

(* the screen, w by h, as a PPM: the bytes tiny-machine -screen writes,
 * a byte's colour the machine's (old: Plan 9's table computed here, a
 * copy of TinyMachineDevices's formula) *)
let ppm w h =
  let b = Buffer.create 1000000 in
  Buffer.add_string b (Printf.sprintf "P6\n%d %d\n255\n" w h);
  for i = 0 to (w * h) - 1 do
    Buffer.add_substring b TinyMachineDevices.colours
      (3 * peekb (0xf00000 + i)) 3
  done;
  Buffer.contents b
