(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/webapi/dom/Script_element.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_element.mli *)
open Js_value
open Script_types
open Script_dom
open Script_host

(* a copy of a node: its name, text and attributes; its subtree if
 * [deep]; not its listeners, nor what a script set on it *)
let rec clone ~(deep : bool) (n : node) : node =
  let c = make_with n.text n.attributes n.name in
  if deep then (
    c.children <- List.map (clone ~deep) n.children;
    adopt c c.children);
  c

(* a node, every node under it, in document order *)
let rec all (n : node) : node list = n :: List.concat_map all n.children

let rec inside (n : node) (ancestor : node) : bool = n == ancestor || match n.parent with Some p -> inside p ancestor | None -> false

(* the numbers of compareDocumentPosition: disconnected 1, preceding 2,
 * following 4, contains 8, contained by 16 *)
let position (n : node) (other : node) : float =
  if n == other then 0.
  else if top n != top other then 1.
  else if inside n other then 10.
  else if inside other n then 20.
  else
    let rec first (l : node list) = match l with x :: _ when x == n -> 4. | x :: _ when x == other -> 2. | _ :: rest -> first rest | [] -> 1. in
    first (all (top n))

let rect (t : t) (n : node) : value =
  let x, y, w, h = (match (t.where n) with Some v_ -> v_ | None -> (0., 0., 0., 0.)) in
  (* from the window's top, not the page's *)
  let y = y -. t.scroll_y in
  let o = new_object () in
  List.iter (fun (k, v) -> set_own o k (Number v)) [ ("x", x); ("y", y); ("top", y); ("left", x); ("right", x +. w); ("bottom", y +. h); ("width", w); ("height", h) ];
  Object o

(* el.dataset: its data-* attributes, by their names in camelCase *)
let dataset (t : t) (n : node) : value =
  host_object
    {
      class_name = "DOMStringMap";
      get = (fun k -> match attribute n ("data-" ^ kebab k) with Some v -> String v | None -> Undefined);
      set = (fun k v -> set_attribute n ("data-" ^ kebab k) (str v); touch t);
      show = (fun () -> "DOMStringMap");
    }

