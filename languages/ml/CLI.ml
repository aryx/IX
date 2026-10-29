(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr >

let print = Console.print and eprint = Console.eprint

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-ml [-m 5|7] [-S | -gas] [-o out] [-I dir] [-i] [-M] file.ml
       mini-ml [-m 5|7] [-S | -gas] [-o out] -start Unit...
       mini-ml -pp file.ml
ocaml-light's ocamlopt's twin in behavior (-m 5: arm, the default; 7: arm64):
a unit to its object, x.5 (x.7) for mini-ld, another unit's names from its .mli
(or .ml) in the source's directory, then the -Is; -S its assembly instead, -gas
GNU's (arm, x.s); -start the program's start, initializing the units in their
order (weakly, mini-ld -h: a library's unit the program does not use is not linked); -i the toplevel's types, as ocamlopt -i; -M the units it names. With
ocaml-light's stdlib (S=~/github/ocaml-light/stdlib) and a fact.ml:
  mini-ml -I $S -i fact.ml                    val fact : int -> int
  mini-ml -m 7 -I $S fact.ml                  fact.7
  languages/ml/tests/run.sh 7 $PWD/w fact.ml  the stdlib, the runtime, libc,
    compiled, linked by mini-ld, run: w/fact (the stdlib: kernels/ocaml-light.sh)
mlpp (plan_ml_bootstrap.md): -pp prints the file as OCaml, its [%bits "..."],
[%list e || x <- l; cond], opt |! or_else, type t = [%mli] and [@@deriving
show] rewritten, with # lines to the source's lines; compiling, mini-ml rewrites them first. For dune (the workspace's
mini-ml, built first; the .mli for type t = [%mli]):
  (preprocess (action (run %{bin:mini-ml} -pp %{input-file})))
  (preprocessor_deps (source_tree .))
Its classes (lib_core/commons/Prelude.mli): type 'a show = { show : 'a -> string }
[@@class], a class; let show_int : int show = ... [@@instance], an instance;
let print [%using: 'a show] (x : 'a) = ... show x ..., a function with a
constraint, whose calls don't write the dictionary: print [ 1; 2 ] is printed
print (show_list show_int) [ 1; 2 ], from the types. So -pp needs the other
units' interfaces, the stdlib's too (-I, or -L lib_core), and dune their files:
  (preprocess (action (run %{bin:mini-ml} -pp -L %{project_root}/lib_core %{input-file})))
  (preprocessor_deps (source_tree .) (source_tree %{project_root}/lib_core))
To debug: -dast the tree, -dscope the names, -dir the stack machine's code,
-dssa its SSA; -ssa compiles from it, -ssa-stack through it and back; -O all
of Opti's passes, -Otails... one each; -O3 every optimization (-O and
-ssa, the mkfiles' MLOPT), -O0 none; -unsafe-types, no type checker.
-facts: no object; the unit as the facts of which function may be which
variable's value (Closure_facts.mli); a program's units' together, then:
  mini-datalog -q 'never_called(G)' languages/datalog/analyses/pointer.dl \
    languages/datalog/analyses/calls.dl *.dl
-flow: no object; the file's functions in SSA form as facts (blocks, points,
what each defines and uses: Ssa_facts.mli), for mini-datalog:
  mini-ml -flow fact.ml > fact.dl
  mini-datalog -q 'live_in(V, B)' languages/datalog/analyses/liveness_ssa.dl fact.dl
-dflow: the compiler's own liveness and dominators, as facts, to compare.
An error names the file and the line: fact.ml:2: this expression has type ...
|}

