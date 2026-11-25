(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze_one.mli *)

module D = Datalog
module C = Ix_analyze_c
module F = Analyze_flags

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* a file's unit: Bugs.ml, Bugs *)
let unit_of_file (f : string) : string =
  String.capitalize_ascii (Filename.remove_extension (Filename.basename f))

let sym (s : string) : C.Facts.arg = C.Facts.Sym s

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
    let mine = List.map unit_of_file ml in
    Hashtbl.iter
      (fun (u : string) _ ->
        if read u && not (List.mem u mine) then List.iter (before u) mine)
      Ml_front.files
  end;
  Hashtbl.iter
    (fun (u : string) (fs : string list) ->
      List.iter (fun (f : string) -> fact "unit_file" [ sym u; sym f ]) fs)
    Ml_front.homes

(* the standard library when none is found: the analyzer's tree's *)
let lib_core (f : F.t) : string =
  if f.home = "." then "lib_core" else Filename.concat f.home "lib_core"

let path (s : string) : Fpath.t =
  match FS.path s with Ok p -> p | Error m -> failwith m

(* the files' directories *)
let parents (files : string list) : Fpath.t list =
  List.sort_uniq compare (List.map (fun x -> Fpath.parent (path x)) files)

(*****************************************************************************)
(* -flow, -flow-answers *)
(*****************************************************************************)

(* each file's functions as facts: ML's in SSA form (Ml_flow), C's as
 * mini-cc's stack code (C_flow); the compilers' own answers on them *)
let flow (caps : < F.caps; .. >) (f : F.t) : int =
  let incs = List.map path f.incs in
  let mls = List.filter (fun x -> not (Filename.check_suffix x ".c")) f.files in
  let dirs =
    parents mls @ (if mls = [] then incs else Ml_front.search caps f.lib incs) in
  List.fold_left
    (fun (status : int) (file : string) ->
      let c (own : bool) = C.C_flow.file caps ~own (f.defs, incs) (path file) in
      if Filename.check_suffix file ".c" then
        let none = Ok "" in
        match (if f.flow then c false else none),
              (if f.answers then c true else none) with
        | Ok a, Ok b -> Console.print caps (a ^ b); status
        | Error m, _ | _, Error m -> Console.eprint caps (m ^ "\n"); 1
      else
        match Ml_flow.file ~sites:true caps dirs (path file) with
        | Ok fns ->
            let unit_name = unit_of_file file in
            let print (s : string) : unit = Console.print caps s in
            if f.flow then List.iter (fun fn -> print (Ssa_facts.func ~unit_name fn)) fns;
            if f.answers then List.iter (fun fn -> print (Ssa_facts.own fn)) fns;
            status
        | Error m -> Console.eprint caps (m ^ "\n"); 1)
    0 f.files

(*****************************************************************************)
(* The analysis *)
(*****************************************************************************)

(* the rules an analysis loads, of datalog/; c and ml: the program has C
 * files, ML files *)
let rule_files (f : F.t) ~(c : bool) ~(ml : bool) : string list =
  let points_to = [ "points_to/instructions.dl"; "points_to/contexts.dl" ] in
  let context = "points_to/" ^ f.context ^ ".dl" in
  match f.analysis with
  | Dead -> points_to @ [ "points_to/insensitive.dl"; "dead.dl" ]
  | Caps -> points_to @ [ "points_to/insensitive.dl"; "dead.dl"; "capabilities.dl" ]
  | Bugs when c && ml -> [ "bugs/raises.dl" ]
  | Bugs when not c ->
      points_to @ [ context; "exceptions.dl" ]
      @ List.map (fun b -> "bugs/" ^ b ^ ".dl")
          [ "physeq"; "stack"; "swallowed"; "intwidth"; "order"; "init";
            "races"; "pairs"; "unused"; "layout"; "evalorder" ]
  | Exn ->
      [ "points_to/instructions.dl"; "points_to/andersen.dl";
        "points_to/contexts.dl"; context; "exceptions.dl" ]
  | Bugs | Calls ->
      [ "points_to/instructions.dl"; "points_to/andersen.dl" ]
      @ (if c then [ "points_to/contexts.dl"; context; "bugs/pointers.dl" ] else [])
      @ if ml then [ "calls.dl" ] else []

(* the program's own files in SSA form, their calls named as
 * Closure_facts' sites: bugs/pairs.dl's paths, ssa_ before each
 * relation; a file mini-ml's lowering refuses, none *)
let ssa_facts (caps : < F.caps; .. >) (p : D.t) (f : F.t) (ml : string list) :
    unit =
  (* (the units it names in each of the program's directories, _mk's
   * generated parsers, a subfolder's) *)
  let dirs = parents ml @ Ml_front.search caps f.lib (List.map path f.incs) in
  List.iter
    (fun (file : string) ->
      let unit_name = unit_of_file file in
      match Ml_flow.file ~sites:true caps dirs (path file) with
      | Ok fns ->
          List.iter (fun fn ->
              D.load p ~from:file (Ssa_facts.func ~prefix:"ssa_" ~unit_name fn))
            fns
      | Error m -> Logs.info (fun l -> l "no SSA: %s" m))
    ml

(* the facts evaluated, -v's and -debug's counts said *)
let evaluate (p : D.t) : unit =
  let relations =
    List.sort
      (fun (a : D.relation) (b : D.relation) -> compare (a.name, a.arity) (b.name, b.arity))
      (Hashtbl.fold (fun _ r acc -> r :: acc) p.relations []) in
  let count f = List.fold_left (fun n r -> n + f r) 0 relations in
  Logs.info (fun m ->
      m "evaluating, in this process (mini-datalog's engine): %d rules, %d facts \
         in %d relations"
        (List.length p.rule_list) (count (fun r -> r.count)) (List.length relations));
  let st = Datalog_eval.run ~naive:false p in
  Logs.info (fun m ->
      m "evaluated: %d rounds, %d firings, %d tuples derived"
        st.rounds st.firings st.derived);
  List.iter
    (fun (r : D.relation) ->
      Logs.debug (fun m ->
          m "%s/%d: %d tuples (%d given), %d rules, stratum %d"
            r.name r.arity r.count r.given r.rules r.stratum))
    relations

(* -dead on one program by its build: the components it reported on *)
let components_note (caps : < F.caps; .. >) : unit =
  if Hashtbl.length Ml_front.components > 0 then begin
    let units =
      List.sort compare (Hashtbl.fold (fun u () acc -> u :: acc) Ml_front.components []) in
    Console.print caps
      ("(on the program's own files alone, not its libraries':\n"
       ^ String.concat "\n" (Analyze_merge.wrapped units)
       ^ "\n a library's dead code: mini-analyze -dead its file, over its programs)\n")
  end

let analyze (caps : < F.caps; .. >) (f : F.t) : int =
  let failed = ref 0 in
  let failure (m : string) : unit = Console.eprint caps (m ^ "\n"); incr failed in
  let incs = List.map path f.incs in
  let p = D.create () in
  let ml, c = List.partition (fun x -> Filename.check_suffix x ".ml") f.files in
  let text = Buffer.create 4096 in
  let fact =
    if f.facts then
      (fun r args -> Buffer.add_string text (Analyze_merge.line r args ^ "\n"))
    else C_report.given p in
  let given = C_report.given p in
  if not f.facts then
    List.iter
      (fun (r : string) ->
        let rules = Fpath.append (path f.rules) (Fpath.v r) in
        Logs.info (fun m -> m "rules: %s" (Fpath.to_string rules));
        D.load p ~from:(Fpath.to_string rules) (FS.read caps rules))
      (rule_files f ~c:(c <> []) ~ml:(ml <> []));
  List.iter (fun (r : string) -> given "entry" [ sym r ]) f.roots;
  if f.library then D.load p ~from:"-library" "entry(F) :- function(F).\n";
  (* (the facts as found, Facts' and Closure_facts', to the program) *)
  C.Facts.added := fact;
  Closure_facts.added :=
    (fun r args ->
      fact r
        (List.map (function
             | Closure_facts.Sym s -> C.Facts.Sym s
             | Closure_facts.Num n -> C.Facts.Num n)
           args));
  List.iter
    (fun (file : string) ->
      Logs.info (fun m -> m "reading %s" file);
      (* (its own flags, a manifest's, else the command line's) *)
      let defs, incs =
        match Hashtbl.find_opt f.cflags file with
        | Some (d, i) -> (d, List.map path i)
        | None -> (f.defs, incs) in
      match C.C_front.file caps (defs, incs) (path file) with
      | Ok () -> ()
      | Error m -> failure m)
    c;
  if ml <> [] then
    List.iter failure
      (Ml_front.program caps (Ml_front.search caps f.lib incs) (List.map path ml));
  (* (with the units -own found: the program's files, for -bugs's start
   * order and SSA form as the files given) *)
  let ml =
    ml
    @ List.sort compare
        (Hashtbl.fold
           (fun (u : string) (file : string) acc ->
             if file <> "" && Hashtbl.mem Ml_front.own u && not (List.mem file ml)
             then file :: acc
             else acc)
           Ml_front.files []) in
  if f.analysis = Bugs then begin
    start_facts given f.start ml;
    ssa_facts caps p f ml;
    Hashtbl.iter
      (fun (u : string) (file : string) ->
        List.iter (fun (d : string) -> given "unit_dir" [ sym u; sym d ])
          (dirs_from caps f.lib file))
      Ml_front.files
  end;
  (* (dead.dl's: what a unit read by its interface alone may build) *)
  if f.analysis = Dead then
    List.iter (fun (x : string) -> given "built_outside" [ sym x ])
      (List.sort_uniq compare !Ml_front.built_outside);
  (* (what they call would be reported dead; -exn's and -bugs's reports
   * through them would be missing, gone from a recording) *)
  if f.analysis <> Calls then
    List.iter (fun m -> failure ("not read: " ^ m)) !Ml_front.unread;
  if f.analysis = Caps || f.analysis = Bugs then
    Hashtbl.iter (fun u () ->
        given "own_unit" [ sym u ];
        given "own_init" [ sym (u ^ ":init") ];
        (* (a unit's init by its unit, for -caps's system units) *)
        given "unit_init" [ sym u; sym (u ^ ":init") ])
      Ml_front.own;
  if f.facts then Console.print caps (Buffer.contents text)
  else begin
    (* (the engine is mini-datalog's, linked in: no program is run, and
     * the facts are added to it directly, never written out) *)
    evaluate p;
    let dead_reports = ref [] in
    let said =
      match f.analysis with
      | Caps -> Caps_report.caps_report caps p
      | Exn -> Exn_report.exn_report caps p
      | Dead ->
          dead_reports := Dead_report.dead_report caps p (ml <> []);
          components_note caps;
          []
      | Bugs when c <> [] && ml <> [] -> Bugs_report.raises_report caps p
      | Bugs when c = [] -> Bugs_report.bugs_report caps p
      | Bugs | Calls ->
          if c <> [] then C_report.report caps p;
          if ml <> [] then Ml_report.ml_report caps p;
          [] in
    if f.summary <> "" then
      Analyze_merge.summary caps f.summary
        (if f.program <> "" then f.program else List.hd f.files)
        f.files !dead_reports said;
    if f.fingerprint then
      Console.print caps
        ("fingerprint of the answers: " ^ Answers.hex (Answers.fingerprint p) ^ "\n")
  end;
  if !failed > 0 then 1 else 0

let run (caps : < F.caps; .. >) (f : F.t) : int =
  (* (no -L: the standard library nearest the first ML file, tiny's
   * TinyLibCore for tiny/'s programs, lib_core for ix's) *)
  if f.lib = "" then
    f.lib <-
      (match List.find_opt (fun x -> Filename.check_suffix x ".ml") f.files with
       | Some x -> (
           match Module_finder.library caps x with Some d -> d | None -> lib_core f)
       | None -> lib_core f);
  (* (-exn's: a recursive call in its caller's context, else
   * List.fold_left's callers are one: exceptions.dl's design note) *)
  if f.context = "" then
    f.context <-
      (match f.analysis with
       | Exn -> "call1_rec"
       | Bugs -> "insensitive"
       | _ -> "call1_heap1");
  try if f.flow || f.answers then flow caps f else analyze caps f with
  | D.Error (msg, at) -> Console.eprint caps (Printf.sprintf "%s: %s\n" at msg); 1
  | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1
