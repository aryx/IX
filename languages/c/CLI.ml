(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let print = Console.print and eprint = Console.eprint

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-cc [-m 5|7] [-S] [-x] [-o out] [-Idir] [-Dname[=value]] file.c
5c and 7c's twin (-m 5: arm, the default; 7: arm64): a C file to its object,
x.5 (x.7) in the current directory as 5c (-o: another), for mini-ld; -S its
listing, 5c's byte for byte; -x each function's trees; 5c's other flags are
ignored. -simple: the back end whose contract is the behavior, a stack machine
(-dir prints its code; -O runs all of Opti's passes, -Oincs, -Oplaces... one).
With goken's libc (linker/tests/libc.sh 5 $PWD/w makes w/t/libc.a), and its
hello.c (~/goken/tests/c/hello_libc/), for example:
  G=~/goken/include; mini-cc -m 5 -I$G -I$G/ALL -I$G/arch/arm hello.c
  mini-ld -m 5 -o hello hello.5 w/t/libc.a
  mini-5i hello                   hello from libc.a: 2 + 2 = 4
An error names the file and the line: hello.c:5: syntax error
-facts: no object; the file as the facts of a pointer analysis (what is
assigned to what, who calls whom: Facts.mli), for mini-datalog:
  mini-cc -m 7 -facts hello.c > hello.dl
  mini-datalog -q 'call_edge(I, F)' languages/datalog/analyses/pointer.dl hello.dl
-flow: no object; each function's stack code as facts (who follows whom, the
variables read and written: Ir_facts.mli), for liveness by mini-datalog:
  mini-cc -m 7 -flow hello.c > flow.dl
  mini-datalog -q 'across_call(V, P)' languages/datalog/analyses/liveness.dl flow.dl
-dflow: the compiler's own liveness (Opti's regs), as facts, to compare.
|}

