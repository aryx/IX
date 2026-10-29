(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Builtin.caps; Cap.stdin; Cap.stdout; Cap.stderr >

let help = {|usage: mini-acid [-l library]...
Plan 9's acid, a debugger that is a language: the libraries read (-l, each a
file of acid), then the standard input, a statement at a time:
  mini-acid
  acid: defn fact(n) { if n <= 1 then return 1; return n*fact(n-1); }
  acid: fact(10)\D
  3628800
  acid: x = {1, "two", {3}}; print(head x, " ", tail x)
  0x00000001 {"two", {0x00000003}}
A value has a format (x\D: decimal, \X hexadecimal, \s a string, \c a
character...); its statements are C's (if e then s else s, while e do s,
loop a, b do s), with lists (head, tail, append, delete, {a, b}), local and
return in a defn. Not yet: the process (*, @, start, stop, the symbols).
|}

(* the input's name, for the errors: <stdin>:12: (error) ... *)
let source = ref "<stdin>"

(* a statement at a time, run as soon as it is read; after a syntax
 * error the rest of the statement is dropped, up to its ; (an error in
 * running one comes after it is read whole) *)
let run (caps : < caps; .. >) lexbuf ~prompt =
  (* (written out at once: at a terminal, the answer before the next line) *)
  let write s = let oc = Console.stdout caps in output_string oc s; flush oc in
  let flush () =
    write (Buffer.contents Eval.out);
    Buffer.clear Eval.out in
  let report msg =
    flush ();
    write (Printf.sprintf "%s:%d: (error) %s\n" !source !Lexer.line msg);
    Eval.reset () in
  let rec skip () = match Lexer.token lexbuf with Parser.SEMI | Parser.EOF -> () | _ -> skip () | exception Lexer.Error _ -> skip () in
  let next () = flush (); if prompt then write "acid: " in
  Eval.ran := next;
  (* a parse to the end, or to an error: then another from where it was *)
  let rec loop () =
    match Parser.program Lexer.token lexbuf with
    | () -> flush (); if prompt then write "\n"     (* (acid's at the end) *)
    | exception Eval.Error msg -> report msg; next (); loop ()
    | exception Lexer.Error msg -> report msg; Lexer.depth := 0; skip (); next (); loop ()
    | exception Parsing.Parse_error ->
        flush ();
        write (Printf.sprintf "%s:%d: syntax error, near symbol '%s'\n" !source !Lexer.line !Lexer.symbol);
        Eval.reset (); Lexer.depth := 0; skip (); next (); loop ()
  in
  if prompt then write "acid: ";
  loop ()

(* the standard input as the lexer reads it: what a read gives, a line
 * at a terminal, so that a statement runs when its line is typed *)
let stdin_lexbuf (caps : < caps; .. >) =
  let fd = Console.stdin_fd caps in
  Lexing.from_function (fun b n -> try Unix.read fd b 0 n with Unix.Unix_error _ -> 0)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let rec libs acc = function
    | "-l" :: f :: rest -> libs (f :: acc) rest
    | [] -> Some (List.rev acc)
    | _ -> None in
  match libs [] (List.tl (Array.to_list argv)) with
  | None -> Console.eprint caps help; Exit.Code 1
  | Some files ->
      Builtin.init caps;
      List.iter (fun f ->
        match FS.read_opt caps (Fpath.v f) with
        | Some text ->
            source := f;
            Lexer.line := 1;
            Lexer.interactive := false;
            run caps (Lexing.from_string text) ~prompt:false
        | None -> Console.print caps (Printf.sprintf "%s:%d: (error) pushfile: %s: file does not exist\n" !source !Lexer.line f)) files;
      source := "<stdin>";
      Lexer.line := 1;
      Lexer.interactive := true;
      run caps (stdin_lexbuf caps) ~prompt:true;
      Exit.OK
