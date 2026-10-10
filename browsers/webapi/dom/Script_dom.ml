(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/webapi/dom/Script_dom.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_dom.mli *)
open Js_value
open Script_types

(*****************************************************************************)
(* The copy: nodes with a parent *)
(*****************************************************************************)

let text_name = "#text"
let is_text (n : node) : bool = n.name = text_name

(* two more that are not elements: a comment (its text kept,
 * never shown), and a fragment, a parent for nodes on their way into
 * a tree (appended, its children go in its place) *)
let comment_name = Dom.comment_name
let fragment_name = "#document-fragment"
let is_element (n : node) : bool = n.name = "" || n.name.[0] <> '#'
let make_with (text : string) (attributes : (string * string) list) (name : string) : node =
  { name; text; attributes; children = []; parent = None; expando = []; wrapper = None; listeners = []; compiled = []; shadow = None }

let make (name : string) : node = make_with "" [] name

let rec thaw (e : Dom.element) : node =
  (* a comment the parser kept: a node of its text *)
  if e.name = comment_name then make_with (Dom.text_content e) [] comment_name
  else
  let n = make_with "" (e.attributes @ e.extensions) e.name in
  let children =
    List.map
      (fun (c : Dom.node) ->
        let child = match c with Element e -> thaw e | Text s -> make_with s [] text_name in
        child.parent <- Some n;
        child)
      e.children
  in
  (* a <template shadowrootmode> written in the page is its parent's
   * shadow tree, not its child (Shadow_tree.mli: declarative) *)
  let declared (c : node) = c.name = "template" && List.mem_assoc "shadowrootmode" c.attributes in
  (match List.find_opt declared children with Some template -> attach_shadow n template.children | None -> ());
  n.children <- List.filter (fun c -> not (declared c)) children;
  n

(* a shadow tree's root for [host], holding [children]: a fragment,
 * whose parent is said to be the host -- so that what is put in it is
 * in the page, and an event in it goes up through the host *)
and attach_shadow (host : node) (children : node list) : unit =
  let root = make fragment_name in
  root.children <- children;
  List.iter (fun (c : node) -> c.parent <- Some root) children;
  root.parent <- Some host;
  host.shadow <- Some root

(* back into a Dom value: Netscape's attributes apart again (Dtd.origin),
 * as the lexer puts them *)
let rec freeze (n : node) : Dom.element =
  let origin = Dtd.element_origin n.name in
  let attributes, extensions =
    match origin with
    | Netscape -> (n.attributes, [])
    | Core -> List.partition (fun a -> Dtd.attribute_origin n.name a = Dtd.Core) n.attributes
  in
  let children = List.filter_map (fun c -> if is_text c then Some (Dom.Text c.text) else if is_element c then Some (Dom.Element (freeze c)) else None) n.children in
  { name = n.name; attributes; extensions; origin; children }

(* every element under [n] ([n] too), in document order *)
let rec elements (n : node) : node list = (if is_element n then [ n ] else []) @ List.concat_map elements n.children

let rec text_content (n : node) : string =
  if is_text n then n.text else String.concat "" (List.map text_content (List.filter (fun c -> c.name <> comment_name) n.children))

(* the top of the tree a node is in: the page's root, or that of a
 * tree a script made and has not put in the page *)
let rec top (n : node) : node = match n.parent with Some p -> top p | None -> n
let attribute (n : node) (k : string) : string option = List.assoc_opt k n.attributes

let set_attribute (n : node) (k : string) (v : string) : unit =
  n.attributes <- (if List.mem_assoc k n.attributes then List.map (fun (a, x) -> if a = k then (a, v) else (a, x)) n.attributes else n.attributes @ [ (k, v) ])

let detach (n : node) : unit =
  Option.iter (fun p -> p.children <- List.filter (fun c -> c != n) p.children) n.parent;
  n.parent <- None

let adopt (parent : node) (children : node list) : unit = List.iter (fun c -> c.parent <- Some parent) children

(*****************************************************************************)
(* HTML: innerHTML read and written *)
(*****************************************************************************)

