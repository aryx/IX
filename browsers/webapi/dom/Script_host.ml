(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/webapi/dom/Script_host.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_host.mli *)
open Js_value
open Script_types
open Script_dom (* the copy: its nodes read and changed *)

(* a script has changed the tree: the page to be laid out again *)
let touch (t : t) : unit =
  t.changed <- true;
  t.geometry <- None
let str (v : value) : string = to_string v

(* what a script gives where a text is expected, as a text: an
 * object's by its own toString -- a page that wraps its HTML and its
 * scripts' addresses in "trusted" objects (Trusted Types, or its own:
 * YouTube) gives those to innerHTML and to src, and "[object Object]"
 * was what became of them *)
let text (t : t) (v : value) : string =
  match v with
  | Object { kind = Plain; _ } -> (
      match Js_eval.get t.engine v "toString" with
      | Object { kind = Closure _ | Host_function _; _ } as f -> to_string (Js_eval.call_in_run t.engine f ~this:v [])
      | _ -> to_string v)
  | _ -> to_string v
let arg (args : value list) (i : int) : value = (match (List.nth_opt args i) with Some v_ -> v_ | None -> Undefined)

(* the node a host object stands for *)
let node_of (t : t) (v : value) : node =
  match v with
  | Object o -> ( match Hashtbl.find_opt t.nodes o.id with Some n -> n | None -> throw "TypeError" "parameter 1 is not of type 'Node'")
  | _ -> throw "TypeError" "parameter 1 is not of type 'Node'"

(* the properties that are an attribute of the same name, or almost,
 * and those that say whether an attribute is there *)
let reflected = [ ("name", "name"); ("type", "type"); ("title", "title"); ("lang", "lang"); ("dir", "dir"); ("rel", "rel"); ("target", "target"); ("placeholder", "placeholder"); ("alt", "alt"); ("action", "action"); ("method", "method"); ("role", "role"); ("htmlFor", "for"); ("crossOrigin", "crossorigin"); ("integrity", "integrity"); ("charset", "charset"); ("media", "media") ]
let reflected_flags = [ ("disabled", "disabled"); ("selected", "selected"); ("hidden", "hidden"); ("readOnly", "readonly"); ("required", "required"); ("multiple", "multiple"); ("open", "open"); ("async", "async"); ("defer", "defer"); ("noModule", "nomodule") ]

(* backgroundColor, the property; background-color, the CSS *)
let kebab (s : string) : string =
  String.concat "" (List.map (fun c -> if c >= 'A' && c <= 'Z' then "-" ^ String.make 1 (Char.lowercase_ascii c) else String.make 1 c) (List.init (String.length s) (String.get s)))

(* el.style: its style= attribute's declarations, read and written one
 * by one *)
