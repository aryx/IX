(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/dom/Script_document.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_document.mli *)
open Js_value
open Script_types
open Script_dom
open Script_host

let document (t : t) : value =
  let root = t.root in
  let title () = find root "title" in
  let named name = nodes_array t (List.filter (fun e -> e.name = name) (elements root)) in
  (* a page of its own: enough of a document to parse HTML into *)
  let other_document (html_text : string) =
    (* a <head> before its <body>, as every document has (a sanitizer
     * takes "the first element of <html>" away to have the body alone) *)
    let html = make "html" and head = make "head" and body = make "body" in
    html.children <- [ head; body ];
    adopt html [ head; body ];
    body.children <- parse_fragment html_text;
    adopt body body.children;
    let o = new_object () in
    set_own o "body" (wrap t body);
    set_own o "documentElement" (wrap t html);
    set_own o "nodeType" (Number 9.);
    set_own o "querySelector" (method_ "querySelector" (fun args -> match select t (str (arg args 0)) ~within:html with e :: _ -> wrap t e | [] -> Null));
    set_own o "querySelectorAll" (method_ "querySelectorAll" (fun args -> nodes_array t (select t (str (arg args 0)) ~within:html)));
    set_own o "createElement" (method_ "createElement" (fun args -> wrap t (make (String.lowercase_ascii (str (arg args 0))))));
    (* the lookups its root has (getElementsByTagName("svg"): an icon read from its text), its head *)
    (match wrap t html with
    | Object { kind = Host_object h; _ } -> List.iter (fun k -> set_own o k (h.get k)) [ "getElementsByClassName"; "getElementById"; "firstChild" ]
    | _ -> ());
    set_own o "getElementsByTagName"
      (method_ "getElementsByTagName" (fun args ->
           let name = String.lowercase_ascii (str (arg args 0)) in
           nodes_array t (List.filter (fun e -> name = "*" || e.name = name) (let all = elements html in if List.memq html all then all else html :: all))));
    set_own o "head" (wrap t head);
    (* a document as the page's is, for what its prototype has
     * (createNodeIterator, createTreeWalker: how a sanitizer goes through
     * the HTML of a message before showing it -- DOMPurify, in a thread
     * of Topicbox, whose HTML mails came out empty), and what makes nodes *)
    set_own o "createTextNode" (method_ "createTextNode" (fun args -> wrap t (make_with (str (arg args 0)) [] text_name)));
    set_own o "createDocumentFragment" (method_ "createDocumentFragment" (fun _ -> wrap t (make fragment_name)));
    set_own o "createComment" (method_ "createComment" (fun args -> wrap t (make_with (str (arg args 0)) [] comment_name)));
    set_own o "nodeName" (String "#document");
    set_own o "defaultView" Null;
    o.proto <- List.assoc_opt "document" t.protos;
    (* its nodes' ownerDocument: found from their root (Script_host) *)
    html.expando <- ("@@document", Object o) :: html.expando;
    Object o
  in
  let d =
  (* what a script puts on the document, by its name *)
  let kept : (string, value) Hashtbl.t = Hashtbl.create 8 in
  host_object
    {
      class_name = "HTMLDocument";
      get =
        (fun k ->
          match k with
          | "body" -> ( match find root "body" with Some b -> wrap t b | None -> Null)
          | "head" -> ( match find root "head" with Some h -> wrap t h | None -> Null)
          | "documentElement" | "firstChild" | "lastChild" | "firstElementChild" -> wrap t root
          (* the document as a node *)
          | "nodeType" -> Number 9.
          | "nodeName" -> String "#document"
          | "childNodes" | "children" -> nodes_array t [ root ]
          | "ownerDocument" | "parentNode" -> Null
          | "contains" -> method_ k (fun args -> Bool (match arg args 0 with Object _ as o -> top (node_of t o) == root | _ -> false))
          | "compatMode" -> String "CSS1Compat"
          | "characterSet" | "charset" -> String "UTF-8"
          | "hidden" -> Bool false
          | "visibilityState" -> String "visible"
          | "activeElement" -> ( match find root "body" with Some b -> wrap t b | None -> Null)
          | "scripts" -> named "script"
          | "forms" -> named "form"
          | "images" -> named "img"
          | "links" -> named "a"
          | "currentScript" -> ( match t.current_script with Some s -> wrap t s | None -> Null)
          | "createDocumentFragment" -> method_ k (fun _ -> wrap t (make fragment_name))
          | "createComment" -> method_ k (fun args -> wrap t (make_with (str (arg args 0)) [] comment_name))
          | "createElementNS" -> method_ k (fun args -> wrap t (make (String.lowercase_ascii (str (arg args 1)))))
          | "createEvent" -> method_ k (fun _ -> Script_events.create ())
          | "dispatchEvent" -> method_ k (fun args -> Bool (not (t.dispatch None (arg args 0))))
          | "implementation" ->
              let o = new_object () in
              set_own o "createHTMLDocument" (method_ "createHTMLDocument" (fun _ -> other_document ""));
              set_own o "hasFeature" (method_ "hasFeature" (fun _ -> Bool true));
              Object o
          | "getElementsByName" ->
              method_ k (fun args -> nodes_array t (List.filter (fun e -> attribute e "name" = Some (str (arg args 0))) (elements root)))
          | "title" -> String (match title () with Some n -> String.trim (text_content n) | None -> "")
          | "getElementById" ->
              method_ k (fun args ->
                  let id = str (arg args 0) in
                  match List.find_opt (fun e -> attribute e "id" = Some id) (elements root) with Some e -> wrap t e | None -> Null)
          | "querySelector" -> method_ k (fun args -> match select t (str (arg args 0)) ~within:root with e :: _ -> wrap t e | [] -> Null)
          | "querySelectorAll" -> method_ k (fun args -> nodes_array t (select t (str (arg args 0)) ~within:root))
          | "createElement" ->
              method_ k (fun args ->
                  let name = String.lowercase_ascii (str (arg args 0)) in
                  let el = wrap t (make name) in
                  (* a custom element (a name with a dash) is upgraded at once
                   * if its class is defined: the registry's (data/prelude/web/) *)
                  (match Js_eval.global t.engine "__created" with
                  | Some (Object _ as f) when String.contains name '-' -> ignore (Js_eval.call_in_run t.engine f ~this:Undefined [ el ])
                  | _ -> ());
                  el)
          (* a document's elements of a name, its root among them
           * (getElementsByTagName("html")) -- of the document it is
           * called on: a sanitizer keeps the page's function and calls
           * it on the document it has parsed (DOMPurify's
           * getElementsByTagName.call(doc, "html")), which had the
           * page's own elements for answer, and no <html> at all *)
          | "getElementsByTagName" ->
              host_function k (fun ~this args ->
                  let top =
                    match this with
                    | Object ({ kind = Plain; _ } as o) -> ( match get_own o "documentElement" with Some e -> ( try node_of t e with _ -> root) | None -> root)
                    | _ -> root
                  in
                  let name = String.lowercase_ascii (str (arg args 0)) in
                  nodes_array t (List.filter (fun e -> name = "*" || e.name = name) (let all = elements top in if List.memq top all then all else top :: all)))
          | "getElementsByClassName" -> ( match wrap t root with Object { kind = Host_object h; _ } -> h.get k | _ -> Undefined)
          | "location" -> location t
          | "URL" -> String t.base
          (* "a=1; b=2", the browser's for this page *)
          | "cookie" -> String (fst t.cookies ())
          | "referrer" -> String ""
          | "readyState" -> String t.ready
          | "defaultView" -> (match (Js_eval.global t.engine "window") with Some v_ -> v_ | None -> Undefined)
          | "createTextNode" -> method_ k (fun args -> wrap t (make_with (str (arg args 0)) [] text_name))
          | "addEventListener" ->
              method_ k (fun args ->
                  t.document_listeners <- t.document_listeners @ [ (str (arg args 0), arg args 1) ];
                  listening_once t args ~remove:(fun () -> t.document_listeners <- List.filter (fun (ty, g) -> not (ty = str (arg args 0) && g == arg args 1)) t.document_listeners);
                  Undefined)
          | "removeEventListener" ->
              method_ k (fun args ->
                  let typ = str (arg args 0) and f = arg args 1 in
                  t.document_listeners <- List.filter (fun (ty, g) -> not (ty = typ && strict_equal g f)) t.document_listeners;
                  Undefined)
          | _ -> (match (Hashtbl.find_opt kept k) with Some v_ -> v_ | None -> Undefined));
      set =
        (fun k v ->
          match (k, title ()) with
          (* document.cookie = "name=value; Path=/": one cookie
           * set (not the whole string replaced: its odd meaning) *)
          | "cookie", _ -> snd t.cookies (str v)
          | "title", Some n ->
              n.children <- [ make_with (str v) [] text_name ];
              adopt n n.children;
              touch t
          | "title", None -> (
              match find root "head" with
              | Some h ->
                  let n = make "title" in
                  n.children <- [ make_with (str v) [] text_name ];
                  adopt n n.children;
                  h.children <- h.children @ [ n ];
                  adopt h [ n ];
                  touch t
              | None -> ())
          (* the sheets a script made and adopts: the prelude's to put in the page *)
          | "adoptedStyleSheets", _ -> (
              match Js_eval.global t.engine "__adopt" with Some (Object _ as f) -> ignore (Js_eval.call_in_run t.engine f ~this:Undefined [ v ]) | _ -> ())
          (* anything else a script puts on it is kept, as on any object *)
          | _ -> Hashtbl.replace kept k v);
      show = (fun () -> "#document");
    }
  in
  (match d with Object o -> o.proto <- List.assoc_opt "document" t.protos | _ -> ());
  (* new DOMParser().parseFromString(html, "text/html"): a page of its
   * own with that HTML in its body -- how a library reads the HTML a
   * server sent before putting it in the page (htmx) *)
  Js_eval.define t.engine "DOMParser"
    (host_function "DOMParser" (fun ~this _ ->
         (match this with
         | Object o -> set_own o "parseFromString" (method_ "parseFromString" (fun args -> other_document (str (arg args 0))))
         | _ -> ());
         Undefined));
  d
