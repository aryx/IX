(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Output.mli *)

(* 16-bit numbers, the low byte first, as a string's text *)
let packed (ns : int list) =
  let b = Buffer.create (8 * List.length ns) in
  List.iter (fun n -> Buffer.add_string b (Printf.sprintf "\\%03d\\%03d" (n land 255) ((n lsr 8) land 255))) ns;
  Buffer.contents b

(* a clause's variables in their order, each: whether it names one
 * character at each place, whether every way through binds it *)
let variables (re : Lex.regexp) =
  let rec names (r : Lex.regexp) acc =
    match r with
    | Bind (x, r) -> names r (if List.mem x acc then acc else acc @ [ x ])
    | Seq (a, b) | Alt (a, b) -> names b (names a acc)
    | Star r -> names r acc
    | Chars _ | Eps -> acc
  in
  let rec is_char x (r : Lex.regexp) =
    match r with
    | Bind (y, r) -> (x <> y || (match r with Chars _ -> true | _ -> false)) && is_char x r
    | Seq (a, b) | Alt (a, b) -> is_char x a && is_char x b
    | Star r -> is_char x r
    | Chars _ | Eps -> true
  in
  let rec always x (r : Lex.regexp) =
    match r with
    | Bind (y, r) -> x = y || always x r
    | Seq (a, b) -> always x a || always x b
    | Alt (a, b) -> always x a && always x b
    | Star _ | Chars _ | Eps -> false
  in
  List.map (fun x -> x, is_char x re, always x re) (names re [])

(* the regexp as a value of Lexing's, a variable its number *)
let rec value vars (r : Lex.regexp) =
  match r with
  | Chars set when set.[256] = '\001' -> "Lexing.Eof"
  | Chars set ->
      let bits = String.init 32 (fun i -> Char.chr (List.fold_left (fun n k -> if set.[(8 * i) + k] = '\001' then n lor (1 lsl k) else n) 0 [ 0; 1; 2; 3; 4; 5; 6; 7 ])) in
      Printf.sprintf "Lexing.Chars %S" bits
  | Eps -> "Lexing.Eps"
  | Seq (a, b) -> Printf.sprintf "Lexing.Seq (%s, %s)" (value vars a) (value vars b)
  | Alt (a, b) -> Printf.sprintf "Lexing.Alt (%s, %s)" (value vars a) (value vars b)
  | Star a -> Printf.sprintf "Lexing.Star (%s)" (value vars a)
  | Bind (x, a) ->
      let rec index k = function (y, _, _) :: rest -> if x = y then k else index (k + 1) rest | [] -> assert false in
      Printf.sprintf "Lexing.Bind (%d, %s)" (index 0 vars) (value vars a)

let ocaml ~file ~out (lex : Lex.t) (dfa : Dfa.t) : string =
  let b = Buffer.create 65536 in
  (* the lines written so far: after a piece of the .mll, the next line is this file's again *)
  let written = ref 1 in
  let add s = String.iter (fun c -> if c = '\n' then incr written) s; Buffer.add_string b s in
  let lines () = !written in
  let code (c : Lex.code) =
    add (Printf.sprintf "\n# %d %S\n%s%s\n" c.line file (String.make c.col ' ') c.text);
    add (Printf.sprintf "# %d %S\n" (lines () + 1) out)
  in
  Option.iter code lex.header;
  let nstates = Array.length dfa.trans in
  add "let __tables : Lexing.tables = {\n  trans = \"";
  Array.iter (fun row -> add (packed (List.map (fun s -> s + 1) (Array.to_list row))); add "\\\n   ") dfa.trans;
  add (Printf.sprintf "\";\n  accept = \"%s\" }\n\n" (packed (List.init nstates (fun s -> dfa.accept.(s) + 1))));
  List.iteri (fun k (r : Lex.rule) ->
    add (Printf.sprintf "%s %s %slexbuf =\n  match Lexing.engine __tables %d lexbuf with\n" (if k = 0 then "let rec" else "and") r.name
           (String.concat "" (List.map (fun p -> p ^ " ") r.params)) (List.nth dfa.starts k));
    List.iteri (fun n (c : Lex.clause) ->
      add (Printf.sprintf "  | %d ->" n);
      (match c.re, variables c.re with
       | _, [] -> ()
       | Bind (x, _), [ (_, is_char, _) ] ->
           add (Printf.sprintf " let %s = %s in" x (if is_char then "Lexing.lexeme_char lexbuf 0" else "Lexing.lexeme lexbuf"))
       | _, vars ->
           add (Printf.sprintf " let __m = Lexing.captures (%s) %d lexbuf in" (value vars c.re) (List.length vars));
           List.iteri (fun i (x, is_char, always) ->
             add (Printf.sprintf " let %s = Lexing.sub%s%s lexbuf __m %d in" x (if is_char then "_char" else "") (if always then "" else "_opt") i)) vars);
      add (Printf.sprintf "\n# %d %S\n%s(%s)\n" c.action.line file (String.make (max 0 (c.action.col - 1)) ' ') c.action.text);
      add (Printf.sprintf "# %d %S\n" (lines () + 1) out)) r.clauses;
    add "  | _ -> assert false\n\n") lex.rules;
  Option.iter code lex.trailer;
  Buffer.contents b
