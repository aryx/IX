(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Unit_prolog.mli *)

module P = Prolog
module M = Prolog_machine

(* a term's text read, and written as writeq does *)
let rewrite (text : string) : string =
  let ops = P.default_ops () in
  match Prolog_read.term ops text with
  | t, _ -> P.to_string ops ~quoted:true t
  | exception Prolog_read.Error (msg, _) -> "error: " ^ msg

(* the same, operators aside: what the term is *)
let canonical (text : string) : string =
  let ops = P.default_ops () in
  let none : P.ops = { prefix = Hashtbl.create 1; infix = Hashtbl.create 1 } in
  match Prolog_read.term ops text with
  | t, _ -> P.to_string none ~quoted:true t
  | exception Prolog_read.Error (msg, _) -> "error: " ^ msg

(* a program consulted, a goal asked: every answer's value of X, then
 * what was printed and what was said of mistakes *)
let ask (program : string) (goal : string) : string =
  let m = Prolog_builtins.create () in
  let out = Buffer.create 80 in
  m.print <- Buffer.add_string out;
  m.warn <- Buffer.add_string out;
  Prolog_builtins.consult_text m "program" program;
  let answers : string list =
    match Prolog_read.term m.ops goal with
    | exception Prolog_read.Error (msg, _) -> [ "syntax error: " ^ msg ]
    | t, vars -> (
        let value () : string =
          match List.assoc_opt "X" vars with Some x -> P.to_string m.ops ~quoted:true (P.copy x) | None -> "true" in
        let rec all (found : bool) (acc : string list) : string list =
          if found then
            let v = value () in
            all (M.more m) (v :: acc)
          else List.rev acc in
        try all (M.solve m t) [] with M.Throw ball -> [ "throw: " ^ P.to_string m.ops ~quoted:true ball ]) in
  String.concat "; " answers ^ if Buffer.length out > 0 then " | " ^ Buffer.contents out else ""

let check = Alcotest.(check string)

let tests =
  Testo.categorize "Prolog"
    [
      Testo.create "a term read and written back" (fun () ->
          check "an atom" "foo" (rewrite "foo");
          check "a quoted atom" "'hello world'" (rewrite "'hello world'");
          check "a quote not needed" "abc" (rewrite "'abc'");
          check "a compound term" "f(a,'B_',1)" (rewrite "f( a , 'B_' , 1 )");
          check "a list" "[1,2,3]" (rewrite "[1, 2, 3]");
          check "a list's tail" "[a,b|c]" (rewrite "[a, b | c]");
          check "a text is its codes" "[104,105]" (rewrite "\"hi\"");
          check "a character's code" "97" (rewrite "0'a");
          check "curly braces" "{a,b}" (rewrite "{a, b}");
          check "a negative number" "-1" (rewrite "-1");
          check "minus a number" "- 1" (rewrite "-(1)");
          check "a clause" "a:-b,c" (rewrite "a :- b, c");
          check "a word operator" "x is 1+2" (rewrite "x is 1 + 2"));
      Testo.create "the operators' priorities" (fun () ->
          check "times before plus" "+(1,*(2,3))" (canonical "1 + 2 * 3");
          check "minus to the left" "-(-(1,2),3)" (canonical "1 - 2 - 3");
          check "power to the right" "^(2,^(3,4))" (canonical "2 ^ 3 ^ 4");
          check "comma to the right" "','(a,','(b,c))" (canonical "a, b, c");
          check "a body" ":-(h,;(','(a,b),->(c,d)))" (canonical "h :- a, b ; c -> d");
          check "parentheses" "*(+(1,2),3)" (canonical "(1 + 2) * 3");
          check "a prefix operator" "-(-(a))" (canonical "- - a");
          check "an operator as an atom" "f(+,-)" (canonical "f(+, -)");
          check "a sign and a subtraction" "-(a,-1)" (canonical "a - -1");
          check "the bar is a semicolon" ";(a,b)" (canonical "(a | b)");
          check "an argument is under the comma" "error: ) is expected, not :-" (canonical "f(a :- b)"));
      Testo.create "what the reader refuses" (fun () ->
          check "no end" "error: ) is expected, not the clause's end" (rewrite "f(a");
          check "two terms" "error: an operator or the clause's end is expected, not b" (rewrite "a b");
          check "a float" "error: a number with a fraction: there are no floats here" (rewrite "1.5");
          check "a quote" "error: a quote is not closed" (rewrite "'abc"));
      Testo.create "a goal's answers, in the clauses' order" (fun () ->
          let family = "parent(tom, bob). parent(tom, liz). parent(bob, ann). grand(X, Z) :- parent(X, Y), parent(Y, Z)." in
          check "a fact" "bob; liz" (ask family "parent(tom, X)");
          check "a rule" "ann" (ask family "grand(tom, X)");
          check "none" "" (ask family "parent(liz, X)");
          check "append, backwards" "[]-[1,2]; [1]-[2]; [1,2]-[]" (ask "" "append(A, B, [1,2]), X = A-B");
          check "the cut" "1" (ask "a(1). a(2). f(X) :- a(X), !." "f(X)");
          check "if then else" "small" (ask "" "( 1 < 2 -> X = small ; X = big )");
          check "negation binds nothing" "_" (String.sub (ask "" "\\+ X = 1, fail ; true") 0 1);
          check "findall" "[2,3]" (ask "a(1). a(2). a(3)." "findall(Y, (a(Y), Y > 1), X)");
          check "is" "14" (ask "" "X is 2 + 3 * 4"));
      Testo.create "what a program prints, and its mistakes" (fun () ->
          check "write and writeq" "true | a b'a b'\n" (ask "" "write('a b'), writeq('a b'), nl");
          check "a directive" "true | hello\n" (ask ":- write(hello), nl." "true");
          check "format" "true | x=1 a b 'a b'\n" (ask "" "format(\"x=~w ~w ~q~n\", [1, 'a b', 'a b'])");
          check "a mistake's line" "true | program:2: a term is expected, not the clause's end\n" (ask "a.\nb(.\nc." "c");
          check "a grammar" "[a,b]" (ask "s --> [a], t. t --> [b]." "phrase(s, X)"));
      Testo.create "errors are terms" (fun () ->
          check "unknown" "throw: error(existence_error(procedure,nope/0),_" (String.sub (ask "" "nope") 0 48);
          check "caught" "type_error(evaluable,foo/0)" (ask "" "catch(_ is foo + 1, error(X, _), true)");
          check "a throw undoes its bindings" "free" (ask "" "catch((Y = 1, throw(e)), e, true), ( var(Y) -> X = free ; X = bound )"));
    ]