(* what the command asks of a back end: its hooks in the front end set
 * (after the front end's own state), a function's code, the file's
 * end, its listing and its object *)
type backend = {
  init : unit -> unit;
  codgen : Tree.sym -> Tree.stmt -> unit;
  finish : unit -> unit;
  listing : unit -> string;
  obj : Fpath.t -> Asm.obj;
  saved : bool;                       (* an object is written *)
}

(* 5c's and 7c's at -O0, byte for byte: the compat back end *)
let compat (mach : Tree.machine) : backend =
  ({
    init = (fun () ->
      (match mach.thechar with
       | '5' -> Regs.be := Some Arm.backend; Cgen.hooks := Some Arm.hooks
       | _ -> Regs.be := Some Arm64.backend; Cgen.hooks := Some Arm64.hooks);
      (* acom first: a pass of 5c's front end, the listing's *)
      Check.xcom := (fun n -> Cgen.xcom (Acom.acom n));
      Check.outstring := Emit.outstring;
      Declare.gextern := Emit.gextern;
      Emit.init ();
      Regs.init ());
    codgen = Cgen.codgen;
    finish = (fun () -> Regs.gclean (); Emit.gclean ());
    listing = Emit.listing;
    obj = Emit.obj;
    saved = true;
  })

(* the behavior only, a stack machine: the simple back end; with dir,
 * each function's stack machine code printed *)
let simple_backend (caps : < caps; .. >) ~dir ~opti : backend =
  ({
    init = (fun () ->
      Check.xcom := Lower.calls64;
      Check.outstring := Emit.outstring;
      Declare.gextern := Emit.gextern;
      Emit.init ());
    codgen = (fun f body ->
      let fn = Opti.run opti (Lower.func f body) in
      if dir then print caps (Lower.show_func fn);
      Gen.func fn;
      if List.mem "peep" opti then Peep.run ());
    finish = Emit.gclean;
    listing = Emit.listing;
    obj = Emit.obj;
    saved = true;
  })

(* no code: the file's facts, its listing (facts/Facts) *)
let facts_backend : backend =
  ({
    init = (fun () ->
      Check.xcom := (fun (n : Tree.expr) -> n);
      Check.outstring := (fun (_ : string) (_ : int) -> 0);
      Declare.gextern := (fun (s : Tree.sym) (x : Tree.expr) (_ : int) (_ : int) -> Facts.global s x);
      Emit.init ());
    codgen = Facts.func;
    finish = (fun () -> ());
    listing = Facts.text;
    obj = Emit.obj;
    saved = false;
  })

(* no code: each function's stack code as facts (facts/Ir_facts), after
 * Opti's passes but regs; own: what regs itself finds live, instead *)
let flow_backend ~(own : bool) : backend =
  let text = Buffer.create 1024 in
  let passes : string list = List.filter (fun (p : string) -> p <> "regs") (List.map fst Opti.passes) in
  ({
    init = (fun () ->
      Check.xcom := Lower.calls64;
      Check.outstring := Emit.outstring;
      Declare.gextern := Emit.gextern;
      Emit.init ());
    codgen = (fun (f : Tree.sym) (body : Tree.stmt) ->
      let fn = Opti.run passes (Lower.func f body) in
      Buffer.add_string text (if own then Ir_facts.own fn else Ir_facts.func fn));
    finish = (fun () -> ());
    listing = (fun () -> Buffer.contents text);
    obj = Emit.obj;
    saved = false;
  })

(* a front end's state is global: one file per run; the tokens are
 * read by Lexer, whose lexbuf is over Pre's input stack *)
(* (-x and -S together, -D and -I together: at most 7 parameters for
 * mini-ml on arm) *)
let compile (caps : < caps; .. >) (mach : Tree.machine) (be : backend) ~show:(dump, listing) ~out (defs, incs) file =
  Tree_helpers.mach := Some mach;
  Tree_helpers.init_types ();
  Pre.profile := true;
  Lexer.init ();
  let s = Tree_helpers.lookup ".string" in
  let t = Tree_helpers.typ Tree.Tarray (Some (Tree_helpers.ty Tree.Tchar)) in
  t.width <- 0;
  s.sclass <- Tree.Cstatic; s.typ <- Some t;
  List.iter Pre.dodefine defs;
  (* "." is the source's directory; <...> skips it *)
  Pre.includes := Fpath.parent file :: incs;
  Pre.read_file := FS.read_opt caps;
  be.init ();
  Declare.on_function := (fun (f : Tree.sym) body ->
    if dump then print caps (Prtree.prtree f.name body);
    be.codgen f body);
  match FS.read_opt caps file with
  | None -> Error (Printf.sprintf "cannot open %s" (Fpath.to_string file))
  | Some text ->
      Pre.push text;
      Tree_helpers.lineno := 1;
      (match Parser.prog Lexer.token (Lexer.lexbuf ()) with
       | () ->
           be.finish ();
           if listing then print caps (be.listing ());
           if be.saved then Asm.save caps out (be.obj file);
           Ok ()
       | exception Tree_helpers.Error m -> Error (Printf.sprintf "%s:%s" (Fpath.to_string file) m)
       | exception Parsing.Parse_error -> Error (Printf.sprintf "%s:%d: syntax error" (Fpath.to_string file) !Tree_helpers.lineno))

let main (caps : < caps; .. >) (argv : string array) : int =
  let mach = ref Machines.arm and simple = ref false and facts = ref false and flow = ref false and dflow = ref false and dir = ref false and opti = ref [] and dump = ref false and listing = ref false and out = ref "" and defs = ref [] and incs = ref [] and files = ref [] in
  let rec args = function
    | "-m" :: "5" :: rest -> mach := Machines.arm; args rest
    | "-m" :: "7" :: rest -> mach := Machines.arm64; args rest
    | "-simple" :: rest -> simple := true; args rest
    | "-facts" :: rest -> facts := true; listing := true; args rest
    | "-flow" :: rest -> flow := true; listing := true; args rest
    | "-dflow" :: rest -> dflow := true; listing := true; args rest
    | "-dir" :: rest -> dir := true; args rest
    | "-O" :: rest -> opti := "peep" :: List.map fst Opti.passes; args rest
    | o :: rest when String.length o > 2 && String.sub o 0 2 = "-O"
                     && (let p = String.sub o 2 (String.length o - 2) in p = "peep" || List.mem_assoc p Opti.passes) ->
        opti := String.sub o 2 (String.length o - 2) :: !opti; args rest
    | "-x" :: rest -> dump := true; args rest
    | "-o" :: o :: rest -> out := o; args rest
    | "-S" :: rest -> listing := true; args rest
    | "-I" :: d :: rest -> incs := d :: !incs; args rest
    | "-D" :: d :: rest -> defs := d :: !defs; args rest
    | a :: rest when String.length a > 2 && String.sub a 0 2 = "-I" -> incs := String.sub a 2 (String.length a - 2) :: !incs; args rest
    | a :: rest when String.length a > 2 && String.sub a 0 2 = "-D" -> defs := String.sub a 2 (String.length a - 2) :: !defs; args rest
    | a :: rest when String.length a > 1 && a.[0] = '-' -> args rest   (* 5c's other flags: -w, -F, -V... *)
    | f :: rest -> files := f :: !files; args rest
    | [] -> ()
  in
  let argl = List.tl (Array.to_list argv) in
  if List.mem "-h" argl || List.mem "--help" argl then (print caps help; 0) else begin
  args argl;
  let path s = match FS.path s with Ok p -> p | Error m -> failwith m in
  match List.map path !files, List.map path (List.rev !incs) with
  | [ file ], incs -> (
      (* x.c to x.5, in the current directory, as 5c *)
      let out = if !out <> "" then path !out else Fpath.set_ext ("." ^ String.make 1 !mach.thechar) (Fpath.base file) in
      match compile caps !mach (if !facts then facts_backend else if !flow || !dflow then flow_backend ~own:!dflow else if !simple then simple_backend caps ~dir:!dir ~opti:!opti else compat !mach) ~show:(!dump, !listing) ~out (List.rev !defs, incs) file with
      | Ok () -> 0
      | Error m -> eprint caps (m ^ "\n"); 1)
  | exception Failure m -> eprint caps ("mini-cc: " ^ m ^ "\n"); 1
  | _, _ -> eprint caps "usage: mini-cc -m 5|7 [-simple [-dir] [-O|-Opass]] [-facts] [-flow] [-x] [-S] [-Idir] [-Dname=value] [-o out] file.c   (-h: how)\n"; 1
  end
