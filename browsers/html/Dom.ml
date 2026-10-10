(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/html/Dom.ml, its first version; element_with and attribute_any, where the attributes and ~extensions were optional (docs/plans/plan_browser.md) *)

(* See Dom.mli *)

type node = Element of element | Text of string
and element = {
  name : string;
  attributes : (string * string) list;
  extensions : (string * string) list;
  origin : Dtd.origin;
  children : node list;
}

let element_with (attributes : (string * string) list) (name : string) (children : node list) : element =
  { name; attributes; extensions = []; origin = Core; children }

let element (name : string) (children : node list) : element = element_with [] name children
let attribute (name : string) (e : element) : string option = List.assoc_opt name e.attributes

let attribute_any (name : string) (e : element) : string option =
  match List.assoc_opt name e.attributes with Some v -> Some v | None -> List.assoc_opt name e.extensions

(* (mini-chrome's later Dom's: the two below)
 * opti: its name, its attributes and how many children, not
 * Hashtbl.hash of the element, which reads every string it holds: for
 * one near the root, a script of 300 KB written in the page *)
let hash (e : element) : int = Hashtbl.hash (e.name, e.attributes, List.length e.children)

let comment_name = "#comment"

let rec find_all (name : string) (e : element) : element list =
  (if e.name = name then [ e ] else [])
  @ List.concat_map (fun n -> match n with Element c -> find_all name c | Text _ -> []) e.children

let text_content (e : element) : string =
  let b = Buffer.create 64 in
  let rec go (e : element) =
    List.iter (fun n -> match n with Text s -> Buffer.add_string b s | Element c -> go c) e.children
  in
  go e;
  Buffer.contents b

let is_blank (s : string) : bool = String.for_all (fun c -> c = ' ' || c = '\n' || c = '\t') s

let rec without_blank_text (e : element) : element =
  {
    e with
    children =
      List.filter_map
        (fun n ->
          match n with Text s when is_blank s -> None | Text _ -> Some n | Element c -> Some (Element (without_blank_text c)))
        e.children;
  }

let to_lines (root : element) : string list =
  let lines = ref [] in
  let add depth s = lines := (String.make (2 * depth) ' ' ^ s) :: !lines in
  let rec go depth (e : element) =
    let list attributes = List.map (fun (n, v) -> Printf.sprintf "%s=\"%s\"" n v) attributes in
    let mark =
      match (e.origin, e.extensions) with
      | Netscape, _ -> [ "{Netscape}" ]
      | Core, [] -> []
      | Core, extensions -> [ "{Netscape: " ^ String.concat " " (list extensions) ^ "}" ]
    in
    add depth (String.concat " " ((e.name :: list e.attributes) @ mark));
    List.iter
      (fun n ->
        match n with
        | Element c -> go (depth + 1) c
        | Text s ->
            let escaped = String.concat "\\n" (String.split_on_char '\n' s) in
            add (depth + 1) ("\"" ^ escaped ^ "\""))
      e.children
  in
  go 0 root;
  List.rev !lines
