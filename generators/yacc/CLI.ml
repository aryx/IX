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

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-yacc [-b prefix] [-v] file.mly
ocamlyacc's twin, for mini-ml: a grammar, ocamlyacc's, to its LALR(1) parser
in OCaml, file.ml and file.mli (-b: prefix.ml and prefix.mli), on lib_core's
Parsing, whose engine is OCaml. For example:
  mini-yacc Parser.mly                Parser.ml: 251 states
  mini-yacc -v Parser.mly             and Parser.output: the states, their actions
The grammar, by an example:
  %{ open Ast %}                                   OCaml, copied first
  %token <int> INT                                 a token with a value
  %token PLUS TIMES MINUS EOF
  %left PLUS MINUS                                 the lowest precedence first
  %left TIMES
  %start main
  %type <int> main
  %%
  main: expr EOF { $1 };
  expr:
    | INT { $1 }
    | expr PLUS expr { $1 + $3 }                   $n: the n-th symbol's value
    | MINUS expr %prec TIMES { - $2 }              the rule as high as TIMES
  ;
A conflict is decided as yacc does: by the precedences, else the shift, or the
earlier rule, and counted. A syntax error raises Parsing.Parse_error. Not read:
the error token, an action in the middle of a rule. An error names the file and
the line: Parser.mly:3: ...
|}

let main (caps : < caps; .. >) (argv : string array) : int =
  let prefix = ref "" and verbose = ref false and files = ref [] in
  let rec args = function
    | "-b" :: p :: rest -> prefix := p; args rest
    | "-v" :: rest -> verbose := true; args rest
    | f :: rest -> files := f :: !files; args rest
    | [] -> ()
  in
  args (List.tl (Array.to_list argv));
  match List.map Files.path !files with
  | _ when List.exists (fun f -> f = "-h" || f = "--help") !files -> Console.print caps help; 0
  | [ Ok file ] -> (
      match
        let g = Yacc.read (Files.read caps file) in
        let a = Lalr.make g in
        let base = if !prefix <> "" then Fpath.v !prefix else Fpath.rem_ext file in
        let out = Fpath.set_ext ".ml" base in
        Files.write caps out (Output.ocaml ~file:(Fpath.to_string file) ~out:(Fpath.to_string out) g a);
        Files.write caps (Fpath.set_ext ".mli" base) (Output.interface g);
        if !verbose then Files.write caps (Fpath.set_ext ".output" base) (Output.listing a);
        Console.print caps (Printf.sprintf "%s: %d states\n" (Fpath.to_string out) (Array.length a.kernels));
        if a.sr > 0 then Console.eprint caps (Printf.sprintf "%d shift/reduce conflict%s.\n" a.sr (if a.sr > 1 then "s" else ""));
        if a.rr > 0 then Console.eprint caps (Printf.sprintf "%d reduce/reduce conflict%s.\n" a.rr (if a.rr > 1 then "s" else ""))
      with
      | () -> 0
      | exception Yacc.Error (l, m) -> Console.eprint caps (Printf.sprintf "%s:%d: %s\n" (Fpath.to_string file) l m); 1
      | exception Sys_error m -> Console.eprint caps (m ^ "\n"); 1)
  | [ Error m ] -> Console.eprint caps ("mini-yacc: " ^ m ^ "\n"); 1
  | _ -> Console.eprint caps "usage: mini-yacc [-b prefix] [-v] file.mly   (-h: how)\n"; 1
