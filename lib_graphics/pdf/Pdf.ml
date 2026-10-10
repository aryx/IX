(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/pdf/Pdf.ml; Pdf_object's parse_with where parse had a length; a for's variable named (docs/plans/plan_pdf.md) *)

(* See Pdf.mli *)

open Pdf_object

let fail (what : string) = failwith ("Pdf: " ^ what)

(* where an object is: at a place in the file, or the n-th of the
 * objects packed in another's stream *)
type place = At of int | Packed of int * int

type t = {
  bytes : string;
  places : (int, place) Hashtbl.t;
  objects : (int, Pdf_object.t) Hashtbl.t; (* those read so far *)
  unpacked : (int, Pdf_object.t array) Hashtbl.t; (* a packing stream's objects, read once *)
  mutable trailer : dict;
}

type page = { dict : dict; resources : Pdf_object.t; box : float * float * float * float; rotate : int }

(* the object "n g obj" at a place *)
let rec object_at (t : t) (at : int) : Pdf_object.t =
  let s = t.bytes in
  let _, i = word s (skip s at) in
  let _, i = word s (skip s i) in
  let w, i = word s (skip s i) in
  if w <> "obj" then Null else fst (parse_with ~length:(fun v -> match resolve t v with Int n -> Some n | _ -> None) s i)

and resolve (t : t) (v : Pdf_object.t) : Pdf_object.t =
  match v with
  | Ref n -> (
      match Hashtbl.find_opt t.objects n with
      | Some o -> o
      | None ->
          (* said to be Null while it is read: a reference to itself ends *)
          Hashtbl.replace t.objects n Null;
          let o =
            match Hashtbl.find_opt t.places n with
            | Some (At at) -> ( try object_at t at with _ -> Null)
            | Some (Packed (container, index)) -> ( try (packed t container).(index) with _ -> Null)
            | None -> Null
          in
          let o = match o with Ref _ -> resolve t o | o -> o in
          Hashtbl.replace t.objects n o;
          o)
  | v -> v

(* the objects packed in a stream: n pairs of a number and an offset,
 * then the objects themselves *)
and packed (t : t) (container : int) : Pdf_object.t array =
  match Hashtbl.find_opt t.unpacked container with
  | Some objects -> objects
  | None ->
      let objects =
        match resolve t (Ref container) with
        | Stream (d, raw) ->
            let data = fst (Pdf_filter.decode (resolve t) d raw) in
            let int key = match List.assoc_opt key d with Some v -> to_int (resolve t v) | None -> 0 in
            let first = int "First" in
            let rec offsets i k acc = if k = 0 then List.rev acc else let _, i = parse data i in let o, i = parse data i in offsets i (k - 1) (to_int o :: acc) in
            Array.of_list (List.map (fun o -> fst (parse data (first + o))) (offsets 0 (int "N") []))
        | _ -> [||]
      in
      Hashtbl.replace t.unpacked container objects;
      objects

let get (t : t) (d : dict) (key : string) : Pdf_object.t = match List.assoc_opt key d with Some v -> resolve t v | None -> Null
let dict (t : t) (v : Pdf_object.t) : dict = match resolve t v with Dict d | Stream (d, _) -> d | _ -> []

let data (t : t) (v : Pdf_object.t) : string =
  match resolve t v with Stream (d, raw) -> fst (Pdf_filter.decode (resolve t) d raw) | _ -> ""

(* the table of where the objects are, at [at]: lines of text, or a
 * stream of numbers of fixed widths; then the one before it (/Prev),
 * whose places count only for objects not yet known *)
let rec read_table (t : t) (at : int) (seen : int list) : unit =
  let s = t.bytes in
  if at >= 0 && at < String.length s && not (List.mem at seen) then (
    let add n place = if not (Hashtbl.mem t.places n) then Hashtbl.replace t.places n place in
    let w, i = word s (skip s at) in
    let trailer =
      if w = "xref" then (
        let rec sections i =
          let w, j = word s (skip s i) in
          match int_of_string_opt w with
          | Some first ->
              let count, j = word s (skip s j) in
              let j = ref j in
              for n = first to first + int_of_string count - 1 do
                let offset, k = word s (skip s !j) in
                let _, k = word s (skip s k) in
                let kind, k = word s (skip s k) in
                if kind = "n" then add n (At (int_of_string offset));
                j := k
              done;
              sections !j
          | None -> j
        in
        match parse s (sections i) with Dict d, _ -> d | _ -> [])
      else
        match object_at t at with
        | Stream (d, raw) ->
            let data = fst (Pdf_filter.decode (fun v -> v) d raw) in
            let ints key = match List.assoc_opt key d with Some (Array l) -> List.map to_int l | _ -> [] in
            let w = match ints "W" with [ a; b; c ] -> (a, b, c) | _ -> fail "a table of objects with no widths" in
            let w1, w2, w3 = w in
            let size = match List.assoc_opt "Size" d with Some v -> to_int v | None -> 0 in
            let index = match ints "Index" with [] -> [ 0; size ] | l -> l in
            let pos = ref 0 in
            let field width default =
              if width = 0 then default
              else (
                let v = ref 0 in
                for _i = 1 to width do v := (!v lsl 8) lor (if !pos < String.length data then Char.code data.[!pos] else 0); incr pos done;
                !v)
            in
            let rec ranges = function
              | first :: count :: rest ->
                  for n = first to first + count - 1 do
                    let kind = field w1 1 in
                    let a = field w2 0 in
                    let b = field w3 0 in
                    if kind = 1 then add n (At a) else if kind = 2 then add n (Packed (a, b))
                  done;
                  ranges rest
              | _ -> ()
            in
            ranges index;
            d
        | _ -> []
    in
    if t.trailer = [] then t.trailer <- trailer
    else List.iter (fun (k, v) -> if not (List.mem_assoc k t.trailer) then t.trailer <- t.trailer @ [ (k, v) ]) trailer;
    (match List.assoc_opt "XRefStm" trailer with Some (Int o) -> read_table t o (at :: seen) | _ -> ());
    match List.assoc_opt "Prev" trailer with Some (Int o) -> read_table t o (at :: seen) | _ -> ())

(* a file whose table is wrong or missing: every "n g obj" found by
 * reading the whole of it *)
let rebuild (t : t) : unit =
  let s = t.bytes and n = String.length t.bytes in
  Hashtbl.reset t.places;
  Hashtbl.reset t.objects;
  Hashtbl.reset t.unpacked;
  t.trailer <- [];
  let i = ref 0 in
  while !i < n - 3 do
    if s.[!i] = 'o' && String.sub s !i 3 = "obj" && !i > 0 && is_space s.[!i - 1] && (!i + 3 >= n || not (is_regular s.[!i + 3])) then (
      (* back over the generation and the number *)
      let back j = let j = ref j in while !j > 0 && is_space s.[!j - 1] do decr j done; let e = !j in while !j > 0 && s.[!j - 1] >= '0' && s.[!j - 1] <= '9' do decr j done; (!j, e) in
      let g0, _ = back !i in
      let n0, n1 = back g0 in
      match int_of_string_opt (String.sub s n0 (n1 - n0)) with Some num -> Hashtbl.replace t.places num (At n0) | None -> ());
    (if s.[!i] = 't' && !i + 7 <= n && String.sub s !i 7 = "trailer" then match parse s (!i + 7) with Dict d, _ -> t.trailer <- d @ t.trailer | _ -> ());
    incr i
  done;
  if not (List.mem_assoc "Root" t.trailer) then
    Hashtbl.iter (fun num _ -> match resolve t (Ref num) with Dict d when List.assoc_opt "Type" d = Some (Name "Catalog") -> t.trailer <- ("Root", Ref num) :: t.trailer | _ -> ()) (Hashtbl.copy t.places)

let sniff (s : string) : bool =
  let head = String.sub s 0 (min 1024 (String.length s)) in
  let rec has i = i + 5 <= String.length head && (String.sub head i 5 = "%PDF-" || has (i + 1)) in
  has 0

let root (t : t) : dict = dict t (get t t.trailer "Root")

let of_string (bytes : string) : t =
  if not (sniff bytes) then fail "not a PDF file";
  let t = { bytes; places = Hashtbl.create 256; objects = Hashtbl.create 256; unpacked = Hashtbl.create 16; trailer = [] } in
  (* "startxref", then the table's place, at the end *)
  let n = String.length bytes in
  let rec find i = if i < 0 then None else if i + 9 <= n && String.sub bytes i 9 = "startxref" then Some i else find (i - 1) in
  (try match find (n - 9) with Some i -> ( match parse bytes (i + 9) with Int at, _ -> read_table t at [] | _ -> ()) | None -> () with _ -> ());
  if get t (root t) "Pages" = Null then rebuild t;
  if get t (root t) "Pages" = Null then fail "no pages found";
  if List.mem_assoc "Encrypt" t.trailer then fail "an encrypted file: not read";
  t

(* the pages, in order: the leaves of a tree whose nodes hand down
 * what a page does not say (its resources, its size, its turn) *)
let pages (t : t) : page list =
  let rec walk (node : Pdf_object.t) (inherited : dict) (depth : int) : page list =
    let d = dict t node in
    let inherited = List.fold_left (fun acc key -> match List.assoc_opt key d with Some v -> (key, v) :: List.remove_assoc key acc | None -> acc) inherited [ "Resources"; "MediaBox"; "CropBox"; "Rotate" ] in
    match get t d "Kids" with
    | Array kids when depth < 64 -> List.concat_map (fun k -> walk k inherited (depth + 1)) kids
    | _ ->
        let box key = match get t inherited key with Array [ a; b; c; d ] -> let f v = to_float (resolve t v) in Some (f a, f b, f c, f d) | _ -> None in
        let x0, y0, x1, y1 = match box "CropBox" with Some b -> b | None -> ( match box "MediaBox" with Some b -> b | None -> (0., 0., 612., 792.)) in
        [ { dict = d; resources = get t inherited "Resources"; box = (Float.min x0 x1, Float.min y0 y1, Float.max x0 x1, Float.max y0 y1); rotate = ((to_int (get t inherited "Rotate") mod 360) + 360) mod 360 } ]
  in
  walk (get t (root t) "Pages") [] 0

(* a page's drawing: its content streams, one after the other *)
let content (t : t) (p : page) : string =
  match get t p.dict "Contents" with
  | Array parts -> String.concat "\n" (List.map (data t) parts)
  | Stream _ as s -> data t s
  | _ -> ""
