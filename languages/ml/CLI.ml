(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let print = Console.print and eprint = Console.eprint

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-ml [-m 5|7] [-S | -gas] [-o out] [-I dir] [-i] [-M] file.ml
       mini-ml [-m 5|7] [-S | -gas] [-o out] -start Unit...
       mini-ml -pp file.ml
ocaml-light's ocamlopt's twin in behavior (-m 5: arm, the default; 7: arm64):
a unit to its object, x.5 (x.7) for mini-ld, another unit's names from its .mli
(or .ml) in the source's directory, then the -Is; -S its assembly instead, -gas
GNU's (arm, x.s); -start the program's start, initializing the units in their
order; -i the toplevel's types, as ocamlopt -i; -M the units it names. With
ocaml-light's stdlib (S=~/github/ocaml-light/stdlib) and a fact.ml:
  mini-ml -I $S -i fact.ml                    val fact : int -> int
  mini-ml -m 7 -I $S fact.ml                  fact.7
  languages/ml/tests/run.sh 7 $PWD/w fact.ml  the stdlib, the runtime, libc,
    compiled, linked by mini-ld, run: w/fact (the stdlib: kernel/ocaml-light.sh)
mlpp (plan_ml_bootstrap.md): -pp prints the file as OCaml, its [%bits "..."],
type t = _ and [@@deriving show] rewritten, with # lines to the source's
lines; compiling, mini-ml rewrites them first. For dune (the workspace's
mini-ml, built first; the .mli for type t = _):
  (preprocess (action (run %{bin:mini-ml} -pp %{input-file})))
  (preprocessor_deps (source_tree .))
To debug: -dast the tree, -dscope the names, -dir the stack machine's code,
-dssa its SSA; -ssa compiles from it, -ssa-stack through it and back; -O all
of Opti's passes, -Otails... one each; -unsafe-types, no type checker.
An error names the file and the line: fact.ml:2: this expression has type ...
|}

