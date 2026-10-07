(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CLI.mli *)

type caps = < Dc.caps; Cap.stderr >

(* what bc reads: the library's text under a name, a file, the standard input *)
type input = Text of string * string | File of string | Stdin

let help = {|usage: mini-bc [-c] [-l] [-s] [FILE...]
Plan 9's bc, a calculator of numbers of any size in C's notation; the files'
statements, then the standard input's, each run when read:
  echo '2^100' | mini-bc                    1267650600228229401496703205376
  echo 'scale=20; sqrt(2); 1/3' | mini-bc   1.41421356237309504880 and .33333333333333333333
  mini-bc
  define f(n) {
    if (n <= 1) return (1)
    return (n * f(n-1))
  }
  f(20)                                     2432902008176640000
  echo 'obase=16; 255; ibase=2; 1010' | mini-bc
  echo 'scale=10; 4*a(1)' | mini-bc -l      pi, by the library's arctangent
A name is one letter: a variable (x), an array (x[i]), a function (x(a, b)).
scale is how many digits follow the point; ibase and obase the bases read and
printed. if, while, for, { }, break, return, define, auto; sqrt, length, scale;
"text" is printed. An expression alone is printed, an assignment is not.
-l: the library first: s (sine), c (cosine), a (arctangent), l (logarithm),
e (exponential), j (Bessel); -c: the dc commands compiled, not run; -s: an
expression alone is not printed.
|}

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let args = List.tl (Array.to_list argv) in
  if args = [ "-h" ] || args = [ "--help" ] then (Console.print caps help; Exit.OK)
  else begin
    let compile_only = ref false and library = ref false in
    let rec options = function
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          (match a.[1] with
           | 'd' -> options rest
           | 'c' -> compile_only := true; options rest
           | 'l' -> library := true; options rest
           | 's' -> State.silent := true; options rest
           | _ -> None)
      | files -> Some files in
    match options args with
    | None -> Console.eprint caps "Usage: bc [-cdls] [file ...]\n"; Exit.Code 1
    | Some files ->
        let out = Console.stdout caps in
        State.emit := (if !compile_only then (fun s -> output_string out s; flush out) else Dc.feed caps);
        (* the inputs in turn: the library, the files, the standard input;
         * a character at a time, so that a line typed is run when read *)
        let pending = ref ((if !library then [ Text ("/sys/lib/bclib", Bclib.text) ] else []) @ List.map (fun f -> File f) files @ [ Stdin ]) in
        let current : (unit -> int) ref = ref (fun () -> -1) in
        let of_fd fd =
          let buf = Bytes.create 8192 and pos = ref 0 and len = ref 0 in
          let rec next () =
            if !pos < !len then (incr pos; Char.code (Bytes.get buf (!pos - 1)))
            else match Unix.read fd buf 0 8192 with
              | 0 -> -1
              | n -> pos := 0; len := n; next ()
              | exception Unix.Unix_error _ -> -1 in
          next in
        let rec getc () =
          let c = !current () in
          if c >= 0 then c
          else match !pending with
            | [] -> -1
            | input :: rest ->
                pending := rest;
                State.line := 0;
                (match input with
                 | Stdin -> State.file := "stdin"; current := of_fd (Console.stdin_fd caps)
                 | Text (name, text) ->
                     State.file := name;
                     let pos = ref 0 in
                     current := (fun () -> if !pos < String.length text then (incr pos; Char.code text.[!pos - 1]) else -1)
                 | File f ->
                     State.file := f;
                     (match FS.open_in_fd caps f with
                      | fd -> current := of_fd fd
                      | exception (Unix.Unix_error _ | Sys_error _) -> State.error "cannot open input file"));
                getc () in
        let lexbuf = Lexing.from_function (fun buf _ -> let c = getc () in if c < 0 then 0 else (Bytes.set buf 0 (Char.chr c); 1)) in
        let rec statements () =
          (try Parser.stuff Lexer.token lexbuf with Parser.Error | Parsing.Parse_error -> State.error "syntax error");
          statements () in
        (try statements () with
         | State.Quit -> (try !State.emit "q" with Dc.Quit -> ())
         | Dc.Quit -> ());
        Exit.OK
  end
