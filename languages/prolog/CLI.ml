(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

module P = Prolog
module M = Prolog_machine

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-prolog [-g goal]... [-wam] [-S] [-trace] [-s] [file.pl]...   (-h: how)"

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-prolog [-g goal]... [-wam] [-S] [-trace] [-s] [file.pl]...
Prolog: Edinburgh's syntax, the standard's core, integers only. For example:
  mini-prolog -g 'X is 6 * 7, write(X), nl'                    42
  mini-prolog -g 'append(X, Y, [a,b]), write(X-Y), nl, fail'   []-[a,b]  [a]-[b]  [a,b]-[]: every answer, by failing
  mini-prolog -g 'findall(X, member(X, [c,a,b]), L), msort(L, S), print(S), nl'      [a,b,c]
  mini-prolog -g 'atom_codes(A, "hello"), atom_length(A, N), print(A/N), nl'         hello/5
  mini-prolog -g "phrase(([a], [b]), L), print(L), nl"         [a,b]: a grammar's body run
  mini-prolog -g 'catch(X is foo + 1, error(E, _), (print(E), nl))'   type_error(evaluable,foo/0)
  mini-prolog queens.pl -g 'queens(8, Qs), print(Qs), nl'      a file consulted, then a goal
  mini-prolog -trace family.pl -g 'grandparent(tom, X)'        the four ports: Call, Exit, Redo, Fail
  mini-prolog -wam queens.pl -g 'queens(8, Qs), print(Qs), nl' the same by Warren's machine: the clauses compiled
  mini-prolog -S app.pl                                        that machine's code for the file's predicates
  mini-prolog family.pl                                        the file, then a prompt
  mini-prolog                                                  a prompt: ?- a goal, ended by a dot
The files are consulted in order (a clause added, a directive :- Goal run), then
each -g goal is run once: a goal that fails or throws is said and the exit is 1.
With no -g, a prompt: a goal may take several lines, to its final dot; its
answer is the variables' values, or true, or false. If there may be another
answer, ' ?' waits: ; and Enter asks for it, Enter alone stops.
-trace: each call's ports are printed. -s: the machine's steps, at the end.
-wam: the clauses are compiled to the WAM's instructions (get, put, unify, call,
try, retry, trust, a switch on the first argument) and run by it; the answers
are the same, the steps counted are then the calls, and there is no -trace.
-S: the instructions of the files' predicates, nothing run. In it Xn and An are
the same register, a label Ln is the n-th clause, and L1|L2 is the choice
between two; a '$aux' predicate is a disjunction's or an if-then-else's.
What is not there: floats, modules, strings (a text between double quotes is
the list of its codes), the occurs check (unify_with_occurs_check does it).|}