(* a text's tree: an interface for a .mli, else an implementation *)
let parse_text file text =
  let lexbuf = Lexing.from_string text in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = file };
  (* the file and the line a # line of mlpp's says *)
  let where () = Printf.sprintf "%s:%d" lexbuf.lex_curr_p.pos_fname lexbuf.lex_curr_p.pos_lnum in
  try
    if Filename.check_suffix file ".mli" then Ok (Ast.Signature (Parser.interface Lexer.token lexbuf))
    else Ok (Ast.Structure (Parser.implementation Lexer.token lexbuf))
  with
  (* menhir's parser's, mini-yacc's parser's and an action's *)
  | Parser.Error | Parsing.Parse_error -> Error (where () ^ ": syntax error")
  | Lexer.Error m -> Error (where () ^ ": " ^ m)

(* mlpp: its constructs rewritten into OCaml (Pp); a .ml's type t = [%mli]
 * read from its .mli *)
let rewrite (caps : < caps; .. >) file text tree =
  (* the .mli next to the file; for merlin's copy of an editor's buffer,
   * /tmp/merlinppXXXXXXx.ml, x.mli in the current directory, which is
   * the source's when dune configures merlin *)
  let mli_file () =
    let f = Filename.remove_extension file ^ ".mli" and base = Filename.basename file in
    if FS.read_opt caps (Fpath.v f) = None && String.starts_with ~prefix:"merlinpp" base && String.length base > 14 then
      Filename.remove_extension (String.sub base 14 (String.length base - 14)) ^ ".mli"
    else f
  in
  let mli () =
    let f = mli_file () in
    let rec decls (s : Ast.signature) =
      List.concat_map (fun (i : Ast.sig_item) -> match i.s with Stype ds -> ds | Smodule (_, MTsig s) -> decls s | _ -> []) s
    in
    match Option.map (fun t -> t, parse_text f t) (FS.read_opt caps (Fpath.v f)) with
    | Some (mli_text, Ok (Ast.Signature s)) -> Some { Pp.mli_file = f; mli_text; mli_decls = decls s }
    | _ -> None
  in
  try Ok (Pp.file ~file text tree ~mli) with Pp.Error (l, m) -> Error (Printf.sprintf "%s:%d: %s" file l m)

(* a file's text and tree; mlpp: its constructs rewritten first, the
 * rewritten text parsed again. Not yet its classes' dictionaries, which
 * need the names and the types (classes, below): so this is what
 * another unit reads of a unit, its [%using: ...] still there *)
let parse (caps : < caps; .. >) file =
  let f = Fpath.to_string file in
  match FS.read_opt caps file with
  | None -> Error (Printf.sprintf "cannot open %s" f)
  | Some text -> (
      match parse_text f text with
      | Error m -> Error m
      | Ok t -> (
          match rewrite caps f text t with
          | Error m -> Error m
          | Ok text' when text' == text -> Ok (text, t)
          | Ok text' -> (match parse_text f text' with Ok t -> Ok (text', t) | Error m -> Error m)))

(* a file of that name exactly, by its directory's names (read once):
 * on a file system that ignores case (macOS's), opening FS.ml opens
 * Fs.ml when that is the one there, another unit *)
let listed : (string, string list) Hashtbl.t = Hashtbl.create 16
let exists (caps : < caps; .. >) f =
  let f = Fpath.to_string f in
  let d = Filename.dirname f in
  let names =
    match Hashtbl.find_opt listed d with
    | Some names -> names
    | None ->
        let names = try List.map (fun (e : Sys_plan9.dir) -> e.name) (Sys_plan9.dirread caps d) with Unix.Unix_error _ -> [] in
        Hashtbl.replace listed d names;
        names
  in
  List.mem (Filename.basename f) names

(* another unit's source, by module name: its .mli, else its .ml, in
 * the directories in order, its file's name lowercase or not *)
let loader (caps : < caps; .. >) dirs : Scope.loader =
 fun name ->
  let names = List.concat_map (fun ext -> [ String.uncapitalize_ascii name ^ ext; name ^ ext ]) [ ".mli"; ".ml" ] in
  let candidates = List.concat_map (fun d -> List.map (fun n -> Fpath.(d / n)) names) dirs in
  match List.find_opt (fun f -> exists caps f && FS.read_opt caps f <> None) candidates with
  | None -> None
  | Some f -> (
      match parse caps f with
      | Ok (_, src) -> Some src
      | Error m -> raise (Resolve.Error (0, m)))

exception Rejected of string

(* mlpp: a unit's names resolved, and, when it or a unit it names has
 * classes, their dictionaries: found by Typing, written in the text by
 * Pp, and the unit read again from that text, where they are arguments
 * like the others. Its text, its tree, its names.
 * lenient, for -pp, whose output OCaml checks and merlin reads: the
 * text even with an error, which is then OCaml's, at its place. A
 * dictionary not found is written [%ocaml.error "no instance of ..."],
 * which OCaml reports there; a type error is OCaml's own (mini-ml's is
 * a warning: its definition may miss dictionaries). *)
let classes (caps : < caps; .. >) dirs ~lenient file text (items : Ast.structure) =
  let name = String.capitalize_ascii (Filename.remove_extension (Filename.basename file)) in
  let fail l m = raise (Rejected (Printf.sprintf "%s:%d: %s" file l m)) in
  try
    let scoped = Resolve.implementation ~implicit:true (loader caps dirs) name items in
    (* (no class: nothing was left out, the names are as written) *)
    if not (Resolve.has_classes () || Pp.has_classes ~file text items) then (Resolve.implicit := false; text, items, scoped)
    else begin
      ignore (Typing.unit_ name scoped);
      List.iter (fun (l, m) ->
        if lenient then eprint caps (Printf.sprintf "%s:%d: %s (mini-ml's type error: the definition's dictionaries may be missing)\n" file l m)
        else fail l m) (Typing.errors ());
      let dicts =
        List.map (fun (span, l, d) ->
          span, match d with Ok d -> d | Error m -> if lenient then Printf.sprintf "[%%ocaml.error %S]" m else fail l m) (Typing.dictionaries ())
      in
      let text' = Pp.classes ~file text (Structure items) dicts in
      if lenient then text', items, scoped
      else
      match parse_text file text' with
      | Ok (Structure items) -> text', items, Resolve.implementation ~implicit:false (loader caps dirs) name items
      | Ok (Signature _) -> assert false
      | Error m -> raise (Rejected (m ^ " (after mlpp's classes)"))
    end
  with
  | Resolve.Error (l, m) | Typing.Error (l, m) | Pp.Error (l, m) -> fail l m

(* mlpp: mini-ml -pp, the file as OCaml; a file mini-ml doesn't parse as
 * it is (dune runs it on a library's files), with a warning if it seems
 * to have constructs: OCaml rejects them, but mini-ml's error says why.
 * The same for a file whose names mini-ml doesn't resolve (no -I, or
 * what it doesn't compile yet), when no class is in sight: its classes'
 * dictionaries, if it needed any, are then OCaml's type errors *)
let preprocess (caps : < caps; .. >) dirs file text =
  match parse_text file text with
  | Error m ->
      if Pp.has_constructs text then eprint caps (Printf.sprintf "%s, left as it is (mlpp's constructs?)\n" m);
      Ok text
  | Ok tree -> (
      let again text' = if text' == text then Ok (text, tree) else match parse_text file text' with Ok t -> Ok (text', t) | Error m -> Error m in
      match (match rewrite caps file text tree with Ok text' -> again text' | Error m -> Error m) with
      | Error m -> Error m
      | Ok (text, (Signature _ as tree)) -> (try Ok (Pp.classes ~file text tree []) with Pp.Error (l, m) -> Error (Printf.sprintf "%s:%d: %s" file l m))
      | Ok (text, Structure items) -> (
          match classes caps dirs ~lenient:true file text items with
          | text, _, _ -> Ok text
          | exception Rejected m -> if Resolve.has_classes () || Pp.has_classes ~file text items then Error m else Ok text))

(* OPTIMIZATION (inline, across units): the summaries (Summary.mli) of
 * the units this one uses, those beside its object (its build's, which
 * its directory's .depend orders: a unit of another directory, a
 * library's or lib_core's, is not made again when that one changes,
 * and its copies would be stale), each of the text its .ml has now
 * (found as its interface is, in dirs); their places in the text made
 * negative, each unit's apart, with their types' answers
 * (Lower.immediates...): their small functions inlined here as this
 * unit's own (Lower.imports). A summary of another text, or none,
 * nothing inlined from that unit. (Every directory's: mini-doom's frame
 * 0.994, mini-ml 6% larger. lib_core's read too, tried 2026-10-27:
 * tiny-machine 0.93 but mini-ml compiling 1.03; Pervasives' few small
 * functions externals instead, plan_ml_speed.md's 4c.) A summary of
 * another directory, found in an -I's (mkconfig's STDSUM: lib_core's
 * build), its constants alone (Fold's), as ocamlopt's .cmx found by
 * -I; -depend's lines make the unit again when that one is made.
 * old: another unit's .mli only *)
let summary_file name = name ^ ".inline"
let summaries (caps : < caps; .. >) objdir dirs name items =
  let find names dirs = List.find_map (fun f -> if exists caps f then FS.read_opt caps f else None)
      (List.concat_map (fun d -> List.map (fun n -> Fpath.(d / n)) names) dirs) in
  let source u = find [ String.uncapitalize_ascii u ^ ".ml"; u ^ ".ml" ] dirs in
  let current (s : Summary.t) src = s.digest = Digest.to_hex (Digest.string src) in
  let base = ref 0 in
  List.concat_map (fun u ->
    match Option.bind (find [ summary_file u ] [ objdir ]) Summary.of_string, source u with
    | None, Some src -> (
        match Option.bind (find [ summary_file u ] dirs) Summary.of_string with
        | Some s when current s src -> Fold.import s.constants; []
        | _ -> [])
    | Some s, Some src when current s src ->
        let b = !base in
        base := b + String.length src + 1;
        let sh ((x, y) : Ast.span) : Ast.span = (-(x + b) - 1, -(y + b) - 1) in
        let set h = List.iter (fun sp -> Hashtbl.replace h (sh sp) ()) in
        set Lower.immediates s.immediates;
        set Lower.string_eqs s.strings;
        set Lower.float_cmps s.floats;
        List.iter (fun (g, base) -> Hashtbl.replace Lower.min_max_aliases g base) s.min_max;
        Fold.import s.constants;
        List.map (fun (e : Summary.entry) -> { e with body = Summary.respan sh e.body }) s.entries
    | _ -> [])
    (List.filter (fun u -> u <> name) (Summary.uses items))

(* the unit's summary, beside its object *)
let write_summary (caps : < caps; .. >) out file name items =
  let s : Summary.t = {
    digest = Digest.to_hex (Digest.string (FS.read caps file));
    entries = Lower.exports items;
    immediates = Typing.immediates (); strings = Typing.strings (); floats = Typing.floats ();
    min_max = Typing.min_max_globals ();
    constants = Fold.exports ();
  } in
  FS.write caps Fpath.(parent out / summary_file name) (Summary.to_string s)

(* the assembly into the object, through mini-asm's parser *)
let gas = ref false

(* the .ml's lines in the object, from Gen's and Emit's "// line n"
 * before each function: each item the line of its function's body, and
 * the history the .ml from its first line to the one after its last
 * (plan_debugger.md, stage 1b; a line a call's, later). No line of a
 * .ml (the start's text, its functions all the compiler's): no history *)
let ml_lines (caps : < caps; .. >) file text (obj : Asm.obj) : Asm.obj =
  let at = Array.make (String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 2 text) 0 in
  let marked = ref false in
  List.iteri (fun i l ->
    let l = String.trim l in
    if String.length l > 8 && String.sub l 0 8 = "// line " then begin
      at.(i + 1) <- (match int_of_string_opt (String.sub l 8 (String.length l - 8)) with Some n -> n | None -> 0);
      if at.(i + 1) > 0 then marked := true
    end
    else if i > 0 then at.(i + 1) <- at.(i)) (String.split_on_char '\n' text);
  if not !marked then { obj with history = [] }
  else
    let last = String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 1 (FS.read caps file) in
    { obj with items = Array.map (fun (it, l) -> (it, if l < Array.length at then at.(l) else 0)) obj.items;
               history = [ Some (Fpath.to_string file), 1; None, last ] }

let output (caps : < caps; .. >) mach ~listing ~out ~file text =
  if listing then print caps text
  else
    let obj : Asm.obj = Parser_asm.parse caps (Gen.arch mach) file text in
    let obj = ml_lines caps file text obj in
    if !gas then FS.write caps out (Gas.obj obj) else Asm.save caps out obj

(* -depend's way when a unit's names do not resolve: those it names
 * from its tokens, as ocamldep, a capitalized name before a dot
 * (Unit.x, Unit.(e)), after open, a module's alias (module M = Unit),
 * and Pervasives, opened in every unit: the types' too, more than the
 * values whose summaries it reads (a lexer's error: the names before) *)
let named_units text =
  let lexbuf = Lexing.from_string text in
  let us = ref [ "Pervasives" ] in
  let add u = if not (List.mem u !us) then us := u :: !us in
  let rec go (p3 : Parser.token) (p2 : Parser.token) (p1 : Parser.token) =
    match Lexer.token lexbuf with
    | Parser.EOF -> ()
    | t ->
        (match p3, p2, p1, t with
         | _, _, Parser.UIDENT u, Parser.DOT
         | _, _, Parser.OPEN, Parser.UIDENT u
         | Parser.MODULE, Parser.UIDENT _, Parser.EQUAL, Parser.UIDENT u -> add u
         | _ -> ());
        go p2 p1 t
  [@@tailrec] in
  (try go Parser.EOF Parser.EOF Parser.EOF with _ -> ());
  !us

(* the same from a grammar's or a lexer's text (a unit mini-yacc or
 * mini-lex makes, not there before the build): its capitalized words
 * before a dot or after open, comments' too. old: before a dot only:
 * mini-cc's Lexer (open Pre) ordered otherwise than once it was made *)
let named_words text =
  let n = String.length text in
  let ident c = c = '_' || c = '\'' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') in
  let opened i =
    let k = ref (i - 1) in
    while !k >= 0 && (text.[!k] = ' ' || text.[!k] = '\t' || text.[!k] = '\n') do decr k done;
    !k >= 3 && String.sub text (!k - 3) 4 = "open" && (!k = 3 || not (ident text.[!k - 4])) in
  let rec go i acc =
    if i >= n then acc
    else if text.[i] >= 'A' && text.[i] <= 'Z' && (i = 0 || not (ident text.[i - 1])) then begin
      let j = ref i in
      while !j < n && ident text.[!j] do incr j done;
      let named = (!j < n && text.[!j] = '.') || opened i in
      go !j (if named then String.sub text i (!j - i) :: acc else acc)
    end else go (i + 1) acc
  [@@tailrec] in
  go 0 [ "Pervasives" ]

(* -depend obj Unit...: a directory's .depend (mkfiles/depend.rc), mk's
 * line for each unit and each other of those given whose values it
 * names (Summary.uses, its names resolved), so that mk makes a unit
 * after those whose summaries it reads; each unit's file the first
 * dir's (-I's order) .ml, else .mly or .mll. One run for all of them.
 * A unit of another directory whose summary an -I has, with constants:
 * a line on that file, ocamldep -native's on a .cmx (a lib_core unit's
 * made again, the unit too).
 * old: depend.rc's loops, an ls for each unit and dir, then mini-ml
 * -uses for each file: 2 s for play's 39 units, 1.6 of them the
 * processes; a unit whose names did not resolve, no line *)
let depend (caps : < caps; .. >) obj dirs units =
  let find ext u =
    List.find_map (fun d ->
      let f = Fpath.(d / (u ^ ext)) in
      Option.map (fun text -> f, text) (FS.read_opt caps f)) dirs in
  List.iter (fun u ->
    let names =
      match find ".ml" u with
      | Some (f, text) -> (
          let file = Fpath.to_string f in
          match parse caps f with
          | Ok (text', Ast.Structure items) -> (
              match classes caps (Fpath.parent f :: dirs) ~lenient:false file text' items with
              | _, _, scoped -> Summary.uses scoped
              | exception _ -> named_units text)
          | _ -> named_units text
          | exception _ -> named_units text)
      | None -> (
          match find ".mly" u, find ".mll" u with
          | Some (_, text), _ | None, Some (_, text) -> named_words text
          | None, None -> []) in
    List.iter (fun n ->
      if n <> u && List.mem n units then
        print caps (Printf.sprintf "%s/%s.$O: %s/%s.$O\n" obj u obj n)
      else if n <> u then
        match List.find_opt (fun d -> exists caps Fpath.(d / summary_file n)) dirs with
        | Some d -> (
            let f = Fpath.(d / summary_file n) in
            match Option.bind (FS.read_opt caps f) Summary.of_string with
            | Some s when s.constants <> [] ->
                print caps (Printf.sprintf "%s/%s.$O: %s\n" obj u (Fpath.to_string f))
            | _ -> ())
        | None -> ())
      (List.sort_uniq compare names))
    units

let usage = "usage: mini-ml [-m 5|7] [-S] [-o out] [-I dir] file.ml | -start Unit...   (-h: how)"

let main (caps : < caps; .. >) (argv : string array) : int =
  let dast = ref false and dscope = ref false and dir = ref false and listing = ref false and start = ref false and deps = ref false and opti = ref [] and dssa = ref false and facts = ref false and flow = ref false and dflow = ref false and ssa = ref false and ssa_stack = ref false in
  let show_types = ref false and unsafe = ref false and pp = ref false and depends = ref "" in
  let mach = ref Gen.arm and out = ref "" and incs = ref [] and libs = ref [] and files = ref [] in
  let options = [
    "-m", Arg.String (function "5" -> mach := Gen.arm | "7" -> mach := Gen.arm64 | m -> raise (Arg.Bad ("-m " ^ m ^ ": 5 or 7"))), " 5|7: arm or arm64";
    "-o", Arg.Set_string out, " out: the object's name";
    "-I", Arg.String (fun d -> incs := d :: !incs), " dir: where the other units' interfaces are";
    (* mlpp: for a dune file, whose -pp of a unit with classes needs them all *)
    "-L", Arg.String (fun d -> libs := d :: !libs), " dir: ix's lib_core: -I its stdlib's directories (units.txt) and commons/";
    "-S", Arg.Set listing, " the assembly, printed";
    "-gas", Arg.Set gas, " GNU's assembly, for gcc";
    "-i", Arg.Set show_types, " the values' types, printed";
    "-M", Arg.Set deps, " the units the file names, printed";
    "-depend", Arg.Set_string depends, " obj: the Units given, mk's order of their objects, printed (mkfiles/depend.rc)";
    "-start", Arg.Set start, " the start object of the units named";
    "-unsafe-types", Arg.Set unsafe, " no type checking";
    (* mlpp: *)
    "-pp", Arg.Set pp, " the file after mlpp ([%bits], deriving), printed";
    "-O", Arg.Unit (fun () -> opti := List.map fst Opti.passes; Fold.on := true), " every pass of opti/ (-Oname: one), and Fold's";
    (* the mkfiles' (mkconfig's MLOPT): what is added later comes with it.
     * -inline 24: against 16, mini-quake 4.2% fewer instructions over 61
     * frames, mini-doom 1.9%, mini-ml compiling 0.4%, the programs 3% to
     * 6% larger; 32 gains about 1% more for 8% to 9% larger
     * (plan_ml_speed.md, tests/inline_limit.sh). old: -inline 16 *)
    "-O3", Arg.Unit (fun () -> opti := List.map fst Opti.passes; Fold.on := true; ssa := true; Lower.inline_most := 24), " every optimization: -O, -ssa, -inline 24";
    "-O0", Arg.Unit (fun () -> opti := []; Fold.on := false; ssa := false), " none: the stack machine's code as Lower makes it";
    "-no-fold", Arg.Clear Fold.on, " no constant folded (Fold): a toplevel constant read from its global";
    "-ssa", Arg.Set ssa, " compiled from the SSA form";
    "-inline", Arg.Set_int Lower.inline_most, " n: -ssa: a known function of n nodes or fewer copied where it is called (0: none)";
    "-calls", Arg.Unit (fun () -> Lower.strings_in_place := false; Lower.floats_in_place := false; Lower.ints_in_place := false; Emit.alloc_in_place := false; Lower.calls_whole := false),
    " a string's byte and length, a float's arithmetic and a block's allocation by calls of the runtime, not in place; an unknown function an argument at a time";
    "-linear-matches", Arg.Clear Lower.switches, " a match's constructors tested one after the other, no jump table";
    "-own-slots", Arg.Clear Alloc.share_slots, " -ssa: a slot of the frame for each value in memory, none shared";
    "-by-uses", Arg.Clear Alloc.by_density, " -ssa: the registers to the most used values, not the densest (Alloc)";
    "-full-frames", Arg.Clear Emit.small_frames, " -ssa: every function a frame on the value stack and its link saved";
    "-tagged-ints", Arg.Clear Untag.on, " -ssa: every integer tagged, none untagged in a register (Untag)";
    "-no-cse", Arg.Clear Cse.on, " -ssa: a computation made twice made twice (Cse)";
    "-no-licm", Arg.Clear Licm.on, " -ssa: a loop's invariants made at each turn (Licm)";
    "-boxed-floats", Arg.Clear Unbox.on, " -ssa: every float a block, none a double in a register (Unbox)";
    "-ssa-stack", Arg.Set ssa_stack, " through the SSA form and back";
    "-dast", Arg.Set dast, " dump the tree";
    "-dscope", Arg.Set dscope, " dump the names, resolved";
    "-dir", Arg.Set dir, " dump the stack machine's code";
    "-dssa", Arg.Set dssa, " dump the SSA form";
    "-facts", Arg.Set facts, " the unit as Datalog facts: which function a call may reach";
    "-flow", Arg.Set flow, " the SSA form as Datalog facts, for mini-datalog";
    "-dflow", Arg.Set dflow, " dump Alloc's liveness and the dominators, as facts";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] @ List.map (fun (pass, _) -> "-O" ^ pass, Arg.Unit (fun () -> opti := pass :: !opti), "") Opti.passes in
  match Arg.parse_argv argv options (fun f -> files := f :: !files) usage with
  | exception Arg.Help _ -> print caps help; 0
  | exception Arg.Bad m -> eprint caps m; 2
  | () ->
  if !gas then mach := Gen.gnu !mach;
  (* (-O3 with -gas: opti's passes alone) *)
  if !gas && !ssa && List.mem "-O3" (Array.to_list argv) then ssa := false;
  if !gas && !ssa then failwith "-ssa: not with -gas (gcc's calls of C)";
  (* (inlining with ssa's back end only: Lower.inline_most) *)
  if not !ssa then Lower.inline_most := 0;
  let path s = match FS.path s with Ok p -> p | Error m -> failwith m in
  let ext = match Gen.arch !mach with _ when !gas -> ".s" | Arm -> ".5" | Arm64 -> ".7" in
  let outfile file = if !out <> "" then path !out else Fpath.set_ext ext (Fpath.base file) in
  let fail m = eprint caps (m ^ "\n"); 1 in
  (* -L: the directories of its units.txt's lines, core/Pervasives, and
   * commons; the directory from here or from one above (dune names it
   * from the workspace, and merlin runs -pp in the source's directory) *)
  let lib d =
    let rec above d n = if n = 0 || FS.read_opt caps (path (Filename.concat d "units.txt")) <> None then d else above (Filename.concat ".." d) (n - 1) in
    let d = if Filename.is_relative d then above d 8 else d in
    let units = String.split_on_char '\n' (match FS.read_opt caps (path (Filename.concat d "units.txt")) with Some t -> t | None -> "") in
    let dirs = List.filter_map (fun u -> if u = "" || u.[0] = '#' then None else Some (Filename.dirname u)) units in
    List.map (Filename.concat d) (List.sort_uniq compare dirs @ [ "commons" ])
  in
  match List.rev !files, List.map path (List.rev !incs @ List.concat_map lib (List.rev !libs)) with
  | units, dirs when !depends <> "" -> depend caps !depends dirs units; 0
  | units, _ when !start ->
      let file = path "start.s" in
      (* (its functions ssa's with -ssa, as a unit's) *)
      let compile fns =
        let u : Ir.unit_ = { funcs = fns; data = [] } in
        if !ssa then Emit.unit_ (Gen.arch !mach) u else Gen.unit_ !mach u
      in
      (match output caps !mach ~listing:!listing ~out:(outfile file) ~file (Gen.startup !mach compile units) with
       | () -> 0
       | exception Failure m -> fail ("mini-ml: " ^ m))
  (* mlpp: *)
  | [ f ], incs when !pp -> (
      match FS.read_opt caps (path f) with
      | None -> fail ("cannot open " ^ f)
      (* (the current directory too: the source's, for merlin's copy of a buffer, in /tmp) *)
      | Some text -> (match preprocess caps (Fpath.parent (path f) :: path "." :: incs) f text with Ok t -> print caps t; 0 | Error m -> fail m))
  | [ f ], incs -> (
      let file = path f in
      match parse caps file with
      | Error m -> fail m
      | Ok (_, Ast.Signature items) ->
          if !dast then print caps (String.concat "\n" (List.map Ast.show_sig_item items) ^ "\n");
          0
      | Ok (text, Ast.Structure items) -> (
          let name = String.capitalize_ascii (Fpath.to_string (Fpath.rem_ext (Fpath.base file))) in
          match classes caps (Fpath.parent file :: incs) ~lenient:false (Fpath.to_string file) text items with
          | exception Rejected m -> fail m
          | _, tree, items -> (
              if !dast then print caps (String.concat "\n" (List.map Ast.show_item tree) ^ "\n");
              if !dscope then print caps (String.concat "\n" (List.map Scope.show_item items) ^ "\n");
              if !deps then print caps (String.concat " " (Resolve.units_named ()) ^ "\n");
              if !dast || !dscope || !deps then 0
              else
                match if !unsafe then [] else Typing.unit_ name items with
                | exception Typing.Error (l, m) -> fail (Printf.sprintf "%s:%d: %s" (Fpath.to_string file) l m)
                | _ when !facts -> print caps (Closure_facts.unit_ name items); 0
                | types when !show_types -> List.iter (fun (x, t) -> print caps (Printf.sprintf "val %s : %s\n" x t)) types; 0
                | _ ->
                Fold.reset ();
                Fold.bits := (match Gen.arch !mach with Arm -> 31 | Arm64 -> 63);
                Hashtbl.reset Lower.immediates;
                Hashtbl.reset Lower.string_eqs;
                Hashtbl.reset Lower.float_cmps;
                if not !unsafe && !Lower.calls_whole then begin
                  let set h = List.iter (fun sp -> Hashtbl.replace h sp ()) in
                  set Lower.immediates (Typing.immediates ());
                  set Lower.string_eqs (Typing.strings ());
                  set Lower.float_cmps (Typing.floats ());
                  Hashtbl.reset Lower.min_max_aliases;
                  List.iter (fun (g, base) -> Hashtbl.replace Lower.min_max_aliases g base)
                    (Typing.min_max_globals ());
                  if !Lower.inline_most > 0 then Lower.imports (summaries caps (Fpath.parent (outfile file)) (Fpath.parent file :: incs) name items)
                end;
                let items = if !Fold.on then Fold.items items else items in
                match (fun u -> if !ssa_stack then Ssa_build.unit_ u else u) (Opti.run !opti (Lower.unit_ name items)) with
                | exception Failure m -> fail (Printf.sprintf "%s: %s" (Fpath.to_string file) m)
                | u ->
                    if !dssa then List.iter (fun fn -> print caps (Ssa_build.show (Emit.ssa (Gen.arch !mach) fn))) u.funcs;
                    if !flow then List.iter (fun fn -> print caps (Ssa_facts.func (Ssa_build.func fn))) u.funcs;
                    if !dflow then List.iter (fun fn -> print caps (Ssa_facts.own (Ssa_build.func fn))) u.funcs;
                    if !dir then
                      List.iter (fun (fn : Ir.func) ->
                        print caps (fn.name ^ ":\n" ^ String.concat "" (List.map (fun i -> "\t" ^ Ir.show i ^ "\n") fn.code))) u.funcs;
                    (* -ssa: the functions ssa's, the data simple's *)
                    let text () =
                      if !ssa then Emit.unit_ (Gen.arch !mach) u ^ Gen.unit_ !mach { u with funcs = [] }
                      else Gen.unit_ !mach u
                    in
                    match text () with
                    | exception Failure m -> fail (Printf.sprintf "%s: %s" (Fpath.to_string file) m)
                    | text ->
                        if !dir || !dssa || !flow || !dflow then 0
                        else begin
                          output caps !mach ~listing:!listing ~out:(outfile file) ~file text;
                          if !Lower.inline_most > 0 && not !listing then write_summary caps (outfile file) file name items;
                          0
                        end)))
  | _ -> eprint caps (usage ^ "\n"); 2
  | exception Failure m -> fail ("mini-ml: " ^ m)
