(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Highlight.mli *)

let color (fg : Vt.color) : Vt.attrs = { Vt.plain with fg }
let bold (fg : Vt.color) : Vt.attrs = { Vt.plain with fg; bold = true }

let attrs (category : Highlight_code.category) : Vt.attrs =
  match category with
  | Comment -> color Red
  | Comment_section -> bold Red
  | Keyword | Keyword_module -> color Magenta
  | Keyword_control -> bold Magenta
  | Def_function | Def_value | Def_type | Def_module -> bold Blue
  | Type | Type_var -> color Blue
  | Constructor | Module -> color Cyan
  | Capability -> bold Cyan
  | String | Number -> color Green
  | Label | Attribute -> color Yellow
  | Error -> { Vt.plain with fg = Red; reverse = true }
  | Parameter | Local | Global | Field | Operator | Punctuation | Normal -> Vt.plain

let mode (name : string) (lines : string -> Highlight_code.span list array) : Efuns.major_mode = {
  maj_name = name;
  maj_map = Keymap.create ();
  maj_colors = Some (fun (text : string) ->
    Array.map (fun (spans : Highlight_code.span list) ->
      List.filter_map (fun (span : Highlight_code.span) ->
        let a = attrs span.category in
        if a = Vt.plain then None else Some (span.col, String.length span.text, a)) spans) (lines text));
  maj_hooks = [];
}
