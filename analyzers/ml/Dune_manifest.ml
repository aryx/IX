(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dune_manifest.mli *)

module M = Tiny_manifest

(*****************************************************************************)
(* dune's s-expressions *)
(*****************************************************************************)

type sexp = Atom of string | List of sexp list

(* an atom, or a quoted string with OCaml's escapes, or a list *)
let parse (s : string) : sexp list =
  let n = String.length s in
  let i = ref 0 in
  let blank c = c = ' ' || c = '\n' || c = '\t' || c = '\r' in
  let rec skip () = if !i < n && blank s.[!i] then (incr i; skip ()) in
  let rec one () : sexp =
    skip ();
    if !i >= n then failwith "an s-expression ends early";
    match s.[!i] with
    | '(' ->
        incr i;
        let rec items acc =
          skip ();
          if !i >= n then failwith "a list not closed"
          else if s.[!i] = ')' then (incr i; List (List.rev acc))
          else items (one () :: acc) in
        items []
    | '"' ->
        incr i;
        let b = Buffer.create 16 in
        while !i < n && s.[!i] <> '"' do
          if s.[!i] = '\\' && !i + 1 < n then begin
            incr i;
            Buffer.add_char b (match s.[!i] with 'n' -> '\n' | 't' -> '\t' | c -> c)
          end
          else Buffer.add_char b s.[!i];
          incr i
        done;
        incr i;
        Atom (Buffer.contents b)
    | _ ->
        let start = !i in
        while !i < n && not (blank s.[!i]) && s.[!i] <> '(' && s.[!i] <> ')' do
          incr i
        done;
        Atom (String.sub s start (!i - start)) in
  let rec all acc = skip (); if !i >= n then List.rev acc else all (one () :: acc) in
  all []

(* a table's list, [] when it has none *)
let found (o : 'a list option) : 'a list = match o with Some l -> l | None -> []

(* (k v...) among a list's items: the vs *)
let field (k : string) (x : sexp) : sexp list =
  match x with
  | List items ->
      found
        (List.find_map
           (function List (Atom a :: v) when a = k -> Some v | _ -> None)
           items)
  | Atom _ -> []

let atoms (l : sexp list) : string list =
  let atom = function Atom a -> Some a | List _ -> None in
  List.concat_map
    (function Atom a -> [ a ] | List l -> List.filter_map atom l) l

let prefix (p : string) (s : string) : bool =
  String.length s >= String.length p && String.sub s 0 (String.length p) = p

(* (a path of describe's and rules', from the project, which describe
 * says: its root and its build's context, _build/default or dune
 * --build-dir's) *)
type where = { root : string; context : string }

let rel (w : where) (p : string) : string =
  let c = w.context ^ "/" in
  let n = String.length c in
  if prefix c p then String.sub p n (String.length p - n) else p

(*****************************************************************************)
(* describe: the modules' sources *)
(*****************************************************************************)

(* a module's name and its .ml, if it has one (a virtual module none) *)
let modules (fields : sexp) : (string * string) list =
  match field "modules" fields with
  | [ List ms ] ->
      List.filter_map (fun (m : sexp) ->
          match field "name" m, atoms (field "impl" m) with
          | [ Atom name ], [ impl ] when Filename.check_suffix impl ".ml" ->
              Some (name, impl)
          | _ -> None)
        ms
  | _ -> []

type described = {
  libraries : (string, (string * string) list) Hashtbl.t;  (* by name *)
  stanzas : (string, (string * string) list) Hashtbl.t;  (* by .eobjs dir *)
}

let describe (entries : sexp list) : where * described =
  let d = { libraries = Hashtbl.create 64; stanzas = Hashtbl.create 64 } in
  let entries = match entries with [ List l ] -> l | l -> l in
  let one (k : string) : string =
    let value = function List [ Atom a; Atom v ] when a = k -> Some v | _ -> None in
    match List.find_map value entries with
    | Some v -> v
    | None -> failwith ("dune describe workspace: no " ^ k) in
  let w = { root = one "root"; context = one "build_context" } in
  let rel = rel w in
  List.iter (fun (e : sexp) ->
      match e with
      | List [ Atom "library"; fields ] -> (
          match field "name" fields with
          | [ Atom name ] -> Hashtbl.replace d.libraries name (modules fields)
          | _ -> ())
      | List [ Atom "executables"; fields ] ->
          (* (its .eobjs directory: include_dirs' .../.X.eobjs/byte) *)
          List.iter (fun (inc : string) ->
              Hashtbl.replace d.stanzas (Filename.dirname (rel inc))
                (modules fields))
            (atoms (field "include_dirs" fields))
      | _ -> ())
    entries;
  (w, d)

(*****************************************************************************)
(* rules: each executable's link *)
(*****************************************************************************)

(* (run prog args...) anywhere in an action *)
let rec run_args (x : sexp) : string list option =
  match x with
  | List (Atom "run" :: _ :: args) -> Some (atoms args)
  | List l -> List.find_map run_args l
  | Atom _ -> None

(* each executable's path and its link's .cmxa and .cmx, in order *)
let links (rules : sexp list) : (string * string list) list =
  List.filter_map (fun (r : sexp) ->
      let exes =
        List.filter (fun f -> Filename.check_suffix f ".exe")
          (atoms (List.concat_map (field "files") (field "targets" r))) in
      match exes, Option.bind (List.nth_opt (field "action" r) 0) run_args with
      | [ exe ], Some args ->
          let linked a =
            Filename.check_suffix a ".cmxa" || Filename.check_suffix a ".cmx" in
          Some (exe, List.filter linked args)
      | _ -> None)
    rules

(*****************************************************************************)
(* The manifests *)
(*****************************************************************************)

(* the project's file, else the one its build made (a lexer, lib_core's
 * Parallel chosen by OCaml's version): _build's, which dune build makes,
 * else the build context's of describe (dune --build-dir's, not built) *)
let source (caps : < Cap.open_in; .. >) (w : where) (p : string) : string =
  let r = rel w p in
  let read (x : string) = FS.read_opt caps (Fpath.v (Filename.concat w.root x)) in
  let built = Filename.concat "_build/default" r in
  (* (a copy dune made, copy_files#'s: its first line says the file it
   * copied, tiny/user/sdl/emacs.ml's tiny/user/emacs.ml) *)
  let original (x : string) : string =
    match read x with
    | Some text when prefix "# 1 \"" text -> (
        match String.index_from_opt text 5 '"' with
        | Some j ->
            let o = String.sub text 5 (j - 5) in
            if Filename.check_suffix o ".ml" && read o <> None then o else x
        | None -> x)
    | _ -> x in
  if read r <> None then r
  else if read built <> None then original built
  else Filename.concat w.context r

let manifest (caps : < Cap.open_in; .. >) (w : where) (d : described)
    ((exe, args) : string * string list) : M.manifest =
  let unit_ (arg : string) : M.linked list =
    if not (Filename.is_relative arg) then [] (* opam's *)
    else if Filename.check_suffix arg ".cmxa" then
      let name = Filename.chop_suffix (Filename.basename arg) ".cmxa" in
      List.map (fun (m, ml) ->
          { M.l_object = m ^ ".cmx"; l_source = Some (source caps w ml);
            l_taken = M.Archive_member arg })
        (found (Hashtbl.find_opt d.libraries name))
    else
      let base = Filename.chop_suffix (Filename.basename arg) ".cmx" in
      let m =
        String.capitalize_ascii
          (if prefix "dune__exe__" base then
             String.sub base 11 (String.length base - 11)
           else base) in
      let eobjs = Filename.dirname (Filename.dirname arg) in
      let modules = found (Hashtbl.find_opt d.stanzas eobjs) in
      if base = "dune__exe" then []
      else
        [ { M.l_object = arg;
            l_source = Option.map (source caps w) (List.assoc_opt m modules);
            l_taken = M.Command_line } ] in
  let exe = rel w exe in
  { M.m_program = Filename.chop_suffix (Filename.basename exe) ".exe";
    m_units = List.concat_map unit_ args }

(* each executable's manifest, by its path from the project's root;
 * the root *)
let of_dune (caps : < Cap.open_in; .. >) (describe_text : string)
    (rules_text : string) : string * (string * M.manifest) list =
  let w, d = describe (parse describe_text) in
  ( w.root,
    List.map (fun ((exe, _) as link) -> (rel w exe, manifest caps w d link))
      (links (parse rules_text)) )

(* (dune's build directory for these queries: one per project, kept, so
 * that the next run is quick, 0.5 s, not 2.5 s; not _build, which
 * another dune may hold, as a watch) *)
let build_dir (caps : < Cap.readdir; .. >) : string =
  Filename.concat (Filename.get_temp_dir_name ())
    ("mini-analyze-dune-" ^ String.sub (Digest.to_hex (Digest.string (FS.getcwd caps ()))) 0 8)

(* (_build/default/tiny/X.exe, as dune names its target: ./tiny/X.exe) *)
let target (exe : string) : string =
  let marker = "_build/default/" in
  let rec find i =
    if i + String.length marker > String.length exe then None
    else if String.sub exe i (String.length marker) = marker then Some i
    else find (i + 1) in
  match find 0 with
  | Some i ->
      let j = i + String.length marker in
      "./" ^ String.sub exe j (String.length exe - j)
  | None -> if Filename.is_relative exe && not (prefix "./" exe) then "./" ^ exe else exe

(* dune's answer, its standard output, in its build directory (above) *)
(* (another dune holds the build directory: dune does not wait for it) *)
exception Locked

let contains (s : string) (sub : string) : bool =
  let n = String.length sub in
  let rec at i = i + n <= String.length s && (String.sub s i n = sub || at (i + 1)) in
  at 0

let ask (caps : < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. >)
    (args : string list) : string =
  let tmp = Filename.temp_file "mini-analyze" ".sexp" in
  let err = Filename.temp_file "mini-analyze" ".err" in
  let out = FS.open_out_fd caps tmp 0o644 and errs = FS.open_out_fd caps err 0o644 in
  (* (describe targets answers on its standard error, the others on
   * their standard output) *)
  let pid =
    Procs.create_process_stderr caps "dune" args ~stdin:Unix.stdin ~stdout:out
      ~stderr:(if List.mem "targets" args then out else errs) in
  Unix.close out;
  Unix.close errs;
  let ok = Procs.waitpid caps pid = Unix.WEXITED 0 in
  let text = FS.read caps (Fpath.v tmp) and why = FS.read caps (Fpath.v err) in
  FS.remove_any caps tmp;
  FS.remove_any caps err;
  if not ok then begin
    if contains (why ^ text) "locked the build directory" then raise Locked;
    failwith ("dune " ^ String.concat " " args ^ ": failed\n" ^ why)
  end;
  text

(* f given the project's kept build directory, or, another dune holding
 * it (make test's analyses at once), one of this run's, cleaned after *)
let with_build (caps : < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. >)
    (f : string -> 'a) : 'a =
  match f (build_dir caps) with
  | x -> x
  | exception Locked ->
      let b =
        Filename.concat (Filename.get_temp_dir_name ())
          (Printf.sprintf "mini-analyze-dune-%d" (Unix.getpid ())) in
      let clean () = try ignore (ask caps [ "clean"; "--build-dir"; b ]) with _ -> () in
      (match f b with
       | x -> clean (); x
       | exception e -> clean (); raise e)

let run (caps : < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. >)
    (exes : string list) : string * (string * M.manifest) list =
  let root, ms =
    with_build caps (fun (b : string) ->
        let described = ask caps [ "describe"; "workspace"; "--build-dir"; b ] in
        let ruled = ask caps ([ "rules"; "--build-dir"; b ] @ List.map target exes) in
        of_dune caps described ruled) in
  (* (relative when here is the root, as the reports name the files) *)
  ((if root = FS.getcwd caps () then "." else root), ms)

let write (caps : < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. >)
    (exes : string list) : string * (string * string) list * (unit -> unit) =
  let root, ms = run caps exes in
  let d =
    Filename.concat (Filename.get_temp_dir_name ())
      (Printf.sprintf "mini-analyze-manifests-%d" (Unix.getpid ())) in
  if not (CapSys.file_exists caps d) then FS.mkdir caps d 0o755;
  let files =
    List.map (fun ((exe, m) : string * M.manifest) ->
        let f =
          Filename.concat d
            (String.map (fun c -> if c = '/' then '_' else c) exe ^ ".manifest") in
        FS.write caps (Fpath.v f) (M.to_string m);
        (exe, f))
      ms in
  let gone () =
    List.iter (fun ((_, f) : string * string) -> FS.remove_any caps f) files;
    FS.remove_any caps d in
  (root, files, gone)

(* (a tests' directory: tests/, KFS_tests/; their programs are not the
 * project's, as Caller_finder leaves them out) *)
let tests (d : string) : bool =
  List.exists (fun (p : string) -> p = "tests" || String.ends_with ~suffix:"_tests" p)
    (String.split_on_char '/' d)

let executables (caps : < Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; .. >)
    (dirs : string list) : string list =
  with_build caps (fun (b : string) ->
  let answer = parse (ask caps ([ "describe"; "workspace"; "--build-dir"; b ] @ dirs)) in
  let w, _ = describe answer in
  let entries = match answer with [ List l ] -> l | l -> l in
  (* (each stanza's directory, from its .eobjs, and its names) *)
  let stanzas =
    List.concat_map (fun (e : sexp) ->
        match e with
        | List [ Atom "executables"; fields ] -> (
            match atoms (field "include_dirs" fields) with
            | inc :: _ ->
                let d = Filename.dirname (Filename.dirname (rel w inc)) in
                if tests d then []
                else List.map (fun (n : string) -> (d, n)) (atoms (field "names" fields))
            | [] -> [])
        | _ -> [])
      entries in
  let ds = List.sort_uniq compare (List.map fst stanzas) in
  (* (an executable, not a js one, tiny-machine-web's: dune describe
   * targets, its directories' targets as ls says them) *)
  let built = Hashtbl.create 64 in
  let here = ref "" in
  if ds <> [] then
    String.split_on_char '\n' (ask caps ([ "describe"; "targets"; "--build-dir"; b ] @ ds))
    |> List.iter (fun (l : string) ->
           if String.ends_with ~suffix:":" l then here := String.sub l 0 (String.length l - 1)
           else if l <> "" then Hashtbl.replace built (Filename.concat !here l) ());
  List.filter_map (fun ((d, n) : string * string) ->
      let exe = Filename.concat d (n ^ ".exe") in
      if Hashtbl.mem built exe then Some exe else None)
    stanzas)

