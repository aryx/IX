(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-lex [-o out.ml] [-v] file.mll
ocamllex's twin, for mini-ml: a lexer's description, ocamllex's, to the lexer
in OCaml, file.ml (-o: another name), on lib_core's Lexing, whose engine is
OCaml. For example:
  mini-lex Lexer.mll                  Lexer.ml: 57 states
  mini-lex -v Lexer.mll               and each rule's states and clauses
The description, by an example:
  { let line = ref 1 }                             OCaml, copied first
  let digit = ['0'-'9']                            a regexp's name
  rule token = parse
    | digit+ as n      { INT (int_of_string n) }   n: the text matched
    | '\n'             { incr line; token lexbuf }
    | "(*"             { comment 1 lexbuf; token lexbuf }
    | eof              { EOF }
  and comment depth = parse                        a rule with a parameter
    | "*)"             { if depth > 1 then comment (depth - 1) lexbuf }
    | _                { comment depth lexbuf }
A regexp: 'c' "str" _ eof [ 'a'-'z' '_' ] [^ '"' ] a name, r* r+ r? r1 r2
r1 | r2 (r) r as x. The longest match wins, then the first clause. Not read:
r1 # r2, shortest, refill. An error names the file and the line: Lexer.mll:3: ...
|}

let usage = "usage: mini-lex [-o out.ml] [-v] file.mll   (-h: how)"

let main (caps : < caps; .. >) (argv : string array) : int =
  let out = ref "" and verbose = ref false and files = ref [] in
  let options = [
    "-o", Arg.Set_string out, " out.ml: the lexer's name";
    "-v", Arg.Set verbose, " each rule's states and clauses";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how, by examples";
  ] in
  match Arg.parse_argv argv options (fun f -> files := f :: !files) usage; List.map FS.path !files with
  | exception Arg.Help _ -> Console.print caps help; 0
  | exception Arg.Bad m -> Console.eprint caps m; 1
  | [ Ok file ] -> (
      match Lex.read (FS.read caps file) with
      | lex ->
          let dfa = Dfa.make lex.rules in
          let out = if !out <> "" then Fpath.v !out else Fpath.set_ext ".ml" file in
          FS.write caps out (Output.ocaml ~file:(Fpath.to_string file) ~out:(Fpath.to_string out) lex dfa);
          Console.print caps (Printf.sprintf "%s: %d states\n" (Fpath.to_string out) (Array.length dfa.trans));
          if !verbose then
            List.iter2 (fun (r : Lex.rule) start ->
              Console.print caps (Printf.sprintf "  %s: from state %d, %d clauses\n" r.name start (List.length r.clauses))) lex.rules dfa.starts;
          0
      | exception Lex.Error (l, m) -> Console.eprint caps (Printf.sprintf "%s:%d: %s\n" (Fpath.to_string file) l m); 1
      | exception Sys_error m -> Console.eprint caps (m ^ "\n"); 1)
  | [ Error m ] -> Console.eprint caps ("mini-lex: " ^ m ^ "\n"); 1
  | _ -> Console.eprint caps (usage ^ "\n"); 1
