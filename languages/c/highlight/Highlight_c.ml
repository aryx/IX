(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's languages/c/Highlight_c.ml (docs/plans/plan_emacs.md), a token's category from its kind; without the pass over the tree (Parse_c, 898 lines, and Ast_c: what each name is) and analyze *)

(* See Highlight_c.mli *)

open Highlight_code

(*****************************************************************************)
(* From the tokens *)
(*****************************************************************************)

let control_keywords = [ "if"; "else"; "while"; "for"; "do"; "switch"; "case"; "default"; "return"; "break"; "continue"; "goto" ]
let type_keywords = [ "void"; "char"; "short"; "int"; "long"; "float"; "double"; "signed"; "unsigned"; "_Bool"; "__signed__" ]

(* a banner comment: /*****...*/ or //*****... *)
let is_banner (t : Token_c.t) : bool =
  t.kind = Comment
  && String.length t.text >= 7
  && (String.sub t.text 0 7 = "/******" || String.sub t.text 0 7 = "//*****")

(* a token's category from its kind alone *)
let of_kind (t : Token_c.t) : category =
  match t.kind with
  | Comment -> Comment
  | Keyword ->
      if List.mem t.text control_keywords then Keyword_control
      else if List.mem t.text type_keywords then Type
      else Keyword
  | Ident -> if Token_c.is_constant t.text then Constructor else Normal
  | Int | Float -> Number
  | Char | String -> String
  | Operator -> Operator
  | Punctuation -> Punctuation
  | Directive -> Keyword_module
  | Error -> Error

let categorize (toks : Token_c.t list) : (Token_c.t * category) list =
  let all = Array.of_list toks in
  let n = Array.length all in
  Array.to_list (Array.mapi (fun (i : int) (t : Token_c.t) ->
    (t, if is_banner t || (t.kind = Comment && i > 0 && is_banner all.(i - 1) && i + 1 < n && is_banner all.(i + 1)) then Comment_section
        else of_kind t)) all)

let lines (src : string) : span list array =
  Highlight_code.lines src
    (List.rev (List.rev_map (fun ((t : Token_c.t), (c : category)) -> (t.line, t.col, t.text, c)) (categorize (Lexer_c.tokens src))))
