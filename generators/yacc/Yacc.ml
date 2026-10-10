(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Yacc.mli *)

exception Error of int * string

type code = { text : string; line : int; col : int }
type assoc = Left | Right | Nonassoc
type rule = { lhs : string; rhs : string list; prec : string option; action : code; rline : int }

type t = {
  header : code option;
  tokens : (string * string option) list;
  precs : (assoc * string list) list;
  starts : string list;
  types : (string * string) list;
  rules : rule list;
  trailer : code option;
}

type token =
  | Ident of string
  | Directive of string               (* %token, %left... *)
  | Type of string                    (* <...> *)
  | Code of code
  | Sym of char                       (* : | ; ( ) , ? * + *)
  | Mark                              (* %% *)
  | End

type input = { s : string; mutable i : int; mutable line : int; mutable bol : int }

let error (t : input) fmt = Printf.ksprintf (fun m -> raise (Error (t.line, m))) fmt
let peek (t : input) k = if t.i + k < String.length t.s then t.s.[t.i + k] else '\000'
let advance (t : input) = if peek t 0 = '\n' then begin t.line <- t.line + 1; t.bol <- t.i + 1 end; t.i <- t.i + 1
let ended (t : input) = t.i >= String.length t.s

(* the text up to a closing pair of characters, which is passed *)
let until (t : input) a b what =
  let start = t.i and line = t.line and col = t.i - t.bol in
  while not (peek t 0 = a && peek t 1 = b) do
    if ended t then raise (Error (line, what ^ " is not ended"));
    advance t
  done;
  advance t; advance t;
  { text = String.sub t.s start (t.i - 2 - start); line; col }

