(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze.mli *)

module D = Datalog

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr; Cap.exec; Cap.wait >

let usage = "usage: mini-analyze [-r rules-dir] [-Idir] [-own dir] [-Dname=value] [-L lib] [-facts | -flow | -flow-answers] [-dead | -caps | -exn | -bugs] [-root f]... [-sources dir] file.c|file.ml|file.manifest|file.exe...   (-h: how)"

let help = {|usage: mini-analyze [-r rules-dir] [-Idir] [-own dir] [-Dname=value] [-L lib] [-facts | -flow | -flow-answers] [-dead | -caps | -exn | -bugs] [-root f]... [-sources dir] file.c|file.ml|file.manifest|file.exe...
The C files read as one program, each call through a pointer said with the
functions it may reach, by an analysis of where each pointer may point
(points_to/'s: Andersen's first pass, then a context file, -context):
  mini-analyze -r analyzers/datalog -I include prog/*.c
  walk.c:56: in walk, through f: hide, show
  main.c:76: in main, through table[]: show
and the bugs the same answers show (bugs/pointers.dl), each a "may":
  bug? bugs.c:65: in main, free may be given a string (line 64), not the heap's
  bug? bugs.c: scratch may return the address of tmp[], a local of scratch
The ML files the same, with the library's units they name (lib_core's, by
-L): each call of a function held in a variable, which functions it may
reach (Andersen's, by object: a closure is a pointer to a function), and the
program's functions that its toplevel never reaches (calls.dl):
  mini-analyze tests/ml/handlers/*.ml
  Events.ml:15: in Events:fun at line 15, through h.on_key: Events.beep, Main:fun at line 4
  Events.ml:17: in Events.twice, through f: Events.log
  never reached: Events.unused (Events.ml:19)
A program as its build linked it, its files and nothing else, the
platform's among them, no -L or -own to give: dune's executable (dune
describe and dune rules run, Dune_manifest), or tiny-ld's manifest (-map);
-sources where a manifest's paths are read when the build ran in a copy
(TinyKernel's). -dead then says the program's own files' dead code alone,
those no other program of the build links (a library's: -dead its file):
  mini-analyze -dead _build/default/tiny/TinyBuildSystem.exe
  mini-analyze -dead -sources tiny tiny/TinyKernel/_make/src/build.manifest
-dead: instead, what no run can reach (dead.dl), from main and the toplevels:
  dead.c:12: dead: unused, nothing names it
  dead.c:18: dead: hide, named only by dead code: unused
  dead.c:24: dead: orphan, in main but no call goes through the pointer
  dead.c:31: dead code: in main, after a return
-dead on one .ml file some other names, a library's or a part of a program's
(tiny/TinyLibGUI.ml): each program that reaches it, run by mini-analyze
itself, merged (datalog/dead_all.dl), what is said of the file. Its programs
the manifests given that link it, each read as linked (-sources found);
without manifests, those whose files name it (Caller_finder), from their main:
  mini-analyze -dead tiny/TinyLibGUI.ml tiny/TinyKernel/_make/src/*.manifest
  tiny/TinyLibGUI.ml:472: never built: Disc.1, matched in TinyLibGUI.area_of
-caps: instead, whether ML's own functions hold the capabilities they need
(capabilities.dl), from their types' < Cap.x; .. > and what they reach:
  Log.ml:5: Log.log: no capability, needs Cap.stdout (Stdlib.print_string)
  Fs.ml:9: Fs.get: has < Cap.stdout >, needs Cap.open_in|Cap.open_out (Unix.openfile)
  Run.ml:3: Run.go: has < Cap.fork; Cap.stdout >, may not need Cap.fork
-exn: instead, the exceptions an ML program's toplevels may let escape
(exceptions.dl), with where they may be raised:
  Main.ml: the toplevel may let Empty escape, raised at Main.ml:11 (Main.first)
-bugs: instead, an ML program's bugs that may be, each named by its analysis
(docs/plans/done/plan_bug_analyses.md; C's are bugs/pointers.dl's, above):
  Before.ml:6: physeq: in Before.loop, != of a Some made there: always true
  Css.ml:13: stack: Css.components calls itself, not a tail call, over a list
  Process.ml:46: swallowed: in fork, Sys_error silenced, a constant answered
  Sha1.ml:6: int31: in Sha1's toplevel, 0xffffffff: not on the Pi 1's 31 bits
  Unbox.ml:129: order: in Unbox.func, a table's order reaches the output at
  Asm.ml:214
  Poly1305.ml: init: Poly1305's start reads Bignum.modulus (in Poly1305's
  toplevel), Bignum starting after it (-start: the units' order, mini-ml's)
  TinyMachine.ml:66: race: console_type, run by a signal's handler
  (TinyMachine.ml:52), writes a console's queue, as console_poll does
  Event.ml:70: wait: in Event.basic_sync, Condition.wait not in a while
  CLI.ml:31: leak: in CLI.read_file, taken here, given back at CLI.ml:33,
  not when CLI.ml:32 raises End_of_file
  given C files and ML ones (the runtime's, lib_core's): each external's
  [@@raise E] against what its C raises (bugs/raises.dl)
-root f: f is also entered from where the facts do not go (assembly)
-start "units": their order of start, mini-ml -start's, for -bugs's init
-context file: of points_to/, C's (call1_heap1), -exn's (call1_rec) and
  -bugs's (insensitive); the sharper, the longer
-library: every function may be called from outside, not main alone: a runtime
  ML calls, a library; without it what main does not reach is not looked at
-r: the directory of points_to/ and the .dl files (analyzers/datalog)
-I, -D: as mini-cc's; -L: lib_core's directory (lib_core), or a library in
  one directory with its own Stdlib, no units.txt (t-IX's tiny/TinyLibCore:
  read as tiny-ml reads it, searched before the -I's)
-own dir: ML: the units the program names found in dir are its own, reported
  on as the files given: a program given by its main file alone; its
  libraries' functions it does not call said dead too (tiny_check.sh keeps
  what every build says). One file of a program: it and the main file
  given, the libraries by -I, read but not reported on; a t-IX program as
  tiny-kernel runs it:
  mini-analyze -dead -L tiny/TinyLibCore -I tiny/TinyLibSystem/tinykernel tiny/user/temp.ml tiny/TinyAppTemperature.ml
-facts, -flow, -flow-answers: facts printed, nothing analyzed. -facts: the
facts the analyses load, not the analysis; -alone: an ML file's own facts, without those of the
library units it names; -no-models: List's, Hashtbl's and @'s code read as
written, not their models at each call (analyzers/ml/Models: to compare, slower)
-flow: ML's files each as its functions in SSA form, the facts of
analyzers/datalog/liveness_ssa.dl and dominators.dl (Ssa_facts, by mini-ml's
own way to its SSA: Ml_flow); C's as each function's stack code, the facts of
liveness.dl (Ir_facts, by mini-cc's simple back end: C_flow); -flow-answers:
the compiler's own answers on those facts, its liveness (ML's dominators
too), what the rules must find (analyzers/ml/tests/ and analyzers/c/tests/):
  mini-analyze -flow -L lib_core fact.ml > fact.dl
  mini-datalog -q 'live_in(V, B)' analyzers/datalog/liveness_ssa.dl fact.dl
  mini-analyze -flow hello.c > flow.dl
  mini-datalog -q 'across_call(V, P)' analyzers/datalog/liveness.dl flow.dl|}

module C = Ix_analyze_c

(* the C program's report, the facts given with bugs/pointers.dl's kinds of
 * places (C_report); the ML program's (Ml_report): mini-analyze
 * -dotnet's too (analyzers/dotnet/Analyze_rt) *)
module R = C_report

let locate = R.locate
let given = R.given
let report = R.report
let ml_report = Ml_report.ml_report

let dead_report = Dead_report.dead_report
let caps_report = Caps_report.caps_report
let exn_report = Exn_report.exn_report
let bugs_report = Bugs_report.bugs_report
let raises_report = Bugs_report.raises_report

(* a fact as a line, for -facts *)
let line (relation : string) (args : C.Facts.arg list) : string =
  let show = function C.Facts.Sym s -> "'" ^ String.concat "\\'" (String.split_on_char '\'' s) ^ "'" | C.Facts.Num n -> string_of_int n in
  relation ^ "(" ^ String.concat ", " (List.map show args) ^ ")."

(* a file's unit: Bugs.ml, Bugs *)
let unit_of_file (f : string) : string =
  String.capitalize_ascii (Filename.remove_extension (Filename.basename f))

(* bugs/intwidth.dl's unit_dir: the directories of a unit's file from
 * the top of the tree, lib_core's parent: kernels, kernels/lib_machine,
 * kernels/lib_machine/pi4, whether read from kernels/9pi or the top *)
let dirs_from (caps : < Cap.readdir; .. >) (lib : string) (file : string) :
    string list =
  let parts (s : string) : string list =
    let s =
      if Filename.is_relative s then Filename.concat (FS.getcwd caps ()) s
      else s in
    List.rev
      (List.fold_left
         (fun (acc : string list) (c : string) ->
           match c with
           | "" | "." -> acc
           | ".." -> (match acc with _ :: r -> r | [] -> [])
           | c -> c :: acc)
         [] (String.split_on_char '/' s)) in
  let rec under (top : string list) (l : string list) : string list option =
    match top, l with
    | [], l -> Some l
    | t :: ts, c :: cs when t = c -> under ts cs
    | _ -> None in
  if file = "" then []
  else
    match under (parts (Filename.dirname lib)) (parts (Filename.dirname file)) with
    | None -> []
    | Some ds ->
        List.mapi
          (fun (k : int) _ ->
            String.concat "/" (List.filteri (fun j _ -> j <= k) ds))
          ds

(* bugs/init.dl's: unit_start; starts_before, the units' starts in
 * -start's order, or (none given) the library's before the files', no
 * order known among either; unit_file, Ml_front.homes *)
let start_facts (fact : string -> C.Facts.arg list -> unit) (start : string)
    (ml : string list) : unit =
  let read (u : string) : bool =
    match Hashtbl.find_opt Ml_front.files u with Some f -> f <> "" | None -> false in
  let sym (s : string) : C.Facts.arg = C.Facts.Sym s in
  let init (u : string) : C.Facts.arg = sym (u ^ ":init") in
  Hashtbl.iter
    (fun (u : string) _ -> if read u then fact "unit_start" [ sym u; init u ])
    Ml_front.files;
  let before (u : string) (v : string) : unit =
    fact "starts_before" [ init u; init v ] in
  let rec in_order (l : string list) : unit =
    match l with
    | [] -> ()
    | u :: more -> List.iter (before u) more; in_order more in
  if start <> "" then
    in_order (List.filter read (String.split_on_char ' ' (String.trim start)))
  else begin
    let unit_of (f : string) : string =
      String.capitalize_ascii (Filename.remove_extension (Filename.basename f)) in
    let mine = List.map unit_of ml in
    Hashtbl.iter
      (fun (u : string) _ ->
        if read u && not (List.mem u mine) then List.iter (before u) mine)
      Ml_front.files
  end;
  Hashtbl.iter
    (fun (u : string) (fs : string list) ->
      List.iter (fun (f : string) -> fact "unit_file" [ sym u; sym f ]) fs)
    Ml_front.homes

(* -summary: what a -dead run says of its program, as facts, so that the
 * runs of several programs can be merged (datalog/dead_all.dl): the files
 * it reads (has) and those it reports on (own); an implementation whose
 * interface is elsewhere (implements); a file outside the project, whose
 * root is the first directory above the first file given that has a
 * dune-project (outside); each report, by its file, line, what is dead
 * and message (report, or report_one when one program's is kept: a
 * [@@for_testing] function the program calls) *)
let summary (caps : < Cap.open_in; Cap.open_out; Cap.readdir; .. >) (out : string) (prog : string)
    (given_files : string list) (reports : (string * int * string * string * Dead_report.kept) list)
    (said : string list) : unit =
  let b = Buffer.create 4096 in
  let add (r : string) (args : C.Facts.arg list) : unit = Buffer.add_string b (line r args ^ "\n") in
  let sym (s : string) : C.Facts.arg = C.Facts.Sym s in
  let read = Hashtbl.fold (fun _ (f : string) acc -> if f = "" then acc else f :: acc) Ml_front.files [] in
  let own = Hashtbl.fold (fun (u : string) () acc -> match Hashtbl.find_opt Ml_front.files u with Some f when f <> "" -> f :: acc | _ -> acc) Ml_front.own [] in
  let c = List.filter (fun (f : string) -> Filename.check_suffix f ".c") given_files in
  let has = List.sort_uniq compare (c @ read) and own = List.sort_uniq compare (c @ own) in
  List.iter (fun (f : string) -> add "has" [ sym prog; sym f ]) has;
  List.iter (fun (f : string) -> add "own" [ sym prog; sym f ]) own;
  List.iter
    (fun (f : string) -> Option.iter (fun (i : string) -> add "implements" [ sym f; sym i ]) (Hashtbl.find_opt Ml_front.interfaces f))
    has;
  let cwd = FS.getcwd caps () in
  let absolute (f : string) : string = FS.cleanname (if Filename.is_relative f then Filename.concat cwd f else f) in
  let rec root (d : string) : string option =
    if FS.read_opt caps (Fpath.v (Filename.concat d "dune-project")) <> None then Some d
    else if Filename.dirname d = d then None
    else root (Filename.dirname d) in
  (match given_files with
   | first :: _ -> (
       match root (Filename.dirname (absolute first)) with
       | Some r ->
           let inside (f : string) : bool = String.starts_with ~prefix:(r ^ "/") (absolute f) in
           List.iter (fun (f : string) -> if not (inside f) then add "outside" [ sym f ]) has
       | None -> ())
   | [] -> ());
  List.iter
    (fun ((f, l, w, m, kept) : string * int * string * string * Dead_report.kept) ->
      let r = match kept with Dead_report.Every_program -> "report" | Dead_report.One_program -> "report_one" in
      add r [ sym prog; sym f; C.Facts.Num l; sym w; sym m ])
    reports;
  (* (another analysis's lines, a unit not read: datalog/merge/'s) *)
  List.iter (fun (l : string) -> add "said" [ sym prog; sym l ]) said;
  List.iter (fun (m : string) -> add "unread" [ sym prog; sym m ]) !Ml_front.unread;
  FS.write caps (Fpath.v out) (Buffer.contents b)

(* (Sys.is_directory's, false for what is not there: a flag, a typo) *)
let directory (caps : < Cap.readdir; .. >) (p : string) : bool =
  try CapSys.is_directory caps p with Sys_error _ -> false

(* words on lines within the console's 80 columns, each after a blank *)
let wrapped (words : string list) : string list =
  let line = Buffer.create 80 and lines = ref [] in
  List.iter (fun (w : string) ->
      if Buffer.length line > 0 && Buffer.length line + String.length w > 72 then begin
        lines := Buffer.contents line :: !lines;
        Buffer.clear line
      end;
      Buffer.add_string line (" " ^ w))
    words;
  List.rev (Buffer.contents line :: !lines)

(* Several programs analyzed and merged (a library's file's programs,
 * Caller_finder's or the manifests' that link it; or the programs given):
 * each is mini-analyze itself, run with the flags given, its own and
 * -summary, all at once, as tiny_check.sh runs them; their summaries
 * merged in this process, -dead's by datalog/dead_all.dl (what every
 * program that has the file says), the others' by datalog/said_all.dl
 * (-bugs's, -caps's: any program's; -exn's: by program); the merged
 * lines printed (of [file] alone when one is given), then how many
 * programs said them. A program's own report goes to a file of the
 * run's directory, left there if it failed; a unit a program could not
 * read is said, and the status is 1. *)
let merged_runs (caps : < caps; .. >) (args : string list) (rules : string) (analysis : string)
    (file : string option) (mains : (string * string * string list) list) : int =
  let file = Option.map FS.cleanname file in
  let w = Filename.concat (Filename.get_temp_dir_name ()) (Printf.sprintf "mini-analyze-%d" (Unix.getpid ())) in
  FS.mkdir caps w 0o755;
  (* (the flags given, not the file, not a program: each run its own) *)
  let program (a : string) : bool =
    List.exists (fun x -> Filename.check_suffix a x) [ ".manifest"; ".exe" ]
    || directory caps a
    || List.exists (fun ((_, m, _) : string * string * string list) -> m = a) mains in
  (* (-sources each run's, in its extra flags) *)
  let rec without_sources (l : string list) : string list =
    match l with
    | "-sources" :: _ :: rest -> without_sources rest
    | a :: rest -> a :: without_sources rest
    | [] -> [] in
  let flags =
    List.filter (fun (a : string) -> Some (FS.cleanname a) <> file && not (program a))
      (without_sources args) in
  let names = Hashtbl.create 16 in
  let file_of (name : string) : string = String.map (fun c -> if c = '/' then '_' else c) name in
  let runs =
    List.map
      (fun ((given, main, extra) : string * string * string list) ->
        (* (its name, given, or its main's, made unique; its files' names
         * without a /) *)
        let base = if given <> "" then given else Filename.remove_extension (Filename.basename main) in
        let n = (match Hashtbl.find_opt names base with Some n -> n | None -> 0) + 1 in
        Hashtbl.replace names base n;
        let name = if n = 1 then base else Printf.sprintf "%s%d" base n in
        let file = file_of name in
        let out = FS.open_out_fd caps (Filename.concat w (file ^ ".out")) 0o644 in
        let args = flags @ extra @ [ "-summary"; Filename.concat w (file ^ ".dl"); "-program"; name; main ] in
        let pid = Procs.create_process caps Sys.executable_name args ~stdin:Unix.stdin ~stdout:out in
        Unix.close out;
        (name, main, pid))
      mains in
  let failed =
    List.filter
      (fun ((_, _, pid) : string * string * int) -> Procs.waitpid caps pid <> Unix.WEXITED 0)
      runs in
  List.iter
    (fun ((name, main, _) : string * string * int) ->
      Console.eprint caps (Printf.sprintf "mini-analyze: %s failed (its report: %s)\n" main (Filename.concat w (file_of name ^ ".out"))))
    failed;
  let p = D.create () in
  let merge = if analysis = "-dead" then "dead_all.dl" else "said_all.dl" in
  let all = Fpath.to_string (Fpath.append (Fpath.v rules) (Fpath.v merge)) in
  D.load p ~from:all (FS.read caps (Fpath.v all));
  List.iter
    (fun ((name, _, _) : string * string * int) ->
      let f = Filename.concat w (file_of name ^ ".dl") in
      match FS.read_opt caps (Fpath.v f) with Some text -> D.load p ~from:f text | None -> ())
    runs;
  ignore (Datalog_eval.run ~naive:false p);
  let tuples (r : string) (n : int) : string list list =
    List.map (fun (t : int array) -> List.map (R.name p) (Array.to_list t)) (D.tuples (D.relation p r n)) in
  let mine (f : string) : bool = match file with Some x -> FS.cleanname f = x | None -> true in
  let lines =
    match analysis with
    | "-dead" ->
        List.filter_map
          (function
            | [ f; l; m ] when mine f ->
                Some (if l = "0" then Printf.sprintf "%s: %s" f m else Printf.sprintf "%s:%s: %s" f l m)
            | _ -> None)
          (tuples "dead_all" 3)
    | "-exn" -> List.map (function [ p; l ] -> p ^ ": " ^ l | _ -> "") (tuples "said_by" 2)
    | _ -> List.map (function [ l ] -> l | _ -> "") (tuples "said_any" 1) in
  let lines = List.sort_uniq compare lines in
  List.iter (fun (l : string) -> Console.print caps (l ^ "\n")) lines;
  let unread = if analysis = "-dead" then [] else tuples "not_read" 2 in
  List.iter (function [ p; m ] -> Console.eprint caps (Printf.sprintf "%s: not read: %s\n" p m) | _ -> ()) unread;
  Console.print caps
    (Printf.sprintf "%d reports, over the %d programs%s:\n%s\n" (List.length lines) (List.length runs)
       (if file = None then "" else " that reach it")
       (String.concat "\n" (wrapped (List.map (fun ((n, _, _) : string * string * int) -> n) runs))));
  if failed <> [] || unread <> [] then 1
  else begin
    List.iter
      (fun ((name, _, _) : string * string * int) ->
        List.iter (fun (x : string) -> FS.remove_any caps (Filename.concat w (file_of name ^ x))) [ ".out"; ".dl" ])
      runs;
    FS.remove_any caps w;
    0
  end

let main (caps : < caps; .. >) (argv : string array) : int =
  let rules = ref "analyzers/datalog" and lib = ref "" and only = ref false and incs = ref [] and defs = ref [] and files = ref [] in
  let dead = ref false and ambient = ref false and roots = ref [] and context = ref "" and library = ref false in
  let fingerprint = ref false and exns = ref false and flow = ref false and answers = ref false in
  let bugs = ref false and start = ref "" and summary_file = ref "" and program = ref "" in
  let sources = ref "" in
  let options =
    Logging.flags
    @ [ ("-r", Arg.Set_string rules, " the directory of points_to/ and bugs/");
        ("-facts", Arg.Set only, " the facts, not the analysis");
        ("-alone", Arg.Set Ml_front.alone, " ML: the files' facts alone, not their library's units'");
        ("-no-models", Arg.Clear Models.on, " ML: List's and Hashtbl's code as written, not their models");
        ("-summaries",
         Arg.String
           (fun (f : string) ->
             Logs.info (fun m -> m "summaries: %s" f);
             Models.derived_on := true;
             List.iter (fun (s, m) -> Hashtbl.replace Models.derived s m)
               (Summaries.of_text (FS.read caps (Fpath.v f)))),
         " file: ML: the library's summaries derived from its code (analyzers/summaries/), Models' own for the rest");
        ("-flow", Arg.Set flow, " ML's functions in SSA form, C's stack code, as facts");
        ("-flow-answers", Arg.Set answers,
         " the compiler's own liveness and dominators on -flow's facts, as facts");
        ("-dead", Arg.Set dead, " what no run can reach, not the calls and the bugs");
        ("-summary", Arg.Set_string summary_file,
         " file: -dead's files and reports as facts, for merging programs (datalog/dead_all.dl)");
        ("-program", Arg.Set_string program, " name: the program's, in -summary's facts (the first file's if not said)");
        ("-caps", Arg.Set ambient, " whether ML's own functions hold the capabilities they need");
        ("-exn", Arg.Set exns, " the exceptions ML's toplevels may let escape");
        ("-bugs", Arg.Set bugs, " the bugs an ML program may have (plan_bug_analyses.md)");
        ("-start", Arg.Set_string start,
         " ML: the units in the order they start, as mini-ml -start's (-bugs)");
        ("-root", Arg.String (fun f -> roots := f :: !roots), " a function entered from where the facts do not go");
        ("-context", Arg.Set_string context, " the context file of points_to/: C's (call1_heap1), -exn's (call1_rec)");
        ("-library", Arg.Set library, " every function may be called from outside: a runtime, a library");
        ("-fingerprint", Arg.Set fingerprint, " after the report, one number of every answer (Answers, Fingerprint)");
        ("-L", Arg.Set_string lib, " the standard library's directory, for an ML program (the nearest if not said)");
        ("-I", Arg.String (fun d -> incs := d :: !incs), " a directory of #include's");
        ("-own",
         Arg.String (fun d -> Ml_front.own_dirs := !Ml_front.own_dirs @ [ Fpath.v d ]),
         " dir: ML: the units the program names found there are its own, reported on as the files given");
        ("-D", Arg.String (fun d -> defs := d :: !defs), " name=value, as #define");
        ("-sources", Arg.Set_string sources,
         " dir: a manifest's paths read there, the build having run in a copy\n\
         \    of it (tiny/ for tiny/TinyKernel/_make/src)") ] in
  (* (-Idir and -Dx in one word too, as mini-cc's) *)
  let split a =
    if String.length a > 2 && (String.sub a 0 2 = "-I" || String.sub a 0 2 = "-D") then [ String.sub a 0 2; String.sub a 2 (String.length a - 2) ]
    else [ a ] in
  let argv = Array.of_list (List.concat_map split (Array.to_list argv)) in
  (* (-dead on one .ml file some other names: its programs', found; not a
   * -summary's run, which is one of them) *)
  let callers = ref [] in
  let find_callers () =
    match !files with
    | [ f ] when !dead && Filename.check_suffix f ".ml" && !summary_file = "" && not !only ->
        Caller_finder.programs caps (List.map Fpath.to_string !Ml_front.own_dirs @ !incs) f
    | _ -> [] in
  (* (a manifest's files: its ML units given to the linker, its
   * archives' standard library, every linked unit's file) *)
  let linked (what : string) (p : Tiny_manifest.program) : unit =
    Logs.info (fun l ->
        l "%s: %d units, %d the program's own" what (List.length p.units)
          (List.length p.own));
    files := List.rev_append p.own !files;
    Ml_front.own_dirs := !Ml_front.own_dirs @ List.map Fpath.v p.own_dirs;
    (* (a link with no standard library of the project's, an archive's,
     * is on OCaml's, lib_core's for the analyzer: dune's
     * tiny-machine-window; not the nearest to its files, TinyLibCore) *)
    if !lib = "" then lib := (match p.library with Some d -> d | None -> "lib_core");
    if !program = "" then program := p.name;
    List.iter (fun (u, f) -> Hashtbl.replace Ml_front.linked u f) p.units;
    (* (-dead on the program alone: its components' dead code, not its
     * libraries', which another program may call; a run of a merge,
     * -summary's, all of it) *)
    if !dead && !summary_file = "" then
      List.iter (fun f -> Hashtbl.replace Ml_front.components (unit_of_file f) ()) p.components in
  let manifests = ref [] and exes = ref [] and dirs = ref [] in
  let anon (f : string) =
    if Filename.check_suffix f ".manifest" then manifests := f :: !manifests
    else if Filename.check_suffix f ".exe" then exes := f :: !exes
    else if directory caps f then dirs := f :: !dirs
    else files := f :: !files in
  (* (a program's name, a directory's: its path from it, build or
   * TinyKernel/kernel.img for tiny/TinyKernel/_make/src's, tiny/TinyShell
   * for tiny's dune executables; else its main's, merged_runs's) *)
  let named : (string, string) Hashtbl.t = Hashtbl.create 64 in
  (* (a directory: the manifests under it, every one; with none, the
   * executables dune builds under it) *)
  let expand_dirs () : bool =
    let rec under (d : string) : string list =
      Array.to_list (CapSys.readdir caps d)
      |> List.sort compare
      |> List.concat_map (fun (n : string) ->
             let p = Filename.concat d n in
             (* (not .git's, nor a build's, _build's or _make's, which
              * only a directory given is) *)
             if n <> "" && (n.[0] = '.' || n.[0] = '_') then []
             else if CapSys.is_directory caps p then under p
             else if Filename.check_suffix n ".manifest" then [ p ]
             else []) in
    match
      let source_dirs = ref [] in
      List.iter (fun (d : string) ->
          match under d with
          | [] -> source_dirs := d :: !source_dirs
          | ms ->
              List.iter (fun (m : string) ->
                  let n = String.length (FS.cleanname d) + 1 in
                  let m' = FS.cleanname m in
                  Hashtbl.replace named m (Filename.chop_suffix (String.sub m' n (String.length m' - n)) ".manifest");
                  manifests := m :: !manifests)
                (List.rev ms))
        (List.rev !dirs);
      if !source_dirs <> [] then
        List.iter (fun (e : string) ->
            Hashtbl.replace named e (Filename.chop_suffix e ".exe");
            exes := e :: !exes)
          (Dune_manifest.executables caps (List.rev !source_dirs))
    with
    | () -> false
    | exception (Failure m | Sys_error m) -> Console.eprint caps (m ^ "\n"); true in
  (* (after the flags: -sources; an .exe's manifest by dune itself, its
   * paths from the project's root) *)
  let read_manifests () =
    let sources = if !sources = "" then None else Some !sources in
    match
      List.iter (fun m -> linked m (Tiny_manifest.program caps m sources)) (List.rev !manifests);
      if !exes <> [] then begin
        let root, ms = Dune_manifest.run caps (List.rev !exes) in
        let root = match sources with Some d -> d | None -> root in
        (* (the root's paths, read from here: relative to it when here is
         * it, as the reports name them) *)
        let root = if root = FS.getcwd caps () then "." else root in
        List.iter (fun (exe, m) -> linked exe (Tiny_manifest.of_manifest caps m [] root)) ms
      end
    with
    | () -> false
    | exception (Failure m | Sys_error m) -> Console.eprint caps (m ^ "\n"); true in
  match Arg.parse_argv argv options anon usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () when !summary_file = "" && expand_dirs () -> 1
  (* (-dead on one .ml file and manifests: the file a library's or a
   * part of a program's, its programs the manifests that link it, each
   * run as linked, merged; its -sources found if not given) *)
  | () when (match !files with [ f ] -> !dead && Filename.check_suffix f ".ml" | _ -> false)
            && !manifests <> [] && !summary_file = "" && not !only -> (
      let file = List.hd !files in
      let given = if !sources = "" then None else Some !sources in
      match
        List.filter_map (fun (m : string) ->
            Option.map (fun (root : string) -> ("", m, [ "-sources"; root ]))
              (Tiny_manifest.linking m (Tiny_manifest.of_string (FS.read caps (Fpath.v m))) given file))
          (List.rev !manifests)
      with
      | [] -> Console.eprint caps (Printf.sprintf "mini-analyze: no manifest given links %s\n" file); 1
      | mains -> merged_runs caps (List.tl (Array.to_list argv)) !rules "-dead" (Some file) mains
      | exception (Failure m | Sys_error m) -> Console.eprint caps (m ^ "\n"); 1)
  (* (several programs, manifests or dune's .exe: each run, merged;
   * dune asked once, each .exe's manifest a file of its own) *)
  | () when (List.length !manifests + List.length !exes >= 2 || !dirs <> []) && !files = []
            && !summary_file = "" && not !only -> (
      let analysis =
        if !dead then "-dead" else if !exns then "-exn" else if !bugs then "-bugs"
        else if !ambient then "-caps" else "" in
      try
        if analysis = "" then failwith "several programs: -dead, -exn, -bugs or -caps";
        let dune =
          if !exes = [] then []
          else begin
            let root, ms = Dune_manifest.run caps (List.rev !exes) in
            let d = Filename.concat (Filename.get_temp_dir_name ())
                (Printf.sprintf "mini-analyze-manifests-%d" (Unix.getpid ())) in
            if not (CapSys.file_exists caps d) then FS.mkdir caps d 0o755;
            let root = if root = FS.getcwd caps () then "." else root in
            List.map (fun ((exe, m) : string * Tiny_manifest.manifest) ->
                let name =
                  match Hashtbl.find_opt named exe with
                  | Some n -> n
                  | None -> Filename.chop_suffix exe ".exe" in
                let f = Filename.concat d (String.map (fun c -> if c = '/' then '_' else c) exe ^ ".manifest") in
                FS.write caps (Fpath.v f) (Tiny_manifest.to_string m);
                (name, f, [ "-sources"; root ]))
              ms
          end in
        (* (-sources: the shallowest manifest's directory's, a deeper
         * one's below it as the manifest is below that one: tiny/
         * TinyKernel for _make/src/TinyKernel's kernel.img.manifest) *)
        (* (a program with no ML unit, tiny-cc's: not read, said) *)
        let ml (m : string) : bool =
          List.exists (fun (l : Tiny_manifest.linked) ->
              match l.l_source with Some s -> Filename.check_suffix s ".ml" | None -> false)
            (Tiny_manifest.of_string (FS.read caps (Fpath.v m))).m_units in
        let ms, others = List.partition ml (List.rev !manifests) in
        if others <> [] then
          Console.eprint caps
            (Printf.sprintf "mini-analyze: no ML unit, not read: %s\n" (String.concat " " others));
        let dirs = List.map (fun m -> FS.cleanname (Filename.dirname m)) ms in
        let top =
          List.fold_left (fun a d -> if String.length d < String.length a then d else a)
            (match dirs with d :: _ -> d | [] -> ".") dirs in
        let sources_of (m : string) : string list =
          if !sources = "" then []
          else
            let d = FS.cleanname (Filename.dirname m) in
            let below =
              if d = top then ""
              else if String.starts_with ~prefix:(top ^ "/") d then
                String.sub d (String.length top + 1) (String.length d - String.length top - 1)
              else "" in
            [ "-sources"; if below = "" then !sources else Filename.concat !sources below ] in
        let st =
          merged_runs caps (List.tl (Array.to_list argv)) !rules analysis None
            (List.map (fun m ->
                 ((match Hashtbl.find_opt named m with Some n -> n | None -> ""), m, sources_of m))
                ms
             @ dune) in
        (* (dune's manifests, files of this run's) *)
        List.iter (fun ((_, f, _) : string * string * string list) -> FS.remove_any caps f) dune;
        if dune <> [] then FS.remove_any caps (Filename.dirname (match dune with (_, f, _) :: _ -> f | [] -> "."));
        st
      with Failure m | Sys_error m -> Console.eprint caps (m ^ "\n"); 1)
  | () when read_manifests () -> 1
  | () when (callers := find_callers (); !callers <> []) ->
      merged_runs caps (List.tl (Array.to_list argv)) !rules "-dead" (Some (List.hd !files))
        (List.map (fun m -> ("", m, [])) !callers)
  | () -> (
      (* (no -L: the standard library nearest the first ML file, tiny's
       * TinyLibCore for tiny/'s programs, lib_core for ix's) *)
      if !lib = "" then
        lib :=
          (match List.find_opt (fun (f : string) -> Filename.check_suffix f ".ml") (List.rev !files) with
           | Some f -> (match Unit_finder.library caps f with Some d -> d | None -> "lib_core")
           | None -> "lib_core");
      (* (-exn's: a recursive call in its caller's context, else
       * List.fold_left's callers are one: exceptions.dl's design note) *)
      let context = if !context <> "" then !context else if !exns then "call1_rec" else if !bugs then "insensitive" else "call1_heap1" in
      let path s = match FS.path s with Ok p -> p | Error m -> failwith m in
      try
        if !files = [] then failwith usage;
        let incs = List.map path (List.rev !incs) in
        if !flow || !answers then begin
          let mls = List.filter (fun f -> not (Filename.check_suffix f ".c")) !files in
          let own_dirs = List.sort_uniq compare (List.map (fun f -> Fpath.parent (path f)) mls) in
          let dirs = own_dirs @ (if mls = [] then incs else Ml_front.search caps !lib incs) in
          List.fold_left
            (fun status (f : string) ->
              let c own =
                C.C_flow.file caps ~own (List.rev !defs, incs) (path f) in
              (* (C's: mini-cc's stack code, Ir_facts) *)
              if Filename.check_suffix f ".c" then
                let none = Ok "" in
                match (if !flow then c false else none),
                      (if !answers then c true else none) with
                | Ok a, Ok b -> Console.print caps (a ^ b); status
                | Error m, _ | _, Error m -> Console.eprint caps (m ^ "\n"); 1
              else
              match Ml_flow.file ~sites:true caps dirs (path f) with
              | Ok fns ->
                  let unit_name = unit_of_file f in
                  if !flow then
                    List.iter (fun fn -> Console.print caps (Ssa_facts.func ~unit_name fn)) fns;
                  if !answers then List.iter (fun fn -> Console.print caps (Ssa_facts.own fn)) fns;
                  status
              | Error m -> Console.eprint caps (m ^ "\n"); 1)
            0 (List.rev !files)
        end
        else
        let failed = ref 0 in
        let p = D.create () in
        let ml, c = List.partition (fun f -> Filename.check_suffix f ".ml") (List.rev !files) in
        let text = Buffer.create 4096 in
        let fact = if !only then (fun r args -> Buffer.add_string text (line r args ^ "\n")) else given p in
        if not !only then
          List.iter
            (fun (r : string) ->
              let rules = Fpath.append (path !rules) (Fpath.v r) in
              Logs.info (fun m -> m "rules: %s" (Fpath.to_string rules));
              D.load p ~from:(Fpath.to_string rules) (FS.read caps rules))
            (if !dead || !ambient then
               [ "points_to/instructions.dl"; "points_to/contexts.dl"; "points_to/insensitive.dl"; "dead.dl" ]
               @ if !ambient then [ "capabilities.dl" ] else []
             else if !bugs && c <> [] && ml <> [] then [ "bugs/raises.dl" ]
             else if !bugs && c = [] then
               [ "points_to/instructions.dl"; "points_to/contexts.dl"; "points_to/" ^ context ^ ".dl"; "exceptions.dl";
                 "bugs/physeq.dl"; "bugs/stack.dl"; "bugs/swallowed.dl";
                 "bugs/intwidth.dl"; "bugs/order.dl"; "bugs/init.dl";
                 "bugs/races.dl"; "bugs/pairs.dl";
                 "bugs/unused.dl"; "bugs/layout.dl"; "bugs/evalorder.dl" ]
             else if !exns then
               [ "points_to/instructions.dl"; "points_to/andersen.dl"; "points_to/contexts.dl";
                 "points_to/" ^ context ^ ".dl"; "exceptions.dl" ]
             else
               [ "points_to/instructions.dl"; "points_to/andersen.dl" ]
               @ (if c <> [] then [ "points_to/contexts.dl"; "points_to/" ^ context ^ ".dl"; "bugs/pointers.dl" ] else [])
               @ if ml <> [] then [ "calls.dl" ] else []);
        List.iter (fun (f : string) -> given p "entry" [ C.Facts.Sym f ]) !roots;
        if !library then D.load p ~from:"-library" "entry(F) :- function(F).\n";
        C.Facts.added := fact;
        Closure_facts.added :=
          (fun r args -> fact r (List.map (function Closure_facts.Sym s -> C.Facts.Sym s | Closure_facts.Num n -> C.Facts.Num n) args));
        List.iter
          (fun (f : string) ->
            Logs.info (fun m -> m "reading %s" f);
            match C.C_front.file caps (List.rev !defs, incs) (path f) with
            | Ok () -> ()
            | Error m -> Console.eprint caps (m ^ "\n"); incr failed)
          c;
        if ml <> [] then
          List.iter (fun m -> Console.eprint caps (m ^ "\n"); incr failed) (Ml_front.program caps (Ml_front.search caps !lib incs) (List.map path ml));
        (* (with the units -own found: the program's files, for -bugs's
         * start order and SSA form as the files given) *)
        let ml =
          ml
          @ List.sort compare
              (Hashtbl.fold
                 (fun (u : string) (f : string) acc ->
                   if f <> "" && Hashtbl.mem Ml_front.own u && not (List.mem f ml) then f :: acc else acc)
                 Ml_front.files []) in
        if !bugs then start_facts (given p) !start ml;
        (* (the program's own files in SSA form, their calls named as
         * Closure_facts' sites: bugs/pairs.dl's paths, ssa_ before each
         * relation; a file mini-ml's lowering refuses, none) *)
        if !bugs then begin
          (* (the units it names in each of the program's directories,
           * _mk's generated parsers, a subfolder's) *)
          let own_dirs = List.sort_uniq compare (List.map (fun f -> Fpath.parent (path f)) ml) in
          let dirs = own_dirs @ Ml_front.search caps !lib incs in
          List.iter
            (fun (f : string) ->
              let unit_name = unit_of_file f in
              match Ml_flow.file ~sites:true caps dirs (path f) with
              | Ok fns ->
                  List.iter
                    (fun fn -> D.load p ~from:f (Ssa_facts.func ~prefix:"ssa_" ~unit_name fn))
                    fns
              | Error m -> Logs.info (fun l -> l "no SSA: %s" m))
            ml;
        end;
        if !bugs then
          Hashtbl.iter
            (fun (u : string) (f : string) ->
              List.iter
                (fun (d : string) ->
                  given p "unit_dir" [ C.Facts.Sym u; C.Facts.Sym d ])
                (dirs_from caps !lib f))
            Ml_front.files;
        (* (dead.dl's: what a unit read by its interface alone may build) *)
        if !dead then
          List.iter (fun (c : string) -> given p "built_outside" [ C.Facts.Sym c ])
            (List.sort_uniq compare !Ml_front.built_outside);
        (* (what they call would be reported dead; -exn's and -bugs's
         * reports through them would be missing, gone from a recording) *)
        if !dead || !ambient || !exns || !bugs then List.iter (fun m -> Console.eprint caps ("not read: " ^ m ^ "\n"); incr failed) !Ml_front.unread;
        if !ambient || !bugs then
          Hashtbl.iter (fun u () ->
              given p "own_unit" [ C.Facts.Sym u ];
              given p "own_init" [ C.Facts.Sym (u ^ ":init") ];
              (* (a unit's init by its unit, for -caps's system units) *)
              given p "unit_init" [ C.Facts.Sym u; C.Facts.Sym (u ^ ":init") ])
            Ml_front.own;
        if !only then Console.print caps (Buffer.contents text)
        else begin
          (* (the engine is mini-datalog's, linked in: no program is run,
           * and the facts are added to it directly, never written out) *)
          let relations =
            List.sort (fun (a : D.relation) (b : D.relation) -> compare (a.name, a.arity) (b.name, b.arity))
              (Hashtbl.fold (fun _ r acc -> r :: acc) p.relations []) in
          let count f = List.fold_left (fun n r -> n + f r) 0 relations in
          Logs.info (fun m ->
              m "evaluating, in this process (mini-datalog's engine): %d rules, %d facts in %d relations"
                (List.length p.rule_list) (count (fun r -> r.count)) (List.length relations));
          let st = Datalog_eval.run ~naive:false p in
          Logs.info (fun m -> m "evaluated: %d rounds, %d firings, %d tuples derived" st.rounds st.firings st.derived);
          List.iter
            (fun (r : D.relation) ->
              Logs.debug (fun m -> m "%s/%d: %d tuples (%d given), %d rules, stratum %d" r.name r.arity r.count r.given r.rules r.stratum))
            relations;
          let dead_reports = ref [] in
          let said =
          if !ambient then caps_report caps p
          else if !exns then exn_report caps p
          else if !dead then begin
            let reports = dead_report caps p (ml <> []) in
            dead_reports := reports;
            if Hashtbl.length Ml_front.components > 0 then begin
              (* (the units, wrapped within the console's 80 columns) *)
              let units =
                List.sort compare (Hashtbl.fold (fun u () acc -> u :: acc) Ml_front.components []) in
              Console.print caps
                ("(on the program's own files alone, not its libraries':\n"
                 ^ String.concat "\n" (wrapped units)
                 ^ "\n a library's dead code: mini-analyze -dead its file, over its programs)\n")
            end;
            []
          end
          else if !bugs && c <> [] && ml <> [] then raises_report caps p
          else if !bugs && c = [] then bugs_report caps p
          else begin
            if c <> [] then report caps p;
            if ml <> [] then ml_report caps p;
            []
          end in
          if !summary_file <> "" then
            summary caps !summary_file (if !program <> "" then !program else List.hd (List.rev !files))
              (List.rev !files) !dead_reports said;
          if !fingerprint then Console.print caps ("fingerprint of the answers: " ^ Answers.hex (Answers.fingerprint p) ^ "\n")
        end;
        if !failed > 0 then 1 else 0
      with
      | D.Error (msg, at) -> Console.eprint caps (Printf.sprintf "%s: %s\n" at msg); 1
      | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
