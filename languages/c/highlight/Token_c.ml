(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's languages/c/Token_c.ml (docs/plans/plan_emacs.md) *)

(* See Token_c.mli *)

type kind = Comment | Keyword | Ident | Int | Float | Char | String | Operator | Punctuation | Directive | Error

type t = { kind : kind; text : string; offset : int; line : int; col : int; pp : bool }

let show_kind = function
  | Comment -> "Comment"
  | Keyword -> "Keyword"
  | Ident -> "Ident"
  | Int -> "Int"
  | Float -> "Float"
  | Char -> "Char"
  | String -> "String"
  | Operator -> "Operator"
  | Punctuation -> "Punctuation"
  | Directive -> "Directive"
  | Error -> "Error"

let is_constant (s : string) : bool =
  String.length s >= 2
  && String.exists (fun c -> c >= 'A' && c <= 'Z') s
  && String.for_all (fun c -> (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_') s
