(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* emacs, a program of TinyKernel.ml's: ../../TinyEmacs.ml, the editor,
 * on a screen and a file of tiny-kernel's (given to tiny-ml after
 * ../libml/calls.ml, ../../TinyLibStd.ml, ../../TinyLibDraw.ml and
 * TinyEmacs.ml, as one program: the Makefile).
 *
 *     emacs file
 *
 * The screen is where the program draws, its descriptor 3: a window
 * of tiny-windows, or the machine's screen, in characters of 8 by 16
 * pixels. A window's size is asked of the window: an ENQ printed (the
 * enquiry, ASCII's 5), which tiny-windows answers in the window's
 * mouse box, the 4, as a mouse at (width, height) with the buttons -1.
 * On the console no one answers: the screen is 640 by 480. A window
 * gives the keys as they are typed once one draws in it; the arrows
 * are 128 to 131. The file is the kernel's, in its memory: what is
 * saved is there until the machine stops. Not OCaml's to compile: it
 * names the kernel's calls, calls.ml's externals. *)
open TinyEmacs
open TinyLibDraw

(* our images: 0 is the window, 1 white, 2 black *)
let white = 1
let black = 2

(* the size in pixels: the window's answer, read until it comes (a box
 * may have a mouse in it from before), for at most half a second *)
let size () =
  ignore (u_write 1 "\005");
  let fds = Array.make 1 4 and until = u_ticks () + 200 in
  let rec answer () =
    if u_ready fds 1 until <> 4 then 640, 480
    else (let s = u_read 4 12 in if String.length s = 12 && int16 s 8 = -1 then int16 s 0, int16 s 4 else answer ()) in
  answer ()

(* the lines drawn, and the cursor's place (its cell is the character
 * white on black) *)
let drawn = ref (Array.make 0 "")
let was = ref (0, 0)

(* the columns of a line to draw again, from the first that changed
 * to the last, or to the end when the lengths differ (the rest moved).
 * A key changes a character or two: the kernel draws a character in
 * some 13,000 instructions, and the line at the bottom is 70 (old:
 * every line that changed drawn whole, 50 ticks a key on the console) *)
let changed a b =
  let n = String.length a and m = String.length b in
  let rec first i = if i < n && i < m && a.[i] = b.[i] then first (i + 1) else i in
  let p = first 0 in
  if p = n && p = m then 0, 0
  else if n <> m then p, max n m
  else (let rec last j = if j > p && a.[j - 1] = b.[j - 1] then last (j - 1) else j in p, last n)

let show lines (col, row) =
  let d = !drawn and m = ref "" and was_col, was_row = !was in
  (* line i's columns from a up to b: white, then its characters *)
  let draw i l a b =
    if a < b then begin
      m := !m ^ d_fill 0 white (a * 8) (i * 16) (b * 8) ((i * 16) + 16);
      if a < String.length l then m := !m ^ d_text 0 black (a * 8) (i * 16) (String.sub l a (min b (String.length l) - a))
    end in
  List.iteri (fun i l ->
    if i < Array.length d then begin
      let a, b = changed d.(i) l in
      d.(i) <- l;
      draw i l a b;
      if i = was_row && (was_row <> row || was_col <> col) then draw i l was_col (was_col + 1);
      if i = row then begin
        let c = if col < String.length l then String.sub l col 1 else " " in
        m := !m ^ d_fill 0 black (col * 8) (i * 16) ((col * 8) + 8) ((i * 16) + 16) ^ d_text 0 white (col * 8) (i * 16) c
      end
    end) lines;
  was := (col, row);
  ignore (u_write 3 !m)

(* the keys read and not yet given; -1 at their end *)
let keys = ref ""
let rec next () =
  let s = !keys in
  if s <> "" then (keys := String.sub s 1 (String.length s - 1); Char.code s.[0])
  else (let r = u_read 0 16 in if r = "" then -1 else (keys := r; next ()))

(* a file's text, "" when it is not there; whether it was written *)
let read file =
  let fd = u_open file 0 in
  if fd < 0 then ""
  else (let rec go acc = let s = u_read fd 4096 in if s = "" then acc else go (acc ^ s) in let s = go "" in ignore (u_close fd); s)

(* user.h's O_WRONLY | O_CREATE | O_TRUNC; u_write is 0 when all was written *)
let write file text =
  let fd = u_open file 0x601 in
  fd >= 0 && (let r = u_write fd text in ignore (u_close fd); r = 0)

let edit file =
  let w, h = size () in
  let cols = w / 8 and rows = h / 16 in
  (* (what is under at first: the window's text, all of it drawn over) *)
  drawn := Array.make rows (String.make cols '\000');
  ignore (u_write 3 (d_colour white 255 ^ d_colour black 0));
  let e = create cols rows file (read file) in
  let rec loop () =
    show (view e) (cursor e);
    let k = next () in
    if k >= 0 then begin
      match key e k with
      | Continue -> loop ()
      | Save -> if write file (String.concat "\n" (lines e)) then saved e else say e ("Cannot write " ^ file); loop ()
      | Quit -> ()
    end in
  loop ();
  ignore (u_write 3 (d_fill 0 white 0 0 w h ^ d_free white ^ d_free black))

let () =
  if u_argc () <> 2 then (ignore (u_write 2 "usage: emacs file\n"); exit 1);
  edit (u_arg 1);
  exit 0
