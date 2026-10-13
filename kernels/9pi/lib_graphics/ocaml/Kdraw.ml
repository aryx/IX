(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Kdraw.mli: the OCaml pixels (Memimage, Memdraw, Memlayer, Memfont,
 * Memshape), stage F *)

type image = Memimage.t

let on_screen = Memdraw.hwdraw
let on_refresh = ref (fun (_ : int * int * int * int * int) -> ())

let chan hi lo = match Memchan.make hi lo with Some c -> c | None -> failwith "chan"
let grey1 = 0x31
let grey8 = 0x38
(* RGB16: r5 g6 b5 *)
let rgb16 = chan 0x05 0x1625

(* a 1x1 repl image, its pixel from rgba's halves *)
let huge = (-0x3FFFFFF, -0x3FFFFFF, 0x3FFFFFF, 0x3FFFFFF)
let color c hi lo =
  let i = Memimage.alloc (0, 0, 1, 1) c in
  i.Memimage.repl <- true;
  i.Memimage.clipr <- huge;
  Memimage.fill i hi lo;
  i

(* memimageinit's memwhite (memopaque), memblack; the screen; the
 * default font *)
let white_ = color (chan 0 grey1) 0xffff 0xffff
let black_ = color (chan 0 grey1) 0 0x00ff
let nil = Memimage.alloc (0, 0, 1, 1) (chan 0 grey1)
let screen_ = ref nil
let font = ref None

(* The images' memory (Machine.Imag: principia's imagmem), 48 MB of
 * the machine's pages in one piece, taken at the boot: the screen's
 * copy, each window and each image of a program's (1024 by 768 by 16
 * bits is 1.5 MB, a window of it in 32 bits 3). No piece that size:
 * no arena, and every image is the heap's, as before. *)
let imag_bytes = 48 * 1024 * 1024
let imag_ok = ref false

let init pa w h =
  if not !imag_ok then begin
    match Mmu.kalloc_run (imag_bytes / Mmu.pgsize) with
    | Some base -> Machine.Imag.init base imag_bytes; imag_ok := true
    | None -> ()
  end;
  (* (the screen's own copy of its pixels, in the images' memory: kept) *)
  let i = Memimage.alloc_out (0, 0, w, h) rgb16 in
  let data = { Memimage.bytes = i.Memimage.data.Memimage.bytes; Memimage.onscreen = true; Memimage.keep = true } in
  screen_ := Memimage.alloc_on data (0, 0, w, h) rgb16;
  Machine.Imag.screen data.Memimage.bytes;
  Memimage.framebuffer := (pa, Machine.fb_pitch ());
  Memimage.to_screen := Machine.Phys.write_sub;
  font := Some (Memfont.default ());
  true

