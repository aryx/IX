(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * testing:
 * tests/TinyML_test.sh: a program prints exactly what OCaml's ocamlopt
 * makes it print (the recorded ones were ocaml-light's on arm64, whose
 * back end this compiler also had until plan_tiny_self_hosting.md).
 *)

open Common
module Tree = TinyMLTree
module Lexer = TinyMLLexer
module Parser = TinyMLParser
module M = TinyLibMachine
module Types = TinyMLTypes
module Machine = TinyMLMachine
module Compile = TinyMLCompile
module Link = TinyMLLink

let usage = {|usage: tiny-ml [-L dir] [-S] [-o out.o] file.ml...
       | tiny-ml -c [-S] [-L dir] [-I dir]... [-o out.o] file.ml
       | tiny-ml -o prog.start.o lib.a... file.o...
       | tiny-ml -depend [-I dir]... file.ml...|}

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A tiny ML compiler: an ML file (its own small dialect: a file a module, no
functors nor labels) to an object of tiny-machine's code, for tiny-ld;
-S: its assembly instead, on stdout without -o. A fact.ml, for example:
  let rec fact n = if n = 0 then 1 else n * fact (n - 1)
  let () = print_string "fact 10 = "; print_int (fact 10); print_newline ()
  tiny-ml fact.ml                          fact.o
  tiny-ml -S fact.ml                       ml_start: ldw r12, 0(sp) ...
  tiny-cc main.c                           main.o
  L=tiny/runtime
  for f in $L/start $L/udivmod exit; do tiny-as $f.s; done
  tiny-ld -o fact start.o udivmod.o exit.o fact.o main.o /lib/ml/stdlib.a
  tiny-cpu fact                            fact 10 = 3628800
main.c includes tiny/runtime/ml.c and gives it memory (ml_run),
exit.s is exit (sys 0), as tiny/tests/TinyML_test.sh makes them. The
standard library, TinyLibCore/'s modules, is read from /lib/ml (-L: another
directory), the interfaces of those a file names, Stdlib's always, and
linked from there (stdlib.a, its objects); each module compiled once, by
tiny-ml -c -L . in TinyLibCore/, after the ones it names.
Several files are a module each, one after the other, then their main: a's
x is A.x in b, or x after open A. Or a module at a time, then the start:
  tiny-ml -c a.ml                          a.o, its code; a.tmi, its interface
  tiny-ml -c -I . b.ml                     b.o and b.tmi, a.tmi found (-I)
  tiny-ml -o start.o L/stdlib.a a.o b.o    the library's, a's and b's init,
                                           ml_start (each .tmi beside its file)
  (linked: ... start.o L/stdlib.a a.o b.o; what nothing uses left out by
  tiny-ld)
An error names the file and the line: fact.ml: line 2: this has type int ...
|}

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