(* OCaml's text skipped: a string, a comment, a character *)
let rec skip_string (t : input) =
  advance t;
  while (not (ended t)) && peek t 0 <> '"' do if peek t 0 = '\\' then advance t; advance t done;
  if ended t then error t "a string is not ended";
  advance t

and skip_comment (t : input) =
  let start = t.line in
  advance t; advance t;
  while not (peek t 0 = '*' && peek t 1 = ')') do
    if ended t then raise (Error (start, "a comment is not ended"));
    if peek t 0 = '(' && peek t 1 = '*' then skip_comment t else if peek t 0 = '"' then skip_string t else advance t
  done;
  advance t; advance t

(* { ... }: the text between, its braces matched *)
let code (t : input) =
  advance t;
  let start = t.i and line = t.line and col = t.i - t.bol in
  let depth = ref 1 in
  while !depth > 0 do
    if ended t then raise (Error (line, "an action is not ended"));
    match peek t 0 with
    | '"' -> skip_string t
    | '(' when peek t 1 = '*' -> skip_comment t
    | '\'' when peek t 1 = '\\' -> advance t; advance t; while peek t 0 <> '\'' do advance t done; advance t
    | '\'' when peek t 2 = '\'' -> advance t; advance t; advance t
    | '{' -> incr depth; advance t
    | '}' -> decr depth; advance t
    | _ -> advance t
  done;
  { text = String.sub t.s start (t.i - 1 - start); line; col }

let is_ident c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_' || c = '\''

let rec token (t : input) : token =
  match peek t 0 with
  | ' ' | '\t' | '\r' | '\n' | '\012' -> advance t; token t
  | '/' when peek t 1 = '*' -> advance t; advance t; ignore (until t '*' '/' "a comment"); token t
  | '\000' when ended t -> End
  | '{' -> Code (code t)
  | '%' when peek t 1 = '%' -> advance t; advance t; Mark
  | '%' when peek t 1 = '{' -> advance t; advance t; Code (until t '%' '}' "the header")
  | '%' ->
      advance t;
      let start = t.i in
      while is_ident (peek t 0) do advance t done;
      Directive (String.sub t.s start (t.i - start))
  | '<' ->
      (* a type: to its >, which is not an arrow's *)
      advance t;
      let start = t.i in
      while not (peek t 0 = '>' && peek t (-1) <> '-') do if ended t then error t "a type is not ended"; advance t done;
      advance t;
      Type (String.trim (String.sub t.s start (t.i - 1 - start)))
  | (':' | '|' | ';' | '(' | ')' | ',' | '?' | '*' | '+') as c -> advance t; Sym c
  | c when is_ident c && c <> '\'' ->
      let start = t.i in
      while is_ident (peek t 0) do advance t done;
      Ident (String.sub t.s start (t.i - start))
  | c -> error t "the character %C" c

let read (s : string) : t =
  let t = { s; i = 0; line = 1; bol = 0 } in
  let tok = ref (token t) in
  let next () = tok := token t in
  let rec names () = match !tok with Ident x -> next (); x :: names () | _ -> [] in
  let header = match !tok with Code c -> next (); Some c | _ -> None in
  let tokens = ref [] and precs = ref [] and starts = ref [] and types = ref [] in
  let typ () = match !tok with Type ty -> next (); Some ty | _ -> None in
  let rec declarations () =
    match !tok with
    | Directive "token" -> next (); let ty = typ () in tokens := !tokens @ List.map (fun x -> x, ty) (names ()); declarations ()
    | Directive (("left" | "right" | "nonassoc") as d) ->
        next ();
        precs := !precs @ [ (match d with "left" -> Left | "right" -> Right | _ -> Nonassoc), names () ];
        declarations ()
    | Directive "start" -> next (); starts := !starts @ names (); declarations ()
    | Directive "type" ->
        next ();
        (match typ () with Some ty -> types := !types @ List.map (fun x -> x, ty) (names ()) | None -> error t "%%type: a type expected");
        declarations ()
    | Mark -> next ()
    | Directive d -> error t "%%%s is not read by mini-yacc" d
    | _ -> error t "a declaration or %%%% expected"
  in
  declarations ();
  (* menhir's standard rules: each use, list(x), is a non-terminal with
   * rules of its own, made at its first use and named as menhir names
   * it (list_x_); a list is in the text's order, so its rule is
   * recursive on the right *)
  let made = ref [] in
  let rec instance f args =
    let name = f ^ "_" ^ String.concat "_" args ^ "_" and line = t.line in
    let rule rhs text = { lhs = name; rhs; prec = None; action = { text; line; col = 0 }; rline = line } in
    let define rules = if not (List.exists (fun r -> r.lhs = name) !made) then made := !made @ rules; name in
    match f, args with
    | "option", [ x ] -> define [ rule [] "None"; rule [ x ] "Some $1" ]
    | "boption", [ x ] -> define [ rule [] "false"; rule [ x ] "true" ]
    | "loption", [ x ] -> define [ rule [] "[]"; rule [ x ] "$1" ]
    | "list", [ x ] -> define [ rule [] "[]"; rule [ x; name ] "$1 :: $2" ]
    | "nonempty_list", [ x ] -> define [ rule [ x ] "[ $1 ]"; rule [ x; name ] "$1 :: $2" ]
    | "separated_nonempty_list", [ sep; x ] -> define [ rule [ x ] "[ $1 ]"; rule [ x; sep; name ] "$1 :: $3" ]
    | "separated_list", [ sep; x ] -> instance "loption" [ instance "separated_nonempty_list" [ sep; x ] ]
    | _ -> error t "%s with %d parameters is not read by mini-yacc" f (List.length args)
  in
  let rec symbol x =
    next ();
    if !tok <> Sym '(' then suffixed x
    else begin
      let rec arguments () =
        next ();
        let a = match !tok with Ident y -> symbol y | _ -> error t "%s(: a symbol expected" x in
        if !tok = Sym ',' then a :: arguments () else [ a ]
      in
      let args = arguments () in
      if !tok <> Sym ')' then error t "%s(: a ) expected" x;
      next ();
      suffixed (instance x args)
    end
  (* x?, x*, x+: option(x), list(x), nonempty_list(x) *)
  and suffixed s =
    match !tok with
    | Sym (('?' | '*' | '+') as c) -> next (); suffixed (instance (match c with '?' -> "option" | '*' -> "list" | _ -> "nonempty_list") [ s ])
    | _ -> s
  in
  (* a rule: lhs : symbols { action } | ... ; *)
  let rec rules () =
    match !tok with
    | Ident lhs ->
        next ();
        if !tok <> Sym ':' then error t "%s: a : expected" lhs;
        next ();
        if !tok = Sym '|' then next ();
        let rec alternatives () =
          let rline = t.line in
          let rec symbols () = match !tok with Ident "error" -> error t "the error token is not read by mini-yacc" | Ident x -> let s = symbol x in s :: symbols () | _ -> [] in
          let rhs = symbols () in
          let prec = match !tok with Directive "prec" -> next (); (match !tok with Ident x -> next (); Some x | _ -> error t "%%prec: a token expected") | _ -> None in
          let action = match !tok with Code c -> next (); c | _ -> error t "%s: an action expected" lhs in
          (match !tok with Ident _ | Code _ -> error t "%s: an action in the middle of a rule is not read by mini-yacc" lhs | _ -> ());
          let r = { lhs; rhs; prec; action; rline } in
          if !tok = Sym '|' then (next (); r :: alternatives ()) else [ r ]
        in
        let alts = alternatives () in
        if !tok = Sym ';' then next ();
        alts @ rules ()
    | Mark | End -> []
    | _ -> error t "a rule expected"
  in
  let rules = rules () in
  let rules = rules @ !made in
  (* what follows the second %%, as it is *)
  let trailer = if !tok = Mark then Some { text = String.sub s t.i (String.length s - t.i); line = t.line; col = 0 } else None in
  if !starts = [] then error t "no %%start";
  { header; tokens = !tokens; precs = !precs; starts = !starts; types = !types; rules; trailer }
