(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Doc.mli *)

type font = Roman | Italic | Bold | Mono
type style = { font : font; size : int; shift : int }
type inline = Text of style * string | Break
type par = { fill : bool; first : float; tabs : float list; center : bool; body : inline list }

type block =
  | Heading of int * inline list
  | Para of par
  | Tagged of tagged
  | Indent of float * block list
  | Space of float

and tagged = { tag : inline list; width : float; body : block list }

type t = { header : string * string * string; body : block list }

let plain : style = { font = Roman; size = 0; shift = 0 }

let letters (s : string) : string =
  if not (String.contains s '\xc2' || String.contains s '\xe2') then s
  else String.concat "" (List.filter (fun c -> c <> "\xc2\xad" && c <> "\xe2\x81\xa0" && c <> "\xe2\x80\x8b") (fst (Utf8.chars s)))
