(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze.mli *)

module D = Datalog

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr >

let usage = "usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-L lib] [-facts | -flow | -flow-answers] [-dead | -caps | -exn | -bugs] [-root f]... file.c|file.ml...   (-h: how)"

let help = {|usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-L lib] [-facts | -flow | -flow-answers] [-dead | -caps | -exn | -bugs] [-root f]... file.c|file.ml...
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
-dead: instead, what no run can reach (dead.dl), from main and the toplevels:
  dead.c:12: dead: unused, nothing names it
  dead.c:18: dead: hide, named only by dead code: unused
  dead.c:24: dead: orphan, in main but no call goes through the pointer
  dead.c:31: dead code: in main, after a return
-caps: instead, whether ML's own functions hold the capabilities they need
(capabilities.dl), from their types' < Cap.x; .. > and what they reach:
  Log.ml:5: Log.log: no capability, needs Cap.stdout (Pervasives.print_string)
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
-I, -D: as mini-cc's; -L: lib_core's directory (lib_core)
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

let main (caps : < caps; .. >) (argv : string array) : int =
  let rules = ref "analyzers/datalog" and lib = ref "lib_core" and only = ref false and incs = ref [] and defs = ref [] and files = ref [] in
  let dead = ref false and ambient = ref false and roots = ref [] and context = ref "" and library = ref false in
  let fingerprint = ref false and exns = ref false and flow = ref false and answers = ref false in
  let bugs = ref false and start = ref "" in
  let options =
    Logging.flags
    @ [ ("-r", Arg.Set_string rules, " the directory of points_to/ and bugs/");
        ("-facts", Arg.Set only, " the facts, not the analysis");
        ("-alone", Arg.Set Ml_front.alone, " ML: the files' facts alone, not their library's units'");
        ("-no-models", Arg.Clear Models.on, " ML: List's and Hashtbl's code as written, not their models");
        ("-summaries",
         Arg.String
           (fun (f : string) ->
             Models.derived_on := true;
             List.iter (fun (s, m) -> Hashtbl.replace Models.derived s m)
               (Summaries.of_text (FS.read caps (Fpath.v f)))),
         " file: ML: the library's summaries derived from its code (analyzers/summaries/), not Models' own");
        ("-flow", Arg.Set flow, " ML's functions in SSA form, C's stack code, as facts");
        ("-flow-answers", Arg.Set answers,
         " the compiler's own liveness and dominators on -flow's facts, as facts");
        ("-dead", Arg.Set dead, " what no run can reach, not the calls and the bugs");
        ("-caps", Arg.Set ambient, " whether ML's own functions hold the capabilities they need");
        ("-exn", Arg.Set exns, " the exceptions ML's toplevels may let escape");
        ("-bugs", Arg.Set bugs, " the bugs an ML program may have (plan_bug_analyses.md)");
        ("-start", Arg.Set_string start,
         " ML: the units in the order they start, as mini-ml -start's (-bugs)");
        ("-root", Arg.String (fun f -> roots := f :: !roots), " a function entered from where the facts do not go");
        ("-context", Arg.Set_string context, " the context file of points_to/: C's (call1_heap1), -exn's (call1_rec)");
        ("-library", Arg.Set library, " every function may be called from outside: a runtime, a library");
        ("-fingerprint", Arg.Set fingerprint, " after the report, one number of every answer (Answers, Fingerprint)");
        ("-L", Arg.Set_string lib, " lib_core's directory, for an ML program's library");
        ("-I", Arg.String (fun d -> incs := d :: !incs), " a directory of #include's");
        ("-D", Arg.String (fun d -> defs := d :: !defs), " name=value, as #define") ] in
  (* (-Idir and -Dx in one word too, as mini-cc's) *)
  let split a =
    if String.length a > 2 && (String.sub a 0 2 = "-I" || String.sub a 0 2 = "-D") then [ String.sub a 0 2; String.sub a 2 (String.length a - 2) ]
    else [ a ] in
  let argv = Array.of_list (List.concat_map split (Array.to_list argv)) in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
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
          let dirs = own_dirs @ incs @ Ml_front.library caps !lib in
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
          List.iter (fun m -> Console.eprint caps (m ^ "\n"); incr failed) (Ml_front.program caps (incs @ Ml_front.library caps !lib) (List.map path ml));
        if !bugs then start_facts (given p) !start ml;
        (* (the program's own files in SSA form, their calls named as
         * Closure_facts' sites: bugs/pairs.dl's paths, ssa_ before each
         * relation; a file mini-ml's lowering refuses, none) *)
        if !bugs then begin
          (* (the units it names in each of the program's directories,
           * _mk's generated parsers, a subfolder's) *)
          let own_dirs = List.sort_uniq compare (List.map (fun f -> Fpath.parent (path f)) ml) in
          let dirs = own_dirs @ incs @ Ml_front.library caps !lib in
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
        (* (what they call would be reported dead) *)
        if !dead || !ambient then List.iter (fun m -> Console.eprint caps ("not read: " ^ m ^ "\n"); incr failed) !Ml_front.unread;
        if !ambient || !bugs then
          Hashtbl.iter (fun u () -> given p "own_unit" [ C.Facts.Sym u ]; given p "own_init" [ C.Facts.Sym (u ^ ":init") ]) Ml_front.own;
        if !only then Console.print caps (Buffer.contents text)
        else begin
          ignore (Datalog_eval.run ~naive:false p);
          if !ambient then caps_report caps p
          else if !exns then exn_report caps p
          else if !dead then dead_report caps p (ml <> [])
          else if !bugs && c <> [] && ml <> [] then raises_report caps p
          else if !bugs && c = [] then bugs_report caps p
          else begin
            if c <> [] then report caps p;
            if ml <> [] then ml_report caps p
          end;
          if !fingerprint then Console.print caps ("fingerprint of the answers: " ^ Answers.hex (Answers.fingerprint p) ^ "\n")
        end;
        if !failed > 0 then 1 else 0
      with
      | D.Error (msg, at) -> Console.eprint caps (Printf.sprintf "%s: %s\n" at msg); 1
      | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