let style_object (t : t) (n : node) : value =
  let decls () = match attribute n "style" with Some s -> Css.declarations s | None -> [] in
  (* a property given a value, or taken out ("") *)
  let put (k : string) (v : string) : unit =
    let others = List.remove_assoc k (decls ()) in
    let all = if v = "" then others else others @ [ (k, v) ] in
    set_attribute n "style" (String.concat "; " (List.map (fun (k, v) -> k ^ ": " ^ v) all));
    touch t
  in
  host_object
    {
      class_name = "CSSStyleDeclaration";
      get =
        (fun k ->
          match k with
          (* the same by a property's own name: style.setProperty("--x", "1") *)
          | "setProperty" -> host_function k (fun ~this:_ args -> put (str (arg args 0)) (str (arg args 1)); Undefined)
          | "removeProperty" -> host_function k (fun ~this:_ args -> put (str (arg args 0)) ""; String "")
          | "getPropertyValue" -> host_function k (fun ~this:_ args -> String ((match (List.assoc_opt (str (arg args 0)) (decls ())) with Some v_ -> v_ | None -> "")))
          | "cssText" -> String ((match (attribute n "style") with Some v_ -> v_ | None -> ""))
          | "length" -> Number (float_of_int (List.length (decls ())))
          | k -> ( match List.assoc_opt (kebab k) (decls ()) with Some v -> String v | None -> String ""));
      set = (fun k v -> if k = "cssText" then (set_attribute n "style" (str v); touch t) else put (kebab k) (str v));
      show = (fun () -> "CSSStyleDeclaration");
    }

(* what a page asked for that is not here, said once a page with -v
 * ("missing: Window.indexedDB"): a property read that neither the
 * object nor its prototypes have, a function that is there to do
 * nothing. Most are a page asking before it uses (and doing without);
 * the one that matters is in the list, when a page looks wrong *)
(* ix: the debugging switches, a host's to set (they were the logs'
 * level and the environment's JS_MISSING and JS_EVENTS); what they say
 * goes to Js_value.say *)
let says_missing = ref false
let events_said : string list ref = ref []

let missed_here = Per_domain.make (fun () -> (Hashtbl.create 64 : (string, unit) Hashtbl.t))
let missed_names () = missed_here ()

let missed (name : string) : unit =
  if not (Hashtbl.mem (missed_names ()) name) then (
    Hashtbl.add (missed_names ()) name ();
    if !says_missing then !Js_value.say ("missing: " ^ name))

let rec wrap (t : t) (n : node) : value =
  match n.wrapper with
  | Some v -> v
  | None ->
      let v = host_object { class_name = (if is_text n then "Text" else "HTMLElement"); get = get t n; set = set t n; show = (fun () -> show n) } in
      let kind = if is_text n then "text" else if n.name = comment_name then "comment" else if n.name = fragment_name then "fragment" else "element" in
      (match v with Object o -> Hashtbl.replace t.nodes o.id n; o.proto <- (match List.assoc_opt ("tag:" ^ n.name) t.protos with Some p when kind = "element" -> Some p | _ -> List.assoc_opt kind t.protos) | _ -> ());
      n.wrapper <- Some v;
      v

(* an attribute of a custom element set or removed by a script: its
 * class told, if it observes that one (attributeChangedCallback, by
 * the registry: data/prelude/web/) *)
and told_attribute (t : t) (n : node) (a : string) (old : string option) : unit =
  if List.mem_assoc "__upgraded" n.expando && old <> attribute n a then
    match Js_eval.global t.engine "__attribute" with
    | Some (Object _ as f) ->
        let v = function Some s -> String s | None -> Null in
        ignore (Js_eval.call_in_run t.engine f ~this:Undefined [ wrap t n; String a; v old; v (attribute n a) ])
    | _ -> ()

(* how the console shows an element: its start tag *)
and show (n : node) : string =
  if is_text n then Printf.sprintf "%S" n.text
  else if not (is_element n) then n.name
  else "<" ^ n.name ^ String.concat "" (List.map (fun (k, v) -> Printf.sprintf " %s=\"%s\"" k v) n.attributes) ^ ">"

and nodes_array (t : t) (ns : node list) : value = Object (new_array (List.map (wrap t) ns))

and method_ (name : string) (f : value list -> value) : value = host_function name (fun ~this:_ args -> f args)

and get (t : t) (n : node) (k : string) : value =
  let str = text t in
  let elements_of ns = List.filter is_element ns in
  let opt = function Some c -> wrap t c | None -> Null in
  match k with
  (* an element of a drawing keeps its name's case (svg, linearGradient) *)
  | "tagName" | "nodeName" when is_element n && (let rec drawn (n : node) = n.name = "svg" || (match n.parent with Some p -> p.name <> "foreignObject" && drawn p | None -> false) in drawn n) -> String n.name
  | "tagName" | "nodeName" -> String (if is_element n then String.uppercase_ascii n.name else n.name)
  | "nodeType" -> Number (if is_text n then 3. else if n.name = comment_name then 8. else if n.name = fragment_name then 11. else 1.)
  (* the page's, or the document it was read into (DOMParser, createHTMLDocument: its root says) *)
  | "ownerDocument" -> (
      let rec top (n : node) = match n.parent with Some p -> top p | None -> n in
      match List.assoc_opt "@@document" (top n).expando with Some d -> d | None -> (match (Js_eval.global t.engine "document") with Some v_ -> v_ | None -> Null))

  | "id" -> String ((match (attribute n "id") with Some v_ -> v_ | None -> ""))
  | "className" -> String ((match (attribute n "class") with Some v_ -> v_ | None -> ""))
  (* a text's data, a comment's: not an element's, whose class may have a data of its own *)
  | ("data" | "nodeValue") when is_element n -> (match (List.assoc_opt k n.expando) with Some v_ -> v_ | None -> (match t.more n k with Some v_ -> v_ | None -> if k = "data" then Undefined else Null))
  | "textContent" | "innerText" | "data" | "nodeValue" -> String (if is_element n || n.name = fragment_name then text_content n else n.text)
  | "innerHTML" -> String (inner_html n)
  | "outerHTML" -> String (html_of n)
  | "value" -> String (if n.name = "textarea" then text_content n else (match (attribute n "value") with Some v_ -> v_ | None -> ""))
  | "checked" -> Bool (attribute n "checked" <> None)
  | "style" -> style_object t n
  | "children" -> nodes_array t (elements_of n.children)
  | "childNodes" -> nodes_array t n.children
  | "firstChild" -> opt (List.nth_opt n.children 0)
  | "lastChild" -> opt (List.nth_opt (List.rev n.children) 0)
  | "firstElementChild" -> opt (List.nth_opt (elements_of n.children) 0)
  | "parentNode" | "parentElement" -> opt n.parent
  (* its siblings: the next or previous node, or element *)
  | "nextSibling" | "previousSibling" | "nextElementSibling" | "previousElementSibling" -> (
      match n.parent with
      | None -> Null
      | Some p ->
          let sibs = if String.starts_with ~prefix:"previous" k then List.rev p.children else p.children in
          (* what follows it; of those, the first element if one is asked
           * (of a comment or a text too: they are not among the elements) *)
          let rec after l = match l with x :: rest when x == n -> rest | _ :: r -> after r | [] -> [] in
          let following = after sibs in
          opt (List.nth_opt (if String.ends_with ~suffix:"ElementSibling" k then elements_of following else following) 0))
  | "getElementsByClassName" ->
      method_ k (fun args ->
          let wanted = List.filter (( <> ) "") (String.split_on_char ' ' (str (arg args 0))) in
          nodes_array t (List.filter (fun e -> e != n && has_classes e wanted) (elements n)))
  | "getElementsByTagName" ->
      method_ k (fun args ->
          let name = String.lowercase_ascii (str (arg args 0)) in
          nodes_array t (List.filter (fun e -> e != n && (name = "*" || e.name = name)) (elements n)))
  | "classList" -> class_list t n
  | "href" when n.name = "a" || n.name = "link" || n.name = "area" -> (
      match attribute n "href" with Some h -> String (Browser_url.resolve t.base h) | None -> String "")
  | "src" when n.name = "img" || n.name = "script" -> ( match attribute n "src" with Some h -> String (Browser_url.resolve t.base h) | None -> String "")
  (* what a page does that has no effect here: nothing to scroll to, no
   * focus to move *)
  | "scrollIntoView" | "focus" | "blur" -> method_ k (fun _ -> Undefined)
  | "insertAdjacentHTML" ->
      method_ k (fun args ->
          let nodes = parse_fragment (str (arg args 1)) in
          (match String.lowercase_ascii (str (arg args 0)) with
          | "beforeend" -> n.children <- n.children @ nodes; adopt n nodes
          | "afterbegin" -> n.children <- nodes @ n.children; adopt n nodes
          | ("beforebegin" | "afterend") as where -> (
              match n.parent with
              | Some p ->
                  p.children <- List.concat_map (fun c -> if c == n then (if where = "beforebegin" then nodes @ [ c ] else c :: nodes) else [ c ]) p.children;
                  adopt p nodes
              | None -> ())
          | _ -> ());
          touch t;
          Undefined)
  | "getAttribute" -> method_ k (fun args -> match attribute n (str (arg args 0)) with Some v -> String v | None -> Null)
  | "setAttribute" ->
      method_ k (fun args ->
          let a = String.lowercase_ascii (str (arg args 0)) in
          let old = attribute n a in
          set_attribute n a (str (arg args 1));
          touch t;
          told_attribute t n a old;
          Undefined)
  | "removeAttribute" ->
      method_ k (fun args ->
          let a = str (arg args 0) in
          let old = attribute n a in
          n.attributes <- List.remove_assoc a n.attributes;
          touch t;
          told_attribute t n a old;
          Undefined)
  | "appendChild" -> method_ k (fun args -> insert t n (arg args 0) ~before:None)
  | "insertBefore" -> method_ k (fun args -> insert t n (arg args 0) ~before:(match arg args 1 with Null | Undefined -> None | v -> Some (node_of t v)))
  | "removeChild" ->
      method_ k (fun args ->
          let c = node_of t (arg args 0) in
          (match c.parent with
          | Some p when p == n -> ()
          | _ -> throw "NotFoundError" "The node to be removed is not a child of this node.");
          detach c;
          touch t;
          arg args 0)
  | "remove" -> method_ k (fun _ -> detach n; touch t; Undefined)
  | "querySelector" -> method_ k (fun args -> opt (List.nth_opt (select t (str (arg args 0)) ~within:n) 0))
  | "querySelectorAll" -> method_ k (fun args -> nodes_array t (select t (str (arg args 0)) ~within:n))
  | "addEventListener" ->
      method_ k (fun args ->
          n.listeners <- n.listeners @ [ (str (arg args 0), arg args 1) ];
          listening_once t args ~remove:(fun () -> n.listeners <- List.filter (fun (ty, g) -> not (ty = str (arg args 0) && g == arg args 1)) n.listeners);
          Undefined)
  | "removeEventListener" ->
      method_ k (fun args ->
          let typ = str (arg args 0) and f = arg args 1 in
          n.listeners <- List.filter (fun (ty, g) -> not (ty = typ && strict_equal g f)) n.listeners;
          Undefined)
  (* what a script set on it; else the members of Script_element *)
  (* el.hasOwnProperty(k): a property a script put on it -- what a
   * custom element looks for when it is upgraded, to take the values
   * given before its class was defined (Polymer; YouTube's icons) *)
  | _ when String.length k > 6 && String.sub k 0 6 = Js_builtins.own_query -> Bool (List.mem_assoc (String.sub k 6 (String.length k - 6)) n.expando)
  | _ -> ( match List.assoc_opt k n.expando with Some v -> v | None -> (match (t.more n k) with Some v_ -> v_ | None -> Undefined))

(* addEventListener(type, f, { once: true }): noted, to be removed when
 * called; { signal }: removed when the signal aborts (an
 * AbortController's: how a component takes all its listeners off at
 * once) -- read as any property is, a page testing for it with a getter *)
and listening_once (t : t) (args : value list) ~(remove : unit -> unit) : unit =
  match arg args 2 with
  | Object _ as options ->
      if truthy (Js_eval.get t.engine options "once") then t.once <- (str (arg args 0), arg args 1) :: t.once;
      (match Js_eval.get t.engine options "signal" with
      | Object _ as signal -> (
          match Js_eval.get t.engine signal "addEventListener" with
          | Object _ as listen -> ignore (Js_eval.call_in_run t.engine listen ~this:signal [ String "abort"; host_function "abort" (fun ~this:_ _ -> remove (); Undefined) ])
          | _ -> ())
      | _ -> ())
  | _ -> ()

(* whether an element has every class of [wanted] *)
and has_classes (e : node) (wanted : string list) : bool =
  let have = match attribute e "class" with Some c -> String.split_on_char ' ' c | None -> [] in
  wanted <> [] && List.for_all (fun w -> List.mem w have) wanted

(* el.classList: its class= as a set of words *)
and class_list (t : t) (n : node) : value =
  let words () = List.filter (( <> ) "") (String.split_on_char ' ' ((match (attribute n "class") with Some v_ -> v_ | None -> ""))) in
  let write ws = set_attribute n "class" (String.concat " " ws); touch t in
  host_object
    {
      class_name = "DOMTokenList";
      get =
        (fun k ->
          match k with
          | "length" -> Number (float_of_int (List.length (words ())))
          (* gone through: for (const c of el.classList), [...el.classList] *)
          | "@@iterator" | "values" -> method_ k (fun _ -> Js_builtins.iterator (List.map (fun c -> String c) (words ())))
          | k when int_of_string_opt k <> None -> ( match List.nth_opt (words ()) (int_of_string k) with Some c -> String c | None -> Undefined)
          | "contains" -> method_ k (fun args -> Bool (List.mem (str (arg args 0)) (words ())))
          | "add" -> method_ k (fun args -> write (words () @ List.filter (fun c -> not (List.mem c (words ()))) (List.map str args)); Undefined)
          | "remove" -> method_ k (fun args -> write (List.filter (fun c -> not (List.mem (String c) args || List.exists (fun a -> str a = c) args)) (words ())); Undefined)
          | "toggle" ->
              method_ k (fun args ->
                  let c = str (arg args 0) in
                  (* toggle(c, on): there or not as said, not turned over *)
                  let on = match args with [ _; force ] -> truthy force | _ -> not (List.mem c (words ())) in
                  write (List.filter (( <> ) c) (words ()) @ if on then [ c ] else []);
                  Bool on)
          | "replace" ->
              method_ k (fun args ->
                  let a = str (arg args 0) and b = str (arg args 1) in
                  let had = List.mem a (words ()) in
                  if had then write (List.map (fun c -> if c = a then b else c) (words ()));
                  Bool had)
          | "item" -> method_ k (fun args -> match List.nth_opt (words ()) (int_of_float (to_number (arg args 0))) with Some c -> String c | None -> Null)
          | "value" -> String (String.concat " " (words ()))
          | "forEach" -> method_ k (fun args -> List.iteri (fun i c -> ignore (Js_eval.call_in_run t.engine (arg args 0) ~this:Undefined [ String c; Number (float_of_int i) ])) (words ()); Undefined)
          | _ -> Undefined);
      set = (fun _ _ -> ());
      show = (fun () -> String.concat " " (words ()));
    }

and set (t : t) (n : node) (k : string) (v : value) : unit =
  let str = text t in
  let replace_children (cs : node list) =
    List.iter (fun c -> c.parent <- None) n.children;
    n.children <- cs;
    adopt n cs;
    touch t
  in
  match k with
  | "id" -> set_attribute n "id" (str v); touch t
  | "className" -> set_attribute n "class" (str v); touch t
  | ("data" | "nodeValue") when is_element n -> n.expando <- (k, v) :: List.remove_assoc k n.expando
  | "textContent" | "innerText" | "data" | "nodeValue" ->
      if is_text n || n.name = comment_name then (
        n.text <- str v;
        touch t;
        (* a text a MutationObserver watches: the observer told (data/prelude/web/) *)
        if List.mem_assoc "__observed" n.expando then
          match Js_eval.global t.engine "__mutated" with
          | Some (Object _ as f) -> ignore (Js_eval.call_in_run t.engine f ~this:Undefined [ wrap t n; String "characterData" ])
          | _ -> ())
      else replace_children [ make_with (str v) [] text_name ]
  (* a <script>'s and a <style>'s is text, not markup: "r<t;r++" in a
   * script written so was read as a tag, up to the next ">" *)
  | "innerHTML" when n.name = "script" || n.name = "style" -> replace_children [ make_with (str v) [] text_name ]
  | "innerHTML" -> replace_children (parse_fragment (str v))
  (* the element itself replaced by what the HTML reads to -- but a
   * <body>, which stays, the HTML its content: what a parser makes of
   * text given in a body's place (a sanitizer builds its document so:
   * body.outerHTML = the text to clean) *)
  | "outerHTML" when n.name = "body" || n.name = "html" -> replace_children (parse_fragment (str v))
  | "outerHTML" -> (
      match n.parent with
      | Some p ->
          let nodes = parse_fragment (str v) in
          p.children <- List.concat_map (fun c -> if c == n then nodes else [ c ]) p.children;
          adopt p nodes;
          n.parent <- None;
          touch t
      | None -> ())
  | "value" -> if n.name = "textarea" then replace_children [ make_with (str v) [] text_name ] else (set_attribute n "value" (str v); touch t)
  | "checked" ->
      (if truthy v then set_attribute n "checked" "" else n.attributes <- List.remove_assoc "checked" n.attributes);
      touch t
  (* an address: the attribute as written (read back resolved) *)
  | "src" | "href" -> set_attribute n k (str v); touch t
  (* a property that is an attribute: el.type = "radio", el.disabled = true *)
  | k when List.mem_assoc k reflected -> set_attribute n (List.assoc k reflected) (str v); touch t
  | k when List.mem_assoc k reflected_flags ->
      let a = List.assoc k reflected_flags in
      (if truthy v then set_attribute n a "" else n.attributes <- List.remove_assoc a n.attributes);
      touch t
  (* delete el.k: what a script had put on it, gone *)
  | _ when String.length k > 6 && String.sub k 0 6 = Js_builtins.own_query -> n.expando <- List.remove_assoc (String.sub k 6 (String.length k - 6)) n.expando
  | _ -> n.expando <- (k, v) :: List.remove_assoc k n.expando

(* child put in [parent], before [before] or at the end: moved if it
 * was elsewhere; never inside itself *)
and insert (t : t) (parent : node) (child_v : value) ~(before : node option) : value =
  let child = node_of t child_v in
  (* a fragment: its children, in its place *)
  if child.name = fragment_name then (List.iter (fun c -> ignore (insert t parent (wrap t c) ~before)) child.children; child_v)
  else
  let rec inside (p : node option) = match p with Some p -> p == child || inside p.parent | None -> false in
  if inside (Some parent) then throw "HierarchyRequestError" "The new child element contains the parent.";
  detach child;
  (parent.children <-
     match before with
     | None -> parent.children @ [ child ]
     | Some b -> List.concat_map (fun c -> if c == b then [ child; c ] else [ c ]) parent.children);
  child.parent <- Some parent;
  touch t;
  t.inserted child;
  child_v

(* the first element named so, at any depth *)
let find (n : node) (name : string) : node option = List.find_opt (fun e -> e.name = name) (elements n)

(* a URL's parts, as location and URL give them: href, protocol, host,
 * pathname, search, hash... *)
let url_parts (href : string) : (string * string) list =
  let without_hash, hash = match String.index_opt href '#' with Some i -> (String.sub href 0 i, String.sub href i (String.length href - i)) | None -> (href, "") in
  let without_query, search =
    match String.index_opt without_hash '?' with Some i -> (String.sub without_hash 0 i, String.sub without_hash i (String.length without_hash - i)) | None -> (without_hash, "")
  in
  let protocol, rest = match String.index_opt without_query ':' with Some i -> (String.sub without_query 0 (i + 1), String.sub without_query (i + 1) (String.length without_query - i - 1)) | None -> ("", without_query) in
  let host, pathname =
    if String.starts_with ~prefix:"//" rest then
      let r = String.sub rest 2 (String.length rest - 2) in
      match String.index_opt r '/' with Some i -> (String.sub r 0 i, String.sub r i (String.length r - i)) | None -> (r, "/")
    else ("", rest)
  in
  let hostname = match String.index_opt host ':' with Some i -> String.sub host 0 i | None -> host in
  (* a site's address with no path has the path /, in its href too
   * (https://x.org is https://x.org/): what a router compares its base with *)
  let href = if host <> "" then protocol ^ "//" ^ host ^ pathname ^ search ^ hash else href in
  [ ("href", href); ("protocol", protocol); ("host", host); ("hostname", hostname); ("pathname", pathname); ("search", search); ("hash", hash);
    ("origin", Cors.origin href) ]

(* an object of a URL's parts; URL's searchParams, and toString *)
let url_object (href : string) : value =
  let parts = url_parts href in
  let o = new_object () in
  List.iter (fun (k, v) -> set_own o k (String v)) parts;
  let query = let s = List.assoc "search" parts in if s = "" then "" else String.sub s 1 (String.length s - 1) in
  let params = Urlencoded.decode query in
  let sp = new_object () in
  set_own sp "get" (host_function "get" (fun ~this:_ args -> match List.assoc_opt (str (arg args 0)) params with Some v -> String v | None -> Null));
  set_own sp "has" (host_function "has" (fun ~this:_ args -> Bool (List.mem_assoc (str (arg args 0)) params)));
  set_own o "searchParams" (Object sp);
  set_own o "toString" (host_function "toString" (fun ~this:_ _ -> String href));
  Object o

(* location: the page's address in parts, and the way for a script to
 * send the page elsewhere -- location.href = url, assign(url) (the
 * page left is kept in the history), replace(url) (it is not),
 * reload(). The browser goes there once the script has returned *)
let location (t : t) : value =
  let go ~(replace : bool) (url : string) = t.navigation <- Some (Browser_url.resolve t.base url, replace) in
  let searchParams = match url_object t.base with Object o -> (match (get_own o "searchParams") with Some v_ -> v_ | None -> Undefined) | _ -> Undefined in
  host_object
    {
      class_name = "Location";
      get =
        (fun k ->
          (* of the address as it is now: history.pushState changes it *)
          match (k, List.assoc_opt k (url_parts t.base)) with
          | _, Some v -> String v
          | "assign", _ -> method_ k (fun args -> go ~replace:false (str (arg args 0)); Undefined)
          | "replace", _ -> method_ k (fun args -> go ~replace:true (str (arg args 0)); Undefined)
          | "reload", _ -> method_ k (fun _ -> go ~replace:true t.base; Undefined)
          | "toString", _ -> method_ k (fun _ -> String t.base)
          | "searchParams", _ -> searchParams
          | _ -> Undefined);
      set = (fun k v -> match k with "href" -> go ~replace:false (str v) | "hash" | "search" | "pathname" -> () | _ -> ());
      show = (fun () -> t.base);
    }
