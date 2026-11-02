(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See C_front.mli *)

let owner : (string, string) Hashtbl.t = Hashtbl.create 101
let histories : (string, (string option * int) list) Hashtbl.t = Hashtbl.create 17

(* mini-cc's CLI.compile, on arm64, the listing and the object left out:
 * init sets the front end's hooks, codgen is given each function *)
let read (caps : < Cap.open_in; .. >) (defs, incs) ~(init : unit -> unit)
    ~(codgen : Tree.sym -> Tree.stmt -> unit) (file : Fpath.t) :
    (unit, string) result =
  let f = Fpath.to_string file in
  Tree_helpers.mach := Some Machines.arm64;
  Tree_helpers.init_types ();
  Pre.profile := true;
  Lexer.init ();
  let s = Tree_helpers.lookup ".string" in
  let t = Tree_helpers.typ Tree.Tarray (Some (Tree_helpers.ty Tree.Tchar)) in
  t.width <- 0;
  s.sclass <- Tree.Cstatic;
  s.typ <- Some t;
  List.iter Pre.dodefine defs;
  Pre.includes := Fpath.parent file :: incs;
  Pre.read_file := FS.read_opt caps;
  init ();
  Declare.on_function := codgen;
  match FS.read_opt caps file with
  | None -> Error (Printf.sprintf "cannot open %s" f)
  | Some text -> (
      Tree_helpers.lineno := 1;
      Pre.history := [];
      Pre.push_file f text;
      match Parser.prog Lexer.token (Lexer.lexbuf ()) with
      | () -> Hashtbl.replace histories f (List.rev !Pre.history); Ok ()
      | exception Tree_helpers.Error m -> Error (Printf.sprintf "%s:%s" f m)
      | exception Parsing.Parse_error -> Error (Printf.sprintf "%s:%d: syntax error" f !Tree_helpers.lineno))

(* no code: the pointer facts (was mini-cc -facts's back end) *)
let file (caps : < Cap.open_in; .. >) (defs, incs) (file : Fpath.t) :
    (unit, string) result =
  let f = Fpath.to_string file in
  let init () =
    Check.xcom := (fun (n : Tree.expr) -> n);
    Check.outstring := (fun (_ : string) (_ : int) -> 0);
    Declare.gextern :=
      (fun (s : Tree.sym) (x : Tree.expr) (o : int) (_ : int) -> Facts.global s x o);
    Emit.init () in
  let codgen (fn : Tree.sym) body =
    Hashtbl.replace owner fn.name f;
    Facts.func fn body in
  read caps (defs, incs) ~init ~codgen file
