(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/css/Css.ml, its first version (docs/plans/plan_browser.md) *)

(* See Css.mli *)

type rule = { selector : Selectors.complex; declarations : (string * string) list; important : string list }
type sheet = rule list

(*****************************************************************************)
(* Parsing *)
(*****************************************************************************)

let text_of (ds : Css_syntax.declaration list) : (string * string) list =
  List.map (fun (d : Css_syntax.declaration) -> (d.name, Css_syntax.to_string d.value)) ds

(* a style rule's selectors, a rule each; an at-rule skipped (@media is
 * Cascade's); a selector list not understood, its rule
 * dropped whole, as CSS says *)
let parse (text : string) : sheet =
  Css_syntax.parse_stylesheet text
  |> List.concat_map (fun (r : Css_syntax.rule) ->
         match r with
         | Style_rule { prelude; declarations } -> (
             match Selectors.parse prelude with
             | Some selectors ->
                 let important = List.filter_map (fun (d : Css_syntax.declaration) -> if d.important then Some d.name else None) declarations in
                 List.map (fun selector -> { selector; declarations = text_of declarations; important }) selectors
             | None -> [])
         | At_rule _ -> [])

let declarations (text : string) : (string * string) list = text_of (Css_syntax.parse_declarations text)
let specificity = Selectors.specificity
let matches (sel : Selectors.complex) (ancestors : Dom.element list) (e : Dom.element) : bool = Selectors.matches sel ancestors e
