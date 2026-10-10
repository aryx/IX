(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/run/Browser_script.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Browser_script.mli *)
open Js_value
open Script_types
open Script_dom (* the copy *)
open Script_host (* the host objects *)

type t = Script_types.t

(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

(* data/prelude/web/, parsed once *)
(* (ix: read at its first use and kept, by hand: mini-ml has no lazy) *)
let prelude_read : Js_ast.program option ref = ref None

let prelude () : Js_ast.program =
  match !prelude_read with
  | Some program -> program
  | None ->
      let program = match Js_parse.parse Script_prelude.text with Ok program -> program | Error e -> failwith (Printf.sprintf "data/prelude/web/, line %d: %s" e.line e.message) in
      prelude_read := Some program;
      program

(* [inserted], which is written after what it needs *)
let inserted_later : (t -> node -> unit) ref = ref (fun _ _ -> ())

let say (t : t) (line : string) : unit =
  t.console <- line :: t.console;
  t.log line

let report (t : t) (e : Js_eval.error) : unit =
  let m = e.message in
  say t (Printf.sprintf "%s (line %d)" (if String.starts_with ~prefix:"Uncaught" m then m else "Uncaught " ^ m) e.line)

(*****************************************************************************)
(* Events *)
(*****************************************************************************)

(* a handler run. The browser's event (a click, a timer) is a task of
 * its own: the engine's budget renewed, its jobs run after. One
 * dispatched by a script ([nested]) is in that script's run. Either
 * way its error is said in the console, not the next handler's
 * business; whether it returned false (DOM level 0's way to cancel,
 * onclick="...; return false") *)
let where_later : (t -> node -> (float * float * float * float) option) ref = ref (fun _ _ -> None)

let run_handler ~(nested : bool) (t : t) (f : value) ~(this : value) (event : value) : bool =
  (* a listener that is an object: its handleEvent, the object for this
   * (DOM level 2's EventListener, which a framework gives so that one
   * object hears every event) *)
  let f, this =
    match f with
    | Object { kind = Plain; _ } -> ( match Js_eval.get t.engine f "handleEvent" with Object _ as h -> (h, f) | _ -> (f, this))
    | _ -> (f, this)
  in
  let result =
    if nested then try Ok (Js_eval.call_in_run t.engine f ~this [ event ]) with Throw v -> Error (Js_eval.error_of t.engine v)
    else Js_eval.call t.engine f ~this [ event ]
  in
  match result with
  | Ok (Bool false) -> true
  | Ok _ -> false
  | Error e -> report t e; false

(* onclick="..." compiled once into a function of event, as browsers
 * do: the attribute's text is the function's body *)

let attribute_handler ~(nested : bool) (t : t) (n : node) (typ : string) : value option =
  match attribute n ("on" ^ typ) with
  | None -> None
  | Some src -> (
      match List.assoc_opt src n.compiled with
      | Some f -> Some f
      | None -> (
          let text = "(function (event) {\n" ^ src ^ "\n})" in
          match if nested then (try Ok (Js_eval.eval_in_run t.engine text) with Throw v -> Error (Js_eval.error_of t.engine v)) else Js_eval.eval t.engine text with
          | Ok f ->
              n.compiled <- (src, f) :: n.compiled;
              Some f
          | Error e -> report t e; None))

(* an event (Script_events) dispatched at [target] (None: the
 * document): its handlers, then, if it bubbles, its parent's, up to
 * the document, unless one stops it; whether one prevented the
 * default. What the event says of itself is its properties, read
 * after each handler *)
let dispatch_event ~(nested : bool) (t : t) (target : node option) (event : value) : bool =
  let ev = match event with Object o -> o | _ -> throw "TypeError" "parameter 1 is not of type 'Event'" in
  let typ = match get_own ev "type" with Some v -> to_string v | None -> "" in
  let flag = Script_events.flag event in
  let document = match Js_eval.global t.engine "document" with Some v_ -> v_ | None -> Undefined in
  set_own ev "target" (match target with Some n -> wrap t n | None -> document);
  (* its path: the target, what it is in, the document, the window --
   * composedPath(), and Chrome's older event.path. A component asks
   * it to know which of its parts was clicked (a dialog's button that
   * confirms: Polymer's; with no path YouTube's dialog stayed open) *)
  (let made = ref None in
   let path () =
     match !made with
     | Some p -> p
     | None ->
         let rec chain (n : node option) = match n with Some n -> wrap t n :: chain n.parent | None -> [] in
         let p = Object (new_array (chain target @ [ document ] @ Option.to_list (Js_eval.global t.engine "window"))) in
         made := Some p;
         p
   in
   set_own ev "composedPath" (host_function "composedPath" (fun ~this:_ _ -> path ()));
   if target <> None then set_own ev "path" (path ()));
  let prevent () = set_own ev "defaultPrevented" (Bool true) in
  let handle this (listeners : (string * value) list) ~(remove : value -> unit) (extra : value option) =
    set_own ev "currentTarget" this;
    List.iter
      (fun (ty, f) ->
        if ty = typ && not (flag "@@immediate") then (
          (* { once: true }: gone before it is called *)
          if List.exists (fun (ty', g) -> ty' = typ && g == f) t.once then (
            t.once <- List.filter (fun (ty', g) -> not (ty' = typ && g == f)) t.once;
            remove f);
          if run_handler ~nested t f ~this event then prevent ()))
      listeners;
    Option.iter (fun f -> if (not (flag "@@immediate")) && run_handler ~nested t f ~this event then prevent ()) extra
  in
  let rec up (n : node option) =
    match n with
    | Some n when not (flag "cancelBubble") ->
        (* el.onclick = f, else onclick="..." *)
        let on = match List.assoc_opt ("on" ^ typ) n.expando with Some (Object _ as f) -> Some f | _ -> attribute_handler ~nested t n typ in
        (* JS_EVENTS="click mousedown": each element on the event's way that
         * listens for it, said (who hears a click, when nothing happens) *)
        (match !Script_host.events_said with
        | types when List.mem typ types ->
            let heard = List.length (List.filter (fun (ty, _) -> ty = typ) n.listeners) + if on = None then 0 else 1 in
            if heard > 0 then !Js_value.say (Printf.sprintf "event: %s heard by <%s class=%S> (%d)" typ n.name ((match (attribute n "class") with Some v_ -> v_ | None -> "")) heard)
        | _ -> ());
        handle (wrap t n) n.listeners ~remove:(fun f -> n.listeners <- List.filter (fun (ty, g) -> not (ty = typ && g == f)) n.listeners) on;
        if flag "bubbles" then up n.parent
    | _ -> ()
  in
  up target;
  (match !Script_host.events_said with
  | types when List.mem typ types ->
      !Js_value.say (Printf.sprintf "event: %s at the document and the window: %d listeners%s" typ (List.length (List.filter (fun (ty, _) -> ty = typ) t.document_listeners)) (if flag "cancelBubble" then " (stopped before)" else ""))
  | _ -> ());
  if (target = None || flag "bubbles") && not (flag "cancelBubble") then
    handle document t.document_listeners ~remove:(fun f -> t.document_listeners <- List.filter (fun (ty, g) -> not (ty = typ && g == f)) t.document_listeners) None;
  flag "defaultPrevented"

(* an event of the browser's: a click, a key *)
let dispatch (t : t) (target : node) (typ : string) (fields : (string * value) list) : bool =
  dispatch_event ~nested:false t (Some target) (Script_events.make ~bubbles:true typ fields)

(* the node a frozen element came from *)
let node_of_element (t : t) (e : Dom.element) : node option = List.find_map (fun (e', n) -> if e' == e then Some n else None) t.frozen

(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

(* the limits of one run of a page's script, or of one of its jobs: a
 * minute by the clock, and steps without count (JS_BUDGET=n: so many
 * steps, to cut a loop short and read where it was:
 * docs/dev/notes_debugging_techniques.txt) *)
(* ix: a host's to set, where it was the environment's JS_BUDGET *)
let page_budget = ref max_int
let page_seconds = 60.

type options = {
  seed : int;
  log : string -> unit;
  base : string;
  epoch : float;
  viewport : float * float;
  cookies : (unit -> string) * (string -> unit);
}

let defaults : options =
  { seed = 1; log = (fun _ -> ()); base = "about:blank"; epoch = 0.; viewport = (1000., 768.); cookies = ((fun () -> ""), fun (_ : string) -> ()) }

let create_with ({ seed; log; base; epoch; viewport; cookies } : options) (tree : Dom.element) : t =
  Js_value.missing := None;
  let lines = ref (fun (_ : string) -> ()) in
  let clock = ref (fun () -> epoch) in
  let engine = Js_eval.create_with (fun l -> !lines l) seed (fun () -> !clock ()) in
  (* a page's run may be long: an application's start is one run of
   * hundreds of millions of steps (Gmail's stopped at the language's
   * ten million, "the script ran too long", and showed its "having
   * trouble loading?"). The window is drawn meanwhile (Js_slice), so
   * the limit is only for a loop that truly never ends: a minute (by
   * steps alone, and many, a page that does loop held its tab for
   * half an hour: nobelprize.org) *)
  Js_eval.set_budget engine !page_budget;
  Js_eval.set_seconds engine page_seconds;
  let t =
    { engine; root = thaw tree; changed = false; console = []; log; nodes = Hashtbl.create 64; document_listeners = []; frozen = [];
      now = 0.; timers = []; next_timer = 0; alerts = []; base; address = []; requests = []; waiting = []; next_request = 0; import_map = []; module_sources = []; module_asked = []; modules = None; module_jobs = []; navigation = None; submission = None; current_script = None; cookies;
      more = (fun _ _ -> None); scroll_y = 0.; where = (fun _ -> None); measure = None; geometry = None; dispatch = (fun _ _ -> false); inserted = (fun _ -> ()); exempt = []; once = []; protos = []; ready = "loading"; frames = [] }
  in
  t.more <- Script_element.get t;
  t.where <- (fun n -> !where_later t n);
  t.dispatch <- dispatch_event ~nested:true t;
  t.inserted <- (fun n -> !inserted_later t n);
  (* Date's clock: the page's, from [epoch] *)
  (* (and the time a long run has taken, past a twentieth of a second:
   * a page that waits by asking the time again and again -- while
   * (Date.now() - start < 4000) -- waited for ever on a clock that
   * moved between its tasks alone. Not counted under that, so that a
   * page's dates are the same from one run to the next) *)
  clock := (fun () -> let run = Js_eval.running_for engine *. 1000. in epoch +. t.now +. if run > 50. then Float.round run else 0.);
  lines := say t;
  let define name f = Js_eval.define engine name (host_function name (fun ~this:_ args -> f args)) in
  (* window and what a library looks for on it, the classes of the
   * host objects first: document is one *)
  let (_ : value) = Script_window.install t ~viewport (Js_eval.define engine) in
  Script_events.install (Js_eval.define engine);
  Js_eval.define engine "document" (Script_document.document t);
  Event_loop.install t define;
  define "alert" (fun args -> t.alerts <- str (arg args 0) :: t.alerts; Undefined);
  Js_eval.define engine "location" (location t);
  Js_eval.define engine "navigator"
    (let o = new_object () in
     set_own o "userAgent" (String "Mozilla/5.0 (TinyChrome; elm_playground)");
     set_own o "language" (String "en-US");
     Object o);
  (* a URL's parts, for the URL class (data/prelude/web/): href
   * resolved against a base, the page's if none is given *)
  define "__url" (fun args ->
      let base = match arg args 1 with Undefined -> t.base | v -> str v in
      url_object (Browser_url.resolve base (str (arg args 0))));
  (* a script asking the network: its requests queued for the browser
   * ([take_requests]), their answers given back ([answer]) *)
  XMLHttpRequest.install t (Js_eval.define engine);
  Script_fetch.install t (Js_eval.define engine);
  (* modules: import() is there even in a page with none *)
  ignore (Script_modules.modules t);
  (* the small web APIs written in JavaScript *)
  (match Js_eval.run engine (prelude ()) with Ok _ -> () | Error e -> log (Printf.sprintf "data/prelude/web/, line %d: %s" e.line e.message));
  Script_url.install t (Js_eval.define engine);
  (* with -v, what this page looks for and does not find is said, once
   * a name: not the marks a library keeps on a node (_x, $x, __x), nor
   * what every promise and every JSON asks of any object *)
  Hashtbl.reset (Script_host.missed_names ());
  Js_value.missing :=
    (if !Script_host.says_missing then
       Some (fun cls k -> if k <> "" && (match k.[0] with 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false) && not (List.mem k [ "then"; "toJSON"; "nodeType"; "window"; "jquery"; "event"; "attributeChangedCallback"; "connectedCallback"; "disconnectedCallback"; "adoptedCallback" ]) then Script_host.missed (cls ^ "." ^ k))
     else None);
  t

let create (tree : Dom.element) : t = create_with defaults tree

let eval (t : t) (text : string) : (value, Js_eval.error) result =
  let r = Js_eval.eval t.engine text in
  (match r with Error e -> report t e | Ok _ -> ());
  r

(* a script the page's: JavaScript by its type= (not JSON-LD, not a
 * template; a module is run apart), and not one for the browsers
 * that have no modules (nomodule) *)
let runnable (s : node) : bool =
  attribute s "nomodule" = None
  &&
  match Option.map String.lowercase_ascii (attribute s "type") with
  | None | Some "" | Some "text/javascript" | Some "application/javascript" -> true
  | Some _ -> false

let is_module (s : node) : bool = Option.map String.lowercase_ascii (attribute s "type") = Some "module"

(* the modules ready to run (Script_modules), each a task; one's run
 * may make others ready *)
let rec run_modules (t : t) : unit =
  match Script_modules.take_jobs t with
  | [] -> ()
  | jobs ->
      List.iter
        (fun job ->
          let run = host_function "module" (fun ~this:_ _ -> job (); Undefined) in
          match Js_eval.call t.engine run ~this:Undefined [] with
          | Ok _ -> ()
          | Error e ->
              (* a module's error says which module: its line is that file's *)
              let where = match Js_module.take_failing (Script_modules.modules t) with Some url -> " in " ^ url | None -> "" in
              report t { e with message = e.message ^ where })
        jobs;
      run_modules t


(* a <script> a script put in the page (document.head.appendChild(s):
 * how a loader fetches the rest of a site's code): its text run at
 * once, or its src fetched then run, and its load event, or error --
 * each once *)
let inserted (t : t) (n : node) : unit =
  let connected (n : node) = let rec up (n : node) = n == t.root || (match n.parent with Some p -> up p | None -> false) in up n in
  (* custom elements (data/prelude/web/): an element entering the
   * page, said to the registry, which upgrades it or calls its
   * connectedCallback, and its descendants' *)
  (match Js_eval.global t.engine "__connected" with
  | Some (Object _ as f) when is_element n && connected n -> ignore (run_handler ~nested:false t f ~this:Undefined (wrap t n))
  | _ -> ());
  let ran (s : node) = List.mem_assoc "%ran" s.expando in
  let event (s : node) (typ : string) = ignore (t.dispatch (Some s) (Script_events.make ~bubbles:false typ [])) in
  let run (s : node) (text : string) : unit =
    let before = t.current_script in
    t.current_script <- Some s;
    (try ignore (Js_eval.eval_in_run t.engine text) with Throw v -> report t (Js_eval.error_of t.engine v));
    t.current_script <- before
  in
  if connected n then
    List.iter
      (fun (s : node) ->
        if not (ran s) then (
          s.expando <- ("%ran", Bool true) :: s.expando;
          match (attribute s "src", is_module s) with
          | Some src, false when runnable s ->
              ignore
                (Script_fetch.ask ~cors:false ~headers:[] ~ahead:None t ~meth:"GET" ~url:src ~post:None (fun answer ->
                     match answer with
                     | Ok a when a.status / 100 = 2 -> run s a.body; event s "load"
                     | _ -> event s "error"))
          | Some src, true -> Script_modules.start t ~url:(Browser_url.resolve t.base src) None
          | None, false when runnable s -> run s (text_content s)
          | _ -> ()))
      (List.filter (fun (e : node) -> e.name = "script") (n :: elements n))

let () = inserted_later := inserted

let script_sources (t : t) : string list =
  List.filter_map
    (fun (s : node) -> if runnable s then Option.map (Browser_url.resolve t.base) (attribute s "src") else None)
    (List.filter (fun e -> e.name = "script") (elements t.root))

let run_scripts_with (source : string -> string option) (t : t) : unit =
  List.iter
    (fun (s : node) ->
      t.current_script <- Some s;
      (match attribute s "src" with
      | Some src -> (
          match source (Browser_url.resolve t.base src) with
          | Some text -> ignore (eval t text)
          | None -> say t (Printf.sprintf "<script src=\"%s\"> could not be had" src))
      | None -> ignore (eval t (text_content s)));
      t.current_script <- None)
    (List.filter (fun e -> e.name = "script" && runnable e) (elements t.root));
  (* then its modules, in order: deferred, each run once what it
   * imports has come -- now, if nothing is missing; the page's import
   * map first *)
  List.iter
    (fun (s : node) -> if Option.map String.lowercase_ascii (attribute s "type") = Some "importmap" then Script_modules.read_import_map t (text_content s))
    (List.filter (fun e -> e.name = "script") (elements t.root));
  List.iteri
    (fun i (s : node) ->
      match attribute s "src" with
      | Some src -> Script_modules.start t ~url:(Browser_url.resolve t.base src) None
      | None -> Script_modules.start t ~url:(Printf.sprintf "%s#module-%d" (fst (Browser_url.split_fragment t.base)) (i + 1)) (Some (text_content s)))
    (List.filter (fun e -> e.name = "script" && is_module e) (elements t.root));
  run_modules t;
  (* then the document is loaded: its listeners told *)
  (* (a page asks document.readyState whether its scripts are still
   * being read: Gmail's gives up on the data of a script yet to come
   * if told "complete" too soon) *)
  let tell typ = List.iter (fun (ty, f) -> if ty = typ then ignore (run_handler ~nested:false t f ~this:Undefined Undefined)) t.document_listeners in
  List.iter
    (fun (state, typ) ->
      t.ready <- state;
      tell "readystatechange";
      tell typ)
    [ ("interactive", "DOMContentLoaded"); ("complete", "load") ];
  (* and window.onload = f, the way of 1996, which a program compiled by
   * js_of_ocaml still starts on *)
  match Js_eval.global t.engine "onload" with
  | Some (Object _ as f) -> ignore (run_handler ~nested:false t f ~this:Undefined Undefined)
  | _ -> ()


let run_scripts (t : t) : unit = run_scripts_with (fun _ -> None) t

let tree (t : t) : Dom.element =
  t.changed <- false;
  let pairs = ref [] in
  let rec go (n : node) : Dom.element =
    let origin = Dtd.element_origin n.name in
    let attributes, extensions =
      match origin with
      | Netscape -> (n.attributes, [])
      | Core -> List.partition (fun a -> Dtd.attribute_origin n.name a = Dtd.Core) n.attributes
    in
    (* a comment is not the page's; nor what is in a <noscript>, written
     * for a browser that runs no script, which this page's does *)
    let frozen (nodes : node list) : Dom.node list =
      List.filter_map
        (fun c -> if is_text c then Some (Dom.Text c.text) else if is_element c && c.name <> "noscript" then Some (Dom.Element (go c)) else None)
        nodes
    in
    (* a host: its shadow tree drawn, its children where the slots are *)
    let children = match n.shadow with Some root -> Shadow_tree.distribute ~shadow:(frozen root.children) ~light:(frozen n.children) | None -> frozen n.children in
    let e : Dom.element = { name = n.name; attributes; extensions; origin; children } in
    pairs := (e, n) :: !pairs;
    e
  in
  let root = go t.root in
  t.frozen <- !pairs;
  root

(* where a node is: the tree frozen and laid out by the browser
 * ([measure]) the first time a script asks since it changed -- what a
 * browser calls a forced layout: a script that writes then reads a
 * size makes the page be laid out in the middle of its run *)

let where (t : t) (n : node) : (float * float * float * float) option =
  match (t.geometry, t.measure) with
  | Some f, _ -> f n
  | None, None -> None
  | None, Some measure ->
      (* the tree frozen for the measure alone: the page shown is still
       * the one frozen before, and a click on it must find its nodes *)
      let changed = t.changed and shown = t.frozen in
      let at = measure (tree t) in
      let pairs = t.frozen in
      t.changed <- changed;
      t.frozen <- shown;
      let f (n : node) = Option.bind (List.find_map (fun (e, n') -> if n' == n then Some e else None) pairs) at in
      t.geometry <- Some f;
      f n

let () = where_later := where

let set_measure (t : t) (measure : Dom.element -> Dom.element -> (float * float * float * float) option) : unit =
  t.measure <- Some measure;
  t.geometry <- None

let scrolled (t : t) (y : float) : unit =
  if y <> t.scroll_y then (
    t.scroll_y <- y;
    List.iter (fun k -> Js_eval.define t.engine k (Number y)) [ "scrollY"; "pageYOffset" ])

let click_at (at : (float * float) option) (t : t) (e : Dom.element) : bool =
  (* the left button, no key held: what a page's handler checks before
   * it takes a link's click for its own (event.button === 0); and
   * where, in the page's window, as a mousedown says it *)
  let where = match at with Some (x, y) -> [ ("clientX", Number x); ("clientY", Number y); ("pageX", Number x); ("pageY", Number (y +. t.scroll_y)) ] | None -> [] in
  let held = [ ("button", Number 0.); ("buttons", Number 0.); ("which", Number 1.); ("detail", Number 1.); ("ctrlKey", Bool false); ("shiftKey", Bool false); ("metaKey", Bool false); ("altKey", Bool false) ] in
  match node_of_element t e with Some n -> dispatch t n "click" (where @ held) | None -> false

(* a form about to be sent: its submit event, which a script may
 * prevent (it sends the form itself, later) or use to put a last value
 * in a field of the form -- a token computed as the form goes: the
 * page's proof that its scripts ran, on Google's sign-in *)
let click (t : t) (e : Dom.element) : bool = click_at None t e

let submit (t : t) (form : Dom.element) : bool = match node_of_element t form with Some n -> dispatch t n "submit" [] | None -> false

(* a control's value as the scripts have it now (el.value = ...) *)
let value_now (t : t) (e : Dom.element) : string option = Option.bind (node_of_element t e) (fun n -> attribute n "value")

let key (t : t) (k : string) : bool =
  let body = match List.find_opt (fun n -> n.name = "body") (elements t.root) with Some b -> b | None -> t.root in
  dispatch t body "keydown" [ ("key", String k) ]

(* whether the window (the document) has a listener of that type *)
let rec listens (t : t) (typ : string) : bool =
  List.exists (fun (ty, _) -> ty = typ) t.document_listeners || ((typ = "keydown" || typ = "keyup") && List.exists (fun (_, frame) -> listens frame typ) t.frames)

(* a key as the web names it, from the platform's name (SDL's, in
 * lower case, but the arrows): "return" is "Enter", "space" is " " *)
let web_key (k : string) : string =
  match if String.length k > 1 && not (String.starts_with ~prefix:"Arrow" k) then String.lowercase_ascii k else k with
  | "return" -> "Enter"
  | "space" -> " "
  | "left shift" | "right shift" -> "Shift"
  | "left ctrl" | "right ctrl" -> "Control"
  | "left alt" | "right alt" -> "Alt"
  | "backspace" | "tab" | "escape" | "delete" | "home" | "end" | "insert" -> String.capitalize_ascii k
  | "pageup" -> "PageUp"
  | "pagedown" -> "PageDown"
  | _ when String.length k >= 2 && k.[0] = 'f' && String.for_all (fun c -> c >= '0' && c <= '9') (String.sub k 1 (String.length k - 1)) -> String.capitalize_ascii k
  | k -> k

let rec window_event_at (at : Dom.element option) (t : t) (typ : string) (fields : (string * value) list) : bool =
  let own = List.exists (fun (ty, _) -> ty = typ) t.document_listeners && dispatch_event ~nested:false t (Option.bind at (node_of_element t)) (Script_events.make ~bubbles:true typ (List.map (fun (k, v) -> if k = "key" then (k, (match v with String s -> String (web_key s) | v -> v)) else (k, v)) fields)) in
  (* a key is its frames' too (a deck of slides in a frame, turned by the arrows) *)
  let framed = (typ = "keydown" || typ = "keyup") && List.fold_left (fun any (_, frame) -> window_event_at None frame typ fields || any) false t.frames in
  own || framed

(* a picture has come (or not: [size] None): each <img> of that address
 * is told -- its load event, or error -- and says its size
 * (naturalWidth, complete): what a page waits for to show a picture it
 * keeps hidden until then *)
let window_event (t : t) (typ : string) (fields : (string * value) list) : bool = window_event_at None t typ fields

let picture (t : t) (url : string) (size : (float * float) option) : unit =
  List.iter
    (fun (n : node) ->
      (* its address as the layout takes it: src, else srcset's first *)
      let address =
        match attribute n "src" with
        | Some src when String.trim src <> "" -> Some src
        | _ -> Option.bind (attribute n "srcset") (fun set -> match String.split_on_char ' ' (String.trim (List.hd (String.split_on_char ',' set))) with u :: _ when u <> "" -> Some u | _ -> None)
      in
      match address with
      | Some src when n.name = "img" && Browser_url.resolve t.base src = url ->
          let w, h = (match size with Some v_ -> v_ | None -> (0., 0.)) in
          n.expando <- [ ("complete", Bool true); ("naturalWidth", Number w); ("naturalHeight", Number h) ] @ List.filter (fun (k, _) -> not (List.mem k [ "complete"; "naturalWidth"; "naturalHeight" ])) n.expando;
          ignore (dispatch_event ~nested:false t (Some n) (Script_events.make ~bubbles:false (if size = None then "error" else "load") []))
      | _ -> ())
    (elements t.root)

(* Back or Forward to another state of this document (one the page
 * made by history.pushState): its address is that one's, and the
 * window is told (popstate), for the page to draw that state *)
let popstate (t : t) (url : string) : unit =
  t.base <- url;
  ignore (window_event_at None t "popstate" [ ("state", Null) ])

let input (t : t) (e : Dom.element) (text : string) : unit =
  match node_of_element t e with
  | Some n ->
      set_attribute n "value" text;
      touch t;
      ignore (dispatch t n "input" [])
  | None -> ()

(* an attribute of an element of the last [tree] set, or removed
 * (None): what the browser itself changes (a <details> opened) *)
let set_attribute (t : t) (e : Dom.element) (name : string) (value : string option) : unit =
  match node_of_element t e with
  | Some n ->
      (match value with Some v -> Script_dom.set_attribute n name v | None -> n.attributes <- List.remove_assoc name n.attributes);
      touch t
  | None -> ()

(* the loop's turn for the timers (Event_loop): each one due is a task *)
let rec advance (t : t) (ms : float) : unit =
  Event_loop.advance t ms ~task:(fun f time -> ignore (run_handler ~nested:false t f ~this:Undefined time));
  (* its frames' timers on the same clock *)
  List.iter (fun (_, frame) -> advance frame ms) t.frames

(* a request's answer, given to the script that asked: a task of its
 * own (its promises' thens run after it) *)
let rec answer (t : t) (rid : int) (result : (answer, string) result) : unit =
  match List.find_opt (fun (_, (frame : t)) -> List.mem_assoc rid frame.waiting) t.frames with
  | Some (_, frame) -> answer frame rid result
  | None ->
  let give = host_function "answer" (fun ~this:_ _ -> Script_fetch.answer t rid result; Undefined) in
  (match Js_eval.call t.engine give ~this:Undefined [] with Ok _ -> () | Error e -> report t e);
  (* a module's text, perhaps the last its graph waited for *)
  run_modules t

let rec take_requests (t : t) : request list =
  let r = List.rev t.requests in
  t.requests <- [];
  (* its frames' too: numbered apart ([adopt]), to give each its answer *)
  r @ List.concat_map (fun (_, frame) -> take_requests frame) t.frames

let take_address (t : t) : (string * bool) list =
  let a = List.rev t.address in
  t.address <- [];
  a

let take_navigation (t : t) : (string * bool) option =
  let n = t.navigation in
  t.navigation <- None;
  n

let take_submission (t : t) : (string * (string * string) option) option =
  let s = t.submission in
  t.submission <- None;
  s

let take_alerts (t : t) : string list =
  let a = List.rev t.alerts in
  t.alerts <- [];
  a

let changed (t : t) : bool = t.changed || List.exists (fun (_, (frame : t)) -> frame.changed) t.frames

(*****************************************************************************)
(* Frames *)
(*****************************************************************************)

(* what an <iframe> shows, as the page's layout names it (Frames.source,
 * Browser_page's): its srcdoc's text, else its src's address *)
let shown_by (t : t) (n : node) : string option =
  match (attribute n "srcdoc", attribute n "src") with
  | Some text, _ -> Some text
  | None, Some src when String.trim src <> "" -> Some (Browser_url.resolve t.base (String.trim src))
  | _ -> None

(* a message for a window, told to its "message" listeners in a task
 * of its own: the prelude's __deliver, given the data and who sent it *)
let deliver (t : t) (data : value) (from : value) : unit =
  let task =
    host_function "message" (fun ~this:_ _ ->
        (match Js_eval.global t.engine "__deliver" with
        | Some f -> ( match Js_eval.call t.engine f ~this:Undefined [ data; from ] with Ok _ -> () | Error e -> report t e)
        | None -> ());
        Undefined)
  in
  ignore (Event_loop.add ~frame:false t [ task; Number 0. ] ~repeat:false)

(* [adopt page ~key frame]: the world of the document a frame of the
 * page shows, made the page's. Each is its own engine: the two share
 * no object, and talk by messages alone -- the frame's window.parent
 * and the page's iframe.contentWindow are windows one can only post
 * to (postMessage), which is all two documents of different sites may
 * do in any browser, and here all that any two may *)
let adopt (page : t) ~(key : string) (frame : t) : unit =
  (* its requests numbered apart from the page's and its other frames' *)
  frame.next_request <- (List.length page.frames + 1) * 1_000_000;
  page.frames <- (key, frame) :: List.remove_assoc key page.frames;
  let iframe () = List.find_opt (fun n -> n.name = "iframe" && shown_by page n = Some key) (elements page.root) in
  Js_eval.define frame.engine "__post_parent"
    (host_function "__post_parent" (fun ~this:_ args ->
         deliver page ((match (List.nth_opt args 0) with Some v_ -> v_ | None -> Undefined)) (match iframe () with Some n -> Script_host.wrap page n | None -> Undefined);
         Undefined));
  Js_eval.define page.engine "__post_frame"
    (host_function "__post_frame" (fun ~this:_ args ->
         (match args with
         | el :: data :: _ -> (
             match Option.bind (try Some (Script_host.node_of page el) with _ -> None) (shown_by page) with
             | Some key -> Option.iter (fun (to_ : t) -> deliver to_ data Undefined) (List.assoc_opt key page.frames)
             | None -> ())
         | _ -> ());
         Undefined));
  match Js_eval.eval frame.engine "__framed()" with Ok _ -> () | Error e -> report frame e

(* a frame's document as its scripts have it now *)
(* (the same tree while they change nothing: what is computed from it is kept by its identity) *)
let frozen_here = Per_domain.make (fun () -> (Hashtbl.create 8 : (int, Dom.element) Hashtbl.t))

let frame_tree (t : t) (key : string) : Dom.element option =
  Option.map
    (fun (frame : t) ->
      let id = Hashtbl.hash key in
      match Hashtbl.find_opt (frozen_here ()) id with
      | Some kept when not frame.changed -> kept
      | _ ->
          let now = tree frame in
          Hashtbl.replace (frozen_here ()) id now;
          now)
    (List.assoc_opt key t.frames)
let frames (t : t) : (string * t) list = t.frames
let console (t : t) : string list = List.rev t.console
let print (t : t) (line : string) : unit = say t line
let engine (t : t) : Js_eval.t = t.engine
