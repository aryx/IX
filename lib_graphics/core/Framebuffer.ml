(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* ix: the playground's libs/graphics/core/Framebuffer.ml, its pixels a
 * Bytes in place of a Bigarray of SDL's (mini-ml has no Bigarray; and
 * the bytes are the draw device's, see the .mli); the rest as it was. *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type pixels = Bytes.t

type t = { width : int; height : int; pixels : pixels }

(*****************************************************************************)
(* Colors *)
(*****************************************************************************)

let red rgb = (rgb lsr 16) land 0xFF
let green rgb = (rgb lsr 8) land 0xFF
let blue rgb = rgb land 0xFF

(* a pixel's four bytes, at offset o: blue, green, red, and one unused *)
let set_pixel (pixels : pixels) (o : int) (rgb : int) : unit =
  Bytes.unsafe_set pixels o (Char.unsafe_chr (blue rgb));
  Bytes.unsafe_set pixels (o + 1) (Char.unsafe_chr (green rgb));
  Bytes.unsafe_set pixels (o + 2) (Char.unsafe_chr (red rgb));
  Bytes.unsafe_set pixels (o + 3) '\255'

let get_pixel (pixels : pixels) (o : int) : int =
  (Char.code (Bytes.unsafe_get pixels (o + 2)) lsl 16)
  lor (Char.code (Bytes.unsafe_get pixels (o + 1)) lsl 8)
  lor Char.code (Bytes.unsafe_get pixels o)

let blend ~(src : int) ~(dst : int) ~(alpha : float) : int =
  (* each channel is a weighted average of the two colors, e.g. with
   * alpha = 0.25, a quarter of src and three quarters of dst *)
  let mix s d =
    int_of_float ((float s *. alpha) +. (float d *. (1. -. alpha)) +. 0.5)
  in
  (mix (red src) (red dst) lsl 16)
  lor (mix (green src) (green dst) lsl 8)
  lor mix (blue src) (blue dst)

(*****************************************************************************)
(* Creation *)
(*****************************************************************************)

let of_pixels ~(width : int) ~(height : int) (pixels : pixels) : t =
  if Bytes.length pixels <> 4 * width * height then invalid_arg "Framebuffer.of_pixels";
  { width; height; pixels }

(* The simple version: each pixel set *)
let clear_simple (fb : t) ~(rgb : int) : unit =
  for i = 0 to (fb.width * fb.height) - 1 do
    set_pixel fb.pixels (4 * i) rgb
  done

(* ix: optimization (Opti.enabled). A grey's three bytes are the same
 * (white's are the unused byte's too, 0xFF): the pixels are one byte
 * repeated, which Bytes.fill writes in one call of the runtime's. A
 * million pixels, by mini-ml on arm64: 0.56 s each set, and under
 * 0.06 s filled (Tetris's frame, 1.36 s, became 0.86); and a frame
 * starts by this. (The unused byte is then the grey's, not 0xFF:
 * nothing reads it.) *)
let clear (fb : t) ~(rgb : int) : unit =
  if !Opti.enabled && red rgb = green rgb && green rgb = blue rgb then
    Bytes.fill fb.pixels 0 (Bytes.length fb.pixels) (Char.chr (blue rgb))
  else clear_simple fb ~rgb

let create ~(width : int) ~(height : int) : t =
  let fb = of_pixels ~width ~height (Bytes.create (4 * width * height)) in
  clear fb ~rgb:0xFFFFFF;
  fb

let get_rgb (fb : t) ~(x : int) ~(y : int) : int = get_pixel fb.pixels (4 * ((y * fb.width) + x))

(*****************************************************************************)
(* Spans *)
(*****************************************************************************)

let fill_span (fb : t) ~(y : int) ~(x0 : int) ~(x1 : int) ~(rgb : int) ~(alpha : float) : unit =
  (* clipping: keep only the part of the span that is inside the
   * framebuffer; e.g. on a 1000-pixel-wide framebuffer, the span
   * [-20, 30) becomes [0, 30), and [990, 1200) becomes [990, 1000) *)
  let x0 = max x0 0 and x1 = min x1 fb.width in
  if y >= 0 && y < fb.height && x0 < x1 && alpha > 0. then begin
    let row = 4 * y * fb.width in
    if alpha >= 1. then
      (* opaque: no need to look at what's there, just overwrite; this
       * is by far the most common case *)
      for x = x0 to x1 - 1 do
        set_pixel fb.pixels (row + (4 * x)) rgb
      done
    else
      for x = x0 to x1 - 1 do
        let o = row + (4 * x) in
        set_pixel fb.pixels o (blend ~src:rgb ~dst:(get_pixel fb.pixels o) ~alpha)
      done
  end

(* One pixel: a span of length 1 *)
let plot (fb : t) ~(x : int) ~(y : int) ~(rgb : int) ~(alpha : float) : unit =
  fill_span fb ~y ~x0:x ~x1:(x + 1) ~rgb ~alpha
