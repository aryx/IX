(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

module D = Datalog

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

let usage = "usage: mini-datalog [-q query]... [-all] [-naive] [-s] file.dl...   (-h: how)"

(* -h: how, by an example *)
let help = {|usage: mini-datalog [-q query]... [-all] [-naive] [-s] file.dl...
Datalog: facts, and rules run until nothing new is found. A file's text is
Prolog's, without compound terms:
  edge(a, b). edge(b, c). edge(c, a). edge(c, d).     facts
  path(X, Y) :- edge(X, Y).                           rules: a path is an edge,
  path(X, Y) :- path(X, Z), edge(Z, Y).               or a path and an edge after it
  node(X) :- edge(X, _).   node(Y) :- edge(_, Y).
  apart(X, Y) :- node(X), node(Y), \+ path(X, Y).     a negation: no path from X to Y
  ?- path(a, X).                                      a query (or, on a line: path(a, X)?)
  mini-datalog graph.dl                  path(a,a). path(a,b). path(a,c). path(a,d).
  mini-datalog -q 'apart(d, X)' graph.dl apart(d,a). apart(d,b). apart(d,c). apart(d,d).
The files are read in order as one program (rules in one, facts in another),
then it is run, then each query of the files and each -q is answered: the
tuples that match, as facts, sorted. With no query, nothing is printed but by
-all: every tuple of every relation that has a rule.
A rule whose head is in its own body is no loop here, where it is one in
Prolog: path above is found whole, by any order of its rules and its atoms.
\+ p(...) (or not(p(...))) holds when no tuple matches; a relation is
computed whole before another negates it, and a negation through a recursion
is refused. = \= < > =< >= compare two values (numbers, then atoms).
-naive: every rule on every tuple each round (the definition; the default runs
a rule again only on what the last round found). -s: the relations' sizes,
the rounds, the rules' firings.|}

let main (caps : < caps; .. >) (argv : string array) : int =
  let queries : string list ref = ref [] and files : string list ref = ref [] in
  let all = ref false and naive = ref false and stats = ref false in
  let options =
    [ ("-q", Arg.String (fun (q : string) -> queries := q :: !queries), " a query: the tuples that match it");
      ("-all", Arg.Set all, " every tuple of every relation that has a rule");
      ("-naive", Arg.Set naive, " every rule on every tuple, each round");
      ("-s", Arg.Set stats, " the relations' sizes, the rounds, the firings") ] in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      let p = D.create () in
      try
        if !files = [] then failwith usage;
        List.iter
          (fun (f : string) ->
            let path : Fpath.t = match FS.path f with Ok path -> path | Error msg -> failwith msg in
            (* (Plan 9's error is the file's name alone) *)
            let text = try FS.read caps path with Sys_error msg -> failwith (if msg = f then f ^ ": cannot be read" else msg) in
            D.load p ~from:f text)
          (List.rev !files);
        let asked = List.map (D.query p) (List.rev !queries) in
        (* a relation that is read and never written: a name mistyped, most often *)
        Hashtbl.iter
          (fun (_ : string) (r : D.relation) ->
            if r.rules = 0 && r.given = 0 then
              Console.eprint caps (Printf.sprintf "warning: %s/%d has no fact and no rule\n" r.name r.arity))
          p.relations;
        let st = Datalog_eval.run ~naive:!naive p in
        let relations : D.relation list =
          List.sort
            (fun (a : D.relation) (b : D.relation) -> compare (a.name, a.arity) (b.name, b.arity))
            (Hashtbl.fold (fun (_ : string) (r : D.relation) (acc : D.relation list) -> r :: acc) p.relations []) in
        if !all then
          List.iter
            (fun (r : D.relation) ->
              if r.rules > 0 then
                List.iter
                  (fun (line : string) -> Console.print caps (line ^ "\n"))
                  (List.sort String.compare (List.map (D.show p r) r.all)))
            relations;
        List.iter
          (fun (q : D.query) -> List.iter (fun (line : string) -> Console.print caps (line ^ "\n")) (Datalog_eval.answers p q))
          (List.rev p.queries @ asked);
        flush (Console.stdout caps);
        if !stats then begin
          List.iter
            (fun (r : D.relation) ->
              Console.eprint caps
                (Printf.sprintf "%-32s %8d tuples, %d given, %d rules, stratum %d\n" (Printf.sprintf "%s/%d" r.name r.arity) r.count
                   r.given r.rules r.stratum))
            relations;
          Console.eprint caps
            (Printf.sprintf "%d rounds, %d firings, %d new tuples, %d lookups, %d symbols\n" st.rounds st.firings st.derived st.lookups
               p.nsymbols)
        end;
        0
      with
      | D.Error (msg, at) -> Console.eprint caps (Printf.sprintf "%s: %s\n" at msg); 1
      | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
