(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Swconsole.mli *)

(* (it was 640 by 480, 9pi's default under QEMU, until 2026-10-08: the
 * author, of mini-drscheme's letters on his Pi1, "the text is hard to
 * read"; "1024x768 sounds right". A playground's program has the
 * square of the height: 768, where a letter's cell is the default
 * font's, 9 by 15.) *)
let wid = 1024 and ht = 768 and depth = 16

(* the display's own size, asked before the framebuffer (Machine.display_size);
 * said at boot by Main when it is not an emulator's 640 by 480 *)
let display = ref 0
let scroll_lines = 8
let tabstop = 4

let screen_r = ref None
let rect () = !screen_r

(* the console's window and its cursor *)
let win = ref (0, 0, 0, 0)
let cur = ref (0, 0)
let h = ref 0

let inset (x0, y0, x1, y1) n = (x0 + n, y0 + n, x1 - n, y1 - n)

let fill r img = Kdraw.draw (Kdraw.screen ()) r img (0, 0, 0, 0) (Kdraw.opaque ())

(* the default font's s at (x, y), in black *)
let text (x, y) s =
  ignore (Kdraw.string (Kdraw.screen ()) (x, y) (Kdraw.black ()) s)

(* the positions a backspace goes back to (xbuf) *)
let xbuf = ref []

let scroll () =
  let (x0, y0, x1, y1) = !win in
  let o = scroll_lines * !h in
  Kdraw.draw (Kdraw.screen ()) (x0, y0, x1, y1 - o) (Kdraw.screen ()) (x0, y0 + o, x0, y0 + o) (Kdraw.opaque ());
  fill (x0, y1 - o, x1, y1) (Kdraw.white ());
  let (cx, cy) = !cur in
  cur := (cx, cy - o)

let rec putc s =
  let (x0, _, x1, y1) = !win in
  let (cx, cy) = !cur in
  match s with
  | "\n" ->
      if cy + !h >= y1 then scroll ();
      let (cx, cy) = !cur in
      cur := (cx, cy + !h);
      putc "\r"
  | "\r" -> xbuf := []; cur := (x0, cy)
  | "\t" ->
      let w = Kdraw.stringwidth " " in
      if cx >= x1 - (tabstop * w) then putc "\n";
      let (cx, cy) = !cur in
      let pos = tabstop - (((cx - x0) / w) mod tabstop) in
      xbuf := cx :: !xbuf;
      fill (cx, cy, cx + (pos * w), cy + !h) (Kdraw.white ());
      cur := (cx + (pos * w), cy)
  | "\b" ->
      (match !xbuf with
       | [] -> ()
       | x :: rest ->
           xbuf := rest;
           fill (x, cy, cx, cy + !h) (Kdraw.white ());
           cur := (x, cy))
  | "\000" -> ()
  | _ ->
      let w = Kdraw.stringwidth s in
      if cx >= x1 - w then putc "\n";
      let (cx, cy) = !cur in
      xbuf := cx :: !xbuf;
      fill (cx, cy, cx + w, cy + !h) (Kdraw.white ());
      text (cx, cy) s;
      cur := (cx + w, cy)

(* the bytes of a rune gathered (screenputs' chartorune) *)
let pending = Buffer.create 4

let need c = if c < 0x80 then 1 else if c land 0xe0 = 0xc0 then 2 else if c land 0xf0 = 0xe0 then 3 else 1

let putbyte ch =
  Buffer.add_char pending ch;
  let s = Buffer.contents pending in
  if String.length s >= need (Char.code s.[0]) then begin
    Buffer.clear pending;
    (* the screen's lock: the clock's cursor stays still meanwhile *)
    Swcursor.drawlock := true;
    (try putc s with e -> Swcursor.drawlock := false; raise e);
    Swcursor.drawlock := false
  end

(* screenwin: the title bar, the window below it *)
let screenwin () =
  let orange = Kdraw.color16 0x40 0xfd in
  let (x0, y0, x1, _) = !win in
  Kdraw.draw (Kdraw.screen ()) (x0, y0, x1, y0 + !h + 5 + 6) orange (0, 0, 0, 0) (Kdraw.opaque ());
  Kdraw.free orange;
  win := inset !win 5;
  let (x0, y0, x1, y1) = !win in
  text (x0 + 10, y0) " Plan 9 Console ";
  let y0 = y0 + !h + 6 in
  cur := (x0, y0);
  win := (x0, y0, x1, y0 + (((y1 - y0) / !h) * !h))

let init () =
  display := Machine.display_size ();
  let pa = Machine.fb_init wid ht depth in
  if pa <> 0 && Kdraw.init pa wid ht then begin
    screen_r := Some (0, 0, wid, ht);
    h := Kdraw.fontheight ();
    (* fbinit's "blue screen": its memory all 0x7F (the margin outside
     * the frame keeps it) *)
    let blue = Kdraw.color16 0x7f 0x7f in
    fill (0, 0, wid, ht) blue;
    Kdraw.free blue;
    (* swconsole_init: the frame, the window *)
    let r = inset (0, 0, wid, ht) 4 in
    fill r (Kdraw.black ());
    win := inset r 4;
    fill !win (Kdraw.white ());
    screenwin ();
    Machine.screen := putbyte
  end
