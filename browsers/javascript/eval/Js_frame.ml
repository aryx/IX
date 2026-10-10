(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/eval/Js_frame.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_frame.mli *)
open Js_value
module A = Js_ast

type params = scope -> value -> (A.pattern * A.expr option) list -> A.pattern option -> value list -> unit

let rec pattern_names (pt : A.pattern) : string list =
  match pt with
  | Bind x -> [ x ]
  | Object_pattern (parts, rest) -> List.concat_map (fun (_, pt, _) -> pattern_names pt) parts @ (match rest with Some r -> pattern_names r | None -> [])
  | Array_pattern (parts, rest) ->
      List.concat_map (fun part -> match part with Some (pt, _) -> pattern_names pt | None -> []) parts @ (match rest with Some r -> pattern_names r | None -> [])

(* var's names, declared (undefined) at the top of their function: a
 * var in a block or a loop is the function's -- hoisting, ES5's, what
 * let (block-scoped) came to fix *)
let hoisted (body : A.stmt list) : string list =
  let rec names (st : A.stmt) : string list =
    match st.stmt with
    | Let (Var_kind, decls) -> List.concat_map (fun (pt, _) -> pattern_names pt) decls
    | Var_set decls -> List.map (fun (x, _, _) -> x) decls
    | If (_, a, b) -> names a @ (match b with Some b -> names b | None -> [])
    | While (_, b) | With (_, b) -> names b
    | For (init, _, _, b) -> (match init with Some i -> names i | None -> []) @ names b
    | For_of (Var_kind, x, _, b) | For_await (Var_kind, x, _, b) -> pattern_names x @ names b
    | For_in (Declared (Var_kind, x), _, b) -> x :: names b
    | For_of (_, _, _, b) | For_await (_, _, _, b) | For_in (_, _, b) | Do_while (b, _) | Labeled (_, b) -> names b
    | Switch (_, cases) -> List.concat_map (fun (_, body) -> List.concat_map names body) cases
    | Try (a, handler, finally) ->
        List.concat_map names a
        @ (match handler with Some (_, h) -> List.concat_map names h | None -> [])
        @ (match finally with Some f -> List.concat_map names f | None -> [])
    | Block b -> List.concat_map names b
    | Export (Export_decl st) -> names st
    (* a function declared in a block is the function's too (below) *)
    | Function_decl { name = Some f; _ } -> [ f ]
    | _ -> []
  in
  (* a function declared in a block -- a try's, an if's -- is also a
   * var of the function the block is in, given the function when the
   * block is entered (ECMAScript's Annex B.3.3, "web legacy
   * compatibility": what browsers did before blocks had scopes, kept
   * for the pages that count on it -- a bundle whose parts are each
   * in a try, one calling the other's function: Gmail's). Not one
   * declared at the top, which is declared there whole *)
  List.concat_map (fun (st : A.stmt) -> match st.stmt with Function_decl _ -> [] | _ -> names st) body

let hoist (s : scope) (body : A.stmt list) : unit =
  List.iter (fun x -> if Js_scope.own s x = None then Js_scope.declare s x ~constant:false Undefined) (hoisted body)

(* a call's frame, the simple way: a scope under the function's, and
 * in it arguments, the var's hoisted, then the parameters *)
let simple ~(params : params) (c : closure) (fn : value) (this : value) (args : value list) ~(strict : bool) : scope =
  let frame = if strict then Js_scope.strict c.scope else Js_scope.nested c.scope in
  if not c.func.arrow then Js_scope.declare frame "arguments" ~constant:false (Object (new_array args));
  (* a function expression's own name, in its body (var f =
   * function again(n) { ... again(n - 1) }) *)
  (match c.func.name with Some n when c.func.own_name -> Js_scope.declare frame n ~constant:false fn | _ -> ());
  hoist frame c.func.body;
  params frame this c.func.params c.func.rest args;
  frame

(* opti: what every call of a function declares, found once in its
 * text: arguments, the var's (each once), the parameters when they
 * are plain names; and each parameter's slot *)
let layout_with ~(arguments : bool) (f : A.func) : A.frame =
  let plain = List.for_all (fun (pt, default) -> match ((pt : A.pattern), default) with Bind _, None -> true | _ -> false) f.params in
  let slots = Hashtbl.create 16 and names = ref [] in
  let slot (x : string) : int =
    match Hashtbl.find_opt slots x with
    | Some i -> i
    | None ->
        let i = Hashtbl.length slots in
        Hashtbl.replace slots x i;
        names := x :: !names;
        i
  in
  if not f.arrow then ignore (slot "arguments");
  (* its own name, before the var's and the parameters: one of them of
   * that name is the one meant *)
  let own = match f.name with Some n when f.own_name -> slot n | _ -> -1 in
  List.iter (fun x -> ignore (slot x)) (hoisted f.body);
  let params = if plain then List.map (fun ((pt : A.pattern), _) -> match pt with Bind x -> slot x | _ -> -1) f.params else [] in
  let names = Array.of_list (List.rev !names) in
  { names; index = (if Array.length names > 16 then Some slots else None); slots = Array.of_list params; plain; own; arguments; code = A.No_code }

let layout (f : A.func) : A.frame = layout_with ~arguments:true f

(* opti: a call's frame made at once from the function's layout, an
 * array of bindings beside the function's array of names (shared by
 * its every call), the parameters set by their slots -- where [simple]
 * declares each name in a table, one after the other. 1M calls of a
 * function of two arguments: 3,700 ms to 670, with Js_scope's places *)
let opti ~(params : params) (l : A.frame) (c : closure) (fn : value) (this : value) (args : value list) ~(strict : bool) : scope =
  let f = c.func in
  (* a binding a name; the small frames written out, which most are:
   * Array.make is a call to the runtime (3% of a program's time) *)
  let fresh () : binding = { value = Undefined; constant = false } in
  let cells =
    match Array.length l.names with
    | 0 -> [||]
    | 1 -> [| fresh () |]
    | 2 -> [| fresh (); fresh () |]
    | 3 -> [| fresh (); fresh (); fresh () |]
    | 4 -> [| fresh (); fresh (); fresh (); fresh () |]
    | n ->
        let cells = Array.make n Js_scope.nothing in
        for i = 0 to n - 1 do
          cells.(i) <- fresh ()
        done;
        cells
  in
  let frame = Js_scope.frame c.scope ~names:l.names ~index:l.index ~cells ~strict in
  (* the array of what was given: only for a function that says arguments *)
  if l.arguments && not f.arrow then cells.(0).value <- Object (new_array args);
  if l.own >= 0 then cells.(l.own).value <- fn;
  if l.plain then (
    (* each by its slot; those the call did not give, undefined *)
    let rec set (i : int) (args : value list) : value list =
      if i >= Array.length l.slots then args
      else
        match args with
        | v :: left -> cells.(l.slots.(i)).value <- v; set (i + 1) left
        | [] -> cells.(l.slots.(i)).value <- Undefined; set (i + 1) []
    in
    params frame this [] f.rest (set 0 args))
  else params frame this f.params f.rest args;
  frame

let make ~(params : params) (c : closure) (fn : value) (this : value) (args : value list) ~(strict : bool) : scope =
  match c.func.frame with
  | Some l when Js_scope.slotted c.scope -> opti ~params l c fn this args ~strict
  | _ -> simple ~params c fn this args ~strict