let screen () = !screen_
(* is a copy without the kernel's lock writing these pixels of the
 * screen now (Machine.Imag.covers: the cursor's clock asks) *)
let busy (x0, y0, x1, y1) =
  let s = !screen_ in
  let (_, sy0, _, sy1) = s.Memimage.r in
  let y0 = max y0 sy0 and y1 = min y1 sy1 in
  ignore x0; ignore x1;
  y1 > y0 && Machine.Imag.covers ((y0 - sy0) * s.Memimage.bwidth) ((y1 - sy0) * s.Memimage.bwidth)
let white () = white_
let black () = black_
let opaque () = white_

(* d9_color16: its two bytes, its clip the screen *)
let color16 b0 b1 =
  let i = Memimage.alloc (0, 0, 1, 1) rgb16 in
  i.Memimage.repl <- true;
  i.Memimage.clipr <- (!screen_).Memimage.r;
  Bytes.set i.Memimage.data.Memimage.bytes 0 (Char.chr b0);
  Bytes.set i.Memimage.data.Memimage.bytes 1 (Char.chr b1);
  i

(* (old: let free _ = (), the collector's to free) *)
let free i = Memimage.free i
let soverd = 11

let draw dst r src (sx, sy, mx, my) mask = Memlayer.draw dst r src (sx, sy) mask (mx, my) soverd

let getfont () = match !font with Some f -> f | None -> failwith "no font"
let string dst p src s = fst (Memfont.string Memlayer.draw dst p src (0, 0) (getfont ()) s)
let fontheight () = (getfont ()).Memfont.height
let stringwidth s = Memfont.width (getfont ()) s

let alloc r c = Memimage.alloc_out r (if c = 0 then (!screen_).Memimage.chan else chan 0 c)
let load i s = Memimage.load i i.Memimage.r s

let isnil i = i == nil

let screenimage () = let s = !screen_ in Memimage.alloc_on s.Memimage.data s.Memimage.r s.Memimage.chan

let rect a k = (a.(k), a.(k + 1), a.(k + 2), a.(k + 3))

(* 'b': r[4] chan[2] repl clipr[4] value[2] *)
let allocimage a =
  match Memchan.make a.(4) a.(5) with
  | None -> nil
  | Some c ->
      let r = rect a 0 in
      let i = Memimage.alloc_out r c in
      i.Memimage.repl <- a.(6) <> 0;
      i.Memimage.clipr <- rect a 7;
      (* rectclip: unchanged when they do not meet *)
      if a.(6) = 0 then (match Memimage.clip i.Memimage.clipr r with Some cr -> i.Memimage.clipr <- cr | None -> ());
      Memimage.fill i a.(11) a.(12);
      i

let setrepl i = i.Memimage.repl <- true
let setclipr i a = i.Memimage.clipr <- rect a 0

let info i =
  let c = i.Memimage.chan and (x0, y0, x1, y1) = i.Memimage.r and (c0, d0, c1, d1) = i.Memimage.clipr in
  (Memchan.name c, [| c.Memchan.hi; c.Memchan.lo; (if i.Memimage.repl then 1 else 0); x0; y0; x1; y1; c0; d0; c1; d1;
                      c.Memchan.depth; (if i.Memimage.layer <> None then 1 else 0) |])

let drawop dst src mask a = Memlayer.draw dst (rect a 0) src (a.(4), a.(5)) mask (a.(6), a.(7)) a.(8)
(* [| p0[2] p1[2] end0 end1 radius sp[2] op |] *)
let line dst src a = Memshape.line Memlayer.draw dst (a.(0), a.(1)) (a.(2), a.(3)) (a.(4), a.(5), a.(6)) (src, (a.(7), a.(8)), a.(9))

(* [| end0 end1 radius sp[2] op fill n pts[2n] |] *)
let poly dst src a =
  let pts = List.init a.(7) (fun k -> (a.(8 + (2 * k)), a.(9 + (2 * k)))) in
  if a.(6) <> 0 then Memshape.fillpoly Memlayer.draw dst pts a.(0) src (a.(3), a.(4)) a.(5)
  else Memshape.poly Memlayer.draw dst pts (a.(0), a.(1), a.(2)) (src, (a.(3), a.(4)), a.(5));
  0

(* [| c[2] a b thick sp[2] op arc alpha phi |] *)
let ellipse dst src a =
  if a.(8) <> 0 then Memshape.arc Memlayer.draw dst (a.(0), a.(1)) (a.(2), a.(3), a.(4)) (src, (a.(5), a.(6)), a.(7)) (a.(9), a.(10))
  else Memshape.ellipse Memlayer.draw dst (a.(0), a.(1)) (a.(2), a.(3), a.(4)) (src, (a.(5), a.(6)), a.(7))

let memload dst a data = Memlayer.load dst (rect a 0) data (a.(4) <> 0)

let unload i a = Memimage.unload i (rect a 0)

type memscreen = Memimage.lscreen
let memscreen image fill = Memlayer.screen image fill
let freememscreen _ = ()
let memscreenchan s = let c = s.Memimage.simage.Memimage.chan in (c.Memchan.hi, c.Memchan.lo)
(* 'b' on a screen: r[4] refresh clipr[4] value[2] (every window backed:
 * its refresh ignored) *)
let lalloc s a = Memlayer.alloc s (rect a 0) (rect a 5) a.(9) a.(10)
let lsetrefresh _ _ = ()
let layerinfo w =
  match w.Memimage.layer with
  | Some l -> let (x0, y0, x1, y1) = l.Memimage.screenr in [| 0; x0; y0; x1; y1; 1 |]
  | None -> [| 0; 0; 0; 0; 0; 0 |]
let lfree w delete = (if delete then Memlayer.delete w else Memlayer.free w); Memimage.free w
let ltofront ws front =
  let l = Array.to_list ws in
  match l with
  | [] -> 0
  | w :: _ when w.Memimage.layer = None -> -1
  | w :: rest ->
      let s = (match w.Memimage.layer with Some l -> l.Memimage.lscr | None -> failwith "") in
      if List.exists (fun x -> match x.Memimage.layer with Some l -> l.Memimage.lscr != s | None -> true) rest then -2
      else begin (if front then Memlayer.tofront l else Memlayer.torear l); 0 end
let lorigin w a = if w.Memimage.layer = None then -1 else Memlayer.origin w (a.(0), a.(1)) (a.(2), a.(3))
