(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze_build.mli *)

module F = Analyze_flags

(* (Failure and Sys_error said, 1) *)
let said (caps : < Cap.stderr; .. >) (m : string) : int =
  Console.eprint caps (m ^ "\n");
  1

let project (f : F.t) : string option =
  if f.project = "" then None else Some f.project

(*****************************************************************************)
(* One program *)
(*****************************************************************************)

(* a manifest's program as the files analyzed: its ML units given to the
 * linker, its archives' standard library, every linked unit's file *)
let linked (f : F.t) (what : string) (p : Tiny_manifest.program) : unit =
  Logs.info (fun l ->
      l "%s: %d units, %d the program's own" what (List.length p.units)
        (List.length p.own));
  f.files <- f.files @ p.own;
  Ml_front.own_dirs := !Ml_front.own_dirs @ List.map Fpath.v p.own_dirs;
  (* (a link with no standard library of the project's, an archive's, is
   * on OCaml's, lib_core's for the analyzer: dune's tiny-machine-window;
   * not the nearest to its files, TinyLibCore) *)
  if f.lib = "" then
    f.lib <- (match p.library with Some d -> d | None -> Analyze_one.lib_core f);
  if f.program = "" then f.program <- p.name;
  List.iter (fun (u, file) -> Hashtbl.replace Ml_front.linked u file) p.units;
  (* (-dead on the program alone: its components' dead code, not its
   * libraries', which another program may call; a run of a merge,
   * -summary's, all of it) *)
  if f.analysis = Dead && f.summary = "" then
    List.iter (fun x ->
        Hashtbl.replace Ml_front.components (Analyze_one.unit_of_file x) ())
      p.components

let read (caps : < F.caps; .. >) (f : F.t) : bool =
  match
    List.iter (fun m -> linked f m (Tiny_manifest.program caps m (project f)))
      f.manifests;
    if f.exes <> [] then begin
      let root, ms = Dune_manifest.run caps f.exes in
      let root = match project f with Some d -> d | None -> root in
      List.iter (fun (exe, m) ->
          linked f exe (Tiny_manifest.of_manifest caps m [] root))
        ms
    end
  with
  | () -> false
  | exception (Failure m | Sys_error m) -> ignore (said caps m); true

(*****************************************************************************)
(* Directories *)
(*****************************************************************************)

(* the manifests under a directory, not in a . or _ directory (.git, a
 * build's _build or _make, which only a directory given is) *)
let rec under (caps : < Cap.readdir; .. >) (d : string) : string list =
  Array.to_list (CapSys.readdir caps d)
  |> List.sort compare
  |> List.concat_map (fun (n : string) ->
         let p = Filename.concat d n in
         if n <> "" && (n.[0] = '.' || n.[0] = '_') then []
         else if CapSys.is_directory caps p then under caps p
         else if Filename.check_suffix n ".manifest" then [ p ]
         else [])

let expand_dirs (caps : < F.caps; .. >) (f : F.t) : bool =
  let from (d : string) (p : string) : string =
    let n = String.length (FS.cleanname d) + 1 and p = FS.cleanname p in
    String.sub p n (String.length p - n) in
  match
    let source_dirs =
      List.filter (fun (d : string) ->
          match under caps d with
          | [] -> true
          | ms ->
              List.iter (fun m ->
                  Hashtbl.replace f.names m (Filename.chop_suffix (from d m) ".manifest"))
                ms;
              f.manifests <- f.manifests @ ms;
              false)
        f.dirs in
    if source_dirs <> [] then begin
      let es = Dune_manifest.executables caps source_dirs in
      List.iter (fun e -> Hashtbl.replace f.names e (Filename.chop_suffix e ".exe")) es;
      f.exes <- f.exes @ es
    end
  with
  | () -> false
  | exception (Failure m | Sys_error m) -> ignore (said caps m); true

(*****************************************************************************)
(* Several programs *)
(*****************************************************************************)

(* dune's executables given to runs: their manifests, files (Dune_manifest
 * .write), each run's; and what removes them *)
let dune_runs (caps : < F.caps; .. >) (f : F.t) :
    (string * string * string list) list * (unit -> unit) =
  if f.exes = [] then ([], fun () -> ())
  else
    let root, files, gone = Dune_manifest.write caps f.exes in
    let name (exe : string) : string =
      match Hashtbl.find_opt f.names exe with
      | Some n -> n
      | None -> Filename.chop_suffix exe ".exe" in
    (List.map (fun (exe, file) -> (name exe, file, [ "-project"; root ])) files, gone)

let library (caps : < F.caps; .. >) (f : F.t) : int =
  let file = List.hd f.files in
  let links (given : string option) (m : string) : string option =
    let read = Tiny_manifest.of_string (FS.read caps (Fpath.v m)) in
    Tiny_manifest.linking m read given file in
  match
    let dune, gone = dune_runs caps f in
    let mains =
      List.filter_map (fun (m : string) ->
          Option.map (fun (root : string) -> ("", m, [ "-project"; root ]))
            (links (project f) m))
        f.manifests
      @ List.filter (fun ((_, m, extra) : string * string * string list) ->
          links (Some (List.nth extra 1)) m <> None) dune in
    let st =
      if mains = [] then
        said caps (Printf.sprintf "mini-analyze: no program given links %s" file)
      else Analyze_merge.merged_runs caps f (Some file) mains in
    gone ();
    st
  with
  | st -> st
  | exception (Failure m | Sys_error m) -> said caps m

(* (a program with no ML unit, tiny-cc's: not read) *)
let has_ml (caps : < Cap.open_in; .. >) (m : string) : bool =
  List.exists (fun (l : Tiny_manifest.linked) ->
      match l.l_source with Some (Ppath s) -> Filename.check_suffix s ".ml" | None -> false)
    (Tiny_manifest.of_string (FS.read caps (Fpath.v m))).m_units

let several (caps : < F.caps; .. >) (f : F.t) : int =
  try
    if f.analysis = Calls then failwith "several programs: -dead, -exn, -bugs or -caps";
    let dune, gone = dune_runs caps f in
    let ms, others = List.partition (has_ml caps) f.manifests in
    if others <> [] then
      Console.eprint caps
        (Printf.sprintf "mini-analyze: no ML unit, not read: %s\n"
           (String.concat " " others));
    (* (-project: the shallowest manifest's directory's, a deeper one's
     * below it as the manifest is below that one: tiny/TinyKernel for
     * _make/src/TinyKernel's kernel.img.manifest) *)
    let dirs = List.map (fun m -> FS.cleanname (Filename.dirname m)) ms in
    let top =
      List.fold_left (fun a d -> if String.length d < String.length a then d else a)
        (match dirs with d :: _ -> d | [] -> ".") dirs in
    let project_of (m : string) : string list =
      if f.project = "" then []
      else
        let d = FS.cleanname (Filename.dirname m) in
        let below =
          if d <> top && String.starts_with ~prefix:(top ^ "/") d then
            let n = String.length top + 1 in
            String.sub d n (String.length d - n)
          else "" in
        let dir = if below = "" then f.project else Filename.concat f.project below in
        [ "-project"; dir ] in
    let named (m : string) : string =
      match Hashtbl.find_opt f.names m with Some n -> n | None -> "" in
    let st =
      Analyze_merge.merged_runs caps f None
        (List.map (fun m -> (named m, m, project_of m)) ms @ dune) in
    gone ();
    st
  with Failure m | Sys_error m -> said caps m
