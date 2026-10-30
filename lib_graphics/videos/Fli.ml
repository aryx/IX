(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fli.mli *)
(* ix: the author's playground's libs/graphics/videos/fli/Fli.ml; reading only: its writer is the tests' *)

type format = Fli | Flc
type header = { format : format; width : int; height : int; frames : int; delay : float }

(* the chunks' types *)
let color_256 = 4
let delta_flc = 7
let color_64 = 11
let lc = 12
let black = 13
let brun = 15
let copy = 16
let frame_magic = 0xF1FA

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

let u8 (s : string) (i : int) : int = Char.code s.[i]
let u16 (s : string) (i : int) : int = u8 s i lor (u8 s (i + 1) lsl 8)
let u32 (s : string) (i : int) : int = u16 s i lor (u16 s (i + 2) lsl 16)
let signed (v : int) : int = if v >= 128 then v - 256 else v

(* the decoder's state after a frame: the palette (r g b, 256 of them)
 * and the pixels (a palette index each), and the frame next *)
type state = { palette : Bytes.t; pixels : Bytes.t; next_frame : int }

(* one chunk, at [at], applied to the palette and the pixels *)
let apply (h : header) (s : string) (palette : Bytes.t) (pixels : Bytes.t) (typ : int) (at : int) : unit =
  let w = h.width in
  let body = at + 6 in
  let set x y v = Bytes.set pixels ((y * w) + x) (Char.chr v) in
  let blit_from p x y n = Bytes.blit_string s p pixels ((y * w) + x) n in
  if typ = color_256 || typ = color_64 then (
    let p = ref (body + 2) and entry = ref 0 in
    for _i = 1 to u16 s body do
      entry := !entry + u8 s !p;
      let n = match u8 s (!p + 1) with 0 -> 256 | n -> n in
      p := !p + 2;
      for _i = 1 to n do
        for c = 0 to 2 do
          let v = u8 s (!p + c) in
          (* 0-63, the VGA's: stretched to 0-255, its top bits repeated *)
          let v = if typ = color_64 then (v lsl 2) lor (v lsr 4) else v in
          Bytes.set palette ((3 * !entry) + c) (Char.chr (v land 0xFF))
        done;
        p := !p + 3;
        incr entry
      done
    done)
  else if typ = brun then (
    let p = ref body in
    for y = 0 to h.height - 1 do
      incr p (* the packets' count: the line's width says when it ends *);
      let x = ref 0 in
      while !x < w do
        let n = signed (u8 s !p) in
        incr p;
        if n > 0 then (
          for i = 0 to n - 1 do set (!x + i) y (u8 s !p) done;
          incr p;
          x := !x + n)
        else (
          blit_from !p !x y (-n);
          p := !p - n;
          x := !x - n)
      done
    done)
  else if typ = lc then (
    let y = ref (u16 s body) and p = ref (body + 4) in
    for _i = 1 to u16 s (body + 2) do
      let x = ref 0 and packets = u8 s !p in
      incr p;
      for _i = 1 to packets do
        x := !x + u8 s !p;
        let n = signed (u8 s (!p + 1)) in
        p := !p + 2;
        if n > 0 then (
          blit_from !p !x !y n;
          p := !p + n;
          x := !x + n)
        else (
          for i = 0 to -n - 1 do set (!x + i) !y (u8 s !p) done;
          incr p;
          x := !x - n)
      done;
      incr y
    done)
  else if typ = delta_flc then (
    let y = ref 0 and p = ref (body + 2) in
    for _i = 1 to u16 s body do
      (* the opcodes before the line's packets: lines skipped, an odd
       * line's last pixel, and then the packets' count *)
      let rec packets () =
        let word = u16 s !p in
        p := !p + 2;
        if word land 0xC000 = 0xC000 then (
          y := !y + (0x10000 - word);
          packets ())
        else if word land 0xC000 = 0x8000 then (
          set (w - 1) !y (word land 0xFF);
          packets ())
        else word
      in
      let x = ref 0 in
      for _i = 1 to packets () do
        x := !x + u8 s !p;
        let n = signed (u8 s (!p + 1)) in
        p := !p + 2;
        if n > 0 then (
          blit_from !p !x !y (2 * n);
          p := !p + (2 * n);
          x := !x + (2 * n))
        else (
          for i = 0 to -n - 1 do
            set (!x + (2 * i)) !y (u8 s !p);
            set (!x + (2 * i) + 1) !y (u8 s (!p + 1))
          done;
          p := !p + 2;
          x := !x - (2 * n))
      done;
      incr y
    done)
  else if typ = black then Bytes.fill pixels 0 (Bytes.length pixels) '\000'
  else if typ = copy then Bytes.blit_string s body pixels 0 (Bytes.length pixels)

let of_string (s : string) : header * Movie.t =
  if String.length s < 128 then failwith "FLI: too short";
  let format = match u16 s 4 with 0xAF11 -> Fli | 0xAF12 -> Flc | _ -> failwith "FLI: not an FLI or FLC file" in
  let frames = u16 s 6 in
  let width = match u16 s 8 with 0 -> 320 | w -> w and height = match u16 s 10 with 0 -> 200 | h -> h in
  let delay = match format with Fli -> float_of_int (u16 s 16) /. 70. | Flc -> float_of_int (u32 s 16) /. 1000. in
  let h = { format; width; height; frames; delay = Float.max 0.01 delay } in
  if frames = 0 then failwith "FLI: no frames";
  (* where each frame is: the frame chunks, other chunks (an FLC's
   * prefix, 0xF100) skipped, the ring frame after the last not read *)
  let first = match format with Flc when u32 s 80 >= 128 && u32 s 80 < String.length s -> u32 s 80 | _ -> 128 in
  let rec walk at acc n =
    if n = frames || at + 16 > String.length s then List.rev acc
    else
      let size = u32 s at in
      if size < 16 then failwith "FLI: a chunk of no size"
      else if u16 s (at + 4) = frame_magic then walk (at + size) (at :: acc) (n + 1)
      else walk (at + size) acc n
  in
  let starts = Array.of_list (walk first [] 0) in
  if starts = [||] then failwith "FLI: no frames";
  (* an FLC frame can have a delay of its own *)
  let delays = Array.map (fun at -> match format with Flc when u16 s (at + 8) > 0 -> float_of_int (u16 s (at + 8)) /. 1000. | _ -> h.delay) starts in
  let times = Array.make (Array.length starts) 0. in
  for i = 1 to Array.length starts - 1 do times.(i) <- times.(i - 1) +. delays.(i - 1) done;
  let duration = times.(Array.length starts - 1) +. delays.(Array.length starts - 1) in
  let start () = { palette = Bytes.make 768 '\000'; pixels = Bytes.make (width * height) '\000'; next_frame = 0 } in
  let next (st : state) : state * Rgba_image.t =
    (* the frame before, changed: copies, the state before kept intact *)
    let palette = Bytes.copy st.palette and pixels = Bytes.copy st.pixels in
    let at = starts.(st.next_frame) in
    let chunk = ref (at + 16) in
    (try
       for _i = 1 to u16 s (at + 6) do
         apply h s palette pixels (u16 s (!chunk + 4)) !chunk;
         chunk := !chunk + u32 s !chunk
       done
     with Invalid_argument _ -> () (* a chunk cut short: the frame as far as it went *));
    let img = Rgba_image.create ~width ~height in
    for i = 0 to (width * height) - 1 do
      let c = 3 * Char.code (Bytes.get pixels i) in
      for k = 0 to 2 do Bytes.set_uint8 img.rgba ((4 * i) + k) (Char.code (Bytes.get palette (c + k))) done;
      Bytes.set_uint8 img.rgba ((4 * i) + 3) 255
    done;
    ({ palette; pixels; next_frame = st.next_frame + 1 }, img)
  in
  (h, Movie.sequential ~width ~height ~times ~duration ~start ~next)
