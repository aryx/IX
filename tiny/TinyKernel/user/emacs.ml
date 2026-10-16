(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* emacs, a program of TinyKernel.ml's: ../../TinyEditorScreen.ml, the editor,
 * on a screen and a file of tiny-kernel's (given to tiny-ml after
 * ../libml/calls.ml, ../../TinyLibStd.ml, ../../TinyLibDraw.ml and
 * TinyEditorScreen.ml, as one program: the Makefile).
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
 * are 128 to 131. The console is raw while emacs runs (rawcons): its
 * ^C is C-x C-c's, not the kill of every process. The file is the
 * kernel's, in its memory: what is saved is there until the machine
 * stops. A file of OCaml or C is drawn in colors, a line a piece of
 * one color at a time (the editor's faces); /examples has some to try
 * (emacs /examples/emacs.ml: this file). Not OCaml's to compile: it
 * names the kernel's calls, calls.ml's externals. *)
open TinyEditorScreen
open TinyLibDraw

(* our images: 0 is the window, 1 white, 2 black; and the colors of a
 * file of OCaml or C (faces), of the machine's palette: Emacs's purple
 * keywords and dark red comments, green strings *)
let white = 1
let black = 2
let keyword = 3
let comment = 4
let quoted = 5

let ink face = if face = 'k' then keyword else if face = 'c' then comment else if face = 's' then quoted else black

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

(* the faces drawn, a line's (its colors: "" when it has none) *)
let colored = ref (Array.make 0 "")

let face_at f k = if k < String.length f then f.[k] else '.'

(* the columns that changed in the text or in its colors (typing the
 * start of a comment colors the lines below it, their text the same) *)
let either (a, b) (c, d) = if a = b then c, d else if c = d then a, b else min a c, max b d

(* the messages that draw line i's characters from k up to e, l its
 * text and f its faces, a piece of one color at a time, put on m (the
 * last first: they are joined once, by the editor's join) *)
let rec pieces m i l f e k =
  if k < e then begin
    let c = face_at f k in
    let rec stop j = if j < e && face_at f j = c then stop (j + 1) else j in
    let j = stop (k + 1) in
    m := d_text 0 (ink c) (k * 8) (i * 16) (String.sub l k (j - k)) :: !m;
    pieces m i l f e j
  end

(* line i's columns from a up to b: white, then its characters. (Out
 * of show: tiny-ml loads each value a closure takes, in tiny-machine's
 * 11 registers) *)
let draw m i l f a b =
  if a < b then (m := d_fill 0 white (a * 8) (i * 16) (b * 8) ((i * 16) + 16) :: !m; pieces m i l f (min b (String.length l)) a)

let show lines faces (col, row) =
  let d = !drawn and fd = !colored and m = ref [] and was_col, was_row = !was in
  List.iteri (fun i l ->
    if i < Array.length d then begin
      let f = if i < List.length faces then List.nth faces i else "" in
      let a, b = either (changed d.(i) l) (changed fd.(i) f) in
      d.(i) <- l;
      fd.(i) <- f;
      draw m i l f a b;
      if i = was_row && (was_row <> row || was_col <> col) then draw m i l f was_col (was_col + 1);
      if i = row then begin
        let c = if col < String.length l then String.sub l col 1 else " " in
        m := d_text 0 white (col * 8) (i * 16) c :: d_fill 0 black (col * 8) (i * 16) ((col * 8) + 8) ((i * 16) + 16) :: !m
      end
    end) lines;
  was := (col, row);
  ignore (u_write 3 (join (List.rev !m)))

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
  colored := Array.make rows "";
  ignore (u_write 3 (d_colour white 255 ^ d_colour black 0 ^ d_colour keyword 128 ^ d_colour comment 160 ^ d_colour quoted 8));
  let e = create cols rows file (read file) in
  let rec loop () =
    (* the keys the editor gives itself first; the screen once they are done *)
    let k = match pending e with Some k -> k | None -> let v = view e in show v (faces e) (cursor e); next () in
    if k >= 0 then begin
      match key e k with
      | Continue -> loop ()
      | Save -> if write file (String.concat "\n" (lines e)) then saved e else say e ("Cannot write " ^ file); loop ()
      | Quit -> ()
    end in
  loop ();
  ignore (u_write 3 (d_fill 0 white 0 0 w h ^ d_free white ^ d_free black ^ d_free keyword ^ d_free comment ^ d_free quoted))

(* the console raw while editing: its ^C is a key, C-x C-c's, not the
 * kill of every process *)
let () =
  if u_argc () <> 2 then (ignore (u_write 2 "usage: emacs file\n"); exit 1);
  ignore (u_rawcons 1);
  edit (u_arg 1);
  ignore (u_rawcons 0);
  exit 0
