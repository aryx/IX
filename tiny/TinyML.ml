(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * testing:
 * tests/TinyML_test.sh: a program prints exactly what OCaml's ocamlopt
 * makes it print (the recorded ones were ocaml-light's on arm64, whose
 * back end this compiler also had until plan_tiny_self_hosting.md).
 *)

open TinyMLTree
module Parser = TinyMLParser
module Asm = TinyMachineAsm
open TinyMLTypes
open TinyMLMachine
open TinyMLCompile

let usage = {|usage: tiny-ml [-L dir | -nostdlib] [-o out.tm] file.ml...
       | tiny-ml -c [-o out.tm] file.tmi... file.ml
       | tiny-ml -o main.tm file.tmi...|}

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A tiny ML compiler: an ML file (its own small dialect: a file a module, no
functors nor labels) to tiny-machine's assembly, for tiny-cpu, on stdout
without -o. A fact.ml, for example:
  let rec fact n = if n = 0 then 1 else n * fact (n - 1)
  let () = print_string "fact 10 = "; print_int (fact 10); print_newline ()
  tiny-ml -o fact.tm fact.ml               ml_start: ldw r12, 0(sp) ...
  tiny-c -o main.tm main.c
  L=tiny/TinyCRuntime
  for f in $L/start $L/udivmod exit fact main
  do tiny-assembler -o $f.o $f.tm; done
  tiny-linker -o fact $L/start.o $L/udivmod.o exit.o fact.o main.o \
    /lib/ml/*.o
  tiny-cpu fact                            fact 10 = 3628800
main.c includes tiny/TinyMLRuntime/core.c and gives it memory (ml_run),
exit.tm is exit (sys 0), as tiny/tests/TinyML_test.sh makes them. The
standard library, TinyLibCore/'s modules, is read from /lib/ml (-L: another
directory), its interfaces Stdlib.tmi ... Sha1.tmi, and linked from there,
each module compiled once by tiny-ml -c -nostdlib after the ones before it.
Several files are a module each, one after the other, then their main: a's
x is A.x in b, or x after open A. Or a module at a time, then the main:
  tiny-ml -c a.ml                          a.tm, its code; a.tmi, its interface
  tiny-ml -c a.tmi b.ml                    b.tm and b.tmi, after a
  tiny-ml -o main.tm a.tmi b.tmi           the library's, a's and b's init,
                                           ml_start
  (linked: ... main.o a.o b.o and the library's; what nothing uses left out by
  tiny-linker)
An error names the file and the line: fact.ml: line 2: this has type int ...
|}

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

(* A unit: its toplevel in <unit>.init, its names that are not static
 * (a value computed, a closure allocated) in its globals' table,
 * <unit>.globals, the collector's roots. What nothing uses is left out
 * by tiny-linker, piece by piece (a function, a static block): a
 * function of the toplevel has no free variable, so its closure is
 * static and the init names it not (old: prune, the program's
 * toplevel lets that nothing used dropped before the code was made,
 * when a program was compiled whole: a library cost a program only
 * what it called, which the link's pieces now do) *)
let compile_unit (items : (item * int) list) =
  start_fun 1 0;
  arities := [];
  let table = !unit_name ^ ".globals" and nglobals = ref 0 in
  let rec arity = function TE ("->", [ _; r ]) -> 1 + arity r | _ -> 0 in
  let defs = List.fold_left (fun defs (it, l) ->
    try
      match it with
      | IOpen u -> opened globals u; defs
      | IAlias (a, u) -> aliased globals a u; defs
      | IExt (x, t, p) ->
          let b = Ext (p, arity t) in
          add_name globals x b;
          (x, b) :: defs
      | IExn c ->
          block (exn_id c) (header 1 0) [ DVal (static_string c) ];
          if (find_con c).arity = 0 then
            block (exn_const c) (header 1 0) [ DVal (exn_id c) ];
          defs
      | ILet (r, bs) ->
          (* (the names it adds, in the table: old, the env's first
           * names, counted) *)
          let added = List.map (function
            | x, Loc (Slot s, k) ->
                emit (Get s);
                emit (SetG (table, !nglobals));
                incr nglobals;
                x, Loc (Glob (table, !nglobals - 1), k)
            | b -> b) (bind [] r bs) in
          List.iter (fun (x, b) -> add_name globals x b) (List.rev added);
          added @ defs
    with Failure m -> TinyMLLexer.error (Printf.sprintf "line %d: %s" l m))
    [] items in
  emit (Imm (tagged 0));
  emit Ret;
  finish_fun (!unit_name ^ ".init") 0;
  let rec drain () =
    match dequeue () with Some f -> f (); drain () | None -> () in
  drain ();
  defs, !nglobals

(* The program's main: ml_init, each unit's init in their order, in a
 * handler that prints an uncaught exception; the curry functions the
 * units need; the globals' tables one after the other, ml_globals, and
 * their count, ml_nglobals (what TinyMLRuntime/core.c scans) *)
let compile_main (units : (string * int) list) needed =
  unit_name := "ml";
  start_fun 1 1;
  let handler = label () in
  emit (TryEnter (0, handler));
  List.iter (fun (u, _) ->
      emit (Imm (tagged 0));
      emit (Call (Direct (u ^ ".init"), 0, false));
      emit Drop)
    units;
  emit (TryExit 0);
  emit (Imm (tagged 0));
  emit Ret;
  emit (Label handler);
  emit (Catch 0);
  emit (CallC ("ml_uncaught", 1));
  emit Ret;
  finish_fun "ml_init" 0;
  List.iter (fun n -> for k = 0 to n - 1 do curry_fun n k done)
    (List.sort_uniq compare needed);
  let total = List.fold_left (fun t (_, n) -> t + n) 0 units in
  words "ml_nglobals" [ DNum (Int64.of_int total) ];
  out data
    ([ Asm.Piece; Asm.Label "ml_globals" ]
     @ List.concat_map (fun (u, n) ->
         [ Asm.Label (u ^ ".globals"); Asm.Space (4 * n) ]) units
     @ (if total = 0 then [ Asm.Space 4 ] else []))

(*****************************************************************************)
(* Interfaces *)
(*****************************************************************************)

(* A unit's interface, M.tmi, what a unit compiled after it reads (as
 * OCaml's .cmi): its globals' count and the curry functions it needs;
 * the types, constructors, labels and abbreviations it added; each of
 * its names, where its value is (a static closure and its code, a
 * global, a primitive) and its type, M.mli's when there is one. A
 * record, Marshal's bytes (OCaml's on the host, the runtime's on
 * tiny-kernel: the same), a type in it as a type expression, its
 * variables 'v<number>, read as a type anew (of_texpr), as the text
 * was.
 * (old: a line each, printed and parsed again: half of a small unit's
 * compile was reading the interfaces) *)
(* (at most 7 fields, as each block in it: OCaml 5's Marshal writes a
 * block of 8 or more with two bits of its header set, 4.14's and
 * TinyLibCore's do not, and the host's interface was not tiny-kernel's
 * (bugs/ix.md). old: iname, iglobals, icurry, three fields of eight) *)
(* (tuples, as cinfo's and linfo's fields but the type, which Marshal
 * writes as records: the same blocks) *)
(* a constructor: its name, kind, arity, its type's constant and other
 * constructors' counts, its type *)
type icon = string * kind * int * int * int * texpr
(* a label: its name, its record's type, its index, mutable, the
 * record's labels, its type *)
type ilabel = string * string * int * bool * string list * texpr

type interface = {
  iunit : string * int * int list;  (* its name, globals, curry functions *)
  icons : icon list;
  ilabels : ilabel list;
  iabbrevs : (string * (string list * texpr)) list;
  iforgotten : string list;
  ivals : (string * binding * texpr) list;
}

(* a type as its expression: what is linked followed, a variable by its
 * number *)
let rec texpr_of_ty t =
  match repr t with
  | TVar { contents = Unbound (n, _) } -> TEVar ("v" ^ string_of_int n)
  | TCon (c, ts) -> TE (c, List.map texpr_of_ty ts)
  | TVar _ -> TE ("?", [])

(* what the program's tables held before a unit: its interface has only
 * what the unit added, as OCaml's .cmi (old: the whole program's so far,
 * each unit's .tmi repeating every one before it, all read again by
 * each unit after: 310 KB of interfaces for tiny-kernel's programs) *)
type before = {
  old_con : string -> cinfo -> bool;
  old_label : string -> linfo -> bool;
  old_abbrev : string * (string list * texpr) -> bool;
  old_forgotten : string -> bool;
}

let snapshot () : before =
  let c = Hashtbl.copy cons and l = Hashtbl.copy record_labels
  and a = !Parser.abbreviations and f = !Parser.forgotten in
  { old_con = (fun k ci ->
      match Hashtbl.find_opt c k with Some ci' -> ci' == ci | None -> false);
    old_label = (fun k li -> List.memq li (Hashtbl.find_all l k));
    old_abbrev = (fun ab -> List.memq ab a);
    old_forgotten = (fun t -> List.mem t f) }

let write_interface (old : before) (exports : (string * binding) list) types
    nglobals =
  (* the tables by their names, a label's records the latest first, as
   * the table has them (old: Hashtbl.iter's order, which is OCaml's
   * or TinyLibCore's: an interface was not the same from the two
   * builds of tiny-ml) *)
  let names tbl =
    List.sort_uniq compare (Hashtbl.fold (fun k _ acc -> k :: acc) tbl []) in
  let icons = List.filter_map (fun c ->
    let ci = Hashtbl.find cons c in
    if old.old_con c ci then None
    else
      Some (c, ci.kind, ci.arity, ci.nconst, ci.nblock, texpr_of_ty ci.scheme))
    (names cons) in
  let ilabels = List.concat_map (fun l -> List.filter_map (fun li ->
    if old.old_label l li then None
    else
      Some (l, li.lrec, li.idx, li.mut, li.lnames, texpr_of_ty li.lscheme))
    (Hashtbl.find_all record_labels l)) (names record_labels) in
  (* a name defined twice: the later, first in exports, as OCaml's
   * shadowing (old: both, the earlier read last, so the one the units
   * after saw, with the later's type: www's trap, bugs/ix.md) *)
  let seen = Hashtbl.create 64 in
  let ivals = List.filter_map (fun (x, bd) ->
    if Hashtbl.mem seen x then None
    else begin
      Hashtbl.add seen x ();
      match List.assoc_opt x types, bd with
      | Some t, (Loc ((Static _ | Glob _), _) | Ext _) ->
          Some (qualify !unit_name x, bd, texpr_of_ty t)
      | _ -> None
    end) exports in
  Marshal.to_string
    { iunit = !unit_name, nglobals, !arities; icons = icons; ilabels = ilabels;
      iabbrevs =
        List.filter (fun a -> not (old.old_abbrev a))
          (List.rev !Parser.abbreviations);
      iforgotten =
        List.filter (fun t -> not (old.old_forgotten t)) !Parser.forgotten;
      ivals = ivals }
    (* (No_sharing: which of two equal names is the same string depends
     * on a table's order, OCaml's or TinyLibCore's; shared, the host's
     * and tiny-kernel's interfaces differed in 3 of the system's 40) *)
    [ Marshal.No_sharing ]

(* an interface read: its types the program's, its names in the tables
 * (globals, tglobals); its unit's name, globals and curry functions *)
let read_interface (chan : Chan.i) =
  let text = In_channel.input_all chan.ic in
  if String.length text < 4 || String.sub text 0 4 <> "\132\149\166\190" then
    TinyMLLexer.error "not an interface of tiny-ml's";
  let (i : interface) = Marshal.from_string text 0 in
  let iname, iglobals, icurry = i.iunit in
  let ty te = of_texpr (ref []) te in
  known_units := iname :: !known_units;
  List.iter (fun (c, kind, arity, nconst, nblock, te) ->
      Hashtbl.replace cons c
        { kind = kind; arity = arity; nconst = nconst; nblock = nblock;
          scheme = ty te })
    i.icons;
  List.iter (fun (l, r, idx, mut, lnames, te) ->
    let others =
      List.filter (fun li -> li.lrec <> r) (Hashtbl.find_all record_labels l) in
    while Hashtbl.mem record_labels l do Hashtbl.remove record_labels l done;
    List.iter (Hashtbl.add record_labels l) (List.rev others);
    Hashtbl.add record_labels l
      { lrec = r; idx = idx; mut = mut; lnames = lnames; lscheme = ty te })
    i.ilabels;
  List.iter (fun (t, (ps, te)) ->
    Parser.abbreviations :=
      (t, (ps, te))
      :: List.filter
           (fun (t', (ps', _)) -> t' <> t || List.length ps' <> List.length ps)
           !Parser.abbreviations)
    i.iabbrevs;
  List.iter (fun t ->
      if not (List.mem t !Parser.forgotten) then Parser.forgotten := t :: !Parser.forgotten)
    i.iforgotten;
  (* (a val's name is M.x already; Stdlib's x too) *)
  let n = String.length iname in
  List.iter (fun (x, b, te) ->
    let t = ty te in
    List.iter (fun x -> Hashtbl.replace globals x b; Hashtbl.replace tglobals x t)
      (if implicit iname then
         [ x; String.sub x (n + 1) (String.length x - n - 1) ]
       else [ x ]))
    i.ivals;
  (iname, iglobals), icurry

(* a file's text *)
let text_of (chan : Chan.i) = In_channel.input_all chan.ic

(* a file's unit: its name without the directory and the extension,
 * capitalized, as OCaml's module *)
let unit_of (f : Fpath.t) =
  String.capitalize_ascii (Fpath.to_string (Fpath.rem_ext (Fpath.base f)))

(* the standard library, TinyLibCore/'s modules in their order, the
 * first units of every program: each compiled once, by tiny-ml -c
 * -nostdlib after the ones before it, and read as interfaces from a
 * directory, /lib/ml on tiny-kernel (-L another), its objects
 * linked as any unit's.
 * (old: their text the compiler's, TinyMLPrelude.ml made of them by the
 * build, compiled again at each run: a unit of one line took 47 s on
 * tiny-kernel, and every program's main the library's code, 420 KB of
 * assembly;
 * older: the prelude, TinyLibCore.ml, one unit, its List.map a name
 * with a dot) *)
let library =
  [ "Stdlib"; "Char"; "Seq"; "List"; "String"; "Bytes"; "Array"; "Option";
    "Int64"; "Filename"; "Buffer"; "Printf"; "Marshal"; "Hashtbl"; "Common";
    "Sha1"; "Fpath"; "Fpath_"; "Exit"; "In_channel"; "Out_channel";
    "Chan"; "Logs" ]

(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

open Fpath_.Operators

let main (caps : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    (argv : string array) : Exit.t =
  let output = ref None and file = ref "" and files = ref []
  and separate = ref false and lib = ref (Some "/lib/ml") in
  let rec args l = match l with
    | "-o" :: o :: r -> output := Some (Fpath.v o); args r
    | "-c" :: r -> separate := true; args r
    | "-L" :: d :: r -> lib := Some d; args r
    | "-nostdlib" :: r -> lib := None; args r
    | f :: r -> files := Fpath.v f :: !files; args r
    | [] -> ()
  in
  let argl = List.tl (Array.to_list argv) in
  args argl;
  let files = List.rev !files in
  (* g on the file opened, its name the errors' (file); one that cannot be
   * opened apart from g's errors, which are Failures too *)
  let with_file g f =
    let opened = ref false in
    try
      TinyLibSystem.with_open_in caps
        (fun ch -> opened := true; file := Chan.origin ch; g ch) f
    with Failure m when not !opened -> raise (File_error m) in
  let tmis = List.filter (Fpath.has_ext ".tmi") files
  and mls = List.filter (Fpath.has_ext ".ml") files in
  if List.mem "-h" argl || List.mem "--help" argl then
    (TinyLibSystem.print caps help; Exit.OK)
  else if List.length mls + List.length tmis <> List.length files || files = []
          || (!separate && List.length mls <> 1) then
    (TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2)
  else
  let write f text =
    try
      TinyLibSystem.with_open_out caps
        (fun (ch : Chan.o) -> Out_channel.output_string ch.oc text) f
    with Failure m -> raise (File_error m) in
  try
    (* the interfaces read, in their order: the library's, then the
     * units before this one *)
    let lib =
      match !lib with
      | Some d -> List.map (fun m -> Fpath.v d / (m ^ ".tmi")) library
      | None -> []
    in
    let units, needed =
      List.fold_left (fun (units, needed) f ->
          let u, n = with_file read_interface f in
          units @ [ u ], needed @ n)
        ([], []) (lib @ tmis) in
    (* a file's unit typed and compiled: its names' types, its names'
     * values, its globals' count *)
    let compile_file f =
      unit_name := unit_of f;
      known_units := !unit_name :: !known_units;
      let items = with_file (fun ch -> Parser.parse (text_of ch)) f in
      let tdefs = type_unit items in
      let defs, n = compile_unit items in
      tdefs, defs, n in
    if !separate then begin
      (* one unit: its object and its interface *)
      let f = List.hd mls in
      Buffer.clear text; Buffer.clear data;
      (* (before the parse: a type's constructors are the parser's) *)
      let old = snapshot () in
      let tdefs, exports, n = compile_file f in
      let mli = Fpath.set_ext ".mli" f in
      (* (old: Sys.file_exists mli, then read) *)
      let types =
        (try with_file (fun ch -> Parser.mli_types (text_of ch)) mli
         with File_error _ -> [])
        @ tdefs in
      let out =
        match !output with
        | Some o -> o
        | None -> Fpath.set_ext ".tm" (Fpath.base f) in
      (* (.data: tiny-linker -n's, the statics after the text) *)
      write out
        (Buffer.contents text ^ Asm.print Asm.SectionData
         ^ Buffer.contents data);
      write (Fpath.set_ext ".tmi" out)
        (write_interface old exports types n)
    end else begin
      (* the files one after the other, a unit each, then the main *)
      let units, needed =
        List.fold_left (fun (units, needed) f ->
          let tdefs, defs, n = compile_file f in
          unit_done ();
          export globals !unit_name defs;
          export tglobals !unit_name tdefs;
          units @ [ (!unit_name, n) ], needed @ !arities)
          (units, needed) mls in
      compile_main units needed;
      let asm =
        start ^ Buffer.contents text ^ Asm.print Asm.SectionData
        ^ Buffer.contents data in
      (match !output with
       | None -> TinyLibSystem.print caps asm
       | Some o -> write o asm)
    end;
    Exit.OK
  with
  (* (said after the file, not the program's name) *)
  | Failure m ->
      TinyLibSystem.eprint caps (!file ^ ": " ^ m ^ "\n"); Exit.Code 1
  | File_error m -> Exit.Err m

let () = TinyLibSystem.main "tiny-ml" main
