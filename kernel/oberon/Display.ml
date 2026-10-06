(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Display.mli *)

module Phys = Machine.Phys

let width = 1024
let height = 768

type msg = exn
type frame = {
  mutable x : int; mutable y : int; mutable w : int; mutable h : int;
  mutable dsc : frame list;
  mutable handle : frame -> msg -> unit;
}
let frame handle = { x = 0; y = 0; w = 0; h = 0; dsc = []; handle }
let send (f : frame) m = f.handle f m

type color = Black | White
type mode = Replace | Paint | Invert
type pattern = string

(* Display.Mod's, their bytes *)
let arrow = "\x0f\x0f\x00\x60\x00\x70\x00\x38\x00\x1c\x00\x0e\x00\x07\x80\x03\xc1\x01\xe3\x00\x77\x00\x3f\x00\x1f\x00\x3f\x00\x7f\x00\xff\x00"
let star = "\x0f\x0f\x80\x00\x82\x20\x84\x10\x88\x08\x90\x04\xa0\x02\xc0\x01\x7f\x7f\xc0\x01\xa0\x02\x90\x04\x88\x08\x84\x10\x82\x20\x80\x00"
let hook = "\x0c\x0c\x07\x0f\x87\x07\xc7\x03\xe7\x01\xf7\x00\x7f\x00\x3f\x00\x1f\x00\x0f\x00\x07\x00\x03\x00\x01\x00"
let updown = "\x08\x0e\x18\x3c\x7e\xff\x18\x18\x18\x18\x18\x18\xff\x7e\x3c\x18"
let block = "\x08\x08\xff\xff\xc3\xc3\xc3\xc3\xff\xff"
let cross = "\x0f\x0f\x01\x40\x02\x20\x04\x10\x08\x08\x10\x04\x20\x02\x40\x01\x00\x00\x40\x01\x20\x02\x10\x04\x08\x08\x04\x10\x02\x20\x01\x40"
let grey = "\x20\x02\x00\x00\x55\x55\x55\x55\xaa\xaa\xaa\xaa"

(* The Pi's frame: its address, a row's bytes; a pixel is 16 bits, the
 * low byte first: the emulator's two colours (oberon-risc-emu's: a
 * slate and a cream), as 5, 6 and 5 bits of red, green and blue *)
let fb = ref 0
let pitch = ref (2 * width)
let black_low = '\xd0' and black_high = '\x63'
let white_low = '\xbc' and white_high = '\xff'

(* a row's piece, w pixels from (x, y): where it is; read; written *)
let address x y = !fb + ((height - 1 - y) * !pitch) + (2 * x)
let get_row x y w = Bytes.of_string (Phys.read (address x y) (2 * w))
let put_row x y row = Phys.write (address x y) (Bytes.to_string row)
let is_white row i = Bytes.get row (2 * i) = white_low
let set row i white =
  Bytes.set row (2 * i) (if white then white_low else black_low);
  Bytes.set row ((2 * i) + 1) (if white then white_high else black_high)

(* w pixels of a colour *)
let plain col w =
  let row = Bytes.create (2 * w) in
  for i = 0 to w - 1 do set row i (col = White) done;
  row

(* the part of [x, x + w) and of [y, y + h) that is in the frame: where
 * it starts and its size, none when empty *)
let clip x w limit = let first = max x 0 in let last = min (x + w) limit in first, last - first

let init () =
  fb := Machine.fb_init width height 16;
  if !fb = 0 then Machine.panic "Display: no frame";
  pitch := Machine.fb_pitch ();
  let row = plain Black width in
  for y = 0 to height - 1 do put_row 0 y row done

(* a pixel's new colour under a mode: whether it is white, from whether
 * it was and whether the operation has it *)
let apply mode col was has =
  match mode with
  | Replace -> if has then col = White else was
  | Paint -> was || has
  | Invert -> if has then not was else was

let repl_const col x y w h mode =
  let x, w = clip x w width in
  let y, h = clip y h height in
  if w > 0 && h > 0 then
    match mode with
    | Replace | Paint ->
        (* (no row read: every pixel is the colour) *)
        let row = plain (if mode = Paint then White else col) w in
        for j = y to y + h - 1 do put_row x j row done
    | Invert ->
        for j = y to y + h - 1 do
          let row = get_row x j w in
          for i = 0 to w - 1 do set row i (not (is_white row i)) done;
          put_row x j row
        done

let dot col x y mode = repl_const col x y 1 1 mode

(* a pattern's bit: column i of its row j (from the lowest) *)
let bit (p : pattern) i j =
  let bytes = (Char.code p.[0] + 7) / 8 in
  (Char.code p.[2 + (j * bytes) + (i / 8)] lsr (i land 7)) land 1 = 1

let copy_pattern col (p : pattern) x y mode =
  let pw = Char.code p.[0] and ph = Char.code p.[1] in
  let x0, w = clip x pw width in
  for j = 0 to ph - 1 do
    if w > 0 && y + j >= 0 && y + j < height then begin
      let row = get_row x0 (y + j) w in
      for i = 0 to w - 1 do
        if bit p (x0 + i - x) j then set row i (apply mode col (is_white row i) true)
      done;
      put_row x0 (y + j) row
    end
  done

(* (a row read whole before it is written: the two places may overlap;
 * the rows in the order that does not write one before it is read) *)
let copy_block sx sy w h dx dy =
  let copy j =
    if sy + j >= 0 && sy + j < height && dy + j >= 0 && dy + j < height && sx >= 0 && dx >= 0 && sx + w <= width && dx + w <= width then
      put_row dx (dy + j) (get_row sx (sy + j) w)
  in
  if dy > sy then for j = h - 1 downto 0 do copy j done else for j = 0 to h - 1 do copy j done

(* (the pattern's rows are words of 4 bytes, after a first word with its sizes) *)
let repl_pattern _col (p : pattern) x y w h =
  let ph = Char.code p.[1] in
  let bit i j = (Char.code p.[4 + (4 * j) + (i / 8)] lsr (i land 7)) land 1 = 1 in
  let x, w = clip x w width in
  let y0, h = clip y h height in
  if w > 0 then
    for j = y0 to y0 + h - 1 do
      let row = get_row x j w in
      for i = 0 to w - 1 do
        if bit ((x + i) land 31) ((j - y) mod ph) then set row i (not (is_white row i))
      done;
      put_row x j row
    done
