(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/window/Script_window.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_window.mli *)
open Js_value
open Script_types
open Script_dom
open Script_host

let fn (name : string) (f : value list -> value) : value = host_function name (fun ~this:_ args -> f args)

let object_of (fields : (string * value) list) : value =
  let o = new_object () in
  List.iter (fun (k, v) -> set_own o k v) fields;
  Object o

let nothing (name : string) : string * value = (name, fn name (fun _ -> Undefined))

(*****************************************************************************)
(* The classes of the host objects *)
(*****************************************************************************)

(* each class and the one it extends; its constructor does nothing (a
 * page's class may extend HTMLElement), its prototype is behind its
 * instances' *)
(* an element's class by its tag, where the class has a name of its own
 * (el instanceof HTMLAnchorElement: how a component checks what it was
 * given); the others are HTMLElements *)
let tags =
  [ ("a", "Anchor"); ("img", "Image"); ("input", "Input"); ("form", "Form"); ("template", "Template"); ("select", "Select");
    ("textarea", "TextArea"); ("button", "Button"); ("script", "Script"); ("style", "Style"); ("iframe", "IFrame"); ("slot", "Slot"); ("option", "Option") ]

let more_tags =
  [ ("div", "Div"); ("span", "Span"); ("p", "Paragraph"); ("ul", "UList"); ("ol", "OList"); ("li", "LI"); ("table", "Table"); ("body", "Body");
    ("head", "Head"); ("html", "Html"); ("link", "Link"); ("meta", "Meta"); ("label", "Label"); ("canvas", "Canvas"); ("video", "Video");
    ("audio", "Audio"); ("pre", "Pre"); ("details", "Details"); ("dialog", "Dialog"); ("h1", "Heading"); ("h2", "Heading"); ("h3", "Heading") ]

let classes =
  [ ("EventTarget", None); ("Node", Some "EventTarget"); ("Element", Some "Node"); ("HTMLElement", Some "Element"); ("SVGElement", Some "Element");
    ("CharacterData", Some "Node"); ("Text", Some "CharacterData"); ("Comment", Some "CharacterData"); ("CDATASection", Some "Text"); ("ProcessingInstruction", Some "CharacterData"); ("DocumentFragment", Some "Node");
    ("ShadowRoot", Some "DocumentFragment"); ("Document", Some "Node"); ("HTMLDocument", Some "Document"); ("Window", Some "EventTarget") ]
  @ List.map (fun tag -> ("HTML" ^ tag ^ "Element", Some "HTMLElement")) [ "Input"; "Form"; "Anchor"; "Image"; "Template"; "Select"; "TextArea"; "Button"; "Script"; "Style"; "IFrame"; "Slot"; "Option" ]
  @ List.map (fun (_, name) -> ("HTML" ^ name ^ "Element", Some "HTMLElement")) more_tags

let install_classes (t : t) (define : string -> value -> unit) : unit =
  let protos : (string, obj) Hashtbl.t = Hashtbl.create 32 in
  List.iter
    (fun (name, parent) ->
      let p = { (new_object ()) with proto = Option.bind parent (Hashtbl.find_opt protos) } in
      let c = fn name (fun _ -> Undefined) in
      (match c with Object c -> set_own c "prototype" (Object p) | _ -> ());
      set_own p "constructor" c;
      (* the browser's own, told from a page's classes (Js_props.dom_mark) *)
      set_own p Js_props.dom_mark (Bool true);
      hide p Js_props.dom_mark;
      Hashtbl.replace protos name p;
      define name c)
    classes;
  (match Js_eval.global t.engine "Node" with
  | Some (Object node) ->
      List.iter (fun (k, v) -> set_own node k (Number v)) [ ("ELEMENT_NODE", 1.); ("TEXT_NODE", 3.); ("COMMENT_NODE", 8.); ("DOCUMENT_NODE", 9.); ("DOCUMENT_FRAGMENT_NODE", 11.) ]
  | _ -> ());
  t.protos <- List.map (fun (kind, name) -> (kind, Hashtbl.find protos name)) (List.map (fun (tag, name) -> ("tag:" ^ tag, "HTML" ^ name ^ "Element")) (tags @ more_tags) @ [ ("tag:svg", "SVGElement"); ("tag:path", "SVGElement"); ("element", "HTMLElement"); ("text", "Text"); ("comment", "Comment"); ("fragment", "DocumentFragment"); ("document", "HTMLDocument"); ("window", "Window") ])

(*****************************************************************************)
(* What a page is given *)
(*****************************************************************************)

(* the element's own style=, and a few defaults: not the cascade's answer *)
let computed_style (n : node) : value =
  let decls () = match attribute n "style" with Some s -> Css.declarations s | None -> [] in
  let value (k : string) : string =
    match (List.assoc_opt (kebab k) (decls ()), kebab k) with
    | Some v, _ -> v
    | None, "display" -> if attribute n "hidden" <> None then "none" else "block"
    | None, "visibility" -> "visible"
    | None, "position" -> "static"
    | None, "opacity" -> "1"
    | None, _ -> ""
  in
  host_object
    {
      class_name = "CSSStyleDeclaration";
      get = (fun k -> if k = "getPropertyValue" then fn k (fun args -> String (value (str (arg args 0)))) else String (value k));
      set = (fun _ _ -> ());
      show = (fun () -> "CSSStyleDeclaration");
    }

(* an observer that is never told anything (IntersectionObserver's is
 * data/prelude/web/'s, which says all is in view, and
 * MutationObserver's, told of a text changed) *)
let observer (name : string) : value =
  let c = fn name (fun _ -> object_of [ nothing "observe"; nothing "unobserve"; nothing "disconnect"; ("takeRecords", fn "takeRecords" (fun _ -> Object (new_array []))) ]) in
  c

let install (t : t) ~(viewport : float * float) (define : string -> value -> unit) : value =
  install_classes t define;
  (* a host object asked, or told, itself -- not its prototypes: what
   * the accessors the prelude puts on Node.prototype and the others
   * call (data/prelude/web/, "the DOM's members on its prototypes") *)
  define "__host_get" (fn "__host_get" (fun args -> match arg args 0 with Object { kind = Host_object h; _ } -> h.get (str (arg args 1)) | _ -> Undefined));
  define "__host_set" (fn "__host_set" (fun args -> (match arg args 0 with Object { kind = Host_object h; _ } -> h.set (str (arg args 1)) (arg args 2) | _ -> ()); Undefined));
  (* opti: the elements of a name, in the page and in its shadow trees:
   * what the registry of custom elements asks at each class defined
   * (data/prelude/web/). It went through every element of the page
   * in JavaScript to find them -- YouTube's search page defines 1,103
   * classes: 800,000 elements listed, each asked its name *)
  define "__named"
    (fn "__named" (fun args ->
         let name = str (arg args 0) in
         let rec under (n : node) : node list =
           (if n.name = name then [ n ] else []) @ List.concat_map under n.children @ match n.shadow with Some r -> under r | None -> []
         in
         Object (new_array (List.map (Script_host.wrap t) (under t.root)))));
  define "getComputedStyle" (fn "getComputedStyle" (fun args -> computed_style (node_of t (arg args 0))));
  List.iter (fun name -> define name (observer name)) [ "ResizeObserver"; "PerformanceObserver" ];
  LocalStorage.install define;
  define "performance" (object_of [ ("now", fn "now" (fun _ -> Number t.now)); nothing "mark"; nothing "measure"; ("timeOrigin", Number 0.) ]);
  define "matchMedia"
    (fn "matchMedia" (fun args ->
         (* asked of the cascade's own reader of @media, for the window's size *)
         let matches = Cascade.media_matches { width = fst viewport; height = snd viewport } (Css_syntax.components_of (to_string (arg args 0))) in
         object_of [ ("matches", Bool matches); ("media", arg args 0); nothing "addListener"; nothing "removeListener"; nothing "addEventListener"; nothing "removeEventListener" ]));
  (* history.pushState(state, title, url) (HTML5; an application's
   * router): the page's address changed with no page loaded -- what
   * location says from then on, and what the browser shows *)
  let history = object_of [ ("length", Number 1.); ("state", Null); nothing "back"; nothing "forward"; nothing "go" ] in
  let state ~(replace : bool) (name : string) =
    match history with
    | Object h ->
        set_own h name
          (fn name (fun args ->
               set_own h "state" (arg args 0);
               (match arg args 2 with
               | Undefined | Null -> ()
               | url ->
                   t.base <- Browser_url.resolve t.base (to_string url);
                   t.address <- (t.base, replace) :: t.address);
               Undefined))
    | _ -> ()
  in
  state ~replace:false "pushState";
  state ~replace:true "replaceState";
  define "history" history;
  define "screen" (object_of [ ("width", Number (fst viewport)); ("height", Number (snd viewport)); ("availWidth", Number (fst viewport)); ("availHeight", Number (snd viewport)) ]);
  (* the page's selection, as a script sees it: none (the browser's own
   * selection of a page's text is not told to its scripts). A page
   * asks it before it takes a click for one: Gmail opens no mail
   * while "" + getSelection() is not empty *)
  define "getSelection"
    (fn "getSelection" (fun _ ->
         object_of
           [ ("rangeCount", Number 0.); ("isCollapsed", Bool true); ("type", String "None"); ("anchorNode", Null); ("focusNode", Null); ("anchorOffset", Number 0.); ("focusOffset", Number 0.);
             nothing "removeAllRanges"; nothing "addRange"; nothing "collapse"; nothing "empty"; nothing "selectAllChildren"; nothing "removeRange"; ("toString", fn "toString" (fun _ -> String "")) ]));
  (* CSS.supports says yes: an application asks it to tell an old
   * browser from one of its year (aspect-ratio, subgrid, relative
   * colours: Discourse's check), and stops if not; what we do not
   * draw of those is then missing from its page, as it is from any *)
  define "CSS" (object_of [ ("supports", fn "supports" (fun _ -> Bool true)); ("escape", fn "escape" (fun args -> arg args 0)) ]);
  (* new Image(): an <img> in no tree *)
  define "Image" (fn "Image" (fun _ -> wrap t (make "img")));
  (* a function of the prelude's that is there to do nothing, called: said (Script_host.missed) *)
  define "__missed" (fn "__missed" (fun args -> Script_host.missed (to_string (arg args 0) ^ "()"); Undefined));
  (* JS_MISSING=1: each name asked of the window that it has not, said
   * once -- what a page looks for and this browser lacks (a page that
   * waits without an error: docs/dev/notes_debugging_techniques.txt) *)
  let missing : (string, unit) Hashtbl.t option = if !Script_host.says_missing then Some (Hashtbl.create 64) else None in
  let global k =
    match (Js_eval.global t.engine k, missing) with
    | Some v, _ -> v
    | None, Some seen when not (Hashtbl.mem seen k) ->
        Hashtbl.add seen k ();
        !Js_value.say ("missing: window." ^ k);
        Undefined
    | None, _ -> Undefined
  in
  (* what window has of its own, as globals: in a browser the global
   * object is the window, so innerWidth alone is window.innerWidth,
   * and addEventListener(...) is the window's. Its listeners are the
   * document's, its size the window's *)
  List.iter (fun k -> define k (Number (fst viewport))) [ "innerWidth"; "outerWidth" ];
  List.iter (fun k -> define k (Number (snd viewport))) [ "innerHeight"; "outerHeight" ];
  define "devicePixelRatio" (Number 1.);
  List.iter (fun k -> define k (Number 0.)) [ "scrollX"; "scrollY"; "pageXOffset"; "pageYOffset"; "screenX"; "screenY"; "length" ];
  List.iter
    (fun k ->
      define k
        (fn k (fun args ->
             match global "document" with
             | Object { kind = Host_object h; _ } as document -> Js_eval.call_in_run t.engine (h.get k) ~this:document args
             | _ -> Undefined)))
    [ "addEventListener"; "removeEventListener"; "dispatchEvent" ];
  List.iter (fun k -> define k (fn k (fun _ -> Undefined))) [ "scrollTo"; "scrollBy"; "scroll"; "focus"; "blur"; "postMessage"; "print"; "close"; "stop" ];
  define "open" (fn "open" (fun _ -> Null));
  define "confirm" (fn "confirm" (fun _ -> Bool true));
  define "prompt" (fn "prompt" (fun _ -> Null));
  define "origin" (String (Cors.origin t.base));
  define "isSecureContext" (Bool (Browser_url.starts_with "https://" t.base));
  define "name" (String "");
  define "closed" (Bool false);
  List.iter (fun k -> define k Null) [ "opener"; "frameElement"; "onerror"; "onload"; "onpopstate"; "onunhandledrejection" ];
  (* window: the global object -- a global read or set through it *)
  (* a property defined on window itself (Object.defineProperty(window,
   * "Polymer", { get, set }): how a page watches a library arrive) is
   * the object's own, which the engine reads before asking here. A
   * value set through window must go by its setter, and one defined
   * with a value is the global of that name: moved there, the object
   * keeping none of its own that an assignment to the global would
   * leave behind *)
  let self : value ref = ref Undefined in
  let own (k : string) = match !self with Object o -> get_own o k | _ -> None in
  let settle (k : string) : unit =
    match (own k, !self) with
    | Some (Object { kind = Accessor _; _ }), _ | None, _ -> ()
    | Some v, Object o -> Js_eval.define t.engine k v; o.props <- List.filter (fun (k', _) -> k' <> k) o.props
    | Some _, _ -> ()
  in
  let window =
    host_object
      {
        class_name = "Window";
        get = global;
        (* window.location = url goes there, as location.href = url *)
        set =
          (fun k v ->
            match (k, v, own k) with
            | _, _, Some (Object { kind = Accessor (_, s); _ }) -> (
                ignore (Js_eval.call_in_run t.engine s ~this:!self [ v ]);
                (* the setter may have defined it anew, with a value *)
                settle k;
                match own k with Some (Object { kind = Accessor (g, _); _ }) -> Js_eval.define t.engine k (Js_eval.call_in_run t.engine g ~this:!self []) | _ -> ())
            | "location", String url, _ -> t.navigation <- Some (Browser_url.resolve t.base url, false)
            | _ -> settle k; Js_eval.define t.engine k v);
        show = (fun () -> "Window");
      }
  in
  self := window;
  (match window with Object o -> o.proto <- List.assoc_opt "window" t.protos | _ -> ());
  List.iter (fun name -> define name window) [ "window"; "self"; "globalThis"; "top"; "parent"; "frames" ];
  window
