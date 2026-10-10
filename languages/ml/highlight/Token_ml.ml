(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's languages/ocaml/Token_ml.ml (docs/plans/plan_emacs.md) *)

(* See Token_ml.mli *)

type kind =
  | Comment
  | Keyword
  | Lident
  | Uident
  | Label
  | Type_var
  | Int
  | Float
  | Char
  | String
  | Operator
  | Punctuation
  | Directive
  | Error

type t = { kind : kind; text : string; offset : int; line : int; col : int }

let show_kind = function
  | Comment -> "Comment"
  | Keyword -> "Keyword"
  | Lident -> "Lident"
  | Uident -> "Uident"
  | Label -> "Label"
  | Type_var -> "Type_var"
  | Int -> "Int"
  | Float -> "Float"
  | Char -> "Char"
  | String -> "String"
  | Operator -> "Operator"
  | Punctuation -> "Punctuation"
  | Directive -> "Directive"
  | Error -> "Error"
