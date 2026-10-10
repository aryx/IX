(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/fonts/Truetype.ml; outline's depth, an optional argument that only outline gave itself, is outline_at's (docs/plans/plan_pdf.md) *)

(* See Truetype.mli *)

type t = {
  bytes : string;
  tables : (string * (int * int)) list; (* a table's place and length *)
  units : int; (* a glyph's coordinates are in an em of this many *)
  glyphs : int;
  long_offsets : bool;
}

let u8 (s : string) (i : int) : int = if i < String.length s then Char.code s.[i] else 0
let u16 (s : string) (i : int) : int = (u8 s i lsl 8) lor u8 s (i + 1)
let i16 (s : string) (i : int) : int = let v = u16 s i in if v >= 0x8000 then v - 0x10000 else v
let u32 (s : string) (i : int) : int = (u16 s i lsl 16) lor u16 s (i + 2)

let table (t : t) (tag : string) : (int * int) option = List.assoc_opt tag t.tables

let of_string (bytes : string) : t =
  if String.length bytes < 12 then failwith "Truetype: not a font";
  let count = u16 bytes 4 in
  let tables = List.init count (fun i -> let at = 12 + (16 * i) in (String.sub bytes at 4, (u32 bytes (at + 8), u32 bytes (at + 12)))) in
  let at tag = Option.map fst (List.assoc_opt tag tables) in
  let units = match at "head" with Some h -> u16 bytes (h + 18) | None -> 1000 in
  { bytes; tables; units = (if units = 0 then 1000 else units); glyphs = (match at "maxp" with Some m -> u16 bytes (m + 4) | None -> 0);
    long_offsets = (match at "head" with Some h -> i16 bytes (h + 50) <> 0 | None -> false) }

let units (t : t) : int = t.units
let glyphs (t : t) : int = t.glyphs

(* a font that is PostScript's in TrueType's file (OpenType's "CFF ") *)
let cff (t : t) : string option = Option.map (fun (at, len) -> String.sub t.bytes at (min len (String.length t.bytes - at))) (table t "CFF ")

(* a glyph's bytes in "glyf", by the table of offsets "loca" *)
let glyph_data (t : t) (g : int) : (int * int) option =
  match (table t "loca", table t "glyf") with
  | Some (loca, _), Some (glyf, _) when g >= 0 && g < t.glyphs ->
      let offset i = if t.long_offsets then u32 t.bytes (loca + (4 * i)) else 2 * u16 t.bytes (loca + (2 * i)) in
      let a = offset g and b = offset (g + 1) in
      if b > a then Some (glyf + a, b - a) else None
  | _ -> None

(* a contour's points, on the curve or off it, as lines and quadratic
 * curves: between two points off the curve, one on it is meant,
 * halfway *)
let contour (points : (float * float * bool) array) : Outline.contour option =
  let n = Array.length points in
  if n < 2 then None
  else (
    let mid (ax, ay, _) (bx, by, _) = ((ax +. bx) /. 2., (ay +. by) /. 2.) in
    let on (_, _, o) = o and xy (x, y, _) = (x, y) in
    (* a point on the curve to start from *)
    let first = let rec find i = if i >= n then None else if on points.(i) then Some i else find (i + 1) in find 0 in
    let start, from = match first with Some i -> (xy points.(i), i + 1) | None -> (mid points.(n - 1) points.(0), 0) in
    let count = match first with Some _ -> n - 1 | None -> n in
    let segments = ref [] and control = ref None in
    for k = 0 to count - 1 do
      let p = points.((from + k) mod n) in
      match (!control, on p) with
      | None, true -> segments := Outline.Line (xy p) :: !segments
      | None, false -> control := Some p
      | Some c, true -> segments := Outline.Quadratic (xy c, xy p) :: !segments; control := None
      | Some c, false -> segments := Outline.Quadratic (xy c, mid c p) :: !segments; control := Some p
    done;
    (match !control with Some c -> segments := Outline.Quadratic (xy c, start) :: !segments | None -> segments := Outline.Line start :: !segments);
    Some { Outline.start; segments = List.rev !segments })

let rec outline_at (depth : int) (t : t) (g : int) : Outline.t =
  match glyph_data t g with
  | None -> []
  | Some (at, _) ->
      let s = t.bytes in
      let contours = i16 s at in
      if contours >= 0 then (
        let ends = Array.init contours (fun i -> u16 s (at + 10 + (2 * i))) in
        let count = if contours = 0 then 0 else ends.(contours - 1) + 1 in
        let instructions = u16 s (at + 10 + (2 * contours)) in
        let p = ref (at + 12 + (2 * contours) + instructions) in
        (* each point's flags, a flag repeated as many times as its next byte says *)
        let flags = Array.make count 0 and i = ref 0 in
        while !i < count do
          let f = u8 s !p in
          incr p;
          flags.(!i) <- f;
          incr i;
          if f land 8 <> 0 then (
            let times = u8 s !p in
            incr p;
            for _i = 1 to times do if !i < count then (flags.(!i) <- f; incr i) done)
        done;
        (* the coordinates, each a step from the one before: a byte and a sign, two bytes, or none *)
        let coordinates short same =
          let v = ref 0 in
          Array.map
            (fun f ->
              if f land short <> 0 then (let d = u8 s !p in incr p; v := !v + if f land same <> 0 then d else -d)
              else if f land same = 0 then (v := !v + i16 s !p; p := !p + 2);
              !v)
            flags
        in
        let xs = coordinates 2 16 in
        let ys = coordinates 4 32 in
        let points = Array.init count (fun i -> (float_of_int xs.(i), float_of_int ys.(i), flags.(i) land 1 <> 0)) in
        List.filter_map (fun c -> let first = if c = 0 then 0 else ends.(c - 1) + 1 in contour (Array.sub points first (ends.(c) - first + 1))) (List.init contours Fun.id))
      else if depth > 8 then []
      else (
        (* a glyph made of others, each moved and scaled *)
        let rec parts p acc =
          let flags = u16 s p and index = u16 s (p + 2) in
          let words = flags land 1 <> 0 in
          let arg i = if words then i16 s (p + 4 + (2 * i)) else let v = u8 s (p + 4 + i) in if v >= 128 then v - 256 else v in
          let dx, dy = if flags land 2 <> 0 then (float_of_int (arg 0), float_of_int (arg 1)) else (0., 0.) in
          let p = p + if words then 8 else 6 in
          let f i = float_of_int (i16 s (p + (2 * i))) /. 16384. in
          let (a, b, c, d), p =
            if flags land 8 <> 0 then ((f 0, 0., 0., f 0), p + 2) else if flags land 0x40 <> 0 then ((f 0, 0., 0., f 1), p + 4) else if flags land 0x80 <> 0 then ((f 0, f 1, f 2, f 3), p + 8) else ((1., 0., 0., 1.), p)
          in
          let move (x, y) = ((a *. x) +. (c *. y) +. dx, (b *. x) +. (d *. y) +. dy) in
          let part =
            List.map
              (fun (ct : Outline.contour) ->
                { Outline.start = move ct.start;
                  segments = List.map (fun (sg : Outline.segment) -> match sg with Line q -> Outline.Line (move q) | Quadratic (c, q) -> Quadratic (move c, move q) | Cubic (c1, c2, q) -> Cubic (move c1, move c2, move q)) ct.segments })
              (outline_at (depth + 1) t index)
          in
          if flags land 0x20 <> 0 then parts p (part :: acc) else List.concat (List.rev (part :: acc))
        in
        parts (at + 10) [])

(* how far the pen moves after a glyph *)
let outline (t : t) (g : int) : Outline.t = outline_at 0 t g

let advance (t : t) (g : int) : int =
  match (table t "hmtx", table t "hhea") with
  | Some (hmtx, _), Some (hhea, _) ->
      let count = u16 t.bytes (hhea + 34) in
      if count = 0 then 0 else u16 t.bytes (hmtx + (4 * min g (count - 1)))
  | _ -> 0

(* the table of characters to glyphs made for a platform and its
 * encoding (3 and 1: Windows and Unicode; 1 and 0: the Macintosh's
 * own; 3 and 0: a font of symbols), if the font has it *)
let cmap (t : t) ~(platform : int) ~(encoding : int) : (int -> int) option =
  match table t "cmap" with
  | None -> None
  | Some (cmap, _) ->
      let s = t.bytes in
      let found = List.find_opt (fun i -> u16 s (cmap + 4 + (8 * i)) = platform && u16 s (cmap + 6 + (8 * i)) = encoding) (List.init (u16 s (cmap + 2)) Fun.id) in
      Option.bind found (fun i ->
          let at = cmap + u32 s (cmap + 8 + (8 * i)) in
          match u16 s at with
          | 0 -> Some (fun c -> if c >= 0 && c < 256 then u8 s (at + 6 + c) else 0)
          | 6 -> Some (fun c -> let first = u16 s (at + 6) in if c >= first && c < first + u16 s (at + 8) then u16 s (at + 10 + (2 * (c - first))) else 0)
          | 4 ->
              (* runs of characters, each to a run of glyphs or through a table *)
              let segments = u16 s (at + 6) / 2 in
              let ends = at + 14 in
              let starts = ends + (2 * segments) + 2 in
              let deltas = starts + (2 * segments) in
              let ranges = deltas + (2 * segments) in
              Some
                (fun c ->
                  let rec find k =
                    if k >= segments then 0
                    else if c > u16 s (ends + (2 * k)) then find (k + 1)
                    else if c < u16 s (starts + (2 * k)) then 0
                    else
                      let range = u16 s (ranges + (2 * k)) in
                      if range = 0 then (c + u16 s (deltas + (2 * k))) land 0xffff
                      else
                        let g = u16 s (ranges + (2 * k) + range + (2 * (c - u16 s (starts + (2 * k))))) in
                        if g = 0 then 0 else (g + u16 s (deltas + (2 * k))) land 0xffff
                  in
                  find 0)
          | 12 ->
              Some
                (fun c ->
                  let rec find k = if k >= u32 s (at + 12) then 0 else let g = at + 16 + (12 * k) in if c >= u32 s g && c <= u32 s (g + 4) then u32 s (g + 8) + c - u32 s g else find (k + 1) in
                  find 0)
          | _ -> None)
