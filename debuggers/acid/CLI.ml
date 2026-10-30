(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Builtin.caps; Proc.caps; Cap.stdin; Cap.stdout; Cap.stderr >

let help = {|usage: mini-acid [-l library]... [pid | program [pid]]
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
return in a defn. A program (its a.out, or /proc/PID/text) gives its symbols
as variables; a process its memory (*addr, @addr in the file), its registers
(*PC, *R0); the library (port.acid, arm.acid, from /lib/acid or -l) the rest
(debuggers/acid/lib: new, bpset, cont, step, next, stk, src, regs, asm, mem):
  mini-acid -l port.acid -l arm.acid ./prog
  acid: new()
  acid: bpset(leaf); cont(); stk()
A program's types: acid's declarations (aggr, complex T v), mini-cc -a's in a
file (-l), or in the program, mini-cc -g and mini-ld -g's (.acid); then a
value prints by its type (n1, n1.next->name, *walk:n).
An ML value prints by its words (ml(*Values.l): [1; 2; 3]), a unit's global
named M.x; by its type when mini-ml -g described it (ml(Values.p):
{x = 1; y = 2; name = "origin"}; mlvars(): every global).
On Linux (arm64), a program of this machine, an ELF, by ptrace, with
arm64.acid: mini-cc's, mini-ml's, mini-asm's linked by mini-ld -g -H7 (their
names, lines and types in the program), gcc's (its names, DWARF's lines; its
types by mini-cc -m 7 -a's declarations of its .c, -l):
  mini-acid -l port.acid -l arm64.acid -l prog.acid ./prog
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

(* a library read: acid's loadmodule, statements run, no prompt *)
let run_text (caps : < caps; .. >) name text =
  source := name;
  Lexer.line := 1;
  Lexer.interactive := false;
  run caps (Lexing.from_string text) ~prompt:false

let library (caps : < caps; .. >) f = Option.iter (run_text caps f) (FS.read_opt caps (Fpath.v f))

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let rec options libs = function
    | "-l" :: f :: rest -> options (f :: libs) rest
    | ("-q" | "-w" | "-k") :: rest -> options libs rest
    | rest when List.for_all (fun a -> a = "" || a.[0] <> '-') rest -> Some (List.rev libs, rest)
    | _ -> None in
  let number s = match int_of_string_opt s with Some n when n > 0 -> Some n | _ -> None in
  match options [] (List.tl (Array.to_list argv)) with
  | None -> Console.eprint caps help; Exit.Code 1
  | Some (files, args) ->
      Builtin.init caps;
      Proc.init caps;
      (* acid's main: its variables, the program and its process, the
       * registers, the libraries (/lib/acid's when there, then -l's),
       * acidinit(), the symbols as variables, acidmap() *)
      List.iter (fun (n, v) -> Eval.set_global n v)
        [ "proc", Value.int 'X' 0L; "pid", Value.int 'D' 0L; "proclist", Value.empty ];
      let aout, pid = match args with
        | [ p ] when number p <> None -> Some (Printf.sprintf "/proc/%s/text" p), number p
        | [ p; a ] when number p <> None -> Some a, number p
        | a :: _ -> Some a, None
        | [] -> None, None in
      let start f = try f () with Eval.Error msg ->
        Console.print caps (Buffer.contents Eval.out); Buffer.clear Eval.out;
        Console.print caps (Printf.sprintf "%s:%d: (error) %s\n" !source !Lexer.line msg) in
      (match aout with
       | Some a -> start (fun () -> Proc.program caps a; match pid with Some p -> Proc.attach caps p | None -> ())
       | None -> Proc.registers ());
      List.iter (library caps) [ "/lib/acid/port.acid"; "/lib/acid/arm.acid" ];
      List.iter (fun f ->
        match FS.read_opt caps (Fpath.v f) with
        | Some text ->
            source := f;
            Lexer.line := 1;
            Lexer.interactive := false;
            run caps (Lexing.from_string text) ~prompt:false
        | None -> Console.print caps (Printf.sprintf "%s:%d: (error) pushfile: %s: file does not exist\n" !source !Lexer.line f)) files;
      (* the program's declarations, its own (mini-ld -g): as a -l's *)
      Option.iter (run_text caps (match aout with Some a -> a ^ ":.acid" | None -> ".acid")) (Proc.declarations ());
      (* userinit: the library's acidinit() (arm.acid's: bpfmt, srcpath) *)
      start (fun () -> Eval.call_if_defined "acidinit" []);
      if aout <> None then start Proc.symbols;
      start (fun () -> Eval.call_if_defined "acidmap" []);
      Console.print caps (Buffer.contents Eval.out); Buffer.clear Eval.out;
      source := "<stdin>";
      Lexer.line := 1;
      Lexer.interactive := true;
      run caps (stdin_lexbuf caps) ~prompt:true;
      (* die's: the processes left, how to kill them *)
      List.iter (fun p -> Console.print caps (if Ptrace.available then Printf.sprintf "kill %d\n" p else Printf.sprintf "echo kill > /proc/%d/ctl\n" p)) (Proc.attached ());
      Exit.OK
