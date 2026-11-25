(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze.mli *)

module F = Analyze_flags

let usage =
  "usage: mini-analyze [-dead|-caps|-exn|-bugs] [flags] program... | file...\n\
  \  (a program: x.exe, x.manifest, a directory; a file: x.c, x.ml; -help)"

let help = {|usage: mini-analyze [-dead|-caps|-exn|-bugs] [flags] program... | file...
What a C or ML program may do, by its facts and analyzers/datalog's rules
(docs/man/1/analyze.md says each analysis and flag):
  mini-analyze prog/*.c                 calls through pointers, their bugs
  mini-analyze -dead tiny/TinyShell.exe what no run reaches, as dune links it
  mini-analyze -caps Log.ml Main.ml     capabilities held, needed, unused
  mini-analyze -exn Main.exe            exceptions its toplevels may let escape
  mini-analyze -bugs Main.exe           bugs that may be (stack, leak, order...)
A program is best given by its build: a dune executable, a tiny-ld
manifest (-map's), a directory of either; its files as linked, its
platform's, no -L, -I, -own to give; several, each run and merged:
  mini-analyze -dead -sources tiny tiny/TinyKernel/_make/src tiny
A library's file and its programs (or the file alone: those naming it):
  mini-analyze -dead tiny/TinyLibGUI.ml tiny/TinyKernel/_make/src/*.manifest
Or by its files, the library found or given (-L), the rest found too.
Flags:|}

let options (caps : < Cap.open_in; .. >) (f : F.t) :
    (string * Arg.spec * string) list =
  let set (a : F.analysis) = Arg.Unit (fun () -> f.analysis <- a) in
  let str (set : string -> unit) = Arg.String set in
  let on (set : unit -> unit) = Arg.Unit set in
  Logging.flags
  @ [ ("-dead", set Dead, " what no run can reach");
      ("-caps", set Caps,
       " whether ML's functions hold the capabilities they need");
      ("-exn", set Exn, " the exceptions ML's toplevels may let escape");
      ("-bugs", set Bugs, " the bugs an ML program may have");
      ("-sources", str (fun d -> f.sources <- d),
       " dir: a manifest's paths read there, the build having run in a copy");
      ("-r", str (fun d -> f.rules <- d), " dir: the rules (analyzers/datalog)");
      ("-L", str (fun d -> f.lib <- d),
       " dir: the standard library (found if not said)");
      ("-I", str (fun d -> f.incs <- f.incs @ [ d ]),
       " dir: C's #include's; ML: a library's units");
      ("-D", str (fun d -> f.defs <- f.defs @ [ d ]), " name=value, as #define");
      ("-own",
       str (fun d -> Ml_front.own_dirs := !Ml_front.own_dirs @ [ Fpath.v d ]),
       " dir: ML: the units found there are the program's own");
      ("-root", str (fun r -> f.roots <- r :: f.roots),
       " f: entered from where the facts do not go");
      ("-start", str (fun s -> f.start <- s),
       " units: their order of start (-bugs's init)");
      ("-context", str (fun c -> f.context <- c),
       " file: points_to/'s context (call1_heap1)");
      ("-library", on (fun () -> f.library <- true),
       " every function may be called from outside");
      ("-summary", str (fun s -> f.summary <- s),
       " file: the reports as facts, for a merge");
      ("-program", str (fun p -> f.program <- p),
       " name: the program's, in -summary's facts");
      ("-facts", on (fun () -> f.facts <- true), " the facts, not the analysis");
      ("-flow", on (fun () -> f.flow <- true),
       " the functions' code as facts (SSA, stack code)");
      ("-flow-answers", on (fun () -> f.answers <- true),
       " the compilers' liveness, dominators");
      ("-alone", Arg.Set Ml_front.alone, " ML: the files' facts, not their library's");
      ("-no-models", Arg.Clear Models.on,
       " ML: List's and Hashtbl's code, not their models");
      ("-summaries",
       str (fun (s : string) ->
           Logs.info (fun m -> m "summaries: %s" s);
           Models.derived_on := true;
           List.iter (fun (x, m) -> Hashtbl.replace Models.derived x m)
             (Summaries.of_text (FS.read caps (Fpath.v s)))),
       " file: ML: the library's summaries (analyzers/summaries/)");
      ("-fingerprint", on (fun () -> f.fingerprint <- true),
       " one number of every answer") ]

(* what each word not a flag is: a program by its build, or a file *)
let anon (caps : < Cap.readdir; .. >) (f : F.t) (a : string) : unit =
  if Filename.check_suffix a ".manifest" then f.manifests <- f.manifests @ [ a ]
  else if Filename.check_suffix a ".exe" then f.exes <- f.exes @ [ a ]
  else if Analyze_merge.directory caps a then f.dirs <- f.dirs @ [ a ]
  else f.files <- f.files @ [ a ]

let main (caps : < F.caps; .. >) (argv : string array) : int =
  let f : F.t =
    { analysis = Calls; files = []; manifests = []; exes = []; dirs = [];
      names = Hashtbl.create 64; sources = ""; args = []; rules = "analyzers/datalog";
      lib = ""; incs = []; defs = []; roots = []; start = ""; context = "";
      library = false; summary = ""; program = ""; facts = false; flow = false;
      answers = false; fingerprint = false } in
  (* (-Idir and -Dx in one word too, as mini-cc's) *)
  let split (a : string) : string list =
    let n = String.length a in
    if n > 2 && (String.sub a 0 2 = "-I" || String.sub a 0 2 = "-D") then
      [ String.sub a 0 2; String.sub a 2 (n - 2) ]
    else [ a ] in
  let argv = Array.of_list (List.concat_map split (Array.to_list argv)) in
  let options = options caps f in
  (* (the words read as programs or files, by their place: the flags
   * alone are the runs' of a merge) *)
  let current = ref 0 and taken = ref [] in
  let anon (a : string) : unit = taken := !current :: !taken; anon caps f a in
  match Arg.parse_argv ~current argv options anon usage with
  | exception Arg.Help _ -> Console.print caps (Arg.usage_string options help); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () ->
      f.args <-
        List.filteri (fun i _ -> i > 0 && not (List.mem i !taken)) (Array.to_list argv);
      (* (not a run of a merge's, nor the facts alone) *)
      let first = f.summary = "" && not f.facts in
      let one_ml =
        match f.files with [ x ] -> Filename.check_suffix x ".ml" | _ -> false in
      let built = List.length f.manifests + List.length f.exes in
      if f.summary = "" && Analyze_build.expand_dirs caps f then 1
      else if first && f.analysis = Dead && one_ml && built > 0 then
        Analyze_build.library caps f
      else if first && f.files = [] && (built >= 2 || f.dirs <> []) then
        Analyze_build.several caps f
      else if Analyze_build.read caps f then 1
      else
        (* (-dead on one .ml file some other names: its programs' found) *)
        let callers =
          if first && f.analysis = Dead && one_ml then
            Caller_finder.programs caps
              (List.map Fpath.to_string !Ml_front.own_dirs @ f.incs) (List.hd f.files)
          else [] in
        if callers <> [] then
          Analyze_merge.merged_runs caps f (Some (List.hd f.files))
            (List.map (fun m -> ("", m, [])) callers)
        else if f.files = [] then (Console.eprint caps (usage ^ "\n"); 1)
        else Analyze_one.run caps f