(* A unit: its toplevel in <unit>.init, its names that are not static
 * (a value computed, a closure allocated) in its globals' table,
 * <unit>.globals, the collector's roots. What nothing uses is left out
 * by tiny-ld, piece by piece (a function, a static block): a
 * function of the toplevel has no free variable, so its closure is
 * static and the init names it not (old: prune, the program's
 * toplevel lets that nothing used dropped before the code was made,
 * when a program was compiled whole: a library cost a program only
 * what it called, which the link's pieces now do) *)
let compile_unit (items : (Tree.item * int) list) =
  Compile.start_fun 1 0;
  Machine.arities := [];
  let table = !Tree.unit_name ^ ".globals" and nglobals = ref 0 in
  let rec arity = function Tree.TE ("->", [ _; r ]) -> 1 + arity r | _ -> 0 in
  let defs = List.fold_left (fun defs (it, l) ->
    try
      match it with
      | Tree.IOpen u -> Types.opened Compile.globals u; defs
      | Tree.IAlias (a, u) -> Types.aliased Compile.globals a u; defs
      | Tree.IExt (x, t, p) ->
          let b = Compile.Ext (p, arity t) in
          Types.add_name Compile.globals x b;
          (x, b) :: defs
      | Tree.IExn c ->
          let u = !Tree.unit_name in
          Machine.block (Machine.exn_id u c) (Machine.header 1 0)
            [ Machine.DVal (Machine.static_string c) ];
          if (Tree.find_con c).arity = 0 then
            Machine.block (Machine.exn_const u c) (Machine.header 1 0)
              [ Machine.DVal (Machine.exn_id u c) ];
          defs
      | Tree.ILet (r, bs) ->
          (* (the names it adds, in the table: old, the env's first
           * names, counted) *)
          let added = List.map (function
            | x, Compile.Loc (Compile.Slot s, k) ->
                Compile.emit (Machine.Get s);
                Compile.emit (Machine.SetG (table, !nglobals));
                incr nglobals;
                x, Compile.Loc (Compile.Glob (table, !nglobals - 1), k)
            | b -> b) (Compile.bind [] r bs) in
          List.iter (fun (x, b) -> Types.add_name Compile.globals x b)
            (List.rev added);
          added @ defs
    with Error m -> TinyMLLexer.error (Printf.sprintf "line %d: %s" l m))
    [] items in
  Compile.emit (Machine.Imm (Machine.tagged 0));
  Compile.emit Machine.Ret;
  Compile.finish_fun (!Tree.unit_name ^ ".init") 0;
  let rec drain () =
    match Compile.dequeue () with Some f -> f (); drain () | None -> () in
  drain ();
  defs, !nglobals

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
(* the standard library, TinyLibCore/'s modules, the first units of
 * every program: each compiled once, with -L where the ones it names
 * are (TinyLibCore/Buildfile's -L .), and read as interfaces from a
 * directory, /lib/ml on tiny-kernel (-L another), as any unit's from
 * -I's, only those a unit names; its objects linked as any unit's,
 * from a library (stdlib.a).
 * (old: all of its interfaces read by every unit, in a list of them
 * here, and -nostdlib for its own units, which did not exist yet;
 * older: their text the compiler's, TinyMLPrelude.ml made of them by
 * the build, compiled again at each run: a unit of one line took 47 s
 * on tiny-kernel, and every program's main the library's code, 420 KB
 * of assembly; older: the prelude, TinyLibCore.ml, one unit, its
 * List.map a name with a dot) *)

(* a constructor: its name, kind, arity, its type's constant and other
 * constructors' counts, its type *)
type icon = string * Tree.kind * int * int * int * Tree.texpr
(* a label: its name, its record's type, its index, mutable, the
 * record's labels, its type *)
type ilabel = string * string * int * bool * string list * Tree.texpr

type interface = {
  iunit : string * int * int list;  (* its name, globals, curry functions *)
  icons : icon list;
  ilabels : ilabel list;
  iabbrevs : (string * (string list * Tree.texpr)) list;
  iforgotten : string list;
  ivals : (string * Compile.binding * Tree.texpr) list;
  ideps : string list;
    (* the units whose interfaces were read before this one was
     * compiled, in their order: what -I and -L read before it, as
     * OCaml's .cmi names its imports (Int64's types name Int32's
     * int32) *)
}

(* the units whose interfaces were read, in their order *)
let read_units : string list ref = ref []

(* a type as its expression: what is linked followed, a variable by its
 * number *)
let rec texpr_of_ty t =
  match Types.repr t with
  | Tree.TVar { contents = Tree.Unbound (n, _) } ->
    Tree.TEVar ("v" ^ string_of_int n)
  | Tree.TCon (c, ts) -> Tree.TE (c, List.map texpr_of_ty ts)
  | Tree.TVar _ -> Tree.TE ("?", [])

(* what the program's tables held before a unit: its interface has only
 * what the unit added, as OCaml's .cmi (old: the whole program's so far,
 * each unit's .tmi repeating every one before it, all read again by
 * each unit after: 310 KB of interfaces for tiny-kernel's programs) *)
type before = {
  old_con : string -> Tree.cinfo -> bool;
  old_label : string -> Tree.linfo -> bool;
  old_abbrev : string * (string list * Tree.texpr) -> bool;
  old_forgotten : string -> bool;
}

let snapshot () : before =
  let c = Hashtbl.copy Tree.cons and l = Hashtbl.copy Tree.record_labels
  and a = !Parser.abbreviations and f = !Parser.forgotten in
  { old_con = (fun k ci ->
      match Hashtbl.find_opt c k with Some ci' -> ci' == ci | None -> false);
    old_label = (fun k li -> List.memq li (Hashtbl.find_all l k));
    old_abbrev = (fun ab -> List.memq ab a);
    old_forgotten = (fun t -> List.mem t f) }

let write_interface (old : before) (exports : (string * Compile.binding) list)
  types
    nglobals =
  (* the tables by their names, a label's records the latest first, as
   * the table has them (old: Hashtbl.iter's order, which is OCaml's
   * or TinyLibCore's: an interface was not the same from the two
   * builds of tiny-ml) *)
  let names tbl =
    List.sort_uniq compare (Hashtbl.fold (fun k _ acc -> k :: acc) tbl []) in
  (* the unit's own abbreviations named M.t wherever its types name
   * them: read elsewhere, t is whichever unit's was read last (Tree's
   * abbreviations) *)
  let own =
    List.filter_map (fun ((t, _) as ab) ->
        if old.old_abbrev ab then None else Some t) !Parser.abbreviations in
  let rec qualified te =
    match te with
    | Tree.TE (c, args) ->
        Tree.TE ((if List.mem c own then !Tree.unit_name ^ "." ^ c else c),
                 List.map qualified args)
    | Tree.TEVar _ -> te in
  let texpr_of_ty t = qualified (texpr_of_ty t) in
  let icons = List.filter_map (fun c ->
    let ci = Hashtbl.find Tree.cons c in
    if old.old_con c ci then None
    else
      Some (c, ci.kind, ci.arity, ci.nconst, ci.nblock, texpr_of_ty ci.scheme))
    (names Tree.cons) in
  let ilabels = List.concat_map (fun l -> List.filter_map (fun li ->
    if old.old_label l li then None
    else
      Some (l, li.lrec, li.idx, li.mut, li.lnames, texpr_of_ty li.lscheme))
    (Hashtbl.find_all Tree.record_labels l)) (names Tree.record_labels) in
  (* a name defined twice: the later, first in exports, as OCaml's
   * shadowing (old: both, the earlier read last, so the one the units
   * after saw, with the later's type: www's trap, bugs/ix.md) *)
  let seen = Hashtbl.create 64 in
  let ivals = List.filter_map (fun (x, bd) ->
    if Hashtbl.mem seen x then None
    else begin
      Hashtbl.add seen x ();
      match List.assoc_opt x types, bd with
      | Some t,
        (Compile.Loc ((Compile.Static _ | Compile.Glob _), _) | Compile.Ext _)
          ->
          Some (Types.qualify !Tree.unit_name x, bd, texpr_of_ty t)
      | _ -> None
    end) exports in
  Marshal.to_string
    { iunit = !Tree.unit_name, nglobals, !Machine.arities; icons = icons;
      ilabels = ilabels;
      iabbrevs =
        List.filter_map (fun ((t, (ps, te)) as a) ->
            if old.old_abbrev a then None else Some (t, (ps, qualified te)))
          (List.rev !Parser.abbreviations);
      iforgotten =
        List.filter (fun t -> not (old.old_forgotten t)) !Parser.forgotten;
      ivals = ivals;
      ideps = List.rev !read_units }
    (* (No_sharing: which of two equal names is the same string depends
     * on a table's order, OCaml's or TinyLibCore's; shared, the host's
     * and tiny-kernel's interfaces differed in 3 of the system's 40) *)
    [ Marshal.No_sharing ]

(* an interface's text read *)
let decode_interface (text : string) : interface =
  if String.length text < 4 || String.sub text 0 4 <> "\132\149\166\190" then
    TinyMLLexer.error "not an interface of tiny-ml's";
  Marshal.from_string text 0

(* an interface read: its types the program's, its names in the tables
 * (globals, tglobals); its unit's name, globals and curry functions *)
let rec read_interface (chan : Chan.i) =
  register (decode_interface (In_channel.input_all chan.ic))
and register (i : interface) =
  let iname, iglobals, icurry = i.iunit in
  read_units := !read_units @ [ iname ];
  let ty te = Tree.of_texpr (ref []) te in
  Tree.known_units := iname :: !Tree.known_units;
  (* its abbreviations first, which its other types name (M.t): each as
   * t, the latest, and as M.t, its own *)
  let add name ps te =
    Parser.abbreviations :=
      (name, (ps, te))
      :: List.filter
           (fun (t', (ps', _)) ->
             t' <> name || List.length ps' <> List.length ps)
           !Parser.abbreviations in
  List.iter (fun (t, (ps, te)) -> add t ps te; add (iname ^ "." ^ t) ps te)
    i.iabbrevs;
  List.iter (fun (c, kind, arity, nconst, nblock, te) ->
      Hashtbl.replace Tree.cons c
        { kind = kind; arity = arity; nconst = nconst; nblock = nblock;
          scheme = ty te })
    i.icons;
  List.iter (fun (l, r, idx, mut, lnames, te) ->
    let others =
      List.filter (fun (li : Tree.linfo) -> li.lrec <> r)
        (Hashtbl.find_all Tree.record_labels l) in
    while Hashtbl.mem Tree.record_labels l do Hashtbl.remove Tree.record_labels
      l done;
    List.iter (Hashtbl.add Tree.record_labels l) (List.rev others);
    Hashtbl.add Tree.record_labels l
      { lrec = r; idx = idx; mut = mut; lnames = lnames; lscheme = ty te })
    i.ilabels;
  List.iter (fun t ->
      if not (List.mem t !Parser.forgotten) then Parser.forgotten := t
        :: !Parser.forgotten)
    i.iforgotten;
  (* (a val's name is M.x already; Stdlib's x too) *)
  let n = String.length iname in
  List.iter (fun (x, b, te) ->
    let t = ty te in
    List.iter
      (fun x -> Hashtbl.replace Compile.globals x b;
        Hashtbl.replace Types.tglobals x t)
      (if Types.implicit iname then
         [ x; String.sub x (n + 1) (String.length x - n - 1) ]
       else [ x ]))
    i.ivals;
  (iname, iglobals), icurry

(* a file's text *)
let text_of (chan : Chan.i) = In_channel.input_all chan.ic

(* the modules a source names, in their order: M of M.x, M.C, M.t and
 * M.( op ), of open M and include M, and of module A = M (as ocamldep
 * finds them); what -I reads the interfaces of. A's of module A = M
 * left out: the file's own name for M, not a unit (TinyML.ml's Machine,
 * TinyMLMachine, not the playground's test unit Machine) *)
let named_units (text : string) : string list =
  let toks = Array.map fst (Lexer.lex text) in
  let n = Array.length toks and found = ref [] and aliases = ref [] in
  let add m = if not (List.mem m !found) then found := m :: !found in
  let prefix s =
    match String.index_opt s '.' with
    | Some i -> add (String.sub s 0 i) | None -> () in
  let after k kw = k >= 1 && toks.(k - 1) = Lexer.KW kw in
  for k = 0 to n - 1 do
    match toks.(k) with
    | Lexer.LID s -> prefix s
    | Lexer.UID s ->
        prefix s;
        if k + 1 < n && toks.(k + 1) = Lexer.KW "." then add s;
        if after k "open" || after k "include"
           || (after k "=" && k >= 3 && toks.(k - 3) = Lexer.KW "module")
        then add s;
        if after k "module" && k + 1 < n && toks.(k + 1) = Lexer.KW "="
        then aliases := s :: !aliases
    | _ -> ()
  done;
  List.filter (fun m -> not (List.mem m !aliases)) (List.rev !found)

(* a file's unit: its name without the directory and the extension,
 * capitalized, as OCaml's module *)
let unit_of (f : Fpath.t) =
  String.capitalize_ascii (Fpath.to_string (Fpath.rem_ext (Fpath.base f)))


(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

let main (caps : < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout;
                   Cap.stderr; .. >)
    (argv : string array) : Exit.t =
  let output = ref None and file = ref "" and files = ref []
  and separate = ref false and lib = ref "/lib/ml"
  and text = ref false and incl = ref [] and depend = ref false in
  let rec args l = match l with
    | "-o" :: o :: r -> output := Some (Fpath.v o); args r
    | "-S" :: r -> text := true; args r
    | "-c" :: r -> separate := true; args r
    | "-L" :: d :: r -> lib := d; args r
    | "-I" :: d :: r -> incl := !incl @ [ Fpath.v d ]; args r
    | "-depend" :: r -> depend := true; args r
    (* a library, as ocamlc takes stdlib.cma: its interfaces beside it
     * (-L its directory), its objects tiny-ld's (a link's, where it
     * is among the files) *)
    | f :: r when Filename.check_suffix f ".a" ->
        lib := Filename.dirname f; files := Fpath.v f :: !files; args r
    | f :: r -> files := Fpath.v f :: !files; args r
    | [] -> ()
  in
  (* (-v: each file read said, Logs.info's; -debug, -quiet: logging's) *)
  let argl = TinyLibSystem.logging (List.tl (Array.to_list argv)) in
  args argl;
  let files = List.rev !files in
  (* g on the file opened, its name the errors' (file); one that cannot be
   * opened apart from a Failure of g's, a bug *)
  let with_file g f =
    let opened = ref false in
    Logs.info (fun m -> m "reading %s" (Fpath.to_string f));
    try
      TinyLibSystem.with_open_in caps
        (fun ch -> opened := true; file := Chan.origin ch; g ch) f
    with Failure m when not !opened -> raise (File_error m) in
  let mls = List.filter (Fpath.has_ext ".ml") files
  and archives = List.filter (Fpath.has_ext ".a") files
  and objects = List.filter (Fpath.has_ext ".o") files in
  (* a program's start, made of what links it: objects and libraries,
   * no source (ml -o prog.start.o $prereq: TinyML/TinyMLLink.mli) *)
  let of_link = !output <> None && objects <> [] && mls = [] && not !separate
                && not !depend in
  (* a link's units, in its order, which is the initializations' order
   * (OCaml's rule: the libraries first): an object with its interface
   * beside it; a library's members, each its interface beside the
   * library, in the library's order (ar's). (old: the library's units
   * from -L, by the list library, whatever the link said) *)
  let units_of f =
    let beside t = if TinyLibSystem.exists caps t then [ t ] else [] in
    if Fpath.has_ext ".a" f then
      let dir = Filename.dirname (Fpath.to_string f) in
      (* (not a library: tiny-ld says so) *)
      let members =
        try TinyLibMachine.of_archive (TinyLibSystem.read_file caps f)
        with Failure _ | TinyLibMachine.Error _ -> [] in
      List.concat_map (fun (name, _) ->
          beside (Fpath.v (Filename.concat dir
                             (Filename.remove_extension name ^ ".tmi"))))
        members
    else beside (Fpath.set_ext ".tmi" f) in
  (* a start's interfaces, its files'; a unit's are -I's and -L's (old: also
   * .tmi files given, in their order, before the .ml: two ways for one
   * thing) *)
  let tmis = if of_link then List.concat_map units_of files else [] in
  (* [in_dirs dirs m ext]: the file of module m in the directories, its
   * name M.ext or m.ext (user/tetris.ml is Tetris), compared by the
   * directory's names, not by exists: a host's file system may take
   * Machine.ml for machine.ml *)
  let listed = Hashtbl.create 17 in
  let names d =
    match Hashtbl.find_opt listed d with
    | Some l -> l
    | None ->
        let l = try TinyLibSystem.readdir caps d with Failure _ -> [] in
        Hashtbl.replace listed d l; l in
  let in_dirs dirs m ext =
    List.find_map (fun d ->
      List.find_map (fun base ->
        if List.mem (base ^ ext) (names d)
        then Some (Fpath.add_seg d (base ^ ext)) else None)
        [ m; String.lowercase_ascii (String.sub m 0 1)
             ^ String.sub m 1 (String.length m - 1) ]) dirs in
  if List.mem "-h" argl || List.mem "--help" argl then
    (TinyLibSystem.print caps help; Exit.OK)
  (* -depend: each unit's line for a Buildfile, as ocamldep's and m-ix's
   * mini-ml -depend: its object, then the interfaces of the units it
   * names (Stdlib named or not) whose source is in an -I directory
   * (before any is built), and its .mli; what -c -I will read, so that a
   * build makes them first, and the unit again when one of them changes *)
  else if !depend then begin
    let source m = in_dirs !incl m ".ml" in
    (* a path as a Buildfile names it: ./x is x *)
    let here p =
      let s = Fpath.to_string p in
      if String.length s > 2 && String.sub s 0 2 = "./"
      then String.sub s 2 (String.length s - 2) else s in
    (* a file tiny-ml cannot read (a host's program among the units,
     * TinyMachine.ml and its floats: a Buildfile's *.ml takes it too)
     * said and left out *)
    let unread f m =
      TinyLibSystem.eprint caps
        ("tiny-ml -depend: " ^ Fpath.to_string f ^ ": " ^ m ^ ", left out\n") in
    try
      List.iter (fun f ->
       try
        let mli = Fpath.set_ext ".mli" f in
        let in_ml = with_file (fun ch -> named_units (text_of ch)) f in
        let has_mli = TinyLibSystem.exists caps mli in
        let in_mli =
          if has_mli then with_file (fun ch -> named_units (text_of ch)) mli
          else [] in
        let own = unit_of f in
        let deps =
          List.filter_map (fun m ->
            if m = own then None
            else Option.map (fun s -> here (Fpath.set_ext ".tmi" s)) (source m))
            (List.sort_uniq compare ("Stdlib" :: in_ml @ in_mli)) in
        let deps = deps @ (if has_mli then [ Fpath.to_string mli ] else []) in
        TinyLibSystem.print caps
          (Fpath.to_string (Fpath.set_ext ".o" f) ^ ":"
           ^ String.concat "" (List.map (fun d -> " " ^ d) deps) ^ "\n")
       with Error m -> unread f m)
        mls;
      Exit.OK
    with File_error m -> Exit.Err m
  end
  else if not of_link
          && (List.length mls + List.length archives
              <> List.length files || mls = []
              || (!separate && List.length mls <> 1)) then
    (TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2)
  else
  let write f s =
    Logs.info (fun m -> m "writing %s" (Fpath.to_string f));
    try
      TinyLibSystem.with_open_out caps
        (fun (ch : Chan.o) -> Out_channel.output_string ch.oc s) f
    with Failure m -> raise (File_error m) in
  (* the lines as an object (TinyLibMachine's assemble), or as their
   * text (-S); old: the text always, which tiny-as parsed back
   * into the same lines (docs/plans/done/plan_tiny_libmach.md) *)
  let made (ls : TinyLibMachine.line list) =
    if !text then String.concat "" (List.map TinyLibMachine.print_line ls)
    else TinyLibMachine.to_object (TinyLibMachine.assemble ls) in
  (* x.ml's x.o here (x.s by -S); a whole program's after its first
   * .ml, main.o when it has none (old: its text on stdout) *)
  let named f = Fpath.set_ext (if !text then ".s" else ".o") (Fpath.base f) in
  try
    (* a start's interfaces, its files', in the link's order *)
    let units, needed =
      List.fold_left (fun (units, needed) f ->
          let u, n = with_file read_interface f in
          units @ [ u ], needed @ n)
        ([], []) tmis in
    (* the interfaces of the modules a unit names, found in -I's
     * directories, then in -L's (the library's), each after those it
     * was compiled with (its ideps), once; a name with none (an alias,
     * the unit) skipped. Their units, in the order read, are a whole
     * program's first (old: every library unit's interface read, the
     * library's list, whatever the unit named) *)
    let read = ref [] in
    if not of_link then begin
      let find m = in_dirs (!incl @ [ Fpath.v !lib ]) m ".tmi" in
      let decoded = Hashtbl.create 17 in
      let interface m =
        match Hashtbl.find_opt decoded m with
        | Some i -> i
        | None ->
            let i =
              Option.map
                (fun f -> with_file (fun ch -> decode_interface (text_of ch)) f)
                (find m) in
            Hashtbl.replace decoded m i;
            i in
      let rec need m =
        if not (List.mem m !read_units) then
          match interface m with
          | None -> ()
          | Some i ->
              List.iter need i.ideps;
              if not (List.mem m !read_units) then
                read := !read @ [ register i ] in
      (* how many units an interface stands on, its ideps' and theirs *)
      let rec closure m =
        match interface m with
        | None -> []
        | Some i ->
            List.sort_uniq compare
              (i.ideps @ List.concat_map closure i.ideps) in
      List.iter (fun f ->
        let mli = Fpath.set_ext ".mli" f in
        let own = unit_of f in
        let in_ml = with_file (fun ch -> named_units (text_of ch)) f in
        let in_mli =
          if TinyLibSystem.exists caps mli
          then with_file (fun ch -> named_units (text_of ch)) mli
          else [] in
        (* Stdlib first, named or not, as OCaml opens it *)
        let names = "Stdlib" :: in_ml @ in_mli in
        let names = List.filter (fun m -> m <> own) names in
        (* those that stand on fewer first, the source's order between
         * equals: a unit read after what it stands on, as the
         * Makefile's lists have them. The constructors and the type
         * names are the program's (one name space), the last read
         * winning: TinyCLower's label after TinyLibMachine's *)
        let depth m = List.length (closure m) in
        let order =
          List.stable_sort
            (fun a b -> let da = depth a in let db = depth b in compare da db)
            names in
        List.iter need order) mls
    end;
    let units = units @ List.map fst !read
    and needed = needed @ List.concat_map snd !read in
    (* a file's unit typed and compiled: its names' types, its names'
     * values, its globals' count *)
    let compile_file f =
      Tree.unit_name := unit_of f;
      Tree.known_units := !Tree.unit_name :: !Tree.known_units;
      let items = with_file (fun ch -> Parser.parse (text_of ch)) f in
      let tdefs = Types.type_unit items in
      let defs, n = compile_unit items in
      tdefs, defs, n in
    if !separate then begin
      (* one unit: its object and its interface *)
      let f = List.hd mls in
      let asm = Machine.start_asm () in
      (* (before the parse: a type's constructors are the parser's) *)
      let old = snapshot () in
      let tdefs, exports, n = compile_file f in
      let mli = Fpath.set_ext ".mli" f in
      (* (old: Sys.file_exists mli, then read) *)
      let types =
        (try with_file (fun ch -> Parser.mli_types (text_of ch)) mli
         with File_error _ -> [])
        @ tdefs in
      let out = match !output with Some o -> o | None -> named f in
      (* (.data: tiny-ld -n's, the statics after the text) *)
      write out (made (Machine.lines asm));
      write (Fpath.set_ext ".tmi" out)
        (write_interface old exports types n)
    end else begin
      (* the files one after the other, a unit each, then the main, in
       * one assembly *)
      let asm = Machine.start_asm () in
      let units, needed =
        List.fold_left (fun (units, needed) f ->
          let tdefs, defs, n = compile_file f in
          Types.unit_done ();
          Types.export Compile.globals !Tree.unit_name defs;
          Types.export Types.tglobals !Tree.unit_name tdefs;
          units @ [ (!Tree.unit_name, n) ], needed @ !Machine.arities)
          (units, needed) mls in
      Link.compile_start units needed;
      let program = made (Machine.start @ Machine.lines asm) in
      (match !output with
       | Some o -> write o program
       | None when !text -> TinyLibSystem.print caps program
       | None ->
           write
             (match mls with f :: _ -> named f | [] -> Fpath.v "main.o")
             program)
    end;
    Exit.OK
  with
  (* (said after the file, not the program's name). An error in the
   * program; a Failure is a bug, left uncaught (old: caught as well, the
   * library's on the text, int_of_string's, not told from a bug's) *)
  | Error m ->
      TinyLibSystem.eprint caps (!file ^ ": " ^ m ^ "\n"); Exit.Code 1
  (* a line made that cannot be encoded (a number too big for its
   * field): the compiler's error, said with the file, as tiny-as
   * said it of the text (old) *)
  | TinyLibMachine.Error e ->
      TinyLibSystem.eprint caps (!file ^ ": " ^ e ^ "\n"); Exit.Code 1
  | File_error m -> Exit.Err m

let () = TinyLibSystem.main "tiny-ml" main