(* an answer: the query's variables, each with its value *)
let answer (m : M.t) (vars : (string * P.term) list) : string =
  let shown =
    List.filter_map
      (fun ((name, v) : string * P.term) ->
        if name.[0] = '_' then None else Some (name ^ " = " ^ P.to_string m.ops ~quoted:true v))
      vars in
  match shown with [] -> "true" | _ -> String.concat ",\n" shown

let main (caps : < caps; .. >) (argv : string array) : int =
  let goals : string list ref = ref [] and files : string list ref = ref [] in
  let trace = ref false and stats = ref false and wam = ref false and code = ref false in
  let options =
    [ ("-g", Arg.String (fun (g : string) -> goals := g :: !goals), " a goal to run after the files (several: in order)");
      ("-wam", Arg.Set wam, " run by Warren's machine: the clauses compiled");
      ("-S", Arg.Set code, " that machine's instructions for the files' predicates, nothing run");
      ("-trace", Arg.Set trace, " each call's ports: Call, Exit, Redo, Fail");
      ("-s", Arg.Set stats, " the machine's steps, at the end") ] in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      let m = Prolog_builtins.create () in
      let chan = Console.stdin caps in
      m.print <- Console.print caps;
      m.warn <- (fun (s : string) -> flush (Console.stdout caps); Console.eprint caps s);
      m.read_line <- (fun () -> flush (Console.stdout caps); try Some (input_line chan) with End_of_file -> None);
      (* milliseconds since the first time it was asked (0 where there is no clock: mini-5i) *)
      let start : float option ref = ref None in
      m.clock <-
        (fun () ->
          match Unix.gettimeofday () with
          | exception Unix.Unix_error _ -> 0
          | now -> (
              match !start with
              | None -> start := Some now; 0
              | Some t0 -> int_of_float ((now -. t0) *. 1000.)));
      (* (Plan 9's error is the file's name alone) *)
      m.read_file <-
        (fun (f : string) ->
          match FS.path f with
          | Error msg -> failwith msg
          | Ok p -> ( try FS.read caps p with Sys_error msg -> failwith (if msg = f then f ^ ": cannot be read" else msg)));
      let ok = ref true in
      let complain (what : string) : unit =
        ok := false;
        flush (Console.stdout caps);
        Console.eprint caps (what ^ "\n") in
      (* a goal's text read; None: said *)
      let read (text : string) : (P.term * (string * P.term) list) option =
        match Prolog_read.next (Prolog_read.make m.ops text) with
        | x -> x
        | exception Prolog_read.Error (msg, _) -> complain ("syntax error: " ^ msg); None in
      let finish () : int =
        flush (Console.stdout caps);
        if !stats then Console.eprint caps (Printf.sprintf "%d steps\n" m.steps);
        if !ok && m.errors = 0 then 0 else 1 in
      try
        if !trace && (!wam || !code) then failwith "-trace is the first machine's: not with -wam";
        let w : Wam_machine.t option = if !wam || !code then Some (Wam_machine.install m) else None in
        (* the prelude's predicates: not the files' *)
        let before : (string, unit) Hashtbl.t = Hashtbl.create 255 in
        Hashtbl.iter (fun (k : string) (_ : M.proc) -> Hashtbl.replace before k ()) m.procs;
        List.iter
          (fun (f : string) ->
            match M.once m (P.Struct ("consult", [ P.Atom f ])) with
            | _ -> ()
            | exception M.Throw ball -> complain (Prolog_builtins.message m ball))
          (List.rev !files);
        m.trace <- !trace;
        (match w with
         | Some w when !code ->
             let mine : (string * int) list ref = ref [] in
             Hashtbl.iter
               (fun (k : string) (proc : M.proc) ->
                 match proc with
                 | M.Pred p -> if not (Hashtbl.mem before k) then mine := (p.name, p.arity) :: !mine
                 | _ -> ())
               m.procs;
             List.iter
               (fun ((name, arity) : string * int) ->
                 match Wam_machine.listing w name arity with
                 | Some text -> Console.print caps (text ^ "\n")
                 | None -> ())
               (List.sort compare !mine);
             raise (M.Halt (if m.errors = 0 then 0 else 1))
         | _ -> ());
        List.iter
          (fun (g : string) ->
            match read (g ^ " .") with
            | None -> ()
            | Some (goal, _) -> (
                match M.solve m goal with
                | true -> ()
                | false -> complain ("the goal failed: " ^ g)
                | exception M.Throw ball -> complain (Prolog_builtins.message m ball)))
          (List.rev !goals);
        if !goals = [] then begin
          let pending = ref "" in
          try
            while true do
              Console.print caps (if !pending = "" then "?- " else "|    ");
              (* (the prompt is seen before the line is waited for) *)
              flush (Console.stdout caps);
              pending := !pending ^ input_line chan ^ "\n";
              if String.trim !pending = "" then pending := ""
              else if Prolog_read.complete !pending then begin
                let text = !pending in
                pending := "";
                match read text with
                | None -> ()
                | Some (goal, vars) -> (
                    (* an answer, and the next while ; is typed *)
                    let rec answers (found : bool) : unit =
                      if not found then Console.print caps "false.\n"
                      else if not (M.has_more m) then Console.print caps (answer m vars ^ ".\n")
                      else begin
                        Console.print caps (answer m vars ^ " ? ");
                        flush (Console.stdout caps);
                        match String.trim (input_line chan) with
                        | ";" -> answers (M.more m)
                        | _ -> ()
                      end in
                    try answers (M.solve m goal)
                    with M.Throw ball ->
                      flush (Console.stdout caps);
                      Console.eprint caps (Prolog_builtins.message m ball ^ "\n"))
              end
            done
          with End_of_file -> Console.print caps "\n"
        end;
        finish ()
      with
      | M.Halt code ->
          flush (Console.stdout caps);
          code
      | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
