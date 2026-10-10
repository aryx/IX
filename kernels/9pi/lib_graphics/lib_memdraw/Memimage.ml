(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Memimage.mli *)

type rect = int * int * int * int

type data = { mutable bytes : Bytes.t; onscreen : bool }

type t = {
  data : data; mutable r : rect; mutable clipr : rect; mutable repl : bool; chan : Memchan.t;
  bwidth : int; org : int * int; xbase : int; mutable layer : layer option }
and layer = { lscr : lscreen; mutable screenr : rect }
and lscreen = { simage : t; sfill : t; mutable wins : t list }

(* OPTIMIZATION: max and min on ints. The Stdlib's are polymorphic: each
 * a call to compare_val, the C of OCaml's structural comparison (3% of
 * the kernel's time drawing a console, clip being called several times
 * a draw); on ints the compiler inlines a comparison, 2 instructions.
 * old: max and min (Stdlib's) *)
let max (a : int) b = if a > b then a else b
let min (a : int) b = if a < b then a else b

let clip (x0, y0, x1, y1) (a0, b0, a1, b1) =
  let r = (max x0 a0, max y0 b0, min x1 a1, min y1 b1) in
  let (c0, d0, c1, d1) = r in
  if c0 < c1 && d0 < d1 then Some r else None

let inside (x0, y0, x1, y1) (a0, b0, a1, b1) = a0 <= x0 && x1 <= a1 && b0 <= y0 && y1 <= b1

(* OPTIMIZATION: no division, shifts. Every division here is by a power
 * of 2 (8 bits a byte, 32 a word), and the Pi1's ARMv6 has no divide
 * instruction: each / or mod is a call to libgcc's __aeabi_idivmod, a
 * loop of tens of instructions. byteaddr, called per row of every draw
 * and (before Memdraw's character path computed its rows' addresses
 * once) per pixel of every character, divided by 8: __aeabi_idivmod
 * was 38% of the kernel's time drawing a console, rio unusable. An
 * arithmetic shift right floors, negative numbers included (the
 * layout's x can be negative: a window's origin moved), as fdiv did.
 *
 * old, floor and ceiling of a / b, b > 0:
 *   let fdiv a b = if a >= 0 then a / b else - ((- a + b - 1) / b)
 *   let cdiv a b = - (fdiv (- a) b)
 *   (units ... bits: cdiv (x1 * depth) bits - fdiv (x0 * depth) bits;
 *    byteaddr: ... + fdiv (lx * depth) 8 - img.xbase)
 * now floor and ceiling of a / 2^sh: *)
let fshr a sh = a asr sh
let cshr a sh = - ((- a) asr sh)
(* the byte of bit a in a row: fdiv a 8 *)
let bytex a = a asr 3

(* unitsperline's: the units of 2^sh bits covering a row's pixels *)
let units (x0, _, x1, _) depth sh = cshr (x1 * depth) sh - fshr (x0 * depth) sh

let make data r chan =
  let (x0, y0, _, y1) = r in
  let bwidth = 4 * units r chan.Memchan.depth 5 in
  let data = match data with Some d -> d | None -> { bytes = Bytes.make (bwidth * (y1 - y0)) '\000'; onscreen = false } in
  { data = data; r = r; clipr = r; repl = false; chan = chan; bwidth = bwidth; org = (x0, y0);
    xbase = bytex (x0 * chan.Memchan.depth); layer = None }

let alloc r chan = make None r chan
let alloc_on data r chan = make (Some data) r chan

(* a point in the layout's coordinates (a window's r moved: memlorigin) *)
let layout img x y = let (x0, y0, _, _) = img.r and (ox, oy) = img.org in (x - x0 + ox, y - y0 + oy)

let byteaddr img x y =
  let (lx, ly) = layout img x y and (_, oy) = img.org in
  (* old: ((ly - oy) * img.bwidth) + fdiv (lx * img.chan.Memchan.depth) 8 - img.xbase *)
  ((ly - oy) * img.bwidth) + bytex (lx * img.chan.Memchan.depth) - img.xbase

let framebuffer = ref (0, 0)
(* how the framebuffer's memory is written (the kernel's: Kdraw says) *)
let to_screen = ref (fun (_ : int) (_ : string) (_ : int) (_ : int) -> ())