let escape ~(quote : bool) (s : string) : string =
  let b = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      match c with
      | '&' -> Buffer.add_string b "&amp;"
      | '<' -> Buffer.add_string b "&lt;"
      | '>' -> Buffer.add_string b "&gt;"
      | '"' when quote -> Buffer.add_string b "&quot;"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let rec html_of (n : node) : string =
  if is_text n then escape ~quote:false n.text
  else if n.name = comment_name then "<!--" ^ n.text ^ "-->"
  else if n.name = fragment_name then inner_html n
  else
    let attrs = String.concat "" (List.map (fun (k, v) -> Printf.sprintf " %s=\"%s\"" k (escape ~quote:true v)) n.attributes) in
    Printf.sprintf "<%s%s>%s%s" n.name attrs (inner_html n) (if Dtd.is_void n.name then "" else "</" ^ n.name ^ ">")

(* a <style>'s and a <script>'s text is written as it is ("a > b",
 * "x && y"): the parser reads it so, with no entity *)
and inner_html (n : node) : string =
  match n.name with
  | "style" | "script" -> String.concat "" (List.map (fun (c : node) -> if is_text c then c.text else html_of c) n.children)
  | _ -> String.concat "" (List.map html_of n.children)

(* a fragment's nodes: the parser makes a whole page of it, whose head
 * holds what belongs there (a <style>) and whose body the rest *)
let parse_fragment (s : string) : node list =
  let page = thaw (Html_tree.of_string_with ~comments:true s) in
  List.concat_map (fun (part : node) -> part.children) page.children

(*****************************************************************************)
(* Selectors *)
(*****************************************************************************)

(* the elements matching a selector, in document order, among those of
 * [n]'s tree that [keep]: matched on the frozen tree, with their
 * ancestors, as the page's style sheets are (Css.matches). The tree
 * is the one [n] is in: the page's, or one a script made and has not
 * put in the page (jQuery tries its selectors on such a one) *)