let get (t : t) (n : node) (k : string) : value option =
  let str = Script_host.text t in
  let opt (c : node option) = match c with Some c -> wrap t c | None -> Null in
  let m (f : value list -> value) = Some (method_ k f) in
  (* a method's arguments as nodes: a string is a text *)
  let nodes (args : value list) : value list = List.map (fun a -> match a with Object _ -> a | v -> wrap t (make_with (str v) [] text_name)) args in
  let children_elements () = List.filter is_element n.children in
  match k with
  | "matches" | "webkitMatchesSelector" | "msMatchesSelector" -> m (fun args -> Bool (is_element n && matches (str (arg args 0)) n))
  | "closest" ->
      m (fun args ->
          let sel = str (arg args 0) in
          let rec up (c : node option) = match c with Some c when is_element c -> if matches sel c then wrap t c else up c.parent | _ -> Null in
          up (Some n))
  | "contains" -> m (fun args -> Bool (match arg args 0 with Object o when Hashtbl.mem t.nodes o.id -> inside (node_of t (arg args 0)) n | _ -> false))
  | "compareDocumentPosition" -> m (fun args -> Number (position n (node_of t (arg args 0))))
  | "isConnected" -> Some (Bool (top n == t.root))
  | "getRootNode" -> m (fun _ -> if top n == t.root then (match (Js_eval.global t.engine "document") with Some v_ -> v_ | None -> Null) else wrap t (top n))
  | "hasChildNodes" -> m (fun _ -> Bool (n.children <> []))
  | "lastElementChild" -> Some (opt (List.nth_opt (List.rev (children_elements ())) 0))
  | "childElementCount" -> Some (Number (float_of_int (List.length (children_elements ()))))
  | "localName" -> Some (String n.name)
  | "namespaceURI" ->
      let rec drawn (n : node) = n.name = "svg" || match n.parent with Some p -> p.name <> "foreignObject" && drawn p | None -> false in
      Some (String (if drawn n then "http://www.w3.org/2000/svg" else "http://www.w3.org/1999/xhtml"))
  | "cloneNode" -> m (fun args -> wrap t (clone ~deep:(truthy (arg args 0)) n))
  (* its shadow tree (Shadow_tree.mli): attached, empty, and then filled
   * as any node is; the root's host and mode are said by the prelude *)
  (* form.submit(): the form sent by a script, with no submit event (it
   * is the script's own doing) -- how a page goes on by itself when
   * what it waited for has come (Google's sign-in, told that the phone
   * said yes). Its fields as the script's tree has them; requestSubmit()
   * the same here *)
  | ("submit" | "requestSubmit") when n.name = "form" ->
      m (fun _ ->
          (match Forms.forms (Script_dom.freeze n) with
          | f :: _ ->
              let initial (e : Dom.element) = match Forms.control e with Some c -> c.initial | None -> { Forms.text = ""; checked = false; selected = 0 } in
              let fields = Urlencoded.encode (Forms.submission f ~value:initial ~submitter:None) in
              let action = Browser_url.resolve t.base (if f.action = "" then t.base else f.action) in
              t.submission <-
                Some
                  (if f.post then (action, Some ("application/x-www-form-urlencoded", fields))
                   else (fst (Browser_url.split_query (fst (Browser_url.split_fragment action))) ^ "?" ^ fields, None))
          | [] -> ());
          Undefined)
  | "attachShadow" ->
      m (fun _ ->
          attach_shadow n [];
          let root = Option.get n.shadow in
          root.expando <- [ ("host", wrap t n); ("mode", String "open") ];
          touch t;
          wrap t root)
  | "shadowRoot" -> Some (match n.shadow with Some root -> wrap t root | None -> Null)
  (* where nodes go: in it, or beside it in its parent *)
  | "append" -> m (fun args -> List.iter (fun c -> ignore (insert t n c ~before:None)) (nodes args); Undefined)
  | "prepend" ->
      m (fun args ->
          (* before its first child that is not one of those put there
           * (prepend of the first child itself lost it) *)
          let put = nodes args in
          let moved = List.filter_map (fun (v : value) -> match v with Object o -> Hashtbl.find_opt t.nodes o.id | _ -> None) put in
          let first = List.find_opt (fun c -> not (List.memq c moved)) n.children in
          List.iter (fun c -> ignore (insert t n c ~before:first)) put;
          Undefined)
  | "before" | "after" | "replaceWith" ->
      m (fun args ->
          (match n.parent with
          | None -> ()
          | Some p ->
              let rec next (l : node list) = match l with x :: rest when x == n -> List.nth_opt rest 0 | _ :: rest -> next rest | [] -> None in
              let before = if k = "after" then next p.children else Some n in
              List.iter (fun c -> ignore (insert t p c ~before)) (nodes args);
              if k = "replaceWith" then (detach n; touch t));
          Undefined)
  | "replaceChildren" ->
      m (fun args ->
          List.iter (fun c -> c.parent <- None) n.children;
          n.children <- [];
          List.iter (fun c -> ignore (insert t n c ~before:None)) (nodes args);
          touch t;
          Undefined)
  | "replaceChild" ->
      m (fun args ->
          let old = node_of t (arg args 1) in
          ignore (insert t n (arg args 0) ~before:(Some old));
          detach old;
          arg args 1)
  | "insertAdjacentElement" | "insertAdjacentText" ->
      m (fun args ->
          let c = match nodes [ arg args 1 ] with c :: _ -> c | [] -> Undefined in
          (match (String.lowercase_ascii (str (arg args 0)), n.parent) with
          | "beforeend", _ -> ignore (insert t n c ~before:None)
          | "afterbegin", _ -> ignore (insert t n c ~before:(List.nth_opt n.children 0))
          | "beforebegin", Some p -> ignore (insert t p c ~before:(Some n))
          | "afterend", Some p ->
              let rec next (l : node list) = match l with x :: rest when x == n -> List.nth_opt rest 0 | _ :: rest -> next rest | [] -> None in
              ignore (insert t p c ~before:(next p.children))
          | _ -> ());
          c)
  (* attributes *)
  | "hasAttribute" -> m (fun args -> Bool (attribute n (String.lowercase_ascii (str (arg args 0))) <> None))
  | "hasAttributes" -> m (fun _ -> Bool (n.attributes <> []))
  | "getAttributeNames" -> m (fun _ -> Object (new_array (List.map (fun (a, _) -> String a) n.attributes)))
  | "getAttributeNode" -> m (fun args -> match attribute n (str (arg args 0)) with Some v -> let o = new_object () in set_own o "name" (arg args 0); set_own o "value" (String v); set_own o "specified" (Bool true); Object o | None -> Null)
  | "attributes" ->
      (* its attributes as a list of { name, value }, which is also
       * asked by name (a NamedNodeMap: getNamedItem) *)
      let item (a, v) =
        let o = new_object () in
        List.iter (fun (k, x) -> set_own o k (String x)) [ ("name", a); ("value", v); ("nodeName", a); ("localName", a); ("nodeValue", v) ];
        Object o
      in
      let list = new_array (List.map item n.attributes) in
      let method_ k f = set_own list k (host_function k (fun ~this:_ args -> f args)); hide list k in
      method_ "getNamedItem" (fun args -> match List.assoc_opt (String.lowercase_ascii (str (arg args 0))) n.attributes with Some v -> item (String.lowercase_ascii (str (arg args 0)), v) | None -> Null);
      method_ "item" (fun args -> match List.nth_opt n.attributes (int_of_float (to_number (arg args 0))) with Some a -> item a | None -> Null);
      (* an instance of NamedNodeMap, which the prelude makes a kind of
       * array: a sanitizer takes an element whose attributes are not
       * one for a trap (a form with a field named "attributes") and
       * removes it -- DOMPurify removed every element *)
      (match Js_eval.global t.engine "NamedNodeMap" with
      | Some (Object c) -> ( match get_own c "prototype" with Some (Object p) -> list.proto <- Some p | _ -> ())
      | _ -> ());
      Some (Object list)
  | "toggleAttribute" ->
      m (fun args ->
          let a = String.lowercase_ascii (str (arg args 0)) in
          let on = match arg args 1 with Undefined -> attribute n a = None | v -> truthy v in
          (if on then (if attribute n a = None then set_attribute n a "") else n.attributes <- List.remove_assoc a n.attributes);
          touch t;
          Bool on)
  (* with a namespace (an SVG's): the same attributes *)
  | "getAttributeNS" -> m (fun args -> match attribute n (str (arg args 1)) with Some v -> String v | None -> Null)
  | "setAttributeNS" -> m (fun args -> set_attribute n (str (arg args 1)) (str (arg args 2)); touch t; Undefined)
  | "removeAttributeNS" -> m (fun args -> n.attributes <- List.remove_assoc (str (arg args 1)) n.attributes; touch t; Undefined)
  | "dataset" -> Some (dataset t n)
  | k when List.mem_assoc k reflected -> (
      match (attribute n (List.assoc k reflected), k, n.name) with
      | Some v, _, _ -> Some (String v)
      | None, ("title" | "lang" | "dir"), _ -> Some (String "")
      | None, "type", "input" -> Some (String "text")
      | None, "type", "button" -> Some (String "submit")
      | None, "type", ("select" | "textarea") -> Some (String (if n.name = "select" then "select-one" else "textarea"))
      (* not written: the empty text, on the elements that have the
       * property (a <meta> with no name: Google's library reads
       * meta.name.toLowerCase() of each) *)
      | None, "name", ("meta" | "input" | "select" | "textarea" | "button" | "form" | "iframe" | "a" | "img" | "map" | "object" | "param" | "slot" | "output" | "fieldset") -> Some (String "")
      | None, ("rel" | "target"), ("a" | "area" | "link" | "form" | "base") -> Some (String "")
      | None, "alt", ("img" | "area" | "input") -> Some (String "")
      | None, "media", ("link" | "style" | "source" | "meta") -> Some (String "")
      | None, "placeholder", ("input" | "textarea") -> Some (String "")
      | None, "htmlFor", ("label" | "output") -> Some (String "")
      | None, _, _ -> None)
  | k when List.mem_assoc k reflected_flags -> Some (Bool (attribute n (List.assoc k reflected_flags) <> None))
  (* its box, in a layout of the page as it is now (Script_types' where) *)
  | "getBoundingClientRect" -> m (fun _ -> rect t n)
  | "getClientRects" -> m (fun _ -> Object (new_array []))
  (* but the page's own: the window's (document.documentElement.clientWidth
   * < 768 is how a site decides it is on a phone) *)
  | ("clientWidth" | "offsetWidth" | "scrollWidth") when n.name = "html" || n.name = "body" -> Some ((match (Js_eval.global t.engine "innerWidth") with Some v_ -> v_ | None -> (Number 0.)))
  | ("clientHeight" | "offsetHeight") when n.name = "html" || n.name = "body" -> Some ((match (Js_eval.global t.engine "innerHeight") with Some v_ -> v_ | None -> (Number 0.)))
  | "offsetWidth" | "offsetHeight" | "offsetTop" | "offsetLeft" | "clientWidth" | "clientHeight" | "scrollWidth" | "scrollHeight" ->
      let x, y, w, h = (match (t.where n) with Some v_ -> v_ | None -> (0., 0., 0., 0.)) in
      Some (Number (match k with "offsetTop" -> y | "offsetLeft" -> x | "offsetWidth" | "clientWidth" | "scrollWidth" -> w | _ -> h))
  | "clientTop" | "clientLeft" | "scrollTop" | "scrollLeft" -> Some (Number 0.)
  | "offsetParent" -> Some Null
  | "tabIndex" -> Some (Number (-1.))
  (* events of a script's own *)
  | "dispatchEvent" -> m (fun args -> Bool (not (t.dispatch (Some n) (arg args 0))))
  | "click" -> m (fun _ -> ignore (t.dispatch (Some n) (Script_events.make ~bubbles:true "click" [ ("button", Number 0.); ("buttons", Number 0.); ("detail", Number 0.); ("clientX", Number 0.); ("clientY", Number 0.); ("ctrlKey", Bool false); ("shiftKey", Bool false); ("altKey", Bool false); ("metaKey", Bool false) ])); Undefined)
  | "normalize" -> m (fun _ -> Undefined)
  | _ -> None
