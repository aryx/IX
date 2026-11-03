(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze.mli *)

module D = Datalog

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr >

let usage = "usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-L lib] [-facts] [-flow] [-dflow] [-dead] [-caps] [-exn] [-bugs] [-root f]... file.c|file.ml...   (-h: how)"

let help = {|usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-L lib] [-facts] [-flow] [-dflow] [-dead] [-caps] [-exn] [-bugs] [-root f]... file.c|file.ml...
The C files read as one program, each call through a pointer said with the
functions it may reach, by an analysis of where each pointer may point
(points_to/'s: Andersen's first pass, then a context file, -context):
  mini-analyze -r lib_code/datalog -I include prog/*.c
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
(docs/plans/plan_bug_analyses.md; C's are bugs/pointers.dl's, above):
  Before.ml:6: physeq: in Before.loop, != of a Some made there: always true
  Css.ml:13: stack: Css.components calls itself, not a tail call, over a list
  Process.ml:46: swallowed: in fork, Sys_error silenced, a constant answered
  given C files and ML ones (the runtime's, lib_core's): each external's
  [@@raise E] against what its C raises (bugs/raises.dl)
-root f: f is also entered from where the facts do not go (assembly)
-context file: of points_to/, C's (call1_heap1), -exn's (call1_rec) and
  -bugs's (insensitive); the sharper, the longer
-library: every function may be called from outside, not main alone: a runtime
  ML calls, a library; without it what main does not reach is not looked at
-r: the directory of points_to/ and the .dl files (lib_code/datalog)
-I, -D: as mini-cc's; -L: lib_core's directory (lib_core); -facts: the facts
made, not the analysis; -alone: an ML file's own facts, without those of the
library units it names
-flow: ML's files each as its functions in SSA form, the facts of
lib_code/datalog/liveness_ssa.dl and dominators.dl (Ssa_facts, by mini-ml's
own way to its SSA: Ml_flow); C's as each function's stack code, the facts of
liveness.dl (Ir_facts, by mini-cc's simple back end: C_flow); -dflow: the
compiler's own liveness (ML's dominators too), to compare (analyzers/ml/tests/
and analyzers/c/tests/run.sh):
  mini-analyze -flow -L lib_core fact.ml > fact.dl
  mini-datalog -q 'live_in(V, B)' lib_code/datalog/liveness_ssa.dl fact.dl
  mini-analyze -flow hello.c > flow.dl
  mini-datalog -q 'across_call(V, P)' lib_code/datalog/liveness.dl flow.dl|}

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

let main (caps : < caps; .. >) (argv : string array) : int =
  let rules = ref "lib_code/datalog" and lib = ref "lib_core" and only = ref false and incs = ref [] and defs = ref [] and files = ref [] in
  let dead = ref false and ambient = ref false and roots = ref [] and context = ref "" and library = ref false in
  let fingerprint = ref false and exns = ref false and flow = ref false and dflow = ref false in
  let bugs = ref false in
  let options =
    Logging.flags
    @ [ ("-r", Arg.Set_string rules, " the directory of points_to/ and bugs/");
        ("-facts", Arg.Set only, " the facts, not the analysis");
        ("-alone", Arg.Set Ml_front.alone, " ML: the files' facts alone, not their library's units'");
        ("-flow", Arg.Set flow, " ML's functions in SSA form, C's stack code, as facts");
        ("-dflow", Arg.Set dflow, " the compiler's own liveness and dominators, as facts");
        ("-dead", Arg.Set dead, " what no run can reach, not the calls and the bugs");
        ("-caps", Arg.Set ambient, " whether ML's own functions hold the capabilities they need");
        ("-exn", Arg.Set exns, " the exceptions ML's toplevels may let escape");
        ("-bugs", Arg.Set bugs, " the bugs an ML program may have (plan_bug_analyses.md)");
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
        if !flow || !dflow then begin
          let dirs = incs @ Ml_front.library caps !lib in
          List.fold_left
            (fun status (f : string) ->
              let c own =
                C.C_flow.file caps ~own (List.rev !defs, incs) (path f) in
              (* (C's: mini-cc's stack code, Ir_facts) *)
              if Filename.check_suffix f ".c" then
                let none = Ok "" in
                match (if !flow then c false else none),
                      (if !dflow then c true else none) with
                | Ok a, Ok b -> Console.print caps (a ^ b); status
                | Error m, _ | _, Error m -> Console.eprint caps (m ^ "\n"); 1
              else
              match Ml_flow.file caps dirs (path f) with
              | Ok fns ->
                  if !flow then List.iter (fun fn -> Console.print caps (Ssa_facts.func fn)) fns;
                  if !dflow then List.iter (fun fn -> Console.print caps (Ssa_facts.own fn)) fns;
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
                 "bugs/physeq.dl"; "bugs/stack.dl"; "bugs/swallowed.dl" ]
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
        (* (what they call would be reported dead) *)
        if !dead || !ambient then List.iter (fun m -> Console.eprint caps ("not read: " ^ m ^ "\n"); incr failed) !Ml_front.unread;
        if !ambient then
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
