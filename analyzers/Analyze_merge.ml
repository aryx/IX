(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze_merge.mli *)

module D = Datalog
module C = Ix_analyze_c

(* a fact as a line, for -facts *)
let line (relation : string) (args : C.Facts.arg list) : string =
  let show (a : C.Facts.arg) : string =
    match a with
    | Sym s -> "'" ^ String.concat "\\'" (String.split_on_char '\'' s) ^ "'"
    | Num n -> string_of_int n in
  relation ^ "(" ^ String.concat ", " (List.map show args) ^ ")."

(* the analysis's flag, the runs given it *)
let flag (a : Analyze_flags.analysis) : string =
  match a with
  | Dead -> "-dead"
  | Caps -> "-caps"
  | Exn -> "-exn"
  | Bugs -> "-bugs"
  | Calls -> ""

(*****************************************************************************)
(* A run's summary *)
(*****************************************************************************)

(* (the project's root: the first directory above with a dune-project) *)
let rec root (caps : < Cap.open_in; .. >) (d : string) : string option =
  if FS.read_opt caps (Fpath.v (Filename.concat d "dune-project")) <> None
  then Some d
  else if Filename.dirname d = d then None
  else root caps (Filename.dirname d)

let summary (caps : < Cap.open_in; Cap.open_out; Cap.readdir; .. >)
    (out : string) (prog : string) (given_files : string list)
    (reports : (string * int * string * string * Dead_report.kept) list)
    (said : string list) : unit =
  let b = Buffer.create 4096 in
  let add (r : string) (args : C.Facts.arg list) : unit =
    Buffer.add_string b (line r args ^ "\n") in
  let sym (s : string) : C.Facts.arg = C.Facts.Sym s in
  let read =
    Hashtbl.fold (fun _ (f : string) acc -> if f = "" then acc else f :: acc)
      Ml_front.files [] in
  let own =
    Hashtbl.fold (fun (u : string) () acc ->
        match Hashtbl.find_opt Ml_front.files u with
        | Some f when f <> "" -> f :: acc
        | _ -> acc)
      Ml_front.own [] in
  let c = List.filter (fun f -> Filename.check_suffix f ".c") given_files in
  let has = List.sort_uniq compare (c @ read)
  and own = List.sort_uniq compare (c @ own) in
  List.iter (fun (f : string) -> add "has" [ sym prog; sym f ]) has;
  List.iter (fun (f : string) -> add "own" [ sym prog; sym f ]) own;
  List.iter (fun (f : string) ->
      match Hashtbl.find_opt Ml_front.interfaces f with
      | Some i -> add "implements" [ sym f; sym i ]
      | None -> ())
    has;
  let cwd = FS.getcwd caps () in
  let absolute (f : string) : string =
    FS.cleanname (if Filename.is_relative f then Filename.concat cwd f else f) in
  (match given_files with
   | first :: _ -> (
       match root caps (Filename.dirname (absolute first)) with
       | Some r ->
           let inside (f : string) : bool =
             String.starts_with ~prefix:(r ^ "/") (absolute f) in
           List.iter (fun f -> if not (inside f) then add "outside" [ sym f ]) has
       | None -> ())
   | [] -> ());
  List.iter
    (fun ((f, l, w, m, kept) : string * int * string * string * Dead_report.kept) ->
      let r =
        match kept with
        | Dead_report.Every_program -> "report"
        | Dead_report.One_program -> "report_one" in
      add r [ sym prog; sym f; C.Facts.Num l; sym w; sym m ])
    reports;
  (* (another analysis's lines, a unit not read: said_all.dl's) *)
  List.iter (fun (l : string) -> add "said" [ sym prog; sym l ]) said;
  List.iter (fun (m : string) -> add "unread" [ sym prog; sym m ]) !Ml_front.unread;
  FS.write caps (Fpath.v out) (Buffer.contents b)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let directory (caps : < Cap.readdir; .. >) (p : string) : bool =
  try CapSys.is_directory caps p with Sys_error _ -> false

let wrapped (words : string list) : string list =
  let line = Buffer.create 80 and lines = ref [] in
  List.iter (fun (w : string) ->
      if Buffer.length line > 0 && Buffer.length line + String.length w > 72
      then begin
        lines := Buffer.contents line :: !lines;
        Buffer.clear line
      end;
      Buffer.add_string line (" " ^ w))
    words;
  List.rev (Buffer.contents line :: !lines)

(*****************************************************************************)
(* The runs, merged *)
(*****************************************************************************)

(* a run: its program's name, its main, its process *)
type run = { name : string; main : string; pid : int }

(* (a run's files, by its name without a /: w/name.out, w/name.dl) *)
let file_of (w : string) (name : string) (ext : string) : string =
  Filename.concat w (String.map (fun c -> if c = '/' then '_' else c) name ^ ext)

(* each main run, at once, by mini-analyze itself: the flags given but
 * -sources (each run's its own), then its extra flags and -summary; its
 * name given, or its main's, made unique *)
let start (caps : < Analyze_flags.caps; .. >) (f : Analyze_flags.t)
    (w : string) (mains : (string * string * string list) list) : run list =
  let rec without_sources (l : string list) : string list =
    match l with
    | "-sources" :: _ :: rest -> without_sources rest
    | a :: rest -> a :: without_sources rest
    | [] -> [] in
  let flags = without_sources f.args in
  let names = Hashtbl.create 16 in
  List.map
    (fun ((given, main, extra) : string * string * string list) ->
      let base =
        if given <> "" then given
        else Filename.remove_extension (Filename.basename main) in
      let n = (match Hashtbl.find_opt names base with Some n -> n | None -> 0) + 1 in
      Hashtbl.replace names base n;
      let name = if n = 1 then base else Printf.sprintf "%s%d" base n in
      let out = FS.open_out_fd caps (file_of w name ".out") 0o644 in
      let args =
        flags @ extra @ [ "-summary"; file_of w name ".dl"; "-program"; name; main ] in
      let pid =
        Procs.create_process caps Sys.executable_name args ~stdin:Unix.stdin ~stdout:out in
      Unix.close out;
      { name; main; pid })
    mains

(* the runs' summaries merged by the analysis's rules: the lines (of file
 * alone when given), and the units not read *)
let merge (caps : < Cap.open_in; .. >) (f : Analyze_flags.t) (file : string option)
    (w : string) (runs : run list) : string list * string list list =
  let p = D.create () in
  let dead = f.analysis = Dead in
  let all = Filename.concat f.rules (if dead then "dead_all.dl" else "said_all.dl") in
  D.load p ~from:all (FS.read caps (Fpath.v all));
  List.iter (fun (r : run) ->
      let s = file_of w r.name ".dl" in
      match FS.read_opt caps (Fpath.v s) with
      | Some text -> D.load p ~from:s text
      | None -> ())
    runs;
  ignore (Datalog_eval.run ~naive:false p);
  let tuples (r : string) (n : int) : string list list =
    List.map (fun (t : int array) -> List.map (C_report.name p) (Array.to_list t))
      (D.tuples (D.relation p r n)) in
  let mine (x : string) : bool =
    match file with Some y -> FS.cleanname x = y | None -> true in
  let lines =
    match f.analysis with
    | Dead ->
        List.filter_map
          (function
            | [ x; "0"; m ] when mine x -> Some (Printf.sprintf "%s: %s" x m)
            | [ x; l; m ] when mine x -> Some (Printf.sprintf "%s:%s: %s" x l m)
            | _ -> None)
          (tuples "dead_all" 3)
    | Exn ->
        List.map (function [ p; l ] -> p ^ ": " ^ l | _ -> "") (tuples "said_by" 2)
    | _ -> List.map (function [ l ] -> l | _ -> "") (tuples "said_any" 1) in
  (List.sort_uniq compare lines, if dead then [] else tuples "not_read" 2)

let merged_runs (caps : < Analyze_flags.caps; .. >) (f : Analyze_flags.t)
    (file : string option) (mains : (string * string * string list) list) : int =
  let file = Option.map FS.cleanname file in
  let w =
    Filename.concat (Filename.get_temp_dir_name ())
      (Printf.sprintf "mini-analyze-%d" (Unix.getpid ())) in
  FS.mkdir caps w 0o755;
  let runs = start caps f w mains in
  let failed =
    List.filter (fun (r : run) -> Procs.waitpid caps r.pid <> Unix.WEXITED 0) runs in
  List.iter (fun (r : run) ->
      Console.eprint caps
        (Printf.sprintf "mini-analyze: %s failed (its report: %s)\n" r.main
           (file_of w r.name ".out")))
    failed;
  let lines, unread = merge caps f file w runs in
  List.iter (fun (l : string) -> Console.print caps (l ^ "\n")) lines;
  List.iter (function
      | [ p; m ] -> Console.eprint caps (Printf.sprintf "%s: not read: %s\n" p m)
      | _ -> ())
    unread;
  Console.print caps
    (Printf.sprintf "%d reports, over the %d programs%s:\n%s\n"
       (List.length lines) (List.length runs)
       (if file = None then "" else " that reach it")
       (String.concat "\n" (wrapped (List.map (fun (r : run) -> r.name) runs))));
  if failed <> [] || unread <> [] then 1
  else begin
    List.iter (fun (r : run) ->
        List.iter (fun x -> FS.remove_any caps (file_of w r.name x)) [ ".out"; ".dl" ])
      runs;
    FS.remove_any caps w;
    0
  end
