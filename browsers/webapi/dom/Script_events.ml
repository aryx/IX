(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/dom/Script_events.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Script_events.mli *)
open Js_value

let arg (args : value list) (i : int) : value = (match (List.nth_opt args i) with Some v_ -> v_ | None -> Undefined)
let fn (name : string) (f : value list -> value) : value = host_function name (fun ~this:_ args -> f args)

(* the hidden mark of stopImmediatePropagation *)
let immediate = "@@immediate"

let flag (ev : value) (k : string) : bool = match ev with Object o -> ( match get_own o k with Some v -> truthy v | None -> false) | _ -> false

(* [o] made an event *)
let fill (o : obj) ~(bubbles : bool) (typ : string) (fields : (string * value) list) : unit =
  let set k v = set_own o k v in
  set "type" (String typ);
  set "bubbles" (Bool bubbles);
  set "cancelable" (Bool true);
  set "defaultPrevented" (Bool false);
  set "cancelBubble" (Bool false);
  set "target" Null;
  set "currentTarget" Null;
  set "detail" Null;
  set "timeStamp" (Number 0.);
  List.iter (fun (k, v) -> set k v) fields;
  set "preventDefault" (fn "preventDefault" (fun _ -> set "defaultPrevented" (Bool true); Undefined));
  set "stopPropagation" (fn "stopPropagation" (fun _ -> set "cancelBubble" (Bool true); Undefined));
  set "stopImmediatePropagation" (fn "stopImmediatePropagation" (fun _ -> set "cancelBubble" (Bool true); set immediate (Bool true); Undefined));
  set "composedPath" (fn "composedPath" (fun _ -> Object (new_array [])))

(* the prototype every event has: Event.prototype, once [install]ed *)
let proto : obj option ref = ref None

(* an event of the browser's own making (a click, a key, a load): an
 * Event as one a script makes is -- a library asks "instanceof Event"
 * before it reads one (Polymer, of the click that closes a dialog) *)
let make ~(bubbles : bool) (typ : string) (fields : (string * value) list) : value =
  let o = { (new_object ()) with proto = !proto } in
  fill o ~bubbles typ fields;
  Object o

let install (define : string -> value -> unit) : unit =
  let event_proto = new_object () in
  proto := Some event_proto;
  List.iter
    (fun name ->
      (* new Event(type, { bubbles, cancelable, detail, ... }): the
       * object new made, filled *)
      let c =
        host_function name (fun ~this args ->
            let o = match this with Object o -> o | _ -> throw "TypeError" (Printf.sprintf "Failed to construct '%s': Please use the 'new' operator" name) in
            let init = match arg args 1 with Object i -> List.map (fun k -> (k, Option.get (get_own i k))) (keys i) | _ -> [] in
            fill o ~bubbles:(match List.assoc_opt "bubbles" init with Some v -> truthy v | None -> false) (to_string (arg args 0)) init;
            Undefined)
      in
      (* each kind's prototype is behind Event's: instanceof Event *)
      let p = if name = "Event" then event_proto else { (new_object ()) with proto = Some event_proto } in
      (match c with Object c -> set_own c "prototype" (Object p) | _ -> ());
      set_own p "constructor" c;
      define name c)
    [ "Event"; "CustomEvent"; "UIEvent"; "MouseEvent"; "KeyboardEvent"; "InputEvent"; "FocusEvent"; "PointerEvent"; "ErrorEvent"; "WheelEvent"; "TouchEvent";
      "DragEvent"; "AnimationEvent"; "TransitionEvent"; "ProgressEvent"; "MessageEvent"; "PopStateEvent"; "HashChangeEvent"; "ClipboardEvent";
      "CompositionEvent"; "StorageEvent"; "PageTransitionEvent"; "BeforeUnloadEvent"; "SubmitEvent"; "ToggleEvent" ]

let create () : value =
  let o = { (new_object ()) with proto = !proto } in
  fill o ~bubbles:false "" [];
  let init args = set_own o "type" (String (to_string (arg args 0))); set_own o "bubbles" (Bool (truthy (arg args 1))); set_own o "cancelable" (Bool (truthy (arg args 2))) in
  List.iter (fun name -> set_own o name (fn name (fun args -> init args; Undefined))) [ "initEvent"; "initUIEvent"; "initMouseEvent"; "initKeyboardEvent" ];
  set_own o "initCustomEvent" (fn "initCustomEvent" (fun args -> init args; set_own o "detail" (arg args 3); Undefined));
  Object o
