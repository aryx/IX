(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCLexer.mli *)

(*****************************************************************************)
(* Tokens and the preprocessor *)
(*****************************************************************************)

type token =
  | Id of string | Num of int64 * bool (* LL *) | Str of string | P of string
  | EOF

let puncts = [ "<<="; ">>="; "..."; "->"; "++"; "--"; "<<"; ">>"; "<="; ">=";
               "=="; "!="; "&&"; "||"; "+="; "-="; "*=";
               "/="; "%="; "&="; "|="; "^=" ]

(* where a token is, for the errors: its file (an #include's own) and line *)
type loc = string * int

(* a file's tokens, its #includes' in their place, #defines expanded
 * (a macro's tokens where it is used) *)
let rec tokens (macros : (string, (token * loc) list) Hashtbl.t)
    (read : string -> string) file : (token * loc) list =
  let s = read file in
  let n = String.length s in
  let out = ref [] in
  (* the line of position i, counted from the last one asked: tokens come
   * in the order of their positions *)
  let counted = ref 0 and line = ref 1 in
  let loc i =
    for k = !counted to min i n - 1 do if s.[k] = '\n' then incr line done;
    counted := max !counted i;
    (file, !line)
  in
  let emit i t =
    let l = loc i in
    match t with
    | Id x when Hashtbl.mem macros x ->
        out :=
          List.rev_append
            (List.map (fun (t, _) -> t, l) (Hashtbl.find macros x)) !out
    | t -> out := (t, l) :: !out in
  (* (old: '0' .. '9' and the others as patterns: tiny-ml has no
   * character ranges) *)
  let digit c = c >= '0' && c <= '9' in
  let letter c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_' in
  let escape i =
    (* the escapes: n t r, octal, and any other character as itself *)
    match s.[i] with
    | 'n' -> 10, i + 1 | 't' -> 9, i + 1 | 'r' -> 13, i + 1
    | c when c >= '0' && c <= '7' ->
        let rec oct j v =
          if j < n && j < i + 3 && s.[j] >= '0' && s.[j] <= '7' then
            oct (j + 1) ((v * 8) + Char.code s.[j] - 48)
          else v, j in
        oct i 0
    | c -> Char.code c, i + 1
  in
  let rec span j p = if j < n && p s.[j] then span (j + 1) p else j in
  let rec go i bol =
    if i >= n then ()
    else
      match s.[i] with
      | '\n' -> go (i + 1) true
      | ' ' | '\t' | '\r' -> go (i + 1) bol
      | '#' when bol ->
          let e = try String.index_from s i '\n' with Not_found -> n in
          let line = String.sub s (i + 1) (e - i - 1) in
          (match List.filter (( <> ) "")
                   (String.split_on_char ' '
                      (String.map (function '\t' -> ' ' | c -> c) line)) with
           | "include" :: f :: _ when f.[0] = '"' ->
               let f = String.sub f 1 (String.length f - 2) in
               let dir = Filename.dirname file in
               let f =
                 if Filename.is_relative f && dir <> "." then
                   Filename.concat dir f
                 else f in
               out := List.rev_append (tokens macros read f) !out
           | "define" :: name :: _ ->
               (* the rest of the line, lexed *)
               let rest =
                 String.sub line (String.index line 'd' + 6)
                   (String.length line - String.index line 'd' - 6) in
               let rest = String.trim rest in
               let rest =
                 String.sub rest (String.length name)
                   (String.length rest - String.length name) in
               Hashtbl.replace macros name (tokens macros (fun _ -> rest) file)
           | _ -> ());
          go e true
      | '/' when i + 1 < n && s.[i + 1] = '/' ->
          go (try String.index_from s i '\n' with Not_found -> n) true
      | '/' when i + 1 < n && s.[i + 1] = '*' ->
          let rec close j =
            if j + 1 >= n then n
            else if s.[j] = '*' && s.[j + 1] = '/' then j + 2
            else close (j + 1) in
          go (close (i + 2)) bol
      | c when letter c ->
          let j = span i (fun c -> letter c || digit c) in
          emit i (Id (String.sub s i (j - i)));
          go j false
      | c when digit c ->
          let k = span i (fun c ->
            digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
            || c = 'x' || c = 'X') in
          let lit = String.sub s i (k - i) in
          let lit =
            if String.length lit > 1 && lit.[0] = '0' && lit.[1] <> 'x'
               && lit.[1] <> 'X'
            then "0o" ^ String.sub lit 1 (String.length lit - 1)
            else lit in
          let j =
            span k (function 'u' | 'U' | 'l' | 'L' -> true | _ -> false) in
          let suffix = String.lowercase_ascii (String.sub s k (j - k)) in
          emit i (Num (Int64.of_string lit,
                       String.length suffix >= 2
                       && String.contains
                            (String.sub suffix 1 (String.length suffix - 1))
                            'l'));
          go j false
      | '\'' ->
          let v, j =
            if s.[i + 1] = '\\' then escape (i + 2)
            else Char.code s.[i + 1], i + 2 in
          emit i (Num (Int64.of_int v, false));
          go (j + 1) false
      | '"' ->
          let b = Buffer.create 16 in
          let rec str j =
            if s.[j] = '"' then j + 1
            else if s.[j] = '\\' then
              (let v, j = escape (j + 1) in
               Buffer.add_char b (Char.chr (v land 255));
               str j)
            else (Buffer.add_char b s.[j]; str (j + 1)) in
          let j = str (i + 1) in
          (* "a" "b" is "ab" *)
          (match !out with
           | (Str a, l) :: rest ->
               out := (Str (a ^ Buffer.contents b), l) :: rest
           | _ -> emit i (Str (Buffer.contents b)));
          go j false
      | _ ->
          let p = List.find_opt (fun p ->
            i + String.length p <= n && String.sub s i (String.length p) = p)
            puncts in
          let p = match p with Some p -> p | None -> String.make 1 s.[i] in
          emit i (P p);
          go (i + String.length p) false
  in
  go 0 true;
  List.rev !out
