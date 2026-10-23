(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Memdraw.mli *)

open Memimage

type rect = Memimage.rect

let hwdraw = ref (fun (_ : rect) -> ())

let replxy min max x =
  let sx = (x - min) mod (max - min) in
  (if sx < 0 then sx + max - min else sx) + min

let w (x0, _, x1, _) = x1 - x0
let h (_, y0, _, y1) = y1 - y0

(* drawclip: r, sr, mr, all the same size, sr's and mr's corners in src
 * and mask (a repl one's moved there); None when nothing is left *)
let drawclip dst r src (px, py) mask (qx, qy) =
  let (rx0, ry0, _, _) = r in
  match clip r dst.r with
  | None -> None
  | Some r -> (
      match clip r dst.clipr with
      | None -> None
      | Some r ->
          let (ax, ay, _, _) = r in
          let px = px + ax - rx0 and py = py + ay - ry0 in
          let qx = qx + ax - rx0 and qy = qy + ay - ry0 in
          let sr = (px, py, px + w r, py + h r) in
          let ( >>= ) o f = match o with None -> None | Some v -> f v in
          (if src.repl then Some sr else clip sr src.r) >>= fun sr ->
          clip sr src.clipr >>= fun sr ->
          let (sx0, sy0, sx1, sy1) = sr in
          (if (px, py) <> (qx, qy) then begin
             (* the mask's own corner, moved with the source's clip *)
             let qx = qx + sx0 - px and qy = qy + sy0 - py in
             let omr = (qx, qy, qx + (sx1 - sx0), qy + (sy1 - sy0)) in
             (if mask.repl then Some omr else clip omr mask.r) >>= fun mr ->
             clip mr mask.clipr >>= fun mr ->
             let (a0, b0, a1, b1) = omr and (m0, n0, m1, n1) = mr in
             Some ((sx0 + m0 - a0, sy0 + n0 - b0, sx1 + m1 - a1, sy1 + n1 - b1), (m0, n0))
           end else
             (if mask.repl then Some sr else clip sr mask.r) >>= fun sr ->
             clip sr mask.clipr >>= fun sr ->
             let (a, b, _, _) = sr in Some (sr, (a, b))) >>= fun (sr, (qx, qy)) ->
          let (s0, t0, s1, t1) = sr in
          let r = (s0 + ax - px, t0 + ay - py, s1 + ax - px, t1 + ay - py) in
          let dx = if src.repl then let (a, _, b, _) = src.r in replxy a b s0 - s0 else 0 in
          let dy = if src.repl then let (_, a, _, b) = src.r in replxy a b t0 - t0 else 0 in
          let sr = (s0 + dx, t0 + dy, s1 + dx, t1 + dy) in
          let (m0, _, m1, _) = mask.r and (_, n0, _, n1) = mask.r in
          let mp = (replxy m0 m1 qx, replxy n0 n1 qy) in
          Some (r, sr, (fst mp, snd mp, fst mp + (s1 - s0), snd mp + (t1 - t0))))

(* (the general loop, every pixel read, composed and written, with its
 * arithmetic and the ops' numbers: Memgeneral, a file of its own that
 * a machine's host can run too) *)
open Memgeneral

(*****************************************************************************)
(* Faster paths: the general loop's pixels, sooner *)
(*****************************************************************************)

(* memdraw's memoptdraw and chardraw, for the common cases: a
 * solid colour filled (a console's background, rio's rectangles), an
 * image copied to one of its chan (a window to its screen), a picture
 * of 32 bits a pixel to a screen of 16, a solid colour through a 1-bit
 * mask (a character) or a mask of a byte (a smoothed one). The general
 * loop reads,
 * composes and writes each pixel: 19 times slower than 9pi's C to
 * boot under mini-qemu (323s to rc's prompt, the C 17s). Off
 * ([fast] false), the general loop does them all. *)
let fast = ref true

let single img = img.repl && w img.r = 1 && h img.r = 1
let corner img = let (x0, y0, _, _) = img.r in (x0, y0)
let opaque mask = single mask && (let (x, y) = corner mask in coverage mask (read mask x y)) = 255

(* a row of dx pixels of pat's bytes *)
(* old: let s = String.create (dx * n) in
 *   for i = 0 to (dx * n) - 1 do String.unsafe_set s i pat.[i mod n] done; s
 * (a division a byte: see Memimage.repeat) *)
let row pat dx = repeat pat (dx * String.length pat)

(* a narrow fill's rows written by the machine (kernels/lib_machine's
 * runtime.c: mem_rows); off: by the loops here *)
let fast_rows = ref true
external rows : Bytes.t -> int -> int -> int -> string -> unit = "mem_rows"

(* an image of bits through a mask of bits, below; off: by the general
 * loop *)
let fast_bits = ref true

(* a colour through a mask of a byte a pixel, below; off: by the
 * general loop *)
let fast_grey = ref true

(* its blends: a coverage's, over which pixel, of which colour *)
let over = Array.make 256 (-1) and made = Array.make 256 0 and blended = ref (-1)

let faster dst r src sr mask mr op =
  let d = dst.chan.Memchan.depth in
  let (x0, y0, _, _) = r and dx = w r and dy = h r in
  if d < 8 then false
  else
  (* the colour of a fill, read once (old: read to see that it is
   * opaque, then again to fill) *)
  let colour =
    if single src && (op = o_s || op = o_soverd) && opaque mask then begin
      let (x, y) = corner src in
      let (_, _, _, a) as c = read src x y in
      if op = o_s || a = 255 then Some c else None
    end
    else None in
  match colour with
  | Some (cr, cg, cb, ca) ->
    (* a fill: the colour's bytes, row after row *)
    let k = if src.chan.Memchan.grey || src.chan.Memchan.depth < 8 then cr else Memchan.rgb2k cr cg cb in
    (* (a narrow one of the screen's 16 bits, below, asks for the
     * pixel's two bytes only: no row of them made) *)
    let pat = pattern dst (cr, cg, cb, ca) k in
    let bytes = if d = 16 && dx <= 4 && not !fast_rows then pat else row pat dx in
    (* OPTIMIZATION: a row's address is the one before and the image's
     * bytes a row (not byteaddr again, its layout a tuple, each row);
     * and a narrow fill (16 bytes: a game's column of 3 pixels, 200
     * rows high, a hundred of them a frame) sets its bytes here, a
     * blit being a call of C for each row.
     * old: for j = 0 to dy - 1 do String.blit bytes 0 dst.data.bytes (byteaddr dst x0 (y0 + j)) (String.length bytes) done *)
    let ds = dst.data.bytes and len = dx * String.length pat and bw = dst.bwidth in
    let a0 = byteaddr dst x0 y0 in
    if a0 < 0 || a0 + ((dy - 1) * bw) + len > Bytes.length ds then begin
      let bytes = row pat dx in
      for j = 0 to dy - 1 do Bytes.blit_string bytes 0 ds (byteaddr dst x0 (y0 + j)) len done
    end
    else if !fast_rows && len <= 16 then
      (* (the rows by the machine's C, two bytes a store: mem_rows; the
       * two loops below are OCaml's, a byte a store) *)
      rows ds a0 bw dy bytes
    else if d = 16 && dx <= 4 then begin
      let len = 2 * dx in
      (* (one to four pixels of the screen's 16 bits, a game's wall's
       * column: the pixel's two bytes read once, each row a pair of
       * stores a pixel; the loop below, a byte read and stored a turn,
       * was a fifth of all the time under such a game) *)
      let c0 = String.unsafe_get bytes 0 and c1 = String.unsafe_get bytes 1 in
      let a = ref a0 in
      for j = 1 to dy do
        ignore j;
        let p = !a in
        Bytes.unsafe_set ds p c0; Bytes.unsafe_set ds (p + 1) c1;
        if len > 2 then begin
          Bytes.unsafe_set ds (p + 2) c0; Bytes.unsafe_set ds (p + 3) c1;
          if len > 4 then begin
            Bytes.unsafe_set ds (p + 4) c0; Bytes.unsafe_set ds (p + 5) c1;
            if len > 6 then begin Bytes.unsafe_set ds (p + 6) c0; Bytes.unsafe_set ds (p + 7) c1 end
          end
        end;
        a := p + bw
      done
    end
    else if len <= 16 then
      for j = 0 to dy - 1 do
        let a = a0 + (j * bw) in
        for i = 0 to len - 1 do Bytes.unsafe_set ds (a + i) (String.unsafe_get bytes i) done
      done
    (* (the first row, then the others from it by the machine: one
     * call, the kernel's lock given back when the image is the
     * arena's: Machine.Imag.rows.
     * old: for j = 0 to dy - 1 do Bytes.blit_string bytes 0 ds (a0 + (j * bw)) len done) *)
    else begin Bytes.blit_string bytes 0 ds a0 len; if dy > 1 then Machine.Imag.rows ds a0 bw len dy end;
    true
  | None ->
  if not src.repl && opaque mask && src.chan.Memchan.hi = dst.chan.Memchan.hi && src.chan.Memchan.lo = dst.chan.Memchan.lo
          && (op = o_s || (op = o_soverd && not src.chan.Memchan.alpha)) then begin
    (* a copy: each row's bytes (bottom up when the rows overlap) *)
    let (sx0, sy0, _, _) = sr in
    let up = src.data == dst.data && byteaddr dst x0 y0 > byteaddr src sx0 sy0 in
    (* (the two rows' addresses by adding, as the fill's;
     * old: String.blit src.data.bytes (byteaddr src sx0 (sy0 + j)) dst.data.bytes (byteaddr dst x0 (y0 + j)) (dx * (d asr 3))) *)
    let sa = byteaddr src sx0 sy0 and da = byteaddr dst x0 y0 and n = dx * (d asr 3) in
    (* (the rows by the machine, one call, the kernel's lock given
     * back when both are the arena's: Machine.Imag.copy; when a row
     * is not all inside its image, as before, where a blit refuses.
     * old: the loop, for all) *)
    if n > 0 && dy > 0 && sa >= 0 && da >= 0 && sa + ((dy - 1) * src.bwidth) + n <= Bytes.length src.data.bytes
       && da + ((dy - 1) * dst.bwidth) + n <= Bytes.length dst.data.bytes then
      Machine.Imag.copy dst.data.bytes src.data.bytes [| da; dst.bwidth; sa; src.bwidth; n; dy; (if up then 1 else 0) |]
    else
    for j = 0 to dy - 1 do
      let j = if up then dy - 1 - j else j in
      Bytes.blit src.data.bytes (sa + (j * src.bwidth)) dst.data.bytes (da + (j * dst.bwidth)) n
    done;
    true
  end
  else if not src.repl && opaque mask && src.data != dst.data && (op = o_s || op = o_soverd)
          && src.chan.Memchan.hi = 0x6808 && src.chan.Memchan.lo = 0x1828
          && dst.chan.Memchan.hi = 0x0005 && dst.chan.Memchan.lo = 0x1625 then begin
    (* A picture of 32 bits a pixel (x8r8g8b8: its bytes blue, green,
     * red, one unused) to an image of 16 (r5g6b5, the screen's: the low
     * byte first): each pixel's top bits, as the general loop's write
     * keeps them. A program that computes its own pixels gives them so
     * (lib_playground's platforms/software: a frame of 480 by 480 took
     * the general loop 2.1 seconds under QEMU, of its 2.9). *)
    let (sx0, sy0, _, _) = sr in
    let ss = src.data.bytes and ds = dst.data.bytes in
    for j = 0 to dy - 1 do
      let s = ref (byteaddr src sx0 (sy0 + j)) and p = ref (byteaddr dst x0 (y0 + j)) in
      for i = 0 to dx - 1 do
        ignore i;
        let b = Char.code (Bytes.unsafe_get ss !s) and g = Char.code (Bytes.unsafe_get ss (!s + 1))
        and r = Char.code (Bytes.unsafe_get ss (!s + 2)) in
        let v = ((r lsr 3) lsl 11) lor ((g lsr 2) lsl 5) lor (b lsr 3) in
        Bytes.unsafe_set ds !p (Char.unsafe_chr (v land 255));
        Bytes.unsafe_set ds (!p + 1) (Char.unsafe_chr (v lsr 8));
        s := !s + 4;
        p := !p + 2
      done
    done;
    true
  end
  else if single src && mask.chan.Memchan.depth = 1 && not mask.repl && op = o_soverd
          && (let (x, y) = corner src in let (_, _, _, a) = read src x y in a = 255) then begin
    (* a character: the colour where the mask's bit is set *)
    let (x, y) = corner src in
    let (cr, cg, cb, ca) = read src x y in
    let k = if src.chan.Memchan.grey || src.chan.Memchan.depth < 8 then cr else Memchan.rgb2k cr cg cb in
    let pat = pattern dst (cr, cg, cb, ca) k in
    let n = String.length pat and (mx0, my0, _, _) = mr in
    (* old, per pixel: a layout and two byteaddr (tuples allocated, and
     * then a division each, before Memimage.bytex), 25% of the kernel's
     * time drawing a console:
     *   for i = 0 to dx - 1 do
     *     let (lx, _) = layout mask (mx0 + i) (my0 + j) in
     *     let b = Char.code mask.data.bytes.[byteaddr mask (mx0 + i) (my0 + j)] in
     *     if b land (0x80 lsr (lx land 7)) <> 0 then String.blit pat 0 dst.data.bytes (byteaddr dst (x0 + i) (y0 + j)) n
     *   done
     * Now each row's two addresses computed once: pixel i of the mask
     * is bit (lx0 + i) land 7 of the byte (lx0 + i) asr 3 bytes after
     * the row's first byte's, less lx0's; of the destination, n bytes
     * a pixel (d >= 8) after the row's first *)
    let (lx0, _) = layout mask mx0 my0 in
    let ms = mask.data.bytes and ds = dst.data.bytes in
    for j = 0 to dy - 1 do
      let mrow = byteaddr mask mx0 (my0 + j) - (lx0 asr 3) and drow = byteaddr dst x0 (y0 + j) in
      for i = 0 to dx - 1 do
        let lx = lx0 + i in
        if Char.code (Bytes.get ms (mrow + (lx asr 3))) land (0x80 lsr (lx land 7)) <> 0 then Bytes.blit_string pat 0 ds (drow + (i * n)) n
      done
    done;
    true
  end
  else if !fast_grey && single src && mask.chan.Memchan.depth = 8 && mask.chan.Memchan.grey && not mask.chan.Memchan.alpha
          && not mask.repl && op = o_soverd && mask.data != dst.data
          && (let (x, y) = corner src in let (_, _, _, a) = read src x y in a = 255) then begin
    (* OPTIMIZATION: a smoothed character: an opaque colour through a
     * mask of a byte a pixel (k8), how much of the pixel the letter
     * covers (lib_playground's draw platform: a letter's mask made by
     * its software renderer, docs/notes_font.md). The general loop's
     * arithmetic, its terms known: a source of alpha 255 gives fs = m
     * and fd = 255 - m, so a pixel is mul m s + mul (255 - m) d, the
     * colour's bytes where m is 255, nothing where 0. The screen's
     * format (r5g6b5) read and written here, as [read] and [write]
     * keep its top bits; another by them. The general loop was some
     * 1,400 instructions a pixel, a page of text a hundred thousand *)
    let (x, y) = corner src in
    let (cr, cg, cb, ca) = read src x y in
    let k = if src.chan.Memchan.grey || src.chan.Memchan.depth < 8 then cr else Memchan.rgb2k cr cg cb in
    let pat = pattern dst (cr, cg, cb, ca) k in
    let n = String.length pat and (mx0, my0, _, _) = mr in
    let rgb16 = dst.chan.Memchan.hi = 0x0005 && dst.chan.Memchan.lo = 0x1625 in
    let ms = mask.data.bytes and ds = dst.data.bytes in
    let c (m : int) (s : int) (d : int) = mul m s + mul (255 - m) d in
    (* OPTIMIZATION: a pixel's blend kept by its coverage, with the
     * pixel it was made over: a letter's edges are over the page's
     * background, the same pixel each time, and a blend is then one
     * look (the screen's format; -1: none yet), kept from a letter to
     * the next of the same colour *)
    let colour = (cr lsl 16) lor (cg lsl 8) lor cb in
    if colour <> !blended then begin Array.fill over 0 256 (-1); blended := colour end;
    (* (the colour's two bytes in the screen's format, for a pixel the
     * letter covers whole) *)
    let c0 = String.unsafe_get pat 0 and c1 = String.unsafe_get pat (min 1 (n - 1)) in
    (* (the bounds: the clip's, drawclip's; the rows' addresses the
     * image's own) *)
    for j = 0 to dy - 1 do
      let mrow = byteaddr mask mx0 (my0 + j) and drow = byteaddr dst x0 (y0 + j) in
      for i = 0 to dx - 1 do
        let m = Char.code (Bytes.unsafe_get ms (mrow + i)) in
        (* OPTIMIZATION: a pixel covered whole, of the screen's 16
         * bits, its two bytes stored here: a blit is a call of C, for
         * two bytes, a third of a letter's pixels (mini-qemu's samples,
         * docs/plans/plan_playground_speed.md).
         * old: if m = 255 then Bytes.blit_string pat 0 ds (drow + (i * n)) n *)
        if m = 255 then begin
          if rgb16 then begin
            let p = drow + (2 * i) in
            Bytes.unsafe_set ds p c0; Bytes.unsafe_set ds (p + 1) c1
          end
          else Bytes.blit_string pat 0 ds (drow + (i * n)) n
        end
        else if m > 0 then
          if rgb16 then begin
            let p = drow + (2 * i) in
            let v = Char.code (Bytes.unsafe_get ds p) lor (Char.code (Bytes.unsafe_get ds (p + 1)) lsl 8) in
            let w =
              if Array.unsafe_get over m = v then Array.unsafe_get made m
              else begin
                (* (a channel's bits widened to 8, Memchan.repl's) *)
                let r5 = v lsr 11 and g6 = (v lsr 5) land 63 and b5 = v land 31 in
                let r = c m cr ((r5 lsl 3) lor (r5 lsr 2)) and g = c m cg ((g6 lsl 2) lor (g6 lsr 4))
                and b = c m cb ((b5 lsl 3) lor (b5 lsr 2)) in
                let w = ((r lsr 3) lsl 11) lor ((g lsr 2) lsl 5) lor (b lsr 3) in
                Array.unsafe_set over m v; Array.unsafe_set made m w;
                w
              end in
            Bytes.unsafe_set ds p (Char.unsafe_chr (w land 255));
            Bytes.unsafe_set ds (p + 1) (Char.unsafe_chr (w lsr 8))
          end
          else begin
            let (dr, dg, db, da) = read dst (x0 + i) (y0 + j) in
            write dst (x0 + i) (y0 + j) (c m cr dr, c m cg dg, c m cb db, c m ca da) (c m k dr)
          end
      done
    done;
    true
  end
  else if !fast_bits && not src.repl && not mask.repl && src.data != dst.data && op = o_soverd
          && src.chan.Memchan.depth = 1 && mask.chan.Memchan.depth = 1 && not mask.chan.Memchan.alpha then begin
    (* OPTIMIZATION: an image of one bit a pixel through a mask of one
     * (the cursor, Swcursor's img1 and mask1: 16 by 16, drawn again at
     * each move of the mouse): where the mask's bit is set, white or
     * black by the source's, as the general loop composes them (a
     * coverage of 255 and a source without alpha: the source alone;
     * of 0: the destination as it was). The general loop was 370,000
     * instructions a move, three quarters of what a mouse that moves
     * costs, and more than mini-qemu runs in the sixtieth of a second
     * a move has (docs/plans/plan_mini_qemu_speed.md); the character's
     * loop above, with a second row of bits. *)
    let black = pattern dst (0, 0, 0, 255) 0 and white = pattern dst (255, 255, 255, 255) 255 in
    let n = String.length black and (sx0, sy0, _, _) = sr and (mx0, my0, _, _) = mr in
    let (lx0, _) = layout mask mx0 my0 and (kx0, _) = layout src sx0 sy0 in
    let ms = mask.data.bytes and ss = src.data.bytes and ds = dst.data.bytes in
    for j = 0 to dy - 1 do
      let mrow = byteaddr mask mx0 (my0 + j) - (lx0 asr 3) and srow = byteaddr src sx0 (sy0 + j) - (kx0 asr 3)
      and drow = byteaddr dst x0 (y0 + j) in
      for i = 0 to dx - 1 do
        let lx = lx0 + i and kx = kx0 + i in
        if Char.code (Bytes.get ms (mrow + (lx asr 3))) land (0x80 lsr (lx land 7)) <> 0 then begin
          let pat = if Char.code (Bytes.get ss (srow + (kx asr 3))) land (0x80 lsr (kx land 7)) <> 0 then white else black in
          (* (the screen's two bytes set here: a blit is a call of C's
           * for each pixel. old: Bytes.blit_string pat 0 ds (drow + (i * n)) n) *)
          if n = 2 then begin
            let p = drow + (2 * i) in
            Bytes.set ds p (String.unsafe_get pat 0); Bytes.set ds (p + 1) (String.unsafe_get pat 1)
          end
          else Bytes.blit_string pat 0 ds (drow + (i * n)) n
        end
      done
    done;
    true
  end
  else false

(* OPTIMIZATION: [solid dst src op]: for a shape drawn in one opaque
 * colour (src an image of one pixel, repeated) on an image that is no
 * window, how to write a run of it, [x0, x1) of row y, clipped: the
 * colour's bytes set in place. A shape is its rows' runs (Memshape: a
 * polygon's spans, a line's pixels, each one), and each run was a draw
 * of its own: the clip of three images, the paths tried, a pattern
 * made. None when the general way is needed (a window, a colour with
 * an alpha, a small depth, another operator); and [solid_done] says
 * what was drawn, for the screen (the cursor's place, the
 * framebuffer). *)
let solid dst src op =
  if not !fast || dst.layer <> None || dst.chan.Memchan.depth < 8 || not (single src) || (op <> o_s && op <> o_soverd) then None
  else begin
    let (x, y) = corner src in
    let (cr, cg, cb, ca) = read src x y in
    if ca <> 255 then None
    else begin
      let k = if src.chan.Memchan.grey || src.chan.Memchan.depth < 8 then cr else Memchan.rgb2k cr cg cb in
      let pat = pattern dst (cr, cg, cb, ca) k in
      let n = String.length pat and ds = dst.data.bytes in
      let (cx0, cy0, cx1, cy1) = match clip dst.r dst.clipr with Some c -> c | None -> (0, 0, 0, 0) in
      let p0 = String.unsafe_get pat 0 and p1 = if n > 1 then String.unsafe_get pat 1 else '\000' in
      (* (a run's address from the clip's corner's, by adding: a pixel's
       * bytes are whole ones here. old: let a = byteaddr dst x0 y) *)
      let base = byteaddr dst cx0 cy0 and bw = dst.bwidth in
      Some (fun x0 x1 y ->
        let x0 = if x0 < cx0 then cx0 else x0 and x1 = if x1 > cx1 then cx1 else x1 in
        if y >= cy0 && y < cy1 && x0 < x1 then begin
          let a = base + ((y - cy0) * bw) + ((x0 - cx0) * n) in
          if a >= 0 && a + ((x1 - x0) * n) <= Bytes.length ds then
            if n = 2 then begin
              (* (a long run: its first 8 pixels set, then what is
               * written copied after itself, twice as much each time:
               * a polygon's row of 200 pixels is 5 copies) *)
              let len = x1 - x0 in
              let first = if len > 16 then 8 else len in
              for i = 0 to first - 1 do
                Bytes.unsafe_set ds (a + (2 * i)) p0;
                Bytes.unsafe_set ds (a + (2 * i) + 1) p1
              done;
              let did = ref first in
              while !did < len do
                let k = if !did > len - !did then len - !did else !did in
                Bytes.unsafe_blit ds a ds (a + (2 * !did)) (2 * k);
                did := !did + k
              done
            end
            else
              for i = 0 to x1 - x0 - 1 do
                for b = 0 to n - 1 do Bytes.unsafe_set ds (a + (i * n) + b) (String.unsafe_get pat b) done
              done
        end)
    end
  end

(* (before the runs: the cursor out of r; after them: r to the framebuffer) *)
let solid_start dst r = if dst.data.onscreen then !hwdraw r
let solid_done dst r = match clip r dst.r with Some r -> flush dst r | None -> ()

(* OPTIMIZATION: a colour drawn through a colour (each an image of one
 * pixel, repeated: a fill, and its opaque mask), neither clipped where
 * it is asked: the destination's two rectangles clip, and the colours'
 * corners are their own. drawclip, for any three images, is a dozen
 * tuples and four divisions (a pixel's place in a repeated image); a
 * game's frame is hundreds of fills. *)
let inside (a0, b0, a1, b1) (c0, d0, c1, d1) = a0 >= c0 && b0 >= d0 && a1 <= c1 && b1 <= d1
let fillclip dst r src (px, py) mask (qx, qy) =
  let (rx0, ry0, _, _) = r in
  match clip r dst.r with
  | None -> None
  | Some r' -> (
      match clip r' dst.clipr with
      | None -> None
      | Some ((ax, ay, bx, by) as r') ->
          let dx = ax - rx0 and dy = ay - ry0 and w = bx - ax and h = by - ay in
          if inside (px + dx, py + dy, px + dx + w, py + dy + h) src.clipr
             && inside (qx + dx, qy + dy, qx + dx + w, qy + dy + h) mask.clipr then begin
            let (sx, sy) = corner src and (mx, my) = corner mask in
            Some (r', (sx, sy, sx + w, sy + h), (mx, my, mx + w, my + h))
          end
          else drawclip dst r src (px, py) mask (qx, qy))

(* The general loop run by the machine's host, when the host is an
 * emulator that will (the kernel built for a web page: lib_machine's
 * web/host.s, Memgeneral.mli): the three images said in 49 words, an
 * image's being its chan, its r, its org, its bytes a row and its
 * xbase (what Memimage's byteaddr and read need), and after them the
 * three rectangles and the op; the machine's C adds where each image's
 * bytes are and how many. 1: drawn. 0: not this one (a chan the host
 * has no table for). -1: no such host, and it is not asked again. *)
external host_general : Bytes.t -> Bytes.t -> Bytes.t -> Bytes.t -> int = "web_draw"
let host = ref true

let hosted dst r src sr mask mr op =
  !host && begin
    let b = Bytes.create (49 * 4) and at = ref 0 in
    let put v =
      let p = !at in
      Bytes.unsafe_set b p (Char.unsafe_chr (v land 255)); Bytes.unsafe_set b (p + 1) (Char.unsafe_chr ((v asr 8) land 255));
      Bytes.unsafe_set b (p + 2) (Char.unsafe_chr ((v asr 16) land 255)); Bytes.unsafe_set b (p + 3) (Char.unsafe_chr ((v asr 24) land 255));
      at := p + 4 in
    let rect (x0, y0, x1, y1) = put x0; put y0; put x1; put y1 in
    let image i =
      (* (two words the machine fills: the bytes' address and length) *)
      put 0; put 0;
      put i.chan.Memchan.hi; put i.chan.Memchan.lo; rect i.r; put (fst i.org); put (snd i.org); put i.bwidth; put i.xbase in
    image dst; image src; image mask;
    rect r; rect sr; rect mr; put op;
    match host_general b dst.data.bytes src.data.bytes mask.data.bytes with
    | 1 -> true
    | 0 -> false
    | _ -> host := false; false
  end

let draw dst r src sp mask mp op =
  if op >= o_clear && op <= o_soverd then
    match if !fast && single src && single mask then fillclip dst r src sp mask mp else drawclip dst r src sp mask mp with
    | None -> ()
    | Some (r, sr, mr) ->
        if dst.data.onscreen then !hwdraw r;
        if src.data.onscreen then !hwdraw sr;
        if mask.data.onscreen then !hwdraw mr;
        (* (old: ... then general dst r src sr mask mr op) *)
        if not (!fast && faster dst r src sr mask mr op) then (if not (hosted dst r src sr mask mr op) then general dst r src sr mask mr op);
        flush dst r

(* ix: a picture drawn k times larger, each pixel k by k (the draw
 * device's 'z', docs/plans/plan_playground_framebuffer.md, F5): its
 * rows by the machine's C (Machine.Imag.scale), as a copy's. Only
 * between two images of one chan of whole bytes a pixel, the source
 * not repeated and not the destination's memory; else false, nothing
 * drawn. Clipped as a draw is: dst's rectangle and clip, and where
 * src's rectangle and clip go once scaled. *)
let scale dst r src (spx, spy) k =
  let d = dst.chan.Memchan.depth in
  if k < 1 || src.repl || src.data == dst.data || d land 7 <> 0
     || src.chan.Memchan.hi <> dst.chan.Memchan.hi || src.chan.Memchan.lo <> dst.chan.Memchan.lo then false
  else begin
    let (rx0, ry0, _, _) = r in
    let ( >>= ) o f = match o with None -> None | Some v -> f v in
    (match
       clip r dst.r >>= fun r ->
       clip r dst.clipr >>= fun r ->
       clip src.r src.clipr >>= fun (a0, b0, a1, b1) ->
       clip r (rx0 + (k * (a0 - spx)), ry0 + (k * (b0 - spy)), rx0 + (k * (a1 - spx)), ry0 + (k * (b1 - spy)))
     with
     | None -> ()
     | Some ((x0, y0, x1, y1) as cr) ->
         let ox = x0 - rx0 and oy = y0 - ry0 in
         if dst.data.onscreen then !hwdraw cr;
         Machine.Imag.scale dst.data.bytes src.data.bytes
           [| byteaddr dst x0 y0; dst.bwidth; byteaddr src (spx + (ox / k)) (spy + (oy / k)); src.bwidth;
              d asr 3; k; ox mod k; oy mod k; x1 - x0; y1 - y0 |];
         flush dst cr);
    true
  end