let matching (selector : string) (n : node) ~(keep : node -> bool) : node list =
  match Css.parse (selector ^ " {}") with
  | [] -> throw "SyntaxError" (Printf.sprintf "'%s' is not a valid selector" selector)
  | rules ->
      let found = ref [] in
      (* a tree frozen once, then gone through beside its nodes (it was
       * each element frozen with all it holds, at each element: the
       * tree's size times its depth, for every querySelector) *)
      let rec beside (ancestors : Dom.element list) (n : node) (e : Dom.element) =
        if keep n && List.exists (fun (r : Css.rule) -> Css.matches r.selector ancestors e) rules then found := n :: !found;
        let frozen = List.filter_map (fun (c : Dom.node) -> match c with Element c -> Some c | Text _ -> None) e.children in
        (try List.iter2 (beside (e :: ancestors)) (List.filter is_element n.children) frozen with Invalid_argument _ -> ())
      in
      let rec go (ancestors : Dom.element list) (n : node) =
        if is_element n then beside ancestors n (freeze n) else if n.name = fragment_name then List.iter (go ancestors) n.children
      in
      (* the tree [n] is in ends at a shadow root: what is in a shadow
       * tree is found from its root, not from the page (Shadow_tree.mli) *)
      let rec tree_of (n : node) : node = if n.name = fragment_name then n else match n.parent with Some p -> tree_of p | None -> n in
      go [] (tree_of n);
      List.rev !found

(* opti: what a selector can look at, and no more. The simple way above
 * freezes the whole tree at each question; an application asks matches,
 * closest and querySelector by the thousand as it draws (a Discourse
 * topic: 38 s of them). A selector reads the element, its ancestors
 * and their children (a sibling's place and names), so those alone are
 * frozen: the ancestors with their children bare; and a search goes
 * through the element asked, not the document. Each selector's text is
 * read once. *)
let read_here = Per_domain.make (fun () -> (Hashtbl.create 64 : (string, Css.rule list) Hashtbl.t))

let rules_of (selector : string) : Css.rule list =
  match Hashtbl.find_opt (read_here ()) selector with
  | Some rules -> rules
  | None -> (
      match Css.parse (selector ^ " {}") with
      | [] -> throw "SyntaxError" (Printf.sprintf "'%s' is not a valid selector" selector)
      | rules ->
          if Hashtbl.length (read_here ()) > 2048 then Hashtbl.reset (read_here ());
          Hashtbl.replace (read_here ()) selector rules;
          rules)

(* [n] frozen with these children in place of its own *)
let frozen_with (n : node) (children : Dom.node list) : Dom.element =
  let origin = Dtd.element_origin n.name in
  let attributes, extensions =
    match origin with Netscape -> (n.attributes, []) | Core -> List.partition (fun a -> Dtd.attribute_origin n.name a = Dtd.Core) n.attributes
  in
  { name = n.name; attributes; extensions; origin; children }

(* a node's children frozen bare: themselves, nothing in them *)
let bare (but : (node * Dom.element) option) (n : node) : Dom.node list =
  List.filter_map
    (fun c ->
      match but with
      | Some (kept, e) when c == kept -> Some (Dom.Element e)
      | _ -> if is_text c then Some (Dom.Text c.text) else if is_element c then Some (Dom.Element (frozen_with c [])) else None)
    n.children

(* the ancestors of [n], frozen [e], the nearest first, up to the tree's
 * root (a shadow root ends it) *)
let rec above (n : node) (e : Dom.element) : Dom.element list =
  match n.parent with
  | Some p when is_element p ->
      let pe = frozen_with p (bare (Some (n, e)) p) in
      pe :: above p pe
  | _ -> []

let matches_opti (selector : string) (n : node) : bool =
  let rules = rules_of selector in
  let e = frozen_with n (bare None n) in
  let ancestors = above n e in
  List.exists (fun (r : Css.rule) -> Css.matches r.selector ancestors e) rules

let select_opti (selector : string) ~(within : node) : node list =
  (* opti: "*" is every element under it, and needs no tree frozen to
   * say so. A page's components ask it at each one they connect, and
   * our registry of custom elements does (data/prelude/web/): 5,285
   * times for YouTube's search page, 6.4 million elements copied:
   * its scripts replayed went from 36 s to 29 (OCaml 5.5; 45 to 30
   * with 4.14) *)
  if String.trim selector = "*" then
    (* as the search below goes: through elements, and what is not one (a shadow root) is not entered but from the top *)
    let rec under (n : node) : node list = List.concat_map (fun c -> if is_element c then c :: under c else []) n.children in
    let rec from (n : node) : node list = if is_element n then n :: under n else List.concat_map from n.children in
    if is_element within then under within else List.concat_map from within.children
  else
  let rules = rules_of selector in
  let found = ref [] in
  let rec beside ~(own : bool) (ancestors : Dom.element list) (n : node) (e : Dom.element) =
    if own && List.exists (fun (r : Css.rule) -> Css.matches r.selector ancestors e) rules then found := n :: !found;
    let frozen = List.filter_map (fun (c : Dom.node) -> match c with Element c -> Some c | Text _ -> None) e.children in
    try List.iter2 (beside ~own:true (e :: ancestors)) (List.filter is_element n.children) frozen with Invalid_argument _ -> ()
  in
  let rec from (n : node) =
    if is_element n then (
      let e = freeze n in
      (* the element asked is not among its own answers *)
      beside ~own:(n != within) (above n e) n e)
    else List.iter from n.children
  in
  from within;
  List.rev !found

(* those under [within] *)
let select (_ : t) (selector : string) ~(within : node) : node list =
  (* (found when first asked, and kept) *)
  let inside : node list option ref = ref None in
  let inside () = match !inside with Some l -> l | None -> let l = elements within in inside := Some l; l in
  let find selector =
    if !Mini_opti.enabled then select_opti selector ~within
    else matching selector within ~keep:(fun n -> n != within && List.memq n (inside ()))
  in
  (* :scope is the element asked (el.querySelectorAll(":scope > li")):
   * it is marked for the search, and looked for by its mark *)
  if not (Js_value.contains selector ":scope") then find selector
  else (
    let had = within.attributes in
    within.attributes <- ("data-scope-of-query", "") :: had;
    Fun.protect ~finally:(fun () -> within.attributes <- had)
      (fun () ->
        let b = Buffer.create (String.length selector + 32) and n = String.length selector in
        let rec go i =
          if i < n then
            if i + 6 <= n && String.sub selector i 6 = ":scope" then (Buffer.add_string b "[data-scope-of-query]"; go (i + 6))
            else (Buffer.add_char b selector.[i]; go (i + 1))
        in
        go 0;
        find (Buffer.contents b)))

(* whether [n] itself matches *)
let matches (selector : string) (n : node) : bool =
  if !Mini_opti.enabled then matches_opti selector n else matching selector n ~keep:(fun c -> c == n) <> []
