(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/fonts/Cff.ml; an Option.value ~default written as its match (docs/plans/plan_pdf.md) *)

(* See Cff.mli *)

let u8 (s : string) (i : int) : int = if i >= 0 && i < String.length s then Char.code s.[i] else 0
let u16 (s : string) (i : int) : int = (u8 s i lsl 8) lor u8 s (i + 1)

(* a list of things of any size: a count, the size of an offset, the
 * offsets (from 1), the things. Each thing's place and length; where
 * the list ends *)
let index (s : string) (at : int) : (int * int) array * int =
  let count = u16 s at in
  if count = 0 then ([||], at + 2)
  else (
    let size = u8 s (at + 2) in
    let offset i = let v = ref 0 in for k = 0 to size - 1 do v := (!v lsl 8) lor u8 s (at + 3 + (i * size) + k) done; !v in
    let base = at + 3 + ((count + 1) * size) - 1 in
    (Array.init count (fun i -> (base + offset i, offset (i + 1) - offset i)), base + offset count))

(* a dictionary: numbers, then what they are of (an operator: a byte, or 12 and a byte) *)
let dict (s : string) (at : int) (length : int) : (int * float list) list =
  let stop = at + length in
  let rec go i operands acc =
    if i >= stop then List.rev acc
    else
      let b = u8 s i in
      if b <= 21 then
        let op, i = if b = 12 then (1200 + u8 s (i + 1), i + 2) else (b, i + 1) in
        go i [] ((op, List.rev operands) :: acc)
      else if b = 28 then go (i + 3) (float_of_int (let v = u16 s (i + 1) in if v >= 0x8000 then v - 0x10000 else v) :: operands) acc
      else if b = 29 then
        let v = (u16 s (i + 1) lsl 16) lor u16 s (i + 3) in
        go (i + 5) (float_of_int (if v >= 0x80000000 then v - 0x100000000 else v) :: operands) acc
      else if b = 30 then (
        (* a real number, a digit a half byte *)
        let text = Buffer.create 16 and i = ref (i + 1) and fin = ref false in
        while (not !fin) && !i < stop do
          List.iter
            (fun nibble ->
              if not !fin then
                match nibble with
                | 0xf -> fin := true
                | 0xa -> Buffer.add_char text '.'
                | 0xb -> Buffer.add_char text 'e'
                | 0xc -> Buffer.add_string text "e-"
                | 0xe -> Buffer.add_char text '-'
                | d when d <= 9 -> Buffer.add_char text (Char.chr (48 + d))
                | _ -> ())
            [ u8 s !i lsr 4; u8 s !i land 15 ];
          incr i
        done;
        go !i ((match float_of_string_opt (Buffer.contents text) with Some v -> v | None -> 0.) :: operands) acc)
      else if b >= 32 && b <= 246 then go (i + 1) (float_of_int (b - 139) :: operands) acc
      else if b >= 247 && b <= 250 then go (i + 2) (float_of_int (((b - 247) * 256) + u8 s (i + 1) + 108) :: operands) acc
      else if b >= 251 && b <= 254 then go (i + 2) (float_of_int ((-(b - 251) * 256) - u8 s (i + 1) - 108) :: operands) acc
      else go (i + 1) operands acc
  in
  go at [] []

