(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Eval.caps; Cap.stdout; Cap.stderr >

let help = {|usage: mini-hoc [-e EXPRESSION] [FILE...]
Plan 9's hoc, a calculator with variables, loops and functions (floating point).
The files in order (-: the standard input, the default), a line at a time; an
expression's value is printed, an assignment's is not:
  mini-hoc -e '2^10 + sqrt(2)'
  1025.41421356
  mini-hoc
  func fac(n) { if (n <= 1) return 1
    return n * fac(n-1) }
  fac(10)
  3628800
  for (i = 0; i < 3; i++) print i, "squared:", i*i, "\n"
Operators, by decreasing precedence: ^   ! - ++ --   * / %   + -
  > >= < <= == !=   &&   ||   = += -= *= /= %=
Built in: sin cos tan atan asin acos sinh cosh tanh log log10 exp sqrt int abs;
PI E GAMMA DEG PHI; _ is the last value printed. read(x) reads a number into x
(0 at the end); print takes expressions and "strings"; proc for a procedure;
if, else, while, for, { }; # starts a comment, a \ at a line's end continues it.
|}

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let args = List.tl (Array.to_list argv) in
  if args = [ "-h" ] || args = [ "--help" ] then Console.print caps help
  else begin
    Input.start caps argv.(0) args;
    (* hoc.y's warning, then execerror's recovery *)
    let warning msg =
      Console.eprint caps
        (Printf.sprintf "%s: %s%s near line %d\n" argv.(0) msg (match !Input.file with Some f -> " in " ^ f | None -> "") !Input.lineno);
      Input.recover () in
    (* an input's lines; after an error the lexer starts anew, as what
     * it had read ahead is dropped *)
    let rec lines lexbuf =
      Symbol.in_definition := false;
      match (match Parser.line Lexer.token lexbuf with End -> false | line -> Eval.run caps line; true) with
      | true -> lines lexbuf
      | false -> ()
      | exception Symbol.Error msg -> warning msg; lines (Lexer.lexbuf ())
      | exception (Parser.Error | Parsing.Parse_error) -> warning "syntax error"; lines (Lexer.lexbuf ())
    in
    while Input.more caps do lines (Lexer.lexbuf ()) done
  end;
  Exit.OK