(* a text's tree: an interface for a .mli, else an implementation *)
let parse_text file text =
  let lexbuf = Lexing.from_string text in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = file };
  (* the file and the line a # line of mlpp's says *)
  let where () = Printf.sprintf "%s:%d" lexbuf.lex_curr_p.pos_fname lexbuf.lex_curr_p.pos_lnum in
  try
    if Filename.check_suffix file ".mli" then Ok (Pp.Signature (Parser.interface Lexer.token lexbuf))
    else Ok (Pp.Structure (Parser.implementation Lexer.token lexbuf))
  with
  | Parsing.Parse_error -> Error (where () ^ ": syntax error")
  | Lexer.Error m -> Error (where () ^ ": " ^ m)

(* mlpp: its constructs rewritten into OCaml (Pp); a .ml's type t = _
 * read from its .mli *)
let rewrite (caps : < caps; .. >) file text tree =
  (* the .mli next to the file; for merlin's copy of an editor's buffer,
   * /tmp/merlinppXXXXXXx.ml, x.mli in the current directory, which is
   * the source's when dune configures merlin *)
  let mli_file () =
    let f = Filename.remove_extension file ^ ".mli" and base = Filename.basename file in
    if Files.read_opt caps (Fpath.v f) = None && String.starts_with ~prefix:"merlinpp" base && String.length base > 14 then
      Filename.remove_extension (String.sub base 14 (String.length base - 14)) ^ ".mli"
    else f
  in
  let mli () =
    let f = mli_file () in
    let rec decls (s : Ast.signature) =
      List.concat_map (fun (i : Ast.sig_item) -> match i.s with Stype ds -> ds | Smodule (_, MTsig s) -> decls s | _ -> []) s
    in
    match Option.map (fun t -> t, parse_text f t) (Files.read_opt caps (Fpath.v f)) with
    | Some (mli_text, Ok (Pp.Signature s)) -> Some { Pp.mli_file = f; mli_text; mli_decls = decls s }
    | _ -> None
  in
  try Ok (Pp.file ~file text tree ~mli) with Pp.Error (l, m) -> Error (Printf.sprintf "%s:%d: %s" file l m)

(* mlpp: mini-ml -pp, the file as OCaml; a file mini-ml doesn't parse as
 * it is (dune runs it on a library's files), with a warning if it seems
 * to have constructs: OCaml rejects them, but mini-ml's error says why *)
let preprocess caps file text =
  match parse_text file text with
  | Error m ->
      if Pp.has_constructs text then eprint caps (Printf.sprintf "%s, left as it is (mlpp's constructs?)\n" m);
      Ok text
  | Ok tree -> rewrite caps file text tree

(* a file's tree; mlpp: its constructs rewritten first, the rewritten text
 * parsed again *)
let parse (caps : < caps; .. >) file =
  let f = Fpath.to_string file in
  let tree = function Pp.Signature s -> `Sig s | Pp.Structure s -> `Str s in
  match Files.read_opt caps file with
  | None -> Error (Printf.sprintf "cannot open %s" f)
  | Some text -> (
      match parse_text f text with
      | Error m -> Error m
      | Ok t -> (
          match rewrite caps f text t with
          | Error m -> Error m
          | Ok text' when text' == text -> Ok (tree t)
          | Ok text' -> Result.map tree (parse_text f text')))

(* another unit's source, by module name: its .mli, else its .ml, in
 * the directories in order, its file's name lowercase or not *)
let loader (caps : < caps; .. >) dirs : Scope.loader =
 fun name ->
  let names = List.concat_map (fun ext -> [ String.uncapitalize_ascii name ^ ext; name ^ ext ]) [ ".mli"; ".ml" ] in
  let candidates = List.concat_map (fun d -> List.map (fun n -> Fpath.(d / n)) names) dirs in
  match List.find_opt (fun f -> Files.read_opt caps f <> None) candidates with
  | None -> None
  | Some f -> (
      match parse caps f with
      | Ok (`Sig s) -> Some (`Sig s)
      | Ok (`Str s) -> Some (`Str s)
      | Error m -> raise (Scope.Error (0, m)))

(* the assembly into the object, through mini-asm's parser *)
let gas = ref false

let output (caps : < caps; .. >) mach ~listing ~out ~file text =
  if listing then print caps text
  else if !gas then Files.write caps out (Gas.obj (Ix_asm.Parser.parse caps (Gen.arch mach) file text))
  else Ix_asm.Asm.save caps out (Ix_asm.Parser.parse caps (Gen.arch mach) file text)

let main (caps : < caps; .. >) (argv : string array) : int =
  let dast = ref false and dscope = ref false and dir = ref false and listing = ref false and start = ref false and deps = ref false and opti = ref [] and dssa = ref false and ssa = ref false and ssa_stack = ref false in
  let show_types = ref false and unsafe = ref false and pp = ref false in
  let mach = ref Gen.arm and out = ref "" and incs = ref [] and files = ref [] in
  let rec args = function
    | "-dast" :: rest -> dast := true; args rest
    | "-dscope" :: rest -> dscope := true; args rest
    | "-dir" :: rest -> dir := true; args rest
    | "-dssa" :: rest -> dssa := true; args rest
    | "-ssa" :: rest -> ssa := true; args rest
    | "-ssa-stack" :: rest -> ssa_stack := true; args rest
    | "-O" :: rest -> opti := List.map fst Ix_ml_opti.Opti.passes; args rest
    | o :: rest when String.length o > 2 && String.sub o 0 2 = "-O" && List.mem_assoc (String.sub o 2 (String.length o - 2)) Ix_ml_opti.Opti.passes ->
        opti := String.sub o 2 (String.length o - 2) :: !opti; args rest
    | "-M" :: rest -> deps := true; args rest
    (* mlpp: *)
    | "-pp" :: rest -> pp := true; args rest
    | "-i" :: rest -> show_types := true; args rest
    | "-unsafe-types" :: rest -> unsafe := true; args rest
    | "-S" :: rest -> listing := true; args rest
    | "-gas" :: rest -> gas := true; args rest
    | "-start" :: rest -> start := true; args rest
    | "-m" :: "5" :: rest -> mach := Gen.arm; args rest
    | "-m" :: "7" :: rest -> mach := Gen.arm64; args rest
    | "-o" :: o :: rest -> out := o; args rest
    | "-I" :: d :: rest -> incs := d :: !incs; args rest
    | f :: rest -> files := f :: !files; args rest
    | [] -> ()
  in
  let argl = List.tl (Array.to_list argv) in
  if List.mem "-h" argl || List.mem "--help" argl then (print caps help; 0) else begin
  args argl;
  if !gas then mach := Gen.gnu !mach;
  if !gas && !ssa then failwith "-ssa: not with -gas (gcc's calls of C)";
  let path s = match Files.path s with Ok p -> p | Error m -> failwith m in
  let ext = match Gen.arch !mach with _ when !gas -> ".s" | Arm -> ".5" | Arm64 -> ".7" in
  let outfile file = if !out <> "" then path !out else Fpath.set_ext ext (Fpath.base file) in
  let fail m = eprint caps (m ^ "\n"); 1 in
  match List.rev !files, List.map path (List.rev !incs) with
  | units, _ when !start ->
      let file = path "start.s" in
      (match output caps !mach ~listing:!listing ~out:(outfile file) ~file (Gen.startup !mach units) with
       | () -> 0
       | exception Failure m -> fail ("mini-ml: " ^ m))
  (* mlpp: *)
  | [ f ], _ when !pp -> (
      match Files.read_opt caps (path f) with
      | None -> fail ("cannot open " ^ f)
      | Some text -> (match preprocess caps f text with Ok t -> print caps t; 0 | Error m -> fail m))
  | [ f ], incs -> (
      let file = path f in
      match parse caps file with
      | Error m -> fail m
      | Ok (`Sig items) ->
          if !dast then print caps (String.concat "\n" (List.map Ast.show_sig items) ^ "\n");
          0
      | Ok (`Str items) -> (
          if !dast then print caps (String.concat "\n" (List.map Ast.show_item items) ^ "\n");
          let name = String.capitalize_ascii (Fpath.to_string (Fpath.rem_ext (Fpath.base file))) in
          match Scope.implementation (loader caps (Fpath.parent file :: incs)) name items with
          | exception Scope.Error (l, m) -> fail (Printf.sprintf "%s:%d: %s" (Fpath.to_string file) l m)
          | items -> (
              if !dscope then print caps (String.concat "\n" (List.map Scope.show_item items) ^ "\n");
              if !deps then print caps (String.concat " " (Scope.units_named ()) ^ "\n");
              if !dast || !dscope || !deps then 0
              else
                match if !unsafe then [] else Typing.unit_ name items with
                | exception Typing.Error (l, m) -> fail (Printf.sprintf "%s:%d: %s" (Fpath.to_string file) l m)
                | types when !show_types -> List.iter (fun (x, t) -> print caps (Printf.sprintf "val %s : %s\n" x t)) types; 0
                | _ ->
                match (fun u -> if !ssa_stack then Ix_ml_ssa.Ssa.unit_ u else u) (Ix_ml_opti.Opti.run !opti (Lower.unit_ name items)) with
                | exception Failure m -> fail (Printf.sprintf "%s: %s" (Fpath.to_string file) m)
                | u ->
                    if !dssa then List.iter (fun fn -> print caps (Ix_ml_ssa.Ssa.show (Ix_ml_ssa.Ssa.func fn))) u.funcs;
                    if !dir then
                      List.iter (fun (fn : Lower.func) ->
                        print caps (fn.name ^ ":\n" ^ String.concat "" (List.map (fun i -> "\t" ^ Lower.show i ^ "\n") fn.code))) u.funcs;
                    (* -ssa: the functions ssa's, the data simple's *)
                    let text () =
                      if !ssa then Ix_ml_ssa.Emit.unit_ (Gen.arch !mach) u ^ Gen.unit_ !mach { u with funcs = [] }
                      else Gen.unit_ !mach u
                    in
                    match text () with
                    | exception Failure m -> fail (Printf.sprintf "%s: %s" (Fpath.to_string file) m)
                    | text -> if !dir || !dssa then 0 else (output caps !mach ~listing:!listing ~out:(outfile file) ~file text; 0))))
  | _ -> eprint caps "usage: mini-ml [-m 5|7] [-S] [-o out] [-I dir] file.ml | -start Unit...   (-h: how)\n"; 2
  | exception Failure m -> fail ("mini-ml: " ^ m)
  end
