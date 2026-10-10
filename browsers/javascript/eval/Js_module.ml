(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_module.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_module.mli *)

open Js_value
module A = Js_ast

type state = Fresh | Running | Done | Failed of value

type modul = {
  url : string;
  scope : scope;
  program : A.program;
  mutable state : state;
  (* each name it gives out, and where its value is now *)
  mutable exports : (string * (unit -> binding option)) list;
  mutable stars : string list; (* export * from: the modules whose names are its own too *)
  mutable namespace : value option; (* its names as an object, made once *)
  (* what was bound to its names while it was running (a circle), to
   * bind again once it has run *)
  mutable late : (unit -> unit) list;
}

type t = {
  engine : Js_eval.t;
  resolve : base:string -> string -> string;
  source : string -> string option;
  modules : (string, modul) Hashtbl.t;
  (* a module asked for while the page runs (import()): the host
   * fetches it and what it imports, then says so, or why it could not *)
  mutable dynamic : (string -> (unit -> unit) -> (string -> unit) -> unit) option;
  mutable failing : string option; (* the module whose body threw last, the innermost: where to look *)
}

(*****************************************************************************)
(* What a module's text says, before it runs *)
(*****************************************************************************)

(* the modules a program names: its imports, its exports from *)
let named (program : A.program) : string list =
  List.filter_map
    (fun (st : A.stmt) ->
      match st.stmt with
      | Import (_, m) | Export (Export_names (_, Some m) | Export_all (_, m)) -> Some m
      | _ -> None)
    program

(* opti: a module's text is read once -- it is asked what it imports
 * when it comes, then again by each module that names it, then to be
 * run: three and more parses of the megabytes of a bundle (a tenth of
 * Discourse's start). The last texts read, by the text itself (==) *)
let read : (string * (A.program, Js_parse.error) result) list ref = ref []

(* the memo is also filled from a worker of the pool ([ahead]) *)
let lock = Mutex.create ()
let locked (f : unit -> 'a) : 'a = Mutex.lock lock; Fun.protect ~finally:(fun () -> Mutex.unlock lock) f
let known (text : string) = locked (fun () -> List.find_opt (fun (t, _) -> t == text) !read)
let keep (text : string) r = locked (fun () -> read := (text, r) :: List.filteri (fun i _ -> i < 255) !read)

let parse (text : string) : (A.program, Js_parse.error) result =
  match known text with
  | Some (_, r) when !Mini_opti.enabled -> r
  | _ ->
      let r = Js_parse.parse text in
      keep text r;
      r

(* opti: a text read ahead, where it was fetched (a worker of the
 * pool), for the [parse] of that very text that follows to find it
 * read: GitHub's 119 modules, 4.9 MB, are 1.3 s of the window's
 * thread otherwise *)
let ahead (text : string) : unit = if !Mini_opti.enabled && known text = None then keep text (Js_parse.parse_with ~aside:true text)

(* and a script that is not a module finds its text read the same way *)
let () = Js_eval.read_ahead := fun text -> if !Mini_opti.enabled then Option.map snd (known text) else None

let specifiers (text : string) : string list = match parse text with Ok program -> named program | Error _ -> []

(* the names a declaration declares *)
let declared (st : A.stmt) : string list =
  match st.stmt with
  | Let (_, decls) -> List.concat_map (fun (pt, _) -> Js_eval.names_of pt) decls
  | Function_decl f -> Option.to_list f.name
  | Class_decl c -> Option.to_list c.class_name
  | _ -> []

(*****************************************************************************)
(* The modules *)
(*****************************************************************************)

let rec find (t : t) (url : string) : modul =
  match Hashtbl.find_opt t.modules url with
  | Some m -> m
  | None ->
      let text = match t.source url with Some text -> text | None -> throw "TypeError" ("Failed to fetch the module " ^ url) in
      (* read for the last time: the tree is the module's from here, not the memo's *)
      let parsed = parse text in
      locked (fun () -> read := List.filter (fun (t, _) -> t != text) !read);
      let program = match parsed with Ok p -> p | Error e -> throw "SyntaxError" (Printf.sprintf "%s (%s, line %d)" e.message url e.line) in
      let scope = Js_eval.module_scope t.engine ~url in
      let m = { url; scope; program; state = Fresh; exports = []; stars = []; namespace = None; late = [] } in
      Hashtbl.replace t.modules url m;
      let local x () = Js_scope.own scope x in
      List.iter
        (fun (st : A.stmt) ->
          match st.stmt with
          | Export (Export_decl d) -> m.exports <- m.exports @ List.map (fun x -> (x, local x)) (declared d)
          | Export (Export_default _ | Export_default_decl _) -> m.exports <- m.exports @ [ ("default", local "*default*") ]
          | Export (Export_names (names, None)) -> m.exports <- m.exports @ List.map (fun (here, out) -> (out, local here)) names
          | Export (Export_names (names, Some from)) ->
              let dep = t.resolve ~base:url from in
              m.exports <- m.exports @ List.map (fun (there, out) -> (out, fun () -> export t (find t dep) there)) names
          | Export (Export_all (Some ns, from)) ->
              let dep = t.resolve ~base:url from in
              m.exports <- m.exports @ [ (ns, fun () -> Some { value = namespace t (find t dep); constant = true }) ]
          | Export (Export_all (None, from)) -> m.stars <- m.stars @ [ t.resolve ~base:url from ]
          | _ -> ())
        program;
      m

(* where the value of a name a module gives out is: its own, or one of
 * those it passes on whole (never their default) *)
and export (t : t) (m : modul) (name : string) : binding option = export_seen [] t m name

and export_seen (seen : modul list) (t : t) (m : modul) (name : string) : binding option =
  match List.assoc_opt name m.exports with
  | Some where -> where ()
  | None when name = "default" || List.memq m seen -> None
  | None -> List.find_map (fun dep -> export_seen (m :: seen) t (find t dep) name) m.stars

and names (t : t) (m : modul) : string list = names_seen [] t m

and names_seen (seen : modul list) (t : t) (m : modul) : string list =
  if List.memq m seen then []
  else
    List.sort_uniq compare
      (List.map fst m.exports @ List.concat_map (fun dep -> List.filter (( <> ) "default") (names_seen (m :: seen) t (find t dep))) m.stars)

(* a module's names as an object: each read where it is when asked, so
 * that what the module assigns later is seen *)
and namespace (t : t) (m : modul) : value =
  match m.namespace with
  | Some ns -> ns
  | None ->
      let o = new_object () in
      List.iter
        (fun name ->
          let read = host_function name (fun ~this:_ _ -> match export t m name with Some b -> b.value | None -> Undefined) in
          set_own o name (Object { (new_object ()) with kind = Accessor (read, Undefined) }))
        (names t m);
      let ns = Object o in
      m.namespace <- Some ns;
      ns

(* the module run, once: those it names first, then their names bound
 * in its scope, then its body *)
let rec evaluate (t : t) (url : string) : modul =
  let m = find t url in
  match m.state with
  | Done | Running -> m
  | Failed e -> raise (Throw e)
  | Fresh -> (
      m.state <- Running;
      try
        Js_eval.hoist_module m.scope m.program;
        List.iter (fun from -> ignore (evaluate t (t.resolve ~base:url from))) (named m.program);
        List.iter
          (fun (st : A.stmt) ->
            match st.stmt with
            | Import (n, from) ->
                let dep = find t (t.resolve ~base:url from) in
                (* the importer's name is the exporter's very binding:
                 * what the exporter assigns, the importer sees *)
                let rec bind there here =
                  (match export t dep there with
                  | Some b -> Js_scope.share m.scope here b
                  (* a circle of modules, and that one not run yet: its
                   * functions are there, the rest undefined until it has *)
                  | None when dep.state = Running -> Js_scope.declare m.scope here ~constant:true Undefined
                  | None -> throw "SyntaxError" (Printf.sprintf "The requested module '%s' does not provide an export named '%s'" from there));
                  if dep.state = Running then dep.late <- (fun () -> bind there here) :: dep.late
                in
                Option.iter (bind "default") n.default;
                Option.iter (fun ns -> Js_scope.declare m.scope ns ~constant:true (namespace t dep)) n.namespace;
                List.iter (fun (there, here) -> bind there here) n.named
            | _ -> ())
          m.program;
        Js_eval.exec_module t.engine m.scope m.program;
        m.state <- Done;
        let late = m.late in
        m.late <- [];
        List.iter (fun again -> again ()) late;
        m
      with Throw e ->
        if m.state = Running && t.failing = None then t.failing <- Some url;
        m.state <- Failed e;
        raise (Throw e))

(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

let create (engine : Js_eval.t) ~(resolve : base:string -> string -> string) ~(source : string -> string option) : t =
  let t = { engine; resolve; source; modules = Hashtbl.create 16; dynamic = None; failing = None } in
  (* import("m"): a promise of the module's names -- at once if its
   * text is here, when the host has fetched it otherwise *)
  Js_eval.set_importer engine (fun ~base spec ->
      let p, fulfil, reject = Js_eval.promise engine in
      let url = t.resolve ~base spec in
      let settle () = match namespace t (evaluate t url) with ns -> fulfil ns | exception Throw e -> reject e in
      (match (Hashtbl.mem t.modules url, t.dynamic) with
      | false, Some load -> load url settle (fun why -> reject (error "TypeError" why))
      | _ -> settle ());
      p);
  t

let set_dynamic (t : t) (load : string -> (unit -> unit) -> (string -> unit) -> unit) : unit = t.dynamic <- Some load

let import (t : t) (url : string) : value = namespace t (evaluate t url)

let take_failing (t : t) : string option =
  let f = t.failing in
  t.failing <- None;
  f

let run (t : t) (url : string) : (value, Js_eval.error) result = Js_eval.protect t.engine (fun () -> namespace t (evaluate t url))