type t = {
  bytes : string;
  charstrings : (int * int) array;
  global_subrs : (int * int) array;
  local_subrs : (int * int) array array; (* one a private dictionary *)
  select : int -> int; (* a glyph's private dictionary *)
  names : int array; (* a glyph's name (a string's number), or its CID *)
  strings : (int * int) array;
  cid : bool;
  encoding : int array; (* a code's glyph *)
  matrix : float list;
}

let string (t : t) (sid : int) : string =
  if sid < 391 then Glyph_names.cff_strings.(sid)
  else if sid - 391 < Array.length t.strings then let at, len = t.strings.(sid - 391) in String.sub t.bytes at len
  else ""

let of_string (s : string) : t =
  if String.length s < 4 then failwith "Cff: not a font";
  let _, at = index s (u8 s 2) in
  let tops, at = index s at in
  let strings, at = index s at in
  let global_subrs, _ = index s at in
  if Array.length tops = 0 then failwith "Cff: no font in it";
  let top = dict s (fst tops.(0)) (snd tops.(0)) in
  let int op default = match List.assoc_opt op top with Some (v :: _) -> int_of_float v | _ -> default in
  let charstrings = fst (index s (int 17 0)) in
  let glyphs = Array.length charstrings in
  (* a private dictionary's own subroutines *)
  let subrs (d : (int * float list) list) : (int * int) array =
    match List.assoc_opt 18 d with
    | Some [ size; offset ] -> (
        let p = dict s (int_of_float offset) (int_of_float size) in
        match List.assoc_opt 19 p with Some (o :: _) -> fst (index s (int_of_float offset + int_of_float o)) | _ -> [||])
    | _ -> [||]
  in
  let cid = List.mem_assoc 1230 top in
  let local_subrs, select =
    if cid then (
      let fonts = fst (index s (int 1236 0)) in
      let at = int 1237 0 in
      let select =
        if u8 s at = 0 then fun g -> u8 s (at + 1 + g)
        else fun g ->
          (* ranges: a first glyph and its dictionary, in order *)
          let rec find k = if k + 1 >= u16 s (at + 1) then k else if u16 s (at + 3 + (3 * (k + 1))) > g then k else find (k + 1) in
          u8 s (at + 5 + (3 * find 0))
      in
      (Array.map (fun (a, l) -> subrs (dict s a l)) fonts, select))
    else ([| subrs top |], fun _ -> 0)
  in
  (* each glyph's name: listed, or by runs *)
  let names = Array.make glyphs 0 in
  (match int 15 0 with
   | 0 | 1 | 2 -> Array.iteri (fun g _ -> names.(g) <- g) names
   | at ->
       if u8 s at = 0 then for g = 1 to glyphs - 1 do names.(g) <- u16 s (at + 1 + (2 * (g - 1))) done
       else (
         let wide = u8 s at = 2 and g = ref 1 and p = ref (at + 1) in
         while !g < glyphs do
           let first = u16 s !p and left = if wide then u16 s (!p + 2) else u8 s (!p + 2) in
           for k = 0 to left do if !g < glyphs then (names.(!g) <- first + k; incr g) done;
           p := !p + if wide then 4 else 3
         done));
  let t = { bytes = s; charstrings; global_subrs; local_subrs; select; names; strings; cid; encoding = Array.make 256 0; matrix = (match List.assoc_opt 1207 top with Some m when List.length m = 6 -> m | _ -> [ 0.001; 0.; 0.; 0.001; 0.; 0. ]) } in
  (* a code's glyph: the standard encoding's names looked up, or the font's own list *)
  (match int 16 0 with
   | 0 | 1 ->
       let by_name = Hashtbl.create glyphs in
       Array.iteri (fun g sid -> Hashtbl.replace by_name (string t sid) g) names;
       Array.iteri (fun code name -> if name <> "" then match Hashtbl.find_opt by_name name with Some g -> t.encoding.(code) <- g | None -> ()) Glyph_names.standard_encoding
   | at ->
       let format = u8 s at land 127 in
       if format = 0 then for k = 0 to u8 s (at + 1) - 1 do t.encoding.(u8 s (at + 2 + k)) <- k + 1 done
       else (
         let g = ref 1 in
         for k = 0 to u8 s (at + 1) - 1 do
           let first = u8 s (at + 2 + (2 * k)) in
           for c = first to first + u8 s (at + 3 + (2 * k)) do if c < 256 then t.encoding.(c) <- !g; incr g done
         done));
  t

let glyphs (t : t) : int = Array.length t.charstrings
let is_cid (t : t) : bool = t.cid
let matrix (t : t) : float list = t.matrix
let encoding (t : t) (code : int) : int = if code >= 0 && code < 256 then t.encoding.(code) else 0

(* the glyph of a name; of a CID, in a font keyed by them *)
let glyph_of_name (t : t) (name : string) : int option =
  let rec find g = if g >= Array.length t.names then None else if string t t.names.(g) = name then Some g else find (g + 1) in
  if t.cid then None else find 0

let glyph_of_cid (t : t) (cid : int) : int =
  if not t.cid then cid else let rec find g = if g >= Array.length t.names then 0 else if t.names.(g) = cid then g else find (g + 1) in find 0

(* a glyph's program run: numbers pushed, operators that move the pen
 * by them. The hints (stems, masks) are counted, to step over the
 * masks' bytes, and not used *)
let outline (t : t) (g : int) : Outline.t =
  if g < 0 || g >= Array.length t.charstrings then []
  else (
    let s = t.bytes and pen = Outline.pen () in
    let local = let k = t.select g in if k < Array.length t.local_subrs then t.local_subrs.(k) else [||] in
    let bias (subrs : (int * int) array) = let n = Array.length subrs in if n < 1240 then 107 else if n < 33900 then 1131 else 32768 in
    let stack = ref [] (* the last pushed first *) and stems = ref 0 and first = ref true and ended = ref false in
    (* the operands in order; before the first drawing, one more than needed is the glyph's width *)
    let args (even : bool) (count : int option) : float array =
      let a = Array.of_list (List.rev !stack) in
      stack := [];
      let extra = !first && (match count with Some c -> Array.length a > c | None -> even && Array.length a land 1 = 1) in
      first := false;
      if extra then Array.sub a 1 (Array.length a - 1) else a
    in
    let rec run ((at, length) : int * int) (depth : int) : unit =
      let stop = at + length and i = ref at in
      while (not !ended) && !i < stop do
        let b = u8 s !i in
        incr i;
        if b >= 32 then
          if b <= 246 then stack := float_of_int (b - 139) :: !stack
          else if b <= 250 then (stack := float_of_int (((b - 247) * 256) + u8 s !i + 108) :: !stack; incr i)
          else if b <= 254 then (stack := float_of_int ((-(b - 251) * 256) - u8 s !i - 108) :: !stack; incr i)
          else (
            let v = (u16 s !i lsl 16) lor u16 s (!i + 2) in
            stack := float_of_int (if v >= 0x80000000 then v - 0x100000000 else v) /. 65536. :: !stack;
            i := !i + 4)
        else if b = 28 then (stack := float_of_int (let v = u16 s !i in if v >= 0x8000 then v - 0x10000 else v) :: !stack; i := !i + 2)
        else
          match b with
          | 1 | 3 | 18 | 23 -> stems := !stems + (Array.length (args true None) / 2)
          | 19 | 20 ->
              stems := !stems + (Array.length (args true None) / 2);
              i := !i + ((!stems + 7) / 8)
          | 21 -> let a = args false (Some 2) in if Array.length a >= 2 then Outline.move pen a.(0) a.(1)
          | 22 -> let a = args false (Some 1) in if Array.length a >= 1 then Outline.move pen a.(0) 0.
          | 4 -> let a = args false (Some 1) in if Array.length a >= 1 then Outline.move pen 0. a.(0)
          | 5 -> let a = args false None in for k = 0 to (Array.length a / 2) - 1 do Outline.line pen a.(2 * k) a.((2 * k) + 1) done
          | 6 | 7 ->
              (* lines across and up in turn *)
              let a = args false None in
              Array.iteri (fun k v -> if (k land 1 = 0) = (b = 6) then Outline.line pen v 0. else Outline.line pen 0. v) a
          | 8 -> let a = args false None in for k = 0 to (Array.length a / 6) - 1 do let o = 6 * k in Outline.curve pen a.(o) a.(o + 1) a.(o + 2) a.(o + 3) a.(o + 4) a.(o + 5) done
          | 24 ->
              let a = args false None in
              let curves = (Array.length a - 2) / 6 in
              for k = 0 to curves - 1 do let o = 6 * k in Outline.curve pen a.(o) a.(o + 1) a.(o + 2) a.(o + 3) a.(o + 4) a.(o + 5) done;
              if Array.length a >= (6 * curves) + 2 then Outline.line pen a.(6 * curves) a.((6 * curves) + 1)
          | 25 ->
              let a = args false None in
              let lines = (Array.length a - 6) / 2 in
              for k = 0 to lines - 1 do Outline.line pen a.(2 * k) a.((2 * k) + 1) done;
              let o = 2 * lines in
              if Array.length a >= o + 6 then Outline.curve pen a.(o) a.(o + 1) a.(o + 2) a.(o + 3) a.(o + 4) a.(o + 5)
          | 26 ->
              (* curves that start and end going up *)
              let a = args false None in
              let o = ref 0 and dx = ref 0. in
              if Array.length a land 1 = 1 then (dx := a.(0); o := 1);
              while !o + 4 <= Array.length a do
                Outline.curve pen !dx a.(!o) a.(!o + 1) a.(!o + 2) 0. a.(!o + 3);
                dx := 0.;
                o := !o + 4
              done
          | 27 ->
              let a = args false None in
              let o = ref 0 and dy = ref 0. in
              if Array.length a land 1 = 1 then (dy := a.(0); o := 1);
              while !o + 4 <= Array.length a do
                Outline.curve pen a.(!o) !dy a.(!o + 1) a.(!o + 2) a.(!o + 3) 0.;
                dy := 0.;
                o := !o + 4
              done
          | 30 | 31 ->
              (* curves that start across and end up, or the other way, in turn *)
              let a = args false None in
              let o = ref 0 and across = ref (b = 31) and n = Array.length a in
              while !o + 4 <= n do
                let last = if n - !o = 5 then a.(!o + 4) else 0. in
                if !across then Outline.curve pen a.(!o) 0. a.(!o + 1) a.(!o + 2) last a.(!o + 3) else Outline.curve pen 0. a.(!o) a.(!o + 1) a.(!o + 2) a.(!o + 3) last;
                across := not !across;
                o := !o + 4
              done
          | 10 | 29 -> (
              let subrs = if b = 10 then local else t.global_subrs in
              match !stack with
              | n :: rest ->
                  stack := rest;
                  let k = int_of_float n + bias subrs in
                  if depth < 10 && k >= 0 && k < Array.length subrs then run subrs.(k) (depth + 1)
              | [] -> ())
          | 11 -> i := stop
          | 14 -> ignore (args false (Some 0)); ended := true
          | 12 ->
              let op = u8 s !i in
              incr i;
              let a = args false None in
              let n = Array.length a in
              (* two curves that are nearly a line *)
              if op = 35 && n >= 12 then (Outline.curve pen a.(0) a.(1) a.(2) a.(3) a.(4) a.(5); Outline.curve pen a.(6) a.(7) a.(8) a.(9) a.(10) a.(11))
              else if op = 34 && n >= 7 then (Outline.curve pen a.(0) 0. a.(1) a.(2) a.(3) 0.; Outline.curve pen a.(4) 0. a.(5) (-.a.(2)) a.(6) 0.)
              else if op = 36 && n >= 9 then (Outline.curve pen a.(0) a.(1) a.(2) a.(3) a.(4) 0.; Outline.curve pen a.(5) 0. a.(6) a.(7) a.(8) (-.(a.(1) +. a.(3) +. a.(7))))
              else if op = 37 && n >= 11 then (
                let dx = a.(0) +. a.(2) +. a.(4) +. a.(6) +. a.(8) and dy = a.(1) +. a.(3) +. a.(5) +. a.(7) +. a.(9) in
                Outline.curve pen a.(0) a.(1) a.(2) a.(3) a.(4) a.(5);
                if Float.abs dx > Float.abs dy then Outline.curve pen a.(6) a.(7) a.(8) a.(9) a.(10) (-.dy) else Outline.curve pen a.(6) a.(7) a.(8) a.(9) (-.dx) a.(10))
          | _ -> stack := []
      done
    in
    run t.charstrings.(g) 0;
    Outline.drawn pen)
