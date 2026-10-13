(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Doc.mli *)

type font = Roman | Italic | Bold | Mono
type style = { font : font; size : int; shift : int }
type inline = Text of style * string | Break
type par = { fill : bool; first : float; short : float; tabs : float list; center : bool; body : inline list }

type align = Left | Right | Center | Numeric
type cell = { align : align; span : int; filled : bool; body : inline list }
type table_row = Cells of cell list | Rule
type table = { centered : bool; boxed : bool; widths : float list; rows : table_row list }

type mark = Stroke of (float * float) list | Label of float * float * int * inline list
type picture = { wide : float; high : float; marks : mark list }

type block =
  | Heading of int * inline list
  | Para of par
  | Tagged of tagged
  | Indent of float * block list
  | Space of float
  | Footnote of block list
  | Keep of block list
  | Table of table
  | Picture of picture

and tagged = { tag : inline list; width : float; body : block list }

type t = { header : string * string * string; width : float; margin : float; sub : float; body : block list }

let plain : style = { font = Roman; size = 0; shift = 0 }

let letters (s : string) : string =
  if not (String.contains s '\xc2' || String.contains s '\xe2') then s
  else String.concat "" (List.filter (fun c -> c <> "\xc2\xad" && c <> "\xe2\x81\xa0" && c <> "\xe2\x80\x8b") (fst (Utf8.chars s)))

(* a text's letters, without its looks *)
let words (l : inline list) : string =
  String.concat "" (List.map (fun (i : inline) -> match i with Text (_, s) -> letters s | Break -> " ") l)

let map_text (f : style -> string -> string) (d : t) : t =
  let inline (i : inline) : inline = match i with Text (style, s) -> Text (style, f style s) | Break -> Break in
  let rec block (b : block) : block =
    match b with
    | Heading (level, text) -> Heading (level, List.map inline text)
    | Para p -> Para { p with body = List.map inline p.body }
    | Tagged { tag; width; body } -> Tagged { tag = List.map inline tag; width; body = List.map block body }
    | Indent (by, inner) -> Indent (by, List.map block inner)
    | Space n -> Space n
    | Footnote inner -> Footnote (List.map block inner)
    | Keep inner -> Keep (List.map block inner)
    | Table t ->
        Table { t with rows = List.map (fun (r : table_row) -> match r with Rule -> Rule | Cells cs -> Cells (List.map (fun (c : cell) -> { c with body = List.map inline c.body }) cs)) t.rows }
    | Picture p -> Picture { p with marks = List.map (fun (m : mark) -> match m with Stroke _ -> m | Label (x, y, side, text) -> Label (x, y, side, List.map inline text)) p.marks } in
  { d with body = List.map block d.body }
