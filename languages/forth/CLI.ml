(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-forth [-e text]... [-trace] [-s] [file.fs]...   (-h: how)"

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-forth [-e text]... [-trace] [-s] [file.fs]...
Forth: words between spaces, two stacks, a dictionary; run as threaded code.
For example:
  mini-forth -e '2 3 + .'                                 5: the operands first, then the word
  mini-forth -e ': SQUARE DUP * ;  7 SQUARE .'            49: a word defined, then used
  mini-forth -e ': SQUARE DUP * ;  SEE SQUARE'            what was compiled: the addresses of DUP, * and EXIT
  mini-forth -e ': FACT DUP 1 > IF DUP 1- RECURSE * THEN ;  10 FACT .'          3628800
  mini-forth -e ': STARS 0 DO [CHAR] * EMIT LOOP ;  5 STARS'                    *****
  mini-forth -e 'VARIABLE N  5 N !  N @ 1+ .'             6: a cell of the memory, stored into and fetched
  mini-forth -e ': ARRAY CREATE CELLS ALLOT DOES> + ;  10 ARRAY A  7 3 A !  3 A @ .'   7: a word that defines words
  mini-forth -e 'SEE IF'                                  IF is itself Forth: it compiles a jump
  mini-forth -e 'HEX FF . DECIMAL 255 .'                  FF 255
  mini-forth -trace -e ': SQUARE DUP * ;  7 SQUARE .'     each word the inner interpreter runs, the stack before it
  mini-forth sieve.fs                                     a file
  mini-forth                                              a prompt: a line typed, then ok
The files are interpreted in order, a line at a time, then each -e, in one
dictionary. A mistake is said with its file and line (the word, then ?), the
stacks are emptied, the rest of that text is left, and the exit is 1. With no
-e and no file, the lines typed are interpreted: ok after each, compiled
inside a definition. BYE ends.
-trace: each word run, indented by the return stack's depth. -s: the words
run, said at the end.
An address counts cells and a character takes one (C@ is @); a cell is 63
bits. What is not there: floats, double numbers, blocks, files' words (INCLUDE),
KEY and ACCEPT, vocabularies, an assembler.|}

let main (caps : < caps; .. >) (argv : string array) : int =
  let trace = ref false and stats = ref false in
  (* the texts, in order: where each is from, and it (a file's is read later) *)
  let texts : (string * string) list ref = ref [] in
  let options =
    [ ("-e", Arg.String (fun (e : string) -> texts := ("-e", e) :: !texts), " a text to interpret (several: in order)");
      ("-trace", Arg.Set trace, " each word run, the stack before it");
      ("-s", Arg.Set stats, " the words run, at the end") ] in
  match Arg.parse_argv argv options (fun (f : string) -> texts := (f, "") :: !texts) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      let m = Forth.create (Console.print caps) in
      Forth.set_trace m !trace;
      let ok = ref true in
      let complain (what : string) : unit =
        ok := false;
        flush (Console.stdout caps);
        Console.eprint caps (what ^ "\n") in
      (* (Plan 9's error is the file's name alone) *)
      let read (f : string) : string =
        match FS.path f with
        | Error msg -> failwith msg
        | Ok p -> ( try FS.read caps p with Sys_error msg -> failwith (if msg = f then f ^ ": cannot be read" else msg)) in
      (* a text's lines, to the first mistake *)
      let run (from : string) (text : string) : unit =
        let rec go (n : int) (lines : string list) : unit =
          match lines with
          | [] -> ()
          | line :: rest -> (
              match Forth.interpret m line with
              | () -> if not (Forth.finished m) then go (n + 1) rest
              | exception Forth.Error msg -> complain (Printf.sprintf "%s:%d: %s" from n msg)) in
        go 1 (String.split_on_char '\n' text) in
      try
        let texts = List.rev !texts in
        List.iter
          (fun ((from, text) : string * string) ->
            if not (Forth.finished m) then run from (if from = "-e" then text else read from))
          texts;
        if texts = [] then begin
          let chan = Console.stdin caps in
          try
            while not (Forth.finished m) do
              flush (Console.stdout caps);
              let line = input_line chan in
              match Forth.interpret m line with
              | () -> if not (Forth.finished m) then Console.print caps (if Forth.compiling m then " compiled\n" else " ok\n")
              | exception Forth.Error msg -> complain msg
            done
          with End_of_file -> ()
        end;
        flush (Console.stdout caps);
        if !stats then Console.eprint caps (Printf.sprintf "%d words run\n" (Forth.steps m));
        if !ok then 0 else 1
      with Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
