(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CLI.mli *)

module E = Scheme_eval

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-scheme [-student] [-step] [-e expression]... [-s] [file.scm]...   (-h: how)"

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-scheme [-student] [-step] [-e expression]... [-s] [file.scm]...
A small Scheme (R5RS's core) run by a CESK machine, and How to Design Programs'
Beginning Student over it. For example:
  mini-scheme -e '(+ 1 2 3)'                                  6
  mini-scheme -e "(map (lambda (x) (* x x)) '(1 2 3))"        (1 4 9)
  mini-scheme -student -e '(list 1 2)'                        (list 1 2): a value printed as what makes it
  mini-scheme -e '(define (f n) (if (= n 0) 1 (* n (f (- n 1)))))' -e '(f 10)'     3628800
  mini-scheme -e '(+ 1 (call/cc (lambda (k) (k 41))))'        42
  mini-scheme -e '(display "hello") (newline)'                hello
  mini-scheme -e '(circle 20 "solid" "red")'                  an image, said: there is no window to draw it in
  mini-scheme -step -e '(define (sq x) (* x x)) (sq (+ 1 2))' the stepper: each rewriting, before and after
  mini-scheme queens.scm                                      a file run
  mini-scheme                                                 a prompt: an expression typed, its value
The files are run in order, then each -e, in one machine: what one defines the
next sees. Each form at the top is evaluated and its value printed, as DrScheme
does on Execute, a definition's and (display ...)'s none. With no -e and no
file, what is typed is read: an expression may take several lines, and is run
when its last parenthesis closes. An error is said with its line, the rest of
that text is left, and the exit is 1.
-student: Beginning Student's way of printing. -step: nothing is run; the
stepper (Beginning Student's: define, cond, if, and, or, the built-ins) prints
each step of the texts. -s: the machine's steps, said at the end.
(big-bang ...) fails here: a world wants a window.|}

(* the line of a place in a text, from 1 *)
let line_of (text : string) (pos : int) : int =
  let n = ref 1 in
  String.iteri (fun (i : int) (c : char) -> if i < pos && c = '\n' then incr n) text;
  !n

(* is this text's end the middle of an expression? (a prompt reads on) *)
let unfinished (text : string) : bool =
  match Sexpr_read.read_all Sexpr_read.Scheme text with
  | _ -> false
  | exception Sexpr_read.Error (msg, _) -> String.length msg >= 12 && String.sub msg 0 12 = "end of input"

let main (caps : < caps; .. >) (argv : string array) : int =
  let student = ref false and step = ref false and stats = ref false in
  (* the texts, in order: where each is from, and it *)
  let texts : (string * string) list ref = ref [] in
  let st = ref (E.create ()) in
  let ok = ref true in
  let style () : Scheme.style = if !student then Scheme.Constructor else Scheme.Write in
  let error (from : string) (text : string) (err : E.error) : unit =
    ok := false;
    let where = match err.at with Some span -> Printf.sprintf "%s:%d: " from (line_of text span.start) | None -> from ^ ": " in
    Console.eprint caps (where ^ err.message ^ "\n") in
  (* what display printed, then the value *)
  let flush () : unit =
    let out, s = E.take_output !st in
    st := s;
    if out <> "" then Console.print caps out in
  (* a text's forms, one after the other, to the first error *)
  let run (from : string) (text : string) : unit =
    let rec go (forms : Sexpr.t list) : unit =
      match forms with
      | [] -> ()
      | x :: rest -> (
          match Scheme_syntax.top x with
          | exception Scheme_syntax.Error (message, span) -> error from text { message; at = Some span }
          | e ->
              (* (no budget here: a program that does not end is stopped
               * by who runs it) *)
              let rec finish (s : E.state) : E.outcome =
                match E.run ~fuel:100_000 s with
                | E.Running, s -> finish s
                | outcome, s -> st := s; outcome in
              let outcome = finish (E.start !st e) in
              flush ();
              (match outcome with
               | E.Done Scheme.Void -> go rest
               | E.Done (Scheme.Image i) -> Console.print caps (Scheme_image.to_string i ^ "\n"); go rest
               | E.Done v -> Console.print caps (Scheme.print (style ()) v ^ "\n"); go rest
               | E.Failed err -> error from text err
               | E.World w -> error from text { message = "big-bang: a world wants a window"; at = Some w.span }
               | E.Running -> ())) in
    match Sexpr_read.read_all Sexpr_read.Scheme text with
    | forms -> go forms
    | exception Sexpr_read.Error (message, pos) -> error from text { message = "read: " ^ message; at = Some { start = pos; stop = pos + 1 } } in
  (* the stepper: a step is the program before, an arrow, the program
   * after *)
  let steps (from : string) (text : string) : unit =
    let all, err = Scheme_step.steps ~max:1000 text in
    List.iter (fun (s : Scheme_step.step) -> Console.print caps (Printf.sprintf "%s\n=> %s\n\n" s.before s.after)) all;
    match err with Some message -> error from text { message; at = None } | None -> () in
  let options =
    [ ("-student", Arg.Set student, " Beginning Student's printing: (list 1 2), true");
      ("-step", Arg.Set step, " the stepper's steps, nothing run");
      ("-e", Arg.String (fun (e : string) -> texts := ("-e", e) :: !texts), " an expression (or several) to evaluate");
      ("-s", Arg.Set stats, " the machine's steps, at the end") ] in
  let path (f : string) : Fpath.t = match FS.path f with Ok p -> p | Error msg -> failwith msg in
  match Arg.parse_argv argv options (fun (f : string) -> texts := (f, "") :: !texts) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      try
        let texts = List.map (fun ((from, text) : string * string) -> if from = "-e" then (from, text) else (from, FS.read caps (path from))) (List.rev !texts) in
        List.iter (fun ((from, text) : string * string) -> if !step then steps from text else run from text) texts;
        if texts = [] then begin
          let chan = Console.stdin caps in
          let pending = ref "" in
          try
            while true do
              Console.print caps (if !pending = "" then "> " else "  ");
              pending := !pending ^ input_line chan ^ "\n";
              if not (unfinished !pending) then begin
                (if !step then steps "stdin" !pending else run "stdin" !pending);
                pending := ""
              end
            done
          with End_of_file -> Console.print caps "\n"
        end;
        if !stats then Console.eprint caps (Printf.sprintf "%d steps\n" (E.steps !st));
        if !ok then 0 else 1
      with Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
