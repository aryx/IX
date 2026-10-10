(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

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
    | LPAREN expr RPAREN { at $sloc $2 }           $sloc: where the rule's text is, its first
                                                   and last positions; $loc($2): the 2nd symbol's
    | MINUS expr %prec TIMES { - $2 }              the rule as high as TIMES
  ;
And menhir's standard rules, a symbol as any other, each use rules of its own:
  main: list(statement) EOF { $1 };                a list, in the text's order; or statement*
  call: IDENT LPAREN separated_list(COMMA, expr) RPAREN { Call ($1, $3) }
  option(x) or x?  nonempty_list(x) or x+  boption(x)  loption(x)  separated_nonempty_list(sep, x)
A conflict is decided as yacc does: by the precedences, else the shift, or the
earlier rule, and counted. What a grammar says for nothing is a warning: a token
in no rule, a rule no start symbol leads to, a precedence or a %prec that
decides no conflict. A syntax error raises Parsing.Parse_error. Not read:
the error token, an action in the middle of a rule, the rest of menhir's. An
error names the file and the line: Parser.mly:3: ...
|}

let usage = "usage: mini-yacc [-b prefix] [-v] file.mly   (-h: how)"

let main (caps : < caps; .. >) (argv : string array) : int =
  let prefix = ref "" and verbose = ref false and files = ref [] in
  let options = [
    "-b", Arg.Set_string prefix, " prefix: prefix.ml and prefix.mli";
    "-v", Arg.Set verbose, " the automaton, in prefix.output";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  match Arg.parse_argv argv options (fun f -> files := f :: !files) usage; List.map FS.path !files with
  | exception Arg.Help _ -> Console.print caps help; 0
  | exception Arg.Bad m -> Console.eprint caps m; 1
  | [ Ok file ] -> (
      match
        let g = Yacc.read (FS.read caps file) in
        let a = Lalr.make g in
        let base = if !prefix <> "" then Fpath.v !prefix else Fpath.rem_ext file in
        let out = Fpath.set_ext ".ml" base in
        FS.write caps out (Output.ocaml ~file:(Fpath.to_string file) ~out:(Fpath.to_string out) g a);
        FS.write caps (Fpath.set_ext ".mli" base) (Output.interface g);
        if !verbose then FS.write caps (Fpath.set_ext ".output" base) (Output.listing a);
        Console.print caps (Printf.sprintf "%s: %d states\n" (Fpath.to_string out) (Array.length a.kernels));
        List.iter (fun (l, m) -> Console.eprint caps (Printf.sprintf "%s:%s warning: %s\n" (Fpath.to_string file) (if l = 0 then "" else string_of_int l ^ ":") m)) a.warnings;
        if a.sr > 0 then Console.eprint caps (Printf.sprintf "%d shift/reduce conflict%s.\n" a.sr (if a.sr > 1 then "s" else ""));
        if a.rr > 0 then Console.eprint caps (Printf.sprintf "%d reduce/reduce conflict%s.\n" a.rr (if a.rr > 1 then "s" else ""))
      with
      | () -> 0
      | exception Yacc.Error (l, m) -> Console.eprint caps (Printf.sprintf "%s:%d: %s\n" (Fpath.to_string file) l m); 1
      | exception Sys_error m -> Console.eprint caps (m ^ "\n"); 1)
  | [ Error m ] -> Console.eprint caps ("mini-yacc: " ^ m ^ "\n"); 1
  | _ -> Console.eprint caps (usage ^ "\n"); 1