let flush img (x0, y0, x1, y1) =
  if img.data.onscreen then begin
    let (pa, pitch) = !framebuffer in
    let a = byteaddr img x0 y0 and b = byteaddr img x1 y0 in
    for y = y0 to y1 - 1 do
      let o = (y - y0) * img.bwidth in
      (* OPTIMIZATION: the row written from where it is in the image's
       * bytes, not copied out first. A flush follows every draw, and a
       * scroll's or a window's covers the whole screen: 480 rows of
       * 1280 bytes, each String.sub a new string, too big for the minor
       * heap, so allocated in the major heap, then marked and swept:
       * memmove (the copy, twice) and the major GC (mark_slice,
       * sweep_slice) were 14% of the kernel's time drawing a console.
       * old: Machine.Phys.write (...) (String.sub img.data.bytes (a + o) (b - a)) *)
      !to_screen (pa + (y * pitch) + bytex (x0 * img.chan.Memchan.depth)) (Bytes.unsafe_to_string img.data.bytes) (a + o) (b - a)
    done
  end

let get s i = if i >= 0 && i < Bytes.length s then Char.code (Bytes.unsafe_get s i) else 0

(* a channel's raw bits in a pixel of 8 bits or more, at byte p *)
let field s p (_, n, sh) =
  let b = p + (sh lsr 3) in
  ((get s b lor (get s (b + 1) lsl 8)) lsr (sh land 7)) land ((1 lsl n) - 1)

(* (off: every pixel read by its chan's channels, one after the other) *)
let fast_read = ref true

let read img x y =
  let c = img.chan and s = img.data.bytes in
  let p = byteaddr img x y in
  let d = c.Memchan.depth in
  (* OPTIMIZATION: a pixel of r8g8b8a8, its four bytes: the format of
   * the colours a program makes (an image of one pixel, repeated), and
   * a fill reads its colour and its mask's, a game's frame hundreds of
   * times (docs/plans/plan_playground_speed.md) *)
  if !fast_read && c.Memchan.hi = 0x0818 && c.Memchan.lo = 0x2848 then (get s (p + 3), get s (p + 2), get s (p + 1), get s p)
  else
  if d < 8 then begin
    (* readnbit: the value replicated, grey whatever the channel *)
    let v = (get s p lsr (8 - d - ((fst (layout img x y) * d) land 7))) land ((1 lsl d) - 1) in
    let k = Memchan.repl d v in
    (k, k, k, 255)
  end else begin
    let r = ref 0 and g = ref 0 and b = ref 0 and a = ref 255 in
    List.iter (fun ((t, n, _) as ch) ->
      let v = field s p ch in
      if t = Memchan.cred then r := Memchan.repl n v
      else if t = Memchan.cgreen then g := Memchan.repl n v
      else if t = Memchan.cblue then b := Memchan.repl n v
      else if t = Memchan.cgrey then begin let k = Memchan.repl n v in r := k; g := k; b := k end
      else if t = Memchan.calpha then a := Memchan.repl n v
      else if t = Memchan.cmapped then begin let (cr, cg, cb) = Memchan.cmap2rgb v in r := cr; g := cg; b := cb end) c.Memchan.chans;
    (!r, !g, !b, !a)
  end

let set s i v = if i >= 0 && i < Bytes.length s then Bytes.unsafe_set s i (Char.unsafe_chr v)

let write img x y (r, g, b, a) k =
  let c = img.chan and s = img.data.bytes in
  let p = byteaddr img x y in
  let d = c.Memchan.depth in
  if d < 8 then begin
    (* writenbit: the grey's top bits *)
    let sh = 8 - d - ((fst (layout img x y) * d) land 7) and m = (1 lsl d) - 1 in
    set s p ((get s p land lnot (m lsl sh)) lor ((k lsr (8 - d)) lsl sh))
  end else begin
    (* writebyte (writecmap): the channels' top bits, ignored ones 0; as
     * two 16-bit halves (a Pi1 int has 31 bits) *)
    let lo = ref 0 and hi = ref 0 in
    List.iter (fun (t, n, sh) ->
      let v =
        if t = Memchan.cred then r lsr (8 - n) else if t = Memchan.cgreen then g lsr (8 - n)
        else if t = Memchan.cblue then b lsr (8 - n) else if t = Memchan.cgrey then k lsr (8 - n)
        else if t = Memchan.calpha then a lsr (8 - n) else if t = Memchan.cmapped then Memchan.rgb2cmap r g b
        else 0 in
      if sh >= 16 then hi := !hi lor (v lsl (sh - 16))
      else begin let w = v lsl sh in lo := !lo lor (w land 0xffff); hi := !hi lor (w lsr 16) end) c.Memchan.chans;
    set s p (!lo land 255);
    if d > 8 then set s (p + 1) (!lo lsr 8);
    if d > 16 then set s (p + 2) (!hi land 255);
    if d > 24 then set s (p + 3) (!hi lsr 8)
  end

(* memfillcolor: rgbatoimg's pixel, its pattern over every row's bytes
 * (a small depth's value repeated in each byte), DNofill (0xFFFFFF00)
 * none *)
(* a pixel's bytes in img's chan (depth >= 8), from 8-bit channels (k
 * the grey); a smaller depth's byte of the value repeated *)
(* (off: a pattern always by an image of one pixel, written) *)
let fast_pattern = ref true

let pattern img rgba k =
  let d = img.chan.Memchan.depth in
  (* OPTIMIZATION: the screen's format (r5g6b5) has its two bytes
   * computed here, the channels' top bits as [write] keeps them: a fill
   * asks for a pattern, and a game's frame is hundreds of fills, each
   * of which allocated an image for it
   * (docs/plans/plan_playground_speed.md). *)
  if !fast_pattern && img.chan.Memchan.hi = 0x0005 && img.chan.Memchan.lo = 0x1625 then begin
    let (r, g, b, _) = rgba in
    let v = ((r lsr 3) lsl 11) lor ((g lsr 2) lsl 5) lor (b lsr 3) in
    let s = Bytes.create 2 in
    Bytes.unsafe_set s 0 (Char.unsafe_chr (v land 255));
    Bytes.unsafe_set s 1 (Char.unsafe_chr (v lsr 8));
    Bytes.unsafe_to_string s
  end else
  let npx = if d < 8 then 8 / d else 1 in
  let one = alloc (0, 0, npx, 1) img.chan in
  for x = 0 to npx - 1 do write one x 0 rgba k done;
  Bytes.sub_string one.data.bytes 0 (max 1 (d asr 3))

(* OPTIMIZATION: [repeat pat len], pat's bytes repeated over len bytes,
 * by doubling: pat copied, then what is there copied after itself, twice
 * as much each time, so log2(len / |pat|) blits (each a memmove, a word
 * at a time). Before, a byte at a time, each index a mod |pat|, a
 * division: memdraw's fills (a console's background, rio's windows) and
 * memfillcolor built their rows that way.
 * old: for i = 0 to len - 1 do String.unsafe_set s i pat.[i mod n] done *)
let repeat pat len =
  let n = String.length pat in
  let s = Bytes.create len in
  Bytes.blit_string pat 0 s 0 (min n len);
  let k = ref n in
  while !k < len do let m = min !k (len - !k) in Bytes.blit s 0 s !k m; k := !k + m done;
  Bytes.unsafe_to_string s

let fill img hi lo =
  if not (hi = 0xffff && lo = 0xff00) then begin
    let r = hi lsr 8 and g = hi land 255 and b = lo lsr 8 and a = lo land 255 in
    let pat = pattern img (r, g, b, a) (Memchan.rgb2k r g b) in
    let s = img.data.bytes in
    (* OPTIMIZATION: one row of the pattern made (repeat), then blitted
     * into each row: 2 divisions a byte before (the Pi1 has no divide
     * instruction), 1.2 million of them for a 640x480 screen at 16 bits.
     * old: for i = 0 to String.length s - 1 do String.unsafe_set s i pat.[(i mod img.bwidth) mod n] done *)
    let row = repeat pat img.bwidth in
    for y = 0 to (Bytes.length s / img.bwidth) - 1 do Bytes.blit_string row 0 s (y * img.bwidth) img.bwidth done
  end

let bytesperline r d = units r d 3

(* loadmemimage: a row's edge bytes merged when r does not start or
 * end on a byte (a small depth) *)
(* (off: every row a byte at a time) *)
let fast_load = ref true

let load img r data =
  let (x0, y0, x1, y1) = r in
  let l = bytesperline r img.chan.Memchan.depth in
  if not (inside r img.r) || String.length data < l * (y1 - y0) then -1
  else begin
    let d = img.chan.Memchan.depth in
    let mx = 7 / d in
    let lpart = (x0 land mx) * d and rpart = (x1 land mx) * d in
    let m = 0xff lsr lpart and mr = 0xff lxor (0xff lsr rpart) in
    let s = img.data.bytes in
    let merge q v mask = set s q (get s q lxor ((v lxor get s q) land mask)) in
    for y = y0 to y1 - 1 do
      let q = byteaddr img x0 y and o = (y - y0) * l in
      let v i = Char.code data.[o + i] in
      (* OPTIMIZATION: a row whose pixels are whole bytes is one blit (a
       * memmove), not a byte at a time through set and get, which check
       * each index: a picture of 480 by 480 at 32 bits, 921,600 bytes,
       * took 0.09 s of a frame under QEMU
       * (docs/plans/plan_playground_speed.md, K1). The loop below is the
       * simple way, and the small depths' (their rows' ends share a
       * byte with what is beside them). *)
      if !fast_load && lpart = 0 && rpart = 0 && q >= 0 && q + l <= Bytes.length s then Bytes.blit_string data o s q l
      else if l = 1 then merge q (v 0) (if rpart <> 0 then m lxor (0xff lsr rpart) else m)
      else begin
        let first = if lpart <> 0 then 1 else 0 and last = if rpart <> 0 then l - 2 else l - 1 in
        if lpart <> 0 then merge q (v 0) m;
        for i = first to last do set s (q + i) (v i) done;
        if rpart <> 0 then merge (q + l - 1) (v (l - 1)) mr
      end
    done;
    l * (y1 - y0)
  end

let unload img r =
  let (x0, y0, _, y1) = r in
  let l = bytesperline r img.chan.Memchan.depth in
  String.concat "" (List.map (fun y -> Bytes.sub_string img.data.bytes (byteaddr img x0 y) l) (List.init (y1 - y0) (fun i -> y0 + i)))

(* the compressed form (image(6)): a byte c >= 128 then c-127 bytes as
 * they are; else a match: (c>>2)+3 bytes from (c&3)<<8 | next + 1 back
 * in the last 1024 *)
let nmem = 1024 and nmatch = 3

let cload img r data =
  let (x0, y0, _, y1) = r in
  if not (inside r img.r) then -1
  else begin
    let bpl = bytesperline r img.chan.Memchan.depth in
    let s = img.data.bytes and n = String.length data in
    let mem = Bytes.make nmem '\000' and memp = ref 0 in
    let u = ref 0 and y = ref y0 in
    let line = ref (byteaddr img x0 y0) in
    let eline = ref (!line + bpl) in
    let out v = set s !line v; incr line; Bytes.unsafe_set mem !memp (Char.unsafe_chr v); memp := (!memp + 1) mod nmem in
    let rec go () =
      if !line = !eline && (incr y; !y = y1) then !u
      else begin
        if !line = !eline then begin line := byteaddr img x0 !y; eline := !line + bpl end;
        if !u >= n then -1
        else begin
          let c = Char.code data.[!u] in
          incr u;
          if c >= 128 then begin
            let rec run k = if k = 0 then true else if !u >= n || !line = !eline then false
              else begin out (Char.code data.[!u]); incr u; run (k - 1) end in
            if run (c - 127) then go () else -1
          end else if !u >= n then -1
          else begin
            let offs = Char.code data.[!u] + ((c land 3) lsl 8) + 1 in
            incr u;
            let om = ref ((!memp - offs + nmem) mod nmem) in
            let rec copy k = if k = 0 then true else if !line = !eline then false
              else begin let v = Char.code (Bytes.get mem !om) in om := (!om + 1) mod nmem; out v; copy (k - 1) end in
            if copy ((c lsr 2) + nmatch) then go () else -1
          end
        end
      end in
    go ()
  end
