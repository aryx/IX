(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Lower's jump tables (switches): constants alone, blocks alone, both;
 * a clause past the constructor's test, one tested in full (an
 * or-pattern, a guard, an alias, a field's constant), a wildcard
 * between, a failed clause going on to the next, Match_failure; in a
 * tail call and inside an expression *)

type c = A | B | C | D | E | F
type b = P of int | Q of int * int | R of string | S | T | U of c | V of b | W

let const = function
  | A -> 1
  | B | C -> 2
  | D -> 3
  | _ -> 4

let rec block depth x =
  match x with
  | P 0 -> "p0"
  | P n when n > 10 -> "p>10"
  | Q (a, b) as q when a = b -> (match q with Q _ -> "q=" | _ -> "?")
  | P n -> "p" ^ string_of_int n
  | R s -> "r" ^ s
  | S -> "s"
  | U (A | B) -> "uab"
  | U c -> "u" ^ string_of_int (const c)
  | V y -> if depth > 3 then "deep" else block (depth + 1) y
  | Q (a, _) -> "q" ^ string_of_int a
  | T | W -> "tw"

let blocks = function
  | P n -> n
  | Q (a, b) -> a + b
  | R s -> String.length s
  | U _ -> 100
[@@warning "-8"]

let total l = List.fold_left (fun acc x -> acc + (try blocks x with Match_failure _ -> -1)) 0 l

let () =
  print_endline (String.concat " " (List.map (fun c -> string_of_int (10 + const c)) [ A; B; C; D; E; F ]));
  let all = [ P 0; P 11; P 5; Q (2, 2); Q (3, 4); R "x"; S; T; U A; U B; U D; U F; V (V (P 1)); V (V (V (V (V S)))); W ] in
  print_endline (String.concat " " (List.map (block 0) all));
  Printf.printf "%d\n" (1 + total all);
  let mixed = [ Some 1; None ] in
  print_endline (String.concat " " (List.map (function Some n -> string_of_int n | None -> "none") mixed))
