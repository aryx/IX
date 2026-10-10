(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's libs/dom/Shadow_tree.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Shadow_tree.mli *)
open Dom

let attr (name : string) (e : element) : string option = Dom.attribute_any name e

(* the slot a light node asks for: "" is the one with no name *)
let wanted (n : node) : string = match n with Element e -> (match (attr "slot" e) with Some v_ -> v_ | None -> "") | Text _ -> ""

let distribute ~(shadow : node list) ~(light : node list) : node list =
  let rec node (n : node) : node list =
    match n with
    | Element ({ name = "slot"; _ } as slot) -> (
        let name = (match (attr "name" slot) with Some v_ -> v_ | None -> "") in
        match List.filter (fun l -> wanted l = name) light with
        (* given nothing but spaces between the tags: its own content *)
        | given when List.exists (fun l -> match l with Text t -> String.trim t <> "" | Element _ -> true) given -> given
        | _ -> List.concat_map node slot.children)
    | Element e -> [ Element { e with children = List.concat_map node e.children } ]
    | Text _ -> [ n ]
  in
  List.concat_map node shadow

let is_root (n : node) : bool = match n with Element ({ name = "template"; _ } as t) -> attr "shadowrootmode" t <> None | _ -> false

let rec composed (e : element) : element =
  (* its children first: a host can be in a host's shadow tree, or in its light one *)
  let children = List.map (fun n -> match n with Element c -> let c' = composed c in if c' == c then n else Element c' | Text _ -> n) e.children in
  match List.find_opt is_root children with
  | Some (Element root) -> { e with children = distribute ~shadow:root.children ~light:(List.filter (fun n -> not (is_root n)) children) }
  | _ -> if List.for_all2 ( == ) children e.children then e else { e with children }
