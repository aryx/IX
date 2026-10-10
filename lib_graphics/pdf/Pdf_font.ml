(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/pdf/Pdf_font.ml; two types, where they were polymorphic variants (a ToUnicode table's entries, a font's file); Type1's clear is said (docs/plans/plan_pdf.md) *)

(* See Pdf_font.mli *)

open Pdf_object

type glyph =
  | Shape of Outline.t (* in an em of 1, y up *)
  | Program of string (* a Type 3 font's: drawing operators *)
  | Missing (* no outline to be had: the stroke font's turn *)

type t = {
  name : string;
  wide : bool; (* codes of two bytes *)
  width : int -> float; (* a code's advance, in an em of 1 *)
  glyph : int -> glyph;
  unicode : int -> int list; (* a code's characters *)
  matrix : float list; (* a Type 3 font's glyphs to the em *)
  resources : Pdf_object.t; (* and what its programs name *)
}

(* an outline's points through a matrix [a b c d e f] *)
let through (m : float list) (o : Outline.t) : Outline.t =
  match m with
  | [ a; b; c; d; e; f ] ->
      let p (x, y) = ((a *. x) +. (c *. y) +. e, (b *. x) +. (d *. y) +. f) in
      List.map
        (fun (ct : Outline.contour) ->
          { Outline.start = p ct.start; segments = List.map (fun (s : Outline.segment) -> match s with Line q -> Outline.Line (p q) | Quadratic (c, q) -> Quadratic (p c, p q) | Cubic (c1, c2, q) -> Cubic (p c1, p c2, p q)) ct.segments })
        o
  | _ -> o

(* a stream of "<code> <characters>" pairs and ranges: what each code
 * of a font reads as *)
(* what a ToUnicode table's entries are, between its "begin" and "end"
 * words (ix: a type, where they were `Char, `Range and `None) *)
type entries = No_mode | Chars | Ranges

(* a font's file, by its kind (ix: a type, where they were `Type1,
 * `Cff, `Truetype and `None) *)
type file = No_file | File_type1 of Type1.t | File_cff of Cff.t | File_truetype of Truetype.t

let to_unicode (text : string) : (int, int list) Hashtbl.t =
  let table = Hashtbl.create 256 in
  let number (s : string) = String.fold_left (fun v c -> (v lsl 8) lor Char.code c) 0 s in
  (* UTF-16, the high half first *)
  let characters (s : string) =
    let rec go i acc =
      if i + 1 >= String.length s then List.rev acc
      else
        let u = (Char.code s.[i] lsl 8) lor Char.code s.[i + 1] in
        if u >= 0xd800 && u < 0xdc00 && i + 3 < String.length s then go (i + 4) ((0x10000 + ((u - 0xd800) lsl 10) + (((Char.code s.[i + 2] lsl 8) lor Char.code s.[i + 3]) - 0xdc00)) :: acc) else go (i + 2) (u :: acc)
    in
    go 0 []
  in
  let rec tokens i acc = if Pdf_object.skip text i >= String.length text then List.rev acc else let v, j = parse text i in tokens (max j (i + 1)) (v :: acc) in
  let rec go mode = function
    | v :: rest when keyword v = Some "beginbfchar" -> go Chars rest
    | v :: rest when keyword v = Some "beginbfrange" -> go Ranges rest
    | v :: rest when keyword v = Some "endbfchar" || keyword v = Some "endbfrange" -> go No_mode rest
    | String src :: String dst :: rest when mode = Chars -> Hashtbl.replace table (number src) (characters dst); go mode rest
    | String lo :: String hi :: String dst :: rest when mode = Ranges ->
        let first = characters dst in
        for code = number lo to min (number hi) (number lo + 65535) do
          Hashtbl.replace table code (match List.rev first with last :: before -> List.rev ((last + code - number lo) :: before) | [] -> [])
        done;
        go mode rest
    | String lo :: String _ :: Array dsts :: rest when mode = Ranges ->
        List.iteri (fun k d -> match d with String d -> Hashtbl.replace table (number lo + k) (characters d) | _ -> ()) dsts;
        go mode rest
    | _ :: rest -> go mode rest
    | [] -> ()
  in
  go No_mode (tokens 0 []);
  table

let memo (f : int -> 'a) : int -> 'a =
  let table = Hashtbl.create 64 in
  fun code -> match Hashtbl.find_opt table code with Some v -> v | None -> let v = f code in Hashtbl.replace table code v; v

let load (pdf : Pdf.t) (font : Pdf_object.t) : t =
  let d = Pdf.dict pdf font in
  let get = Pdf.get pdf in
  let name_of v = match v with Name n -> n | _ -> "" in
  let subtype = name_of (get d "Subtype") and name = name_of (get d "BaseFont") in
  let codes = match get d "ToUnicode" with Stream _ as s -> Some (to_unicode (Pdf.data pdf s)) | _ -> None in
  (* the font's file, in its descriptor: which of the three kinds says what it is *)
  let file (descriptor : dict) =
    match (get descriptor "FontFile", get descriptor "FontFile2", get descriptor "FontFile3") with
    | (Stream (sd, _) as s), _, _ -> ( try File_type1 (Type1.of_string ~clear:(to_int (get sd "Length1")) (Pdf.data pdf s)) with _ -> No_file)
    | _, (Stream _ as s), _ -> ( try let f = Truetype.of_string (Pdf.data pdf s) in (match Truetype.cff f with Some c -> File_cff (Cff.of_string c) | None -> File_truetype f) with _ -> No_file)
    | _, _, (Stream (sd, _) as s) -> (
        let bytes = Pdf.data pdf s in
        try if name_of (get sd "Subtype") = "OpenType" then (match Truetype.cff (Truetype.of_string bytes) with Some c -> File_cff (Cff.of_string c) | None -> File_truetype (Truetype.of_string bytes)) else File_cff (Cff.of_string bytes)
        with _ -> No_file)
    | _ -> No_file
  in
  let truetype_shape (f : Truetype.t) (g : int) : glyph = let k = 1. /. float_of_int (Truetype.units f) in Shape (through [ k; 0.; 0.; k; 0.; 0. ] (Truetype.outline f g)) in
  if subtype = "Type0" then (
    (* codes of two bytes, each a CID of the font below *)
    let below = Pdf.dict pdf (match get d "DescendantFonts" with Array (f :: _) -> f | f -> f) in
    let descriptor = Pdf.dict pdf (get below "FontDescriptor") in
    let default = match get below "DW" with Null -> 1000. | v -> to_float v in
    let widths = Hashtbl.create 256 in
    (* "c [w w w]" from c on, or "first last w" *)
    let rec fill = function
      | first :: Array ws :: rest -> List.iteri (fun k w -> Hashtbl.replace widths (to_int first + k) (to_float (Pdf.resolve pdf w))) ws; fill rest
      | first :: last :: w :: rest -> for c = to_int first to min (to_int last) (to_int first + 65535) do Hashtbl.replace widths c (to_float w) done; fill rest
      | _ -> ()
    in
    (match get below "W" with Array l -> fill (List.map (Pdf.resolve pdf) l) | _ -> ());
    let map = match get below "CIDToGIDMap" with Stream _ as s -> Some (Pdf.data pdf s) | _ -> None in
    let glyph =
      match file descriptor with
      | File_truetype f -> fun cid -> truetype_shape f (match map with Some m when (2 * cid) + 1 < String.length m -> (Char.code m.[2 * cid] lsl 8) lor Char.code m.[(2 * cid) + 1] | Some _ -> 0 | None -> cid)
      | File_cff f -> fun cid -> Shape (through (Cff.matrix f) (Cff.outline f (Cff.glyph_of_cid f cid)))
      | _ -> fun _ -> Missing
    in
    { name; wide = true; width = (fun c -> (match Hashtbl.find_opt widths c with Some w -> w | None -> default) /. 1000.); glyph = memo glyph;
      unicode = (fun c -> match codes with Some t -> (match Hashtbl.find_opt t c with Some u -> u | None -> []) | None -> []); matrix = []; resources = Null })
  else (
    let descriptor = Pdf.dict pdf (get d "FontDescriptor") in
    let symbolic = to_int (get descriptor "Flags") land 4 <> 0 in
    let embedded = if subtype = "Type3" then No_file else file descriptor in
    (* a code's glyph by name: the encoding the font names, or its own, with the page's changes *)
    let base, differences =
      match get d "Encoding" with
      | Name n -> (Some n, [])
      | Dict e ->
          let rec changes code acc = function
            | Int c :: rest -> changes c acc rest
            | Name n :: rest -> changes (code + 1) ((code, n) :: acc) rest
            | _ :: rest -> changes code acc rest
            | [] -> acc
          in
          ((match get e "BaseEncoding" with Name n -> Some n | _ -> None), match get e "Differences" with Array l -> changes 0 [] (List.map (Pdf.resolve pdf) l) | _ -> [])
      | _ -> (None, [])
    in
    let by_table (table : int array) (code : int) = if code < 256 then (match Glyph_names.name table.(code) with Some n -> n | None -> "") else "" in
    let builtin (code : int) : string =
      match embedded with
      | File_type1 f -> (Type1.encoding f).(code land 255)
      | _ -> if symbolic then "" else Glyph_names.standard_encoding.(code land 255)
    in
    let named (code : int) : string =
      match List.assoc_opt code differences with
      | Some n -> n
      | None -> (
          match base with
          | Some "WinAnsiEncoding" -> by_table Glyph_names.win_ansi code
          | Some "MacRomanEncoding" -> by_table Glyph_names.mac_roman code
          | Some "StandardEncoding" -> Glyph_names.standard_encoding.(code land 255)
          | _ -> builtin code)
    in
    let first = to_int (get d "FirstChar") in
    let widths = match get d "Widths" with Array l -> Array.of_list (List.map (fun w -> to_float (Pdf.resolve pdf w)) l) | _ -> [||] in
    let missing = to_float (get descriptor "MissingWidth") in
    let matrix = match get d "FontMatrix" with Array l -> List.map (fun v -> to_float (Pdf.resolve pdf v)) l | _ -> [ 0.001; 0.; 0.; 0.001; 0.; 0. ] in
    (* a Type 3 font's widths are in its own units *)
    let unit = if subtype = "Type3" then (match matrix with a :: _ -> Float.abs a | [] -> 0.001) else 0.001 in
    (* a font not in the file and with no widths said: one of the standard ones, whose widths are known *)
    let width (code : int) : float =
      (if code - first >= 0 && code - first < Array.length widths then widths.(code - first)
       else if Array.length widths = 0 then (match Standard_widths.width name (named code) with Some w -> float_of_int w | None -> -1000.)
       else missing)
      *. unit
    in
    let glyph : int -> glyph =
      if subtype = "Type3" then (
        let programs = Pdf.dict pdf (get d "CharProcs") in
        fun code -> match get programs (named code) with Stream _ as s -> Program (Pdf.data pdf s) | _ -> Shape [])
      else
        match embedded with
        | File_type1 f -> fun code -> let n = named code in if Type1.has f n then Shape (through (Type1.matrix f) (fst (Type1.glyph f n))) else Shape []
        | File_cff f ->
            fun code ->
              let g = if base = None && differences = [] then Cff.encoding f code else match Cff.glyph_of_name f (named code) with Some g -> g | None -> Cff.encoding f code in
              Shape (through (Cff.matrix f) (Cff.outline f g))
        | File_truetype f ->
            let unicode = Truetype.cmap f ~platform:3 ~encoding:1 and symbol = Truetype.cmap f ~platform:3 ~encoding:0 and mac = Truetype.cmap f ~platform:1 ~encoding:0 in
            fun code ->
              let try_ (m : (int -> int) option) (c : int option) = match (m, c) with Some m, Some c -> m c | _ -> 0 in
              let by_name = if symbolic && base = None && differences = [] then None else Glyph_names.unicode (named code) in
              let candidates = [ try_ unicode by_name; try_ symbol (Some code); try_ symbol (Some (0xf000 + code)); try_ mac (Some code); try_ unicode (Some code) ] in
              truetype_shape f (match List.find_opt (fun g -> g <> 0) candidates with Some g -> g | None -> 0)
        | No_file -> fun _ -> Missing
    in
    let unicode (code : int) : int list =
      match Option.bind codes (fun t -> Hashtbl.find_opt t code) with
      | Some l -> l
      | None -> ( match Glyph_names.unicode (named code) with Some u -> [ u ] | None -> if code >= 32 && code < 127 then [ code ] else [])
    in
    { name; wide = false; width; glyph = memo glyph; unicode; matrix; resources = get d "Resources" })
