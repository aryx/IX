(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/code/highlight/Highlight_code.ml (docs/plans/plan_emacs.md): the categories and a file as lines of spans; without their colours (an editor's own: mini-emacs's Config), their names, and what a code map asks (occurrences, definitions, references) *)

(* See Highlight_code.mli *)

type category =
  | Comment
  | Comment_section
  | Keyword
  | Keyword_control
  | Keyword_module
  | Def_function
  | Def_value
  | Def_type
  | Def_module
  | Parameter
  | Local
  | Global
  | Module
  | Constructor
  | Type
  | Type_var
  | Label
  | Capability
  | Number
  | String
  | Operator
  | Punctuation
  | Attribute
  | Normal
  | Error
  | Field

type span = { col : int; text : string; category : category }
let lines (src : string) (tokens : (int * int * string * category) list) : span list array =
  let nlines = List.length (String.split_on_char '\n' src) in
  let out = Array.make nlines [] in
  List.iter
    (fun (line1, col, text, category) ->
      (* a token over several lines: a span per line, the first at the
       * token's column, the others at 0 *)
      List.iteri
        (fun k piece ->
          let line = line1 - 1 + k in
          if piece <> "" && line >= 0 && line < nlines then
            out.(line) <- { col = (if k = 0 then col else 0); text = piece; category } :: out.(line))
        (String.split_on_char '\n' text))
    tokens;
  Array.map List.rev out
