(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyML.mli. Its tests, tests/TinyML_test.sh: a program prints
 * exactly what OCaml's ocamlopt makes it print (the recorded ones were
 * ocaml-light's on arm64, whose back end this compiler also had until
 * plan_tiny_self_hosting.md). *)

open Common

let usage = {|usage: tiny-ml [-L dir | -nostdlib] [-o out.tm] file.ml...
       | tiny-ml -c [-o out.tm] file.tmi... file.ml
       | tiny-ml -o main.tm file.tmi...|}

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A tiny ML compiler: an ML file (its own small dialect: a file a module, no
functors nor labels) to tiny-machine's assembly, for tiny-cpu, on stdout
without -o. A fact.ml, for example:
  let rec fact n = if n = 0 then 1 else n * fact (n - 1)
  let () = print_string "fact 10 = "; print_int (fact 10); print_newline ()
  tiny-ml -o fact.tm fact.ml               ml_start: ldw r12, 0(sp) ...
  tiny-c -o main.tm main.c
  L=tiny/TinyCRuntime
  for f in $L/start $L/udivmod exit fact main
  do tiny-assembler -o $f.o $f.tm; done
  tiny-linker -o fact $L/start.o $L/udivmod.o exit.o fact.o main.o \
    /lib/ml/*.o
  tiny-cpu fact                            fact 10 = 3628800
main.c includes tiny/TinyMLRuntime/core.c and gives it memory (ml_run),
exit.tm is exit (sys 0), as tiny/tests/TinyML_test.sh makes them. The
standard library, TinyLibCore/'s modules, is read from /lib/ml (-L: another
directory), its interfaces Stdlib.tmi ... Sha1.tmi, and linked from there,
each module compiled once by tiny-ml -c -nostdlib after the ones before it.
Several files are a module each, one after the other, then their main: a's
x is A.x in b, or x after open A. Or a module at a time, then the main:
  tiny-ml -c a.ml                          a.tm, its code; a.tmi, its interface
  tiny-ml -c a.tmi b.ml                    b.tm and b.tmi, after a
  tiny-ml -o main.tm a.tmi b.tmi           the library's, a's and b's init,
                                           ml_start
  (linked: ... main.o a.o b.o and the library's; what nothing uses left out by
  tiny-linker)
An error names the file and the line: fact.ml: line 2: this has type int ...
|}

(* (old: a format, Printf.ksprintf's: tiny-ml reads a format only where
 * it is written, Printf.sprintf at the call) *)
let error s = failwith s

(* the machine, tiny-machine, has words of 4 bytes: an integer 31 bits
 * (a constant beyond them is refused), a block's fields 4 bytes each *)

(*****************************************************************************)
(* Tokens *)
(*****************************************************************************)

(* a keyword and a symbol are both KW *)
type token =
  | INT of int | CHAR of int | STR of string | LID of string | UID of string
  | KW of string | EOF

let keywords =
  [ "let"; "rec"; "in"; "fun"; "function"; "match"; "with"; "if"; "then";
    "else"; "begin"; "end"; "try"; "type"; "of"; "exception"; "external";
    "and"; "when"; "as"; "while"; "for"; "to"; "downto"; "do"; "done"; "mod";
    "land"; "lor"; "lxor"; "lsl"; "lsr"; "asr"; "or"; "open" ]

let symbols =
  [ "|||"; ";;"; "->"; "::"; ":="; ":>"; "<-"; "<="; ">="; "<>"; "==";
    "!="; "&&"; "||"; "|>"; ".["; "~-" ]

(* both as tables, which the lexer looks a word up in (old: List.mem
 * over the keywords at each name, List.find_opt over the symbols at
 * each other character, a String.sub for each: most of the time of a
 * compilation's lexing, a million comparisons for TinyML.ml) *)
let table l =
  let t = Hashtbl.create 64 in
  List.iter (fun k -> Hashtbl.replace t k ()) l;
  t
let keyword = table keywords
let symbol = table symbols

(* the tokens of a file, each with its line; String.length is one
 * name, true and false constructors *)
let lex (s : string) : (token * int) array =
  let n = String.length s and out = ref [] and line = ref 1 in
  let add t = out := (t, !line) :: !out in
  (* (old: 'a' .. 'z' and the others as patterns: tiny-ml has no
   * character ranges) *)
  let lower c = c >= 'a' && c <= 'z' and upper c = c >= 'A' && c <= 'Z'
  and digit c = c >= '0' && c <= '9' in
  let is_id c = lower c || upper c || digit c || c = '_' || c = '\'' in
  let rec span j = if j < n && is_id s.[j] then span (j + 1) else j in
  let escape i =
    match s.[i] with
    | 'n' -> 10, i + 1 | 't' -> 9, i + 1 | 'r' -> 13, i + 1 | 'b' -> 8, i + 1
    | c when digit c -> int_of_string (String.sub s i 3), i + 3
    | c -> Char.code c, i + 1
  in
  let rec comment i depth =
    if i + 1 >= n then error "unterminated comment"
    else if s.[i] = '*' && s.[i + 1] = ')' then
      if depth = 1 then i + 2 else comment (i + 2) (depth - 1)
    else if s.[i] = '(' && s.[i + 1] = '*' then comment (i + 2) (depth + 1)
    else (if s.[i] = '\n' then incr line; comment (i + 1) depth)
  in
  let rec go i =
    if i < n then
      match s.[i] with
      | '\n' -> incr line; go (i + 1)
      | ' ' | '\t' | '\r' -> go (i + 1)
      | '(' when i + 1 < n && s.[i + 1] = '*' -> go (comment (i + 2) 1)
      | c when digit c ->
          let j = span i in
          add (INT (int_of_string (String.sub s i (j - i))));
          go j
      | c when lower c || c = '_' ->
          let j = span i in
          let w = String.sub s i (j - i) in
          add
            (if w = "_" then KW w
             else if Hashtbl.mem keyword w then KW w
             else if w = "true" || w = "false" then UID w
             else LID w);
          go j
      | c when upper c ->
          let j = span i in
          let j =
            if j + 1 < n && s.[j] = '.' && (lower s.[j + 1] || upper s.[j + 1])
            then span (j + 1)
            else j
          in
          let w = String.sub s i (j - i) in
          (* (M.C is the constructor C: constructors are one namespace) *)
          add
            (match String.rindex_opt w '.' with
             | Some k when w.[k + 1] >= 'a' -> LID w
             | Some k -> UID (String.sub w (k + 1) (String.length w - k - 1))
             | None -> UID w);
          go j
      | '\'' when i + 2 < n && (s.[i + 2] = '\'' || s.[i + 1] = '\\') ->
          let c, j =
            if s.[i + 1] = '\\' then escape (i + 2) else Char.code s.[i + 1], i + 2
          in
          add (CHAR c);
          go (j + 1)
      (* {|...|}, OCaml's quoted string: its text as it is, no escape *)
      | '{' when i + 1 < n && s.[i + 1] = '|' ->
          let rec close j =
            if j + 1 >= n then error "unterminated string"
            else if s.[j] = '|' && s.[j + 1] = '}' then j
            else (if s.[j] = '\n' then incr line; close (j + 1))
          in
          let j = close (i + 2) in
          add (STR (String.sub s (i + 2) (j - i - 2)));
          go (j + 2)
      | '"' ->
          let b = Buffer.create 16 in
          let rec str j =
            match s.[j] with
            | '"' -> j + 1
            | '\\' ->
                let c, j = escape (j + 1) in
                Buffer.add_char b (Char.chr c);
                str j
            | c -> if c = '\n' then incr line; Buffer.add_char b c; str (j + 1)
          in
          let j = str (i + 1) in
          add (STR (Buffer.contents b));
          go j
      | _ ->
          (* the longest symbol here, 3 characters, 2, or this one *)
          let sym k =
            if i + k <= n && Hashtbl.mem symbol (String.sub s i k)
            then Some (String.sub s i k)
            else None
          in
          let p = sym 3 ||| (sym 2 ||| String.make 1 s.[i]) in
          add (KW p);
          go (i + String.length p)
  in
  go 0;
  add EOF;
  Array.of_list (List.rev !out)

(*****************************************************************************)
(* The tree *)
(*****************************************************************************)

(* a type variable is a cell: unbound (its number and level), or linked
 * to what it became *)
type ty = TVar of tvar ref | TCon of string * ty list
and tvar = Unbound of int * int | Link of ty

type const = CInt of int | CChar of int | CStr of string

type texpr = TE of string * texpr list | TEVar of string

(* (p : t): an annotation, which makes a record's type known where its
 * labels are used. A record pattern names some of the fields; once
 * typed, it also knows their indexes and how many fields the record has *)
type pat = PAny | PVar of string | PConst of const | PCon of string * pat list
  | PTuple of pat list | PAlias of pat * string | POr of pat * pat
  | PAnnot of pat * texpr
  | PRecord of (string * pat) list * int list ref * int ref

type expr =
  | Const of const
  (* its type where it is used, which a comparison reads *)
  | Var of string * ty ref
  | Con of string * expr list
  | Tuple of expr list
  | App of expr * expr list
  (* a parameter's pattern is a let in the body *)
  | Fun of string list * expr
  | Let of bool * (pat * expr) list * expr
  | Match of expr * case list
  | Try of expr * case list
  | If of expr * expr * expr
  | Seq of expr * expr
  | While of expr * expr
  | For of string * expr * expr * bool * expr
  (* the fields' indexes, known once typed *)
  | Record of (string * expr) list * int list ref
  (* { e with l = e'; ... }: the fields' indexes and how many the record
   * has, known once typed *)
  | With of expr * (string * expr) list * int list ref * int ref
  | Dot of expr * string * int ref    (* e.l *)
  | SetDot of expr * string * int ref * expr

and case = pat * expr option * expr

type item =
  | ILet of bool * (pat * expr) list | IExt of string * texpr * string
  | IExn of string | IOpen of string

(* a constructor: its number among its type's constant ones or among
 * the others (a block's tag), or an exception; its type as
 * %c(result, arguments...), generic in the type's parameters *)
type kind = KConst of int | KBlock of int | KExn
type cinfo = { kind : kind; arity : int; nconst : int; nblock : int; scheme : ty }

let cons : (string, cinfo) Hashtbl.t = Hashtbl.create 64

(* a record's label: its field's index, and its type as %l(record,
 * field), as a constructor's; several records may have it *)
type linfo =
  { lrec : string; idx : int; mut : bool; lnames : string list; lscheme : ty }
let record_labels : (string, linfo) Hashtbl.t = Hashtbl.create 64
let find_con c =
  match Hashtbl.find_opt cons c with
  | Some ci -> ci
  | None -> error ("unknown constructor " ^ c)

let generic = max_int
let level = ref 1 and counter = ref 0
let newvar () = incr counter; TVar (ref (Unbound (!counter, !level)))
let genvar () = incr counter; TVar (ref (Unbound (!counter, generic)))
let tcon c = TCon (c, [])
let arrow a b = TCon ("->", [ a; b ])
let int_t = tcon "int" and bool_t = tcon "bool" and unit_t = tcon "unit"
and string_t = tcon "string"

let () =
  let a = genvar () in
  let add c kind arity nconst nblock res args =
    Hashtbl.replace cons c
      { kind; arity; nconst; nblock; scheme = TCon ("%c", res :: args) }
  in
  add "()" (KConst 0) 0 1 0 unit_t [];
  add "false" (KConst 0) 0 2 0 bool_t [];
  add "true" (KConst 1) 0 2 0 bool_t [];
  add "[]" (KConst 0) 0 1 1 (TCon ("list", [ a ])) [];
  add "::" (KBlock 0) 2 1 1 (TCon ("list", [ a ])) [ a; TCon ("list", [ a ]) ]

(* the unit being compiled (a file: its name, the prefix of its
 * symbols), and the units whose interfaces it read: M.t in a type is
 * t when M is one of them (a type's name is the program's, one name
 * space, as the constructors' and the values') *)
let unit_name = ref "Stdlib"
let known_units : string list ref = ref []

let rec of_texpr vars = function
  | TEVar v ->
      (match List.assoc_opt v !vars with
       | Some t -> t
       | None -> let t = genvar () in vars := (v, t) :: !vars; t)
  | TE (c, args) ->
      let c =
        match String.index_opt c '.' with
        | Some i when List.mem (String.sub c 0 i) !known_units ->
            String.sub c (i + 1) (String.length c - i - 1)
        | _ -> c
      in
      TCon (c, List.map (of_texpr vars) args)

(*****************************************************************************)
(* The parser *)
(*****************************************************************************)

let toks : (token * int) array ref = ref (Array.of_list []) and pos = ref 0
let peek () = fst (!toks).(!pos)
let peek_at k = fst (!toks).(min (!pos + k) (Array.length !toks - 1))
let line () = snd (!toks).(!pos)
let advance () = if peek () <> EOF then incr pos
let accept t = if peek () = t then (advance (); true) else false
let show_tok = function
  | INT n -> string_of_int n | CHAR _ -> "a character" | STR _ -> "a string"
  | LID x -> x | UID x -> x | KW x -> x | EOF -> "the end"
let fail () =
  error
    (Printf.sprintf "line %d: syntax error at %s" (line ()) (show_tok (peek ())))
let expect t = if not (accept t) then fail ()
let var x = Var (x, ref (tcon "?"))
let fresh = ref 0

(* the names of types declared as an object's: read and forgotten (ty) *)
let forgotten : string list ref = ref []

(* Printf's sprintf, ksprintf and bprintf, their format a string written
 * there, read as the concatenation they make: Printf.sprintf "r%d, %s"
 * a b is String.concat "" [ "r"; string_of_int a; ", "; b ], so the
 * type checker sees no format (OCaml's has a type of its own, which
 * HM would need to be told). %d %s %c %x %S and %%, a width, - and 0;
 * TinyLibCore's Printf has what %x, %S and a width call. A format
 * given fewer values than it has holes is a function of the others.
 * (old: no Printf, plan_tiny_self_hosting.md's step 7: its 176 calls
 * written as ^, a string made for each piece) *)
type piece =
  | Text of string
  | Hole of char * bool * bool * int   (* the letter, -, 0, the width *)

let pieces fmt =
  let n = String.length fmt and b = Buffer.create 16 and out = ref [] in
  let text () =
    if Buffer.length b > 0 then
      (out := Text (Buffer.contents b) :: !out; Buffer.clear b)
  in
  let rec digits k w =
    if k < n && fmt.[k] >= '0' && fmt.[k] <= '9' then
      digits (k + 1) ((w * 10) + Char.code fmt.[k] - 48)
    else k, w
  in
  let rec go i =
    if i < n then
      if fmt.[i] <> '%' then (Buffer.add_char b fmt.[i]; go (i + 1))
      else if i + 1 < n && fmt.[i + 1] = '%' then (Buffer.add_char b '%'; go (i + 2))
      else begin
        let left = i + 1 < n && fmt.[i + 1] = '-' in
        let j = if left then i + 2 else i + 1 in
        let zero = j < n && fmt.[j] = '0' in
        let k, width = digits j 0 in
        if k >= n || not (String.contains "dscxS" fmt.[k]) then
          error ("a format of Printf's that tiny-ml does not read: " ^ fmt);
        text ();
        out := Hole (fmt.[k], left, zero, width) :: !out;
        go (k + 1)
      end in
  go 0;
  text ();
  List.rev !out

let printf_call name args =
  let first, args =
    if name = "Printf.sprintf" then None, args
    else
      match args with
      | a :: r -> Some a, r
      | [] -> error (name ^ ": no format")
  in
  match args with
  | Const (CStr fmt) :: given ->
      let ps = pieces fmt in
      let holes =
        List.length (List.filter (function Hole _ -> true | Text _ -> false) ps)
      in
      let missing =
        List.init (max 0 (holes - List.length given))
          (fun i -> Printf.sprintf "%%p%d" i)
      in
      let bool b = Con ((if b then "true" else "false"), []) in
      let hole c left zero w v =
        let s = match c with
          | 'd' -> App (var "string_of_int", [ v ])
          | 'c' -> App (var "String.make", [ Const (CInt 1); v ])
          | 'x' -> App (var "Printf.hex", [ v ])
          | 'S' -> App (var "Printf.quoted", [ v ])
          | _ -> v in
        if w = 0 then s
        else App (var "Printf.pad", [ bool left; bool zero; Const (CInt w); s ])
      in
      let rec build ps vs =
        match ps, vs with
        | [], _ -> Con ("[]", [])
        | Text t :: r, _ -> Con ("::", [ Const (CStr t); build r vs ])
        | Hole (c, left, zero, w) :: r, v :: vr ->
            Con ("::", [ hole c left zero w v; build r vr ])
        | Hole _ :: _, [] -> error "printf: a hole without its value" in
      let values =
        List.filteri (fun i _ -> i < holes) given @ List.map var missing in
      let s = App (var "String.concat", [ Const (CStr ""); build ps values ]) in
      (* bprintf's pieces each added to the buffer, when the values are
       * names or constants (evaluated in any order, the same; else the
       * concatenation, its values evaluated as OCaml's are) *)
      let simple =
        List.for_all (function Var _ | Const _ -> true | _ -> false) values in
      let rec adds b ps vs =
        match ps, vs with
        | [], _ -> Con ("()", [])
        | [ Text t ], _ -> App (var "Buffer.add_string", [ b; Const (CStr t) ])
        | Text t :: r, _ ->
            Seq (App (var "Buffer.add_string", [ b; Const (CStr t) ]), adds b r vs)
        | [ Hole (c, left, zero, w) ], v :: _ ->
            App (var "Buffer.add_string", [ b; hole c left zero w v ])
        | Hole (c, left, zero, w) :: r, v :: vr ->
            Seq (App (var "Buffer.add_string", [ b; hole c left zero w v ]),
              adds b r vr)
        | Hole _ :: _, [] -> error "printf: a hole without its value" in
      let e = match name, first with
        | "Printf.ksprintf", Some k -> App (k, [ s ])
        | "Printf.bprintf", Some b
          when simple && (match b with Var _ -> true | _ -> false) ->
            adds b ps values
        | "Printf.bprintf", Some b -> App (var "Buffer.add_string", [ b; s ])
        | _ -> s in
      let e = if missing = [] then e else Fun (missing, e) in
      (match List.filteri (fun i _ -> i >= holes) given with
       | [] -> e
       | extra -> App (e, extra))
  | _ ->
      error
        (name ^ ": its format must be a string written there (tiny-ml reads it)")

(* type word = piece list, type 'a t = unit -> 'a node: a second name
 * for a type, its parameters' names; unify puts the type in the name's
 * place when the two differ, so a name may be used above its
 * declaration. A name and its number of parameters say which: Sha1's
 * t and Seq's 'a t are two
 * (old: no parameter, a name only) *)
let abbreviations : (string * (string list * texpr)) list ref = ref []

(* the abbreviation that a name with these arguments is *)
let abbreviation c ts =
  match
    List.find_opt (fun (c', (ps, _)) -> c' = c && List.length ps = List.length ts)
      !abbreviations
  with
  | Some (_, (ps, te)) -> Some (of_texpr (ref (List.combine ps ts)) te)
  | None -> None

(* the operators: precedence and right associativity; "," is 1 *)
let binops =
  [ ":=", 0, true; "<-", 0, true; "||", 2, true; "or", 2, true; "&&", 3, true;
    "&", 3, true; "=", 4, false; "<>", 4, false; "<", 4, false; ">", 4, false;
    "<=", 4, false; ">=", 4, false; "==", 4, false; "!=", 4, false;
    "|>", 4, false; "|||", 4, false; "@", 5, true; "^", 5, true; "::", 6, true;
    "+", 7, false; "-", 7, false; "*", 8, false; "/", 8, false; "mod", 8, false;
    "land", 8, false; "lor", 8, false;
    "lxor", 8, false; "lsl", 9, true; "lsr", 9, true; "asr", 9, true ]

let is_op o = List.exists (fun (b, _, _) -> b = o) binops || o = "!" || o = "~-"

(* C (a, b) is a constructor of two arguments, the tuple its parser saw *)
let con_args c args untuple =
  let ci = find_con c in
  match args with
  | [] when ci.arity = 0 -> []
  | [ a ] when ci.arity = 1 -> [ a ]
  | [ a ] when ci.arity > 1 ->
      (match untuple ci.arity a with
       | Some l when List.length l = ci.arity -> l
       | _ ->
           error
             (Printf.sprintf "line %d: %s expects %d arguments" (line ()) c
                ci.arity))
  | _ ->
      error
        (Printf.sprintf "line %d: %s expects %d arguments" (line ()) c ci.arity)

let starts_atom = function
  | INT _ | CHAR _ | STR _ | LID _ | UID _
  | KW ("(" | "[" | "{" | "begin" | "!") -> true
  | _ -> false
let starts_patom = function
  | INT _ | CHAR _ | STR _ | LID _ | UID _ | KW ("_" | "(" | "[" | "{") -> true
  | _ -> false

(* expressions: a sequence, then let/match/fun/if, then the operators
 * by precedence climbing, then application *)
let rec expr () =
  let e = stmt () in
  if accept (KW ";") then
    match peek () with
    | KW ("end" | ")" | "done" | "in" | ";;" | "|" | "]" | "with" | "else"
         | "then")
    | EOF -> e
    | _ -> Seq (e, expr ())
  else e

and stmt () =
  match peek () with
  | KW "let" ->
      advance ();
      let r = accept (KW "rec") in
      let bs = bindings () in
      expect (KW "in");
      Let (r, bs, expr ())
  | KW "match" ->
      advance (); let e = expr () in expect (KW "with"); Match (e, cases ())
  | KW "try" ->
      advance (); let e = expr () in expect (KW "with"); Try (e, cases ())
  | KW "function" -> advance (); Fun ([ "%f" ], Match (var "%f", cases ()))
  | KW "fun" ->
      advance (); let ps = params () in expect (KW "->"); fun_of ps (expr ())
  | KW "if" ->
      advance ();
      let c = expr () in
      expect (KW "then");
      let a = stmt () in
      If (c, a, if accept (KW "else") then stmt () else Con ("()", []))
  | KW "while" ->
      advance ();
      let c = expr () in
      expect (KW "do");
      let b = expr () in
      expect (KW "done");
      While (c, b)
  | KW "for" ->
      advance ();
      let x = match peek () with LID x -> advance (); x | _ -> fail () in
      expect (KW "=");
      let a = expr () in
      let up =
        if accept (KW "to") then true else (expect (KW "downto"); false) in
      let b = expr () in
      expect (KW "do");
      let body = expr () in
      expect (KW "done");
      For (x, a, b, up, body)
  | _ -> binary 0

and binary min =
  let rec loop lhs =
    match peek () with
    | KW "," when min <= 1 ->
        let rec more () =
          advance ();
          let e = binary 2 in
          if peek () = KW "," then e :: more () else [ e ]
        in
        loop (Tuple (lhs :: more ()))
    | KW op -> (
        match List.find_opt (fun (o, _, _) -> o = op) binops with
        | Some (_, p, right) when p >= min ->
            advance ();
            let rhs = binary (if right then p else p + 1) in
            loop
              (match op with
               | "::" -> Con ("::", [ lhs; rhs ])
               | "&&" | "&" -> If (lhs, rhs, Con ("false", []))
               | "||" | "or" -> If (lhs, Con ("true", []), rhs)
               | "<-" -> (
                   match lhs with
                   | Dot (e, l, i) -> SetDot (e, l, i, rhs)
                   | App (Var ("Array.get", _), [ a; i ]) ->
                       (* i, a, then the value, ocamlopt's order *)
                       incr fresh;
                       let a' = Printf.sprintf "%%a%d" !fresh
                       and i' = Printf.sprintf "%%i%d" !fresh in
                       Let (false, [ PVar i', i ],
                         Let (false, [ PVar a', a ],
                           App (var "Array.set", [ var a'; var i'; rhs ])))
                   | _ ->
                       error
                         (Printf.sprintf
                            "line %d: <- on a field or an array's element only"
                            (line ())))
               | _ -> App (var op, [ lhs; rhs ]))
        | _ -> lhs)
    | _ -> lhs
  in
  loop (unary ())

and unary () =
  match peek () with
  | KW "-" ->
      advance ();
      (match peek () with
       | INT n -> advance (); Const (CInt (-n))
       | _ -> App (var "~-", [ unary () ]))
  | _ -> app ()

and app () =
  match peek () with
  | UID c when starts_atom (peek_at 1) && (find_con c).arity > 0 ->
      advance ();
      let a = atom () in
      Con (c, con_args c [ a ] (fun _ -> function Tuple l -> Some l | _ -> None))
  | _ -> (
      let f = atom () in
      let rec args () =
        if starts_atom (peek ()) then let a = atom () in a :: args () else [] in
      match f, args () with
      | _, [] -> f
      | Var (p, _), l
        when p = "Printf.sprintf" || p = "Printf.ksprintf"
             || p = "Printf.bprintf" ->
          printf_call p l
      | _, l -> App (f, l))

and atom () =
  let e =
    match peek () with
    | INT n -> advance (); Const (CInt n)
    | CHAR c -> advance (); Const (CChar c)
    | STR s -> advance (); Const (CStr s)
    | LID x -> advance (); var x
    | UID c -> advance (); Con (c, con_args c [] (fun _ _ -> None))
    | KW "!" -> advance (); App (var "!", [ atom () ])
    | KW "(" -> (
        advance ();
        if accept (KW ")") then Con ("()", [])
        else
          match peek (), peek_at 1 with
          | KW op, KW ")" when is_op op -> advance (); advance (); var op
          | _ ->
              let e = expr () in
              if accept (KW ":") || accept (KW ":>") then ignore (ty ());
              expect (KW ")");
              e)
    | KW "begin" ->
        advance ();
        if accept (KW "end") then Con ("()", [])
        else (let e = expr () in expect (KW "end"); e)
    | KW "[" ->
        advance ();
        let rec elems () =
          if accept (KW "]") then Con ("[]", [])
          else (
            let e = stmt () in
            ignore (accept (KW ";"));
            Con ("::", [ e; elems () ]))
        in
        elems ()
    | KW "{" ->
        advance ();
        let rec fields () =
          if accept (KW "}") then []
          else match peek () with
            (* { text; pos = 0 }: a field alone is the variable of its name *)
            | LID l ->
                advance ();
                let e = if accept (KW "=") then stmt () else var l in
                ignore (accept (KW ";"));
                (l, e) :: fields ()
            | _ -> fail () in
        (* a label followed by =, ; or } begins the fields; anything else
         * is the record that { e with ... } copies *)
        (match peek (), peek_at 1 with
         | LID _, KW ("=" | ";" | "}") -> Record (fields (), ref [])
         | _ ->
             let e = atom () in
             expect (KW "with");
             (match fields () with
              | [] -> fail ()
              | fs -> With (e, fs, ref [], ref 0)))
    | KW ("let" | "match" | "try" | "fun" | "function" | "if" | "while" | "for")
      ->
        stmt ()
    | _ -> fail ()
  in
  postfix e

and postfix e =
  if accept (KW ".[") then (
    let i = expr () in
    expect (KW "]");
    postfix (App (var "String.get", [ e; i ])))
  else if peek () = KW "." then (
    advance ();
    match peek () with
    | LID l -> advance (); postfix (Dot (e, l, ref 0))
    | KW "(" ->
        advance ();
        let i = expr () in
        expect (KW ")");
        postfix (App (var "Array.get", [ e; i ]))
    | _ -> fail ())
  else e

and cases () =
  ignore (accept (KW "|"));
  let p = pattern () in
  let g = if accept (KW "when") then Some (expr ()) else None in
  expect (KW "->");
  let e = expr () in
  (p, g, e) :: (if peek () = KW "|" then cases () else [])

(* patterns: as, then |, then the tuple, then ::, then a constructor's *)
and pattern () =
  let p = por () in
  if accept (KW "as") then
    (match peek () with LID x -> advance (); PAlias (p, x) | _ -> fail ())
  else p

and por () = let p = ptuple () in if accept (KW "|") then POr (p, por ()) else p

and ptuple () =
  let p = pcons () in
  if peek () = KW "," then (
    let rec more () =
      if accept (KW ",") then let q = pcons () in q :: more () else [] in
    PTuple (p :: more ()))
  else p

and pcons () =
  let p = papp () in
  if accept (KW "::") then PCon ("::", [ p; pcons () ]) else p

and papp () =
  match peek () with
  | UID c when starts_patom (peek_at 1) && (find_con c).arity > 0 ->
      advance ();
      let a = patom () in
      PCon (c,
        con_args c [ a ] (fun n -> function
          | PTuple l -> Some l
          | PAny -> Some (List.init n (fun _ -> PAny))
          | _ -> None))
  | _ -> patom ()

and patom () =
  match peek () with
  | LID x -> advance (); PVar x
  | KW "_" -> advance (); PAny
  | INT n -> advance (); PConst (CInt n)
  | CHAR c -> advance (); PConst (CChar c)
  | STR s -> advance (); PConst (CStr s)
  | KW "-" ->
      advance ();
      (match peek () with INT n -> advance (); PConst (CInt (-n)) | _ -> fail ())
  | UID c -> advance (); PCon (c, con_args c [] (fun _ _ -> None))
  | KW "(" ->
      advance ();
      if accept (KW ")") then PCon ("()", [])
      else (
        let p = pattern () in
        let p = if accept (KW ":") then PAnnot (p, ty ()) else p in
        expect (KW ")");
        p)
  | KW "[" ->
      advance ();
      let rec elems () =
        if accept (KW "]") then PCon ("[]", [])
        else (
          let p = pattern () in
          ignore (accept (KW ";"));
          PCon ("::", [ p; elems () ]))
      in
      elems ()
  | KW "{" ->
      advance ();
      (* { view; update = u; _ }: a field alone binds the variable of its
       * name, and _ allows the fields not named *)
      let rec fields () =
        if accept (KW "}") then []
        else match peek () with
          | LID l ->
              advance ();
              let p = if accept (KW "=") then pattern () else PVar l in
              ignore (accept (KW ";"));
              (l, p) :: fields ()
          | KW "_" -> advance (); ignore (accept (KW ";")); expect (KW "}"); []
          | _ -> fail () in
      (match fields () with
       | [] -> fail ()
       | fs -> PRecord (fs, ref [], ref 0))
  | _ -> fail ()

and params () =
  if starts_patom (peek ()) then let p = patom () in p :: params () else []

(* fun p q -> e: a pattern other than a name is a let of the parameter *)
and fun_of ps body =
  let names, body =
    List.fold_right (fun p (names, body) ->
      match p with
      | PVar x -> x :: names, body
      | p ->
          incr fresh;
          let x = Printf.sprintf "%%p%d" !fresh in
          x :: names, Let (false, [ p, var x ], body))
      ps ([], body)
  in
  (* fun x -> function ...: one function of both, as OCaml makes it
   * (old: a closure made at each call of the first, List.length's
   * len n = function ..., an allocation an element: half of tiny-ml's
   * time on tiny-kernel) *)
  match body with
  | Fun (more, body)
    when List.length names + List.length more <= 10
         && not (List.exists (fun x -> List.mem x names) more) ->
      Fun (names @ more, body)
  | _ -> Fun (names, body)

and bindings () =
  let b = binding () in
  if accept (KW "and") then b :: bindings () else [ b ]

and binding () =
  let name =
    match peek (), peek_at 1 with
    | LID x, t when not (List.mem t [ KW "="; KW ","; KW ":"; KW "as"; KW "::" ])
      ->
        advance (); Some x
    | KW "(", KW op when is_op op && peek_at 2 = KW ")" ->
        advance (); advance (); advance (); Some op
    | _ -> None
  in
  match name with
  | Some f ->
      let ps = params () in
      if accept (KW ":") then ignore (ty ());
      expect (KW "=");
      PVar f, (if ps = [] then expr () else fun_of ps (expr ()))
  | None ->
      let p = pattern () in
      let p = if accept (KW ":") then PAnnot (p, ty ()) else p in
      expect (KW "=");
      p, expr ()

(* types: ->, then *, then applications of names (int list). An
 * object's type, < Cap.fork; Cap.exec; .. >, is read and forgotten: any
 * type (ix's capabilities, which OCaml checks when it builds the same
 * file; here a program's caps are a value like another, and (e :> t)
 * is e); so is a name declared as one, type caps = < ... > *)
(* a label, prefix:string -> ... in an .mli, read and dropped: a call
 * gives the arguments in their order, without their labels, which
 * OCaml accepts of a whole application *)
and ty () =
  (match peek (), peek_at 1 with LID _, KW ":" -> advance (); advance () | _ -> ());
  let t = ty_tuple () in if accept (KW "->") then TE ("->", [ t; ty () ]) else t

and ty_tuple () = match ty_args () with [ t ] -> t | l -> TE ("*", l)

and ty_args () =
  let t = ty_app () in
  if accept (KW "*") then t :: ty_args () else [ t ]

and ty_app () =
  let args =
    match peek () with
    | KW "'" ->
        advance ();
        (match peek () with LID v -> advance (); [ TEVar v ] | _ -> fail ())
    | KW "(" ->
        advance ();
        let rec go () =
          let t = ty () in
          if accept (KW ",") then t :: go () else [ t ]
        in
        let l = go () in
        expect (KW ")");
        l
    | KW "<" -> skip_object (); [ any () ]
    | LID c when List.mem c !forgotten -> advance (); [ any () ]
    | LID c -> advance (); [ TE (c, []) ]
    | _ -> fail ()
  in
  (* (val: OCaml's keyword, not tiny-ml's: an .mli's next item) *)
  let rec post args =
    match peek () with
    | LID c when c <> "val" -> advance (); post [ TE (c, args) ]
    | _ -> args
  in
  match post args with [ t ] -> t | _ -> fail ()

and any () = incr fresh; TEVar (Printf.sprintf "%%o%d" !fresh)

and skip_object () =
  advance ();
  while peek () <> KW ">" do (if peek () = EOF then fail ()); advance () done;
  advance ()

(* type ('a, 'b) t = A | B of 'a * t and ...: the constructors
 * numbered, the constant ones and the others apart; or a record, type
 * t = { a : int; mutable b : t }, its labels numbered; or another
 * type's second name, type word = piece list (abbreviations) *)
let rec type_decl () =
  let tvar () =
    expect (KW "'"); match peek () with LID v -> advance (); v | _ -> fail () in
  let params =
    match peek () with
    | KW "'" -> [ tvar () ]
    | KW "(" ->
        advance ();
        let rec go () =
          let v = tvar () in
          if accept (KW ",") then v :: go () else [ v ]
        in
        let l = go () in
        expect (KW ")");
        l
    | _ -> []
  in
  let name = match peek () with LID x -> advance (); x | _ -> fail () in
  expect (KW "=");
  ignore (accept (KW "|"));
  let vars = ref (List.map (fun v -> v, genvar ()) params) in
  let res = TCon (name, List.map snd !vars) in
  if peek () = KW "<" then (skip_object (); forgotten := name :: !forgotten)
  else if accept (KW "{") then begin
    let rec fields () =
      if accept (KW "}") then []
      else
        let mut = accept (LID "mutable") in
        let l = match peek () with LID l -> advance (); l | _ -> fail () in
        expect (KW ":");
        let t = of_texpr vars (ty ()) in
        ignore (accept (KW ";"));
        (l, mut, t) :: fields () in
    let fs = fields () in
    let lnames = List.map (fun (l, _, _) -> l) fs in
    List.iteri (fun idx (l, mut, t) ->
      Hashtbl.add record_labels l
        { lrec = name; idx; mut; lnames; lscheme = TCon ("%l", [ res; t ]) })
      fs
  end else if (match peek () with UID _ -> false | _ -> true) then begin
    abbreviations := (name, (params, ty ())) :: !abbreviations
  end else begin
    let rec ctors () =
      let c =
        match peek () with
        | UID c -> advance (); c
        | _ ->
            error
              (Printf.sprintf "line %d: a constructor or a record expected"
                 (line ()))
      in
      let args =
        if accept (KW "of") then List.map (of_texpr vars) (ty_args ()) else []
      in
      (c, args) :: (if accept (KW "|") then ctors () else [])
    in
    let cs = ctors () in
    let nconst = List.length (List.filter (fun (_, a) -> a = []) cs) in
    let nblock = List.length cs - nconst in
    let ic = ref 0 and ib = ref 0 in
    List.iter (fun (c, args) ->
      let kind =
        if args = [] then (incr ic; KConst (!ic - 1))
        else (incr ib; KBlock (!ib - 1))
      in
      Hashtbl.replace cons c
        { kind; arity = List.length args; nconst; nblock;
          scheme = TCon ("%c", res :: args) })
      cs
  end;
  if accept (KW "and") then type_decl ()

let rec items () : (item * int) list =
  let l = line () in
  match peek () with
  | EOF -> []
  | KW ";;" -> advance (); items ()
  | KW "let" ->
      advance ();
      let r = accept (KW "rec") in
      let bs = bindings () in
      if accept (KW "in") then (
        let e = Let (r, bs, expr ()) in
        (ILet (false, [ PAny, e ]), l) :: items ())
      else (ILet (r, bs), l) :: items ()
  | KW "type" -> advance (); type_decl (); items ()
  | KW "open" ->
      advance ();
      (match peek () with
       | UID m -> advance (); (IOpen m, l) :: items ()
       | _ -> fail ())
  | KW "exception" ->
      advance ();
      let c = match peek () with UID c -> advance (); c | _ -> fail () in
      let args =
        if accept (KW "of") then List.map (of_texpr (ref [])) (ty_args ())
        else []
      in
      Hashtbl.replace cons c
        { kind = KExn; arity = List.length args; nconst = 0; nblock = 0;
          scheme = TCon ("%c", tcon "exn" :: args) };
      (IExn c, l) :: items ()
  | KW "external" ->
      advance ();
      let x =
        match peek () with
        | LID x -> advance (); x
        | KW "(" ->
            advance ();
            let o = (match peek () with KW o -> advance (); o | _ -> fail ()) in
            expect (KW ")");
            o
        | _ -> fail ()
      in
      expect (KW ":");
      let t = ty () in
      expect (KW "=");
      let p = match peek () with STR p -> advance (); p | _ -> fail () in
      (IExt (x, t, p), l) :: items ()
  | _ -> let e = expr () in (ILet (false, [ PAny, e ]), l) :: items ()

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

let rec repr t = match t with TVar { contents = Link t } -> repr t | t -> t

let rec show t =
  match repr t with
  | TVar { contents = Unbound (n, _) } -> (Printf.sprintf "'_%d" n)
  | TCon ("->", [ a; b ]) -> (Printf.sprintf "(%s -> %s)" (show a) (show b))
  | TCon ("*", ts) -> "(" ^ String.concat " * " (List.map show ts) ^ ")"
  | TCon (c, []) -> c
  | TCon (c, ts) -> "(" ^ String.concat ", " (List.map show ts) ^ ") " ^ c
  | TVar _ -> "?"

(* x's variable in its own type is an error; a variable met at a lower
 * level takes it, so that it is generalized only where both are *)
let rec occurs r lv t =
  match repr t with
  | TVar r' when r == r' -> error "a recursive type"
  | TVar ({ contents = Unbound (n, l) } as r') ->
      if l > lv then r' := Unbound (n, lv)
  | TCon (_, ts) -> List.iter (occurs r lv) ts
  | TVar _ -> ()

let rec unify a b =
  match repr a, repr b with
  | TVar r, TVar r' when r == r' -> ()
  (* (old: one case, an or-pattern with names) *)
  | TVar ({ contents = Unbound (_, l) } as r), t -> occurs r l t; r := Link t
  | t, TVar ({ contents = Unbound (_, l) } as r) -> occurs r l t; r := Link t
  | TCon (c, ts), TCon (d, us) when c = d && List.length ts = List.length us ->
      List.iter2 unify ts us
  | a, b ->
      (* a type's second name (abbreviations): the type in its place *)
      let named = function TCon (c, ts) -> abbreviation c ts | _ -> None in
      match named a, named b with
      | Some t, _ -> unify t b
      | _, Some t -> unify a t
      | None, None ->
          error
            (Printf.sprintf "this has type %s but is used with type %s" (show a)
               (show b))

(* the variables deeper than the current let become parameters *)
let rec generalize t =
  match repr t with
  | TVar ({ contents = Unbound (n, l) } as r) when l > !level ->
      r := Unbound (n, generic)
  | TCon (_, ts) -> List.iter generalize ts
  | TVar _ -> ()

let instantiate t =
  let copies = Hashtbl.create 8 in
  let rec go t =
    match repr t with
    | TVar { contents = Unbound (n, l) } when l = generic -> (
        match Hashtbl.find_opt copies n with
        | Some v -> v
        | None -> let v = newvar () in Hashtbl.replace copies n v; v)
    | TCon (c, ts) -> TCon (c, List.map go ts)
    | t -> t
  in
  go t

(* the value restriction: only a value is generalized *)
let rec nonexpansive = function
  | Const _ | Var _ | Fun _ -> true
  | Con (_, l) -> List.for_all nonexpansive l
  | Tuple l -> List.for_all nonexpansive l
  | _ -> false

let con_type c =
  match instantiate (find_con c).scheme with
  | TCon (_, res :: args) -> res, args
  | _ -> invalid_arg "con_type"

(* l's label, in the record t already is when known (an annotation's,
 * a parameter's): type-directed, so that two records may share one;
 * else the latest record's, as OCaml's (a unit's own are read after the
 * interfaces of those before it)
 * (old: an error, "a field of several records: annotate which", when
 * a program was its files compiled whole) *)
let label_for l t =
  let known = match repr t with TCon (n, _) -> Some n | _ -> None in
  match
    List.filter (fun li -> known = None || known = Some li.lrec)
      (Hashtbl.find_all record_labels l)
  with
  | li :: _ -> li
  | [] ->
      error
        (Printf.sprintf "no field %s%s" l
           (match known with Some n -> " in " ^ n | None -> ""))
let label_type li =
  match instantiate li.lscheme with
  | TCon (_, [ r; f ]) -> r, f
  | _ -> invalid_arg "label_type"
let const_type = function
  | CInt _ -> int_t | CChar _ -> tcon "char" | CStr _ -> string_t

(* known: the type the value matched is already known to have (the
 * scrutinee's, an annotation's), so that a record pattern finds its
 * record when two records share a label; a fresh variable when none is
 * known. (A plain argument, not an optional one, which mini-ml, the
 * compiler mini-mk builds this file with, does not have) *)
let rec pat_type known p : ty * (string * ty) list =
  match p with
  | PAny -> newvar (), []
  | PVar x -> let t = newvar () in t, [ x, t ]
  | PConst c -> const_type c, []
  | PCon (c, ps) ->
      let res, args = con_type c in
      res,
      List.concat
        (List.map2
           (fun p t -> let pt, b = pat_type (newvar ()) p in unify pt t; b)
           ps args)
  | PTuple ps ->
      let l = List.map (fun p -> pat_type (newvar ()) p) ps in
      TCon ("*", List.map fst l), List.concat_map snd l
  | PAlias (p, x) -> let t, b = pat_type known p in t, (x, t) :: b
  | PAnnot (p, te) ->
      let ta = instantiate (of_texpr (ref []) te) in
      unify ta known;
      let t, b = pat_type ta p in unify t ta; t, b
  | PRecord (fs, idxs, n) ->
      let li0 = label_for (fst (List.hd fs)) known in
      let r = newvar () in
      let bs = List.map (fun (l, p) ->
        let li =
          match
            List.find_opt (fun li -> li.lrec = li0.lrec)
              (Hashtbl.find_all record_labels l)
          with
          | Some li -> li
          | None -> error (Printf.sprintf "no field %s in %s" l li0.lrec) in
        let r', f = label_type li in
        unify r r';
        let pt, b = pat_type f p in
        unify pt f; li.idx, b) fs in
      idxs := List.map fst bs; n := List.length li0.lnames;
      r, List.concat_map snd bs
  | POr (a, b) ->
      let t, ba = pat_type (newvar ()) a and u, bb = pat_type (newvar ()) b in
      unify t u;
      if ba <> [] || bb <> [] then error "an or-pattern with variables";
      t, []

(* The names of the toplevel, by name, in a table: the units' before
 * this one, M.x, Stdlib's x too (open in all), and this unit's own and
 * what it opens, each added as it comes (a name added again hides the
 * one before, as OCaml's Hashtbl keeps them) and taken out at its end
 * ([unit_done]). The locals are a list, looked in first. Two of them,
 * the types' and the values' (below).
 * (old: all of them one list, Stdlib's at its end: each +, = or ^ found
 * after the whole program's names, most of a compilation's time) *)
let tglobals : (string, ty) Hashtbl.t = Hashtbl.create 1024
let find_name env tbl x =
  match List.assoc_opt x env with
  | Some b -> Some b
  | None -> Hashtbl.find_opt tbl x

(* a name of this unit's toplevel, until its end *)
let unit_names = ref []
let add_name tbl x b =
  Hashtbl.add tbl x b;
  unit_names := (fun () -> Hashtbl.remove tbl x) :: !unit_names
let unit_done () = List.iter (fun f -> f ()) !unit_names; unit_names := []

let rec infer env e : ty =
  match e with
  | Const c -> const_type c
  | Var (x, r) ->
      (match find_name env tglobals x with
       | Some t -> r := instantiate t; !r
       | None -> error ("unbound " ^ x))
  | Con (c, args) ->
      let res, targs = con_type c in
      List.iter2 (fun a t -> unify (infer env a) t) args targs;
      res
  | Tuple es -> TCon ("*", List.map (infer env) es)
  | App (f, args) ->
      List.fold_left
        (fun tf a -> let r = newvar () in unify tf (arrow (infer env a) r); r)
        (infer env f) args
  | Fun (xs, b) ->
      let ts = List.map (fun _ -> newvar ()) xs in
      List.fold_right arrow ts (infer (List.rev (List.combine xs ts) @ env) b)
  | Let (false, bs, b) -> infer (let_types env bs) b
  | Let (true, bs, b) -> infer (rec_types env bs) b
  | Match (e, cases) -> cases_type env (infer env e) cases
  | Try (e, cases) ->
      let t = infer env e in unify t (cases_type env (tcon "exn") cases); t
  | If (c, a, b) ->
      unify (infer env c) bool_t;
      let t = infer env a in
      unify t (infer env b);
      t
  | Seq (a, b) -> ignore (infer env a); infer env b
  | While (c, b) -> unify (infer env c) bool_t; ignore (infer env b); unit_t
  | For (x, a, b, _, body) ->
      unify (infer env a) int_t;
      unify (infer env b) int_t;
      ignore (infer ((x, int_t) :: env) body);
      unit_t
  | Dot (e, l, i) ->
      let t = infer env e in
      let li = label_for l t in
      let r, f = label_type li in
      i := li.idx; unify t r; f
  | SetDot (e, l, i, v) ->
      let t = infer env e in
      let li = label_for l t in
      if not li.mut then error (Printf.sprintf "the field %s is not mutable" l);
      let r, f = label_type li in
      i := li.idx; unify t r; unify (infer env v) f; unit_t
  | Record (fs, order) ->
      (* the record whose labels are exactly these *)
      let names = List.sort compare (List.map fst fs) in
      let li0 =
        match
          List.filter (fun li -> List.sort compare li.lnames = names)
            (Hashtbl.find_all record_labels (fst (List.hd fs)))
        with
        | li :: _ -> li
        | [] -> error ("no record has the fields " ^ (String.concat ", " names))
      in
      let r = newvar () in
      order := List.map (fun (l, e) ->
        let li =
          List.find (fun li -> li.lrec = li0.lrec)
            (Hashtbl.find_all record_labels l)
        in
        let r', f = label_type li in
        unify r r'; unify (infer env e) f; li.idx) fs;
      r
  | With (e, fs, idxs, n) ->
      (* the copy has e's type: a field cannot change a type parameter *)
      let t = infer env e in
      let li0 = label_for (fst (List.hd fs)) t in
      idxs := List.map (fun (l, v) ->
        let li =
          match
            List.find_opt (fun li -> li.lrec = li0.lrec)
              (Hashtbl.find_all record_labels l)
          with
          | Some li -> li
          | None -> error (Printf.sprintf "no field %s in %s" l li0.lrec) in
        let r, f = label_type li in
        unify t r; unify (infer env v) f; li.idx) fs;
      n := List.length li0.lnames;
      t

and cases_type env t cases =
  let r = newvar () in
  List.iter (fun (p, g, e) ->
    let pt, bs = pat_type t p in
    unify pt t;
    let env = bs @ env in
    Option.iter (fun g -> unify (infer env g) bool_t) g;
    unify (infer env e) r) cases;
  r

and let_types env bs =
  List.concat_map (fun (p, e) ->
    incr level;
    let t = infer env e in
    decr level;
    match p with
    | PVar x ->
        if nonexpansive e then generalize t else unify (newvar ()) t; [ x, t ]
    | p -> let pt, b = pat_type t p in unify pt t; b) bs
  @ env

and rec_types env bs =
  incr level;
  let vars =
    List.map
      (function PVar x, _ -> x, newvar () | _ -> error "let rec: a name expected")
      bs
  in
  List.iter2 (fun (_, t) (_, e) -> unify t (infer (vars @ env) e)) vars bs;
  decr level;
  List.iter (fun (_, t) -> generalize t) vars;
  vars @ env

let type_item env (it, l) =
  try
    match it with
    | ILet (false, bs) -> let_types env bs
    | ILet (true, bs) -> rec_types env bs
    | IExt (x, t, _) -> (x, of_texpr (ref []) t) :: env
    | IExn _ | IOpen _ -> env
  with Failure m -> error (Printf.sprintf "line %d: %s" l m)

(* Scopes. A unit's names are M.x for the units after it; open M gives
 * a unit M's names as x, for itself alone. Stdlib is open in every
 * unit. A name's env and a type's env are scoped alike; the types, the
 * constructors and the labels are the program's, one name space
 * (old: every name the program's, open M read and left, List.map a
 * name with a dot) *)
let implicit u = u = "Stdlib"
let qualify u x = u ^ "." ^ x
(* open M: M.x as x too, for this unit *)
let opened tbl u =
  let p = u ^ "." in
  let n = String.length p in
  Hashtbl.fold (fun x b acc ->
      if String.length x > n && String.sub x 0 n = p then
        (String.sub x n (String.length x - n), b) :: acc
      else acc)
    tbl []
  |> List.iter (fun (x, b) -> add_name tbl x b)
(* a unit's names, M.x, into the table for the units after it (and
 * Stdlib's x); the list for them is the one before it *)
let export tbl u defs before =
  List.iter (fun (x, b) ->
      Hashtbl.replace tbl (qualify u x) b;
      if implicit u then Hashtbl.replace tbl x b)
    (List.rev defs);
  before

(* a unit's items typed: the env then, and the names it defined, each
 * in the table as it comes *)
let type_unit env items =
  List.fold_left (fun (env, defs) (it, l) ->
    match it with
    | IOpen u -> opened tglobals u; env, defs
    | _ ->
        let added = type_item [] (it, l) in
        List.iter (fun (x, t) -> add_name tglobals x t) (List.rev added);
        env, added @ defs) (env, []) items

(*****************************************************************************)
(* The stack machine *)
(*****************************************************************************)

type rel = Eq | Ne | Lt | Le | Gt | Ge
type op =
  | Add | Sub | Mul | Div | Mod | And | Or | Xor | Lsl | Lsr | Asr | Cmp of rel
  | Neg | Lnot | Not | IsInt | Tag
(* a function's n-ary code, or a closure's field *)
type target = Direct of string | Code of int

(* a binary operation's first operand is on top, as every operation's:
 * arguments are pushed from the last, as OCaml evaluates them *)
(* a word's 32 bits, signed: what the machine keeps of an int64 *)
let low32 v = Int64.shift_right (Int64.shift_left v 32) 32

type ir =
  | Imm of int64                      (* a word, an integer already tagged *)
  | Addr of string * int              (* a symbol's address: a static block's
                                       * value is its +8 *)
  | Get of int | Set of int           (* a slot of the function's frame on the
                                       * value stack *)
  | GetG of string * int | SetG of string * int   (* a global of a unit: its
                                                   * table, its index *)
  | Field of int                      (* a block by its field *)
  | SetField of int                   (* the value below the block stored in
                                       * its field *)
  | Alloc of int * int                (* a tag, n values by the block of them,
                                       * the top its field 0 *)
  | Blank of int * int                (* a tag, a block of n fields, each () *)
  | Op of op
  | Call of target * int * bool       (* the closure then n arguments by the
                                       * result; a tail call *)
  | CallC of string * int             (* a runtime's function of n arguments *)
  | Label of int | Jmp of int
  | Jz of int | Jnz of int            (* false is 1, the tagged 0 *)
  | Drop
  | Ret
  | Raise                             (* the top raised; its place taken by the
                                       * result, never seen *)
  | TryEnter of int * int             (* the k-th handler of the function, its
                                       * code *)
  | TryExit of int
  | Catch of int                      (* the handler's entry: the exception pushed *)

let labels = ref 0
let label () = incr labels; !labels
let text = Buffer.create 65536 and data = Buffer.create 16384

(*****************************************************************************)
(* The machine: tiny-machine, the stack in r1..r11, the value stack at r12 *)
(*****************************************************************************)

(* TinyMachineCPU's CPU: 32-bit registers, r0 zero, no flags, sp r14, lr
 * r15. The stack machine's registers are r1..r11 (an expression 11
 * deep at most), the value stack's top is r12, r13 the scratch and the
 * result. A function's frames, in words of 4 bytes. On the value
 * stack, f words below r12 (its top, which the function raises by f at
 * its entry): slot 0 its closure, then its parameters, its variables,
 * and a slot per register of the stack machine, where a call or an
 * allocation spills it. On the machine stack, m bytes: C's outgoing
 * arguments from 0(sp) (tiny-c's convention:
 * every argument in memory, the result in r13, every register but sp
 * the callee's), the link at c, then 16 bytes per handler. A call of
 * ML passes the closure in r13 and the arguments in r1..rn (r0 is the
 * zero), so at most 10 (r11 is a tail call's target); the result is in
 * r13. Every call is la then jalr: a jal reaches only 128 KB, and a
 * kernel with its runtime and its programs is bigger. After a call of
 * C, r12 comes back from ml_vsp (C keeps no register). *)
let machine name nparams nslots (code : ir list) =
  (* the lines: text, and those that the frame's sizes make (f, m, c,
   * known at the end) as functions of them; the text between two of
   * those in one buffer (old: a function a line, every line's string
   * made at the end) *)
  let lines = ref [] and chunk = Buffer.create 256 in
  let flush () =
    if Buffer.length chunk > 0 then (
      let s = Buffer.contents chunk in
      Buffer.clear chunk;
      lines := (fun _ _ _ -> s) :: !lines)
  in
  let line f = flush (); lines := f :: !lines in
  let ins s =
    Buffer.add_char chunk '\t'; Buffer.add_string chunk s;
    Buffer.add_char chunk '\n' in
  let sp = ref 0 and maxsp = ref 0 and tries = ref 0 and cargs = ref 0
  and dead = ref false in
  let depth_at = Hashtbl.create 16 and catch_at = Hashtbl.create 4 in
  let get i r =
    line (fun f _ _ -> (Printf.sprintf "\tldw\tr%d, %d(r12)\n" r (4 * (i - f))))
  in
  let put r i =
    line (fun f _ _ -> (Printf.sprintf "\tstw\tr%d, %d(r12)\n" r (4 * (i - f))))
  in
  let spill_slot r = nslots + r - 1 in
  let push () =
    incr sp;
    if !sp > 11 then
      error
        (name
         ^ ": an expression too deep (tiny-machine has 11 registers for it)");
    maxsp := max !maxsp !sp;
    !sp
  in
  let spill () = for r = 1 to !sp do put r (spill_slot r) done in
  let reload () = for r = 1 to !sp do get (spill_slot r) r done in
  let result () = ins (Printf.sprintf "mov\tr%d, r13" (push ())) in
  let lab l = (!unit_name ^ ".L" ^ string_of_int l) in
  let jump l = Hashtbl.replace depth_at l !sp in
  let epilogue () =
    line (fun f _ _ -> (Printf.sprintf "\taddi\tr12, r12, %d\n" (-4 * f)));
    line (fun _ _ c -> (Printf.sprintf "\tldw\tlr, %d(sp)\n" c));
    line (fun _ m _ -> (Printf.sprintf "\taddi\tsp, sp, %d\n" m))
  in
  let record c k = c + 4 + (16 * k) in
  let at k d f = line (fun _ _ c -> "\t" ^ f (record c k + d) ^ "\n") in
  let c_call f =
    ins "la\tlr, ml_vsp"; ins "stw\tr12, 0(lr)";
    ins ("la\tlr, " ^ f); ins "jalr\tlr, 0(lr)";
    ins "la\tlr, ml_vsp"; ins "ldw\tr12, 0(lr)"
  in
  let bin f = let a = !sp in decr sp; f a !sp in
  let tagged d =
    ins (Printf.sprintf "shli\tr%d, r%d, 1" d d);
    ins (Printf.sprintf "ori\tr%d, r%d, 1" d d) in
  (* the length of the string in register s, untagged, into r13; lr used *)
  let length_of s =
    ins (Printf.sprintf "ldw\tr13, -4(r%d)" s);
    ins "shri\tr13, r13, 10";
    ins "shli\tr13, r13, 2";
    ins (Printf.sprintf "add\tlr, r%d, r13" s);
    ins "ldb\tlr, -1(lr)";
    ins "sub\tr13, r13, lr";
    ins "addi\tr13, r13, -1" in
  let op o =
    let a = !sp in
    match o with
    | Add ->
        bin (fun a b ->
          ins (Printf.sprintf "add\tr%d, r%d, r%d" b a b);
          ins (Printf.sprintf "addi\tr%d, r%d, -1" b b))
    | Sub ->
        bin (fun a b ->
          ins (Printf.sprintf "sub\tr%d, r%d, r%d" b a b);
          ins (Printf.sprintf "addi\tr%d, r%d, 1" b b))
    | Mul ->
        bin (fun a b ->
          ins (Printf.sprintf "addi\tr%d, r%d, -1" a a);
          ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
          ins (Printf.sprintf "mul\tr%d, r%d, r%d" b a b);
          ins (Printf.sprintf "addi\tr%d, r%d, 1" b b))
    | Div | Mod ->
        bin (fun a b ->
          ins (Printf.sprintf "sari\tr%d, r%d, 1" a a);
          ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
          ins ((if o = Div then "div" else "rem") ^ "\tr" ^ string_of_int b
               ^ ", r" ^ string_of_int a ^ ", r" ^ string_of_int b);
          tagged b)
    | And -> bin (fun a b -> ins (Printf.sprintf "and\tr%d, r%d, r%d" b a b))
    | Or -> bin (fun a b -> ins (Printf.sprintf "or\tr%d, r%d, r%d" b a b))
    | Xor ->
        bin (fun a b ->
          ins (Printf.sprintf "xor\tr%d, r%d, r%d" b a b);
          ins (Printf.sprintf "ori\tr%d, r%d, 1" b b))
    | Lsl ->
        bin (fun a b ->
          ins (Printf.sprintf "addi\tr%d, r%d, -1" a a);
          ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
          ins (Printf.sprintf "shl\tr%d, r%d, r%d" b a b);
          ins (Printf.sprintf "ori\tr%d, r%d, 1" b b))
    | Lsr | Asr ->
        bin (fun a b ->
          ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
          ins ((if o = Lsr then "shr" else "sar") ^ "\tr" ^ string_of_int b
               ^ ", r" ^ string_of_int a ^ ", r" ^ string_of_int b);
          ins (Printf.sprintf "ori\tr%d, r%d, 1" b b))
    | Cmp r ->
        (* a r b, 1 or 0, then tagged *)
        bin (fun a b ->
          (match r with
           | Lt -> ins (Printf.sprintf "slt\tr%d, r%d, r%d" b a b)
           | Gt -> ins (Printf.sprintf "slt\tr%d, r%d, r%d" b b a)
           | Le ->
               ins (Printf.sprintf "slt\tr%d, r%d, r%d" b b a);
               ins (Printf.sprintf "xori\tr%d, r%d, 1" b b)
           | Ge ->
               ins (Printf.sprintf "slt\tr%d, r%d, r%d" b a b);
               ins (Printf.sprintf "xori\tr%d, r%d, 1" b b)
           | Eq ->
               ins (Printf.sprintf "sub\tr%d, r%d, r%d" b a b);
               ins (Printf.sprintf "sltiu\tr%d, r%d, 1" b b)
           | Ne ->
               ins (Printf.sprintf "sub\tr%d, r%d, r%d" b a b);
               ins (Printf.sprintf "sltu\tr%d, zero, r%d" b b));
          tagged b)
    | Neg ->
        ins (Printf.sprintf "sub\tr%d, zero, r%d" a a);
        ins (Printf.sprintf "addi\tr%d, r%d, 2" a a)
    | Lnot ->
        ins "addi\tr13, zero, -1";
        ins (Printf.sprintf "xor\tr%d, r%d, r13" a a);
        ins (Printf.sprintf "ori\tr%d, r%d, 1" a a)
    | Not -> ins (Printf.sprintf "xori\tr%d, r%d, 2" a a)
    | IsInt -> ins (Printf.sprintf "andi\tr%d, r%d, 1" a a); tagged a
    | Tag -> ins (Printf.sprintf "ldb\tr%d, -4(r%d)" a a); tagged a
  in
  (* a block of n fields from the runtime, in r13 *)
  let alloc tag n =
    spill ();
    cargs := max !cargs 2;
    ins (Printf.sprintf "li\tr13, %d" n); ins "stw\tr13, 0(sp)";
    ins (Printf.sprintf "li\tr13, %d" tag); ins "stw\tr13, 4(sp)";
    c_call "ml_alloc" in
  List.iter (fun i ->
    match i with
    | Label l ->
        (match Hashtbl.find_opt depth_at l with
         | Some d when !dead -> sp := d
         | _ -> ());
        dead := false;
        line (fun _ _ _ -> lab l ^ ":\n")
    | Catch k -> dead := false; sp := Hashtbl.find catch_at k; reload (); result ()
    | _ when !dead -> ()
    (* old: Int64.to_int32 v alone: 4611686018427387903 became -1, and
     * the program printed something else than OCaml *)
    | Imm v ->
        if low32 v <> v then
          error "an integer beyond 31 bits: not on TinyCPU (a 32-bit machine)";
        ins ("li\tr" ^ string_of_int (push ()) ^ ", " ^ Int64.to_string v)
    | Addr (s, _) -> ins (Printf.sprintf "la\tr%d, %s" (push ()) s)
    | Get i -> get i (push ())
    | Set i -> put !sp i; decr sp
    | GetG (t, g) ->
        let r = push () in
        ins (Printf.sprintf "la\tr%d, %s" r t);
        ins (Printf.sprintf "ldw\tr%d, %d(r%d)" r (4 * g) r)
    | SetG (t, g) ->
        ins ("la\tr13, " ^ t);
        ins (Printf.sprintf "stw\tr%d, %d(r13)" !sp (4 * g));
        decr sp
    | Field k -> ins (Printf.sprintf "ldw\tr%d, %d(r%d)" !sp (4 * k) !sp)
    | SetField k ->
        ins (Printf.sprintf "stw\tr%d, %d(r%d)" (!sp - 1) (4 * k) !sp);
        sp := !sp - 2
    | Alloc (tag, n) ->
        alloc tag n;
        for k = 0 to n - 1 do
          get (spill_slot (!sp - k)) 15;
          ins (Printf.sprintf "stw\tr15, %d(r13)" (4 * k))
        done;
        sp := !sp - n;
        reload ();
        result ()
    | Blank (tag, n) ->
        alloc tag n;
        ins "li\tr15, 1";
        for k = 0 to n - 1 do
          ins (Printf.sprintf "stw\tr15, %d(r13)" (4 * k))
        done;
        reload ();
        result ()
    | Op o -> op o
    | Call (t, n, tail) ->
        if n > 10 then
          error
            (name ^ ": " ^ string_of_int n
             ^ " arguments (tiny-machine passes 10 at most)");
        spill ();
        get (spill_slot !sp) 13;
        for k = 1 to n do get (spill_slot (!sp - k)) k done;
        sp := !sp - n - 1;
        if tail then begin
          epilogue ();
          (match t with
           | Direct f -> ins ("la\tr11, " ^ f)
           | Code k -> ins (Printf.sprintf "ldw\tr11, %d(r13)" (4 * k)));
          ins "jalr\tzero, 0(r11)";
          dead := true
        end
        else begin
          (match t with
           | Direct f -> ins ("la\tlr, " ^ f)
           | Code k -> ins (Printf.sprintf "ldw\tlr, %d(r13)" (4 * k)));
          ins "jalr\tlr, 0(lr)";
          reload ();
          result ()
        end
    (* A string's length and its bytes are read inline rather than by a
     * call of the runtime: a call for each byte was a quarter of the time
     * a browser took to read a page (plan_tiny_browser.md, section 12).
     * The length comes from the block's header and its last byte, as in
     * TinyMLRuntime/core.c's length. Only r13 and lr are free here (lr
     * is saved by the prologue). *)
    | CallC ("ml_string_length", 1) ->
        length_of !sp;
        ins (Printf.sprintf "mov\tr%d, r13" !sp);
        tagged !sp
    (* s.[i]: s is on top of the stack, i below it, and the byte takes
     * i's register. The index is checked against the length; only an
     * index out of bounds calls ml_string_get, which reports the error. *)
    | CallC ("ml_string_get", 2) ->
        let s = !sp and i = !sp - 1 in
        let slow = label () and done_ = label () in
        length_of s;
        ins (Printf.sprintf "sari\tlr, r%d, 1" i);
        ins ("bgeu\tlr, r13, " ^ (lab slow));
        ins (Printf.sprintf "add\tlr, r%d, lr" s);
        ins (Printf.sprintf "ldb\tr%d, 0(lr)" i);
        tagged i;
        ins ("j\t" ^ (lab done_));
        line (fun _ _ _ -> lab slow ^ ":\n");
        spill ();
        cargs := max !cargs 2;
        for k = 0 to 1 do
          get (spill_slot (!sp - k)) 13;
          ins (Printf.sprintf "stw\tr13, %d(sp)" (4 * k))
        done;
        sp := !sp - 2;
        c_call "ml_string_get";
        reload ();
        result ();
        line (fun _ _ _ -> lab done_ ^ ":\n")
    | CallC (f, n) ->
        spill ();
        cargs := max !cargs n;
        for k = 0 to n - 1 do
          get (spill_slot (!sp - k)) 13;
          ins (Printf.sprintf "stw\tr13, %d(sp)" (4 * k))
        done;
        sp := !sp - n;
        c_call f;
        reload ();
        result ()
    | Jmp l -> jump l; ins ("j\t" ^ (lab l)); dead := true
    | Jz l ->
        let r = !sp in
        decr sp; jump l; ins "li\tr13, 1";
        ins (Printf.sprintf "beq\tr%d, r13, %s" r (lab l))
    | Jnz l ->
        let r = !sp in
        decr sp; jump l; ins "li\tr13, 1";
        ins (Printf.sprintf "bne\tr%d, r13, %s" r (lab l))
    | Drop -> decr sp
    | Ret ->
        ins (Printf.sprintf "mov\tr13, r%d" !sp);
        decr sp; epilogue (); ins "ret"; dead := true
    | Raise ->
        ins (Printf.sprintf "mov\tr13, r%d" !sp);
        ins "la\tlr, ml_raise"; ins "jalr\tzero, 0(lr)"; dead := true
    | TryEnter (k, handler) ->
        (* the record: sp, r12, the handler's address (call's link: the
         * j after it), the previous record *)
        spill ();
        Hashtbl.replace catch_at k !sp;
        tries := max !tries (k + 1);
        let set = label () in
        ins ("call\t" ^ (lab set));
        ins ("j\t" ^ (lab handler));
        line (fun _ _ _ -> lab set ^ ":\n");
        at k 0 ((fun x0 -> Printf.sprintf "stw\tsp, %d(sp)" x0));
        at k 4 ((fun x0 -> Printf.sprintf "stw\tr12, %d(sp)" x0));
        at k 8 ((fun x0 -> Printf.sprintf "stw\tlr, %d(sp)" x0));
        ins "la\tlr, ml_handler";
        ins "ldw\tr13, 0(lr)";
        at k 12 ((fun x0 -> Printf.sprintf "stw\tr13, %d(sp)" x0));
        at k 0 ((fun x0 -> Printf.sprintf "addi\tr13, sp, %d" x0));
        ins "stw\tr13, 0(lr)"
    | TryExit k ->
        at k 12 ((fun x0 -> Printf.sprintf "ldw\tr13, %d(sp)" x0));
        ins "la\tlr, ml_handler"; ins "stw\tr13, 0(lr)")
    code;
  if nparams > 10 then
    error
      (name ^ ": " ^ string_of_int nparams
       ^ " parameters (tiny-machine passes 10 at most)");
  let f = nslots + !maxsp and c = 4 * !cargs in
  let m = (record c !tries + 7) land lnot 7 in
  let out s = Buffer.add_string text s in
  (* a piece: tiny-linker leaves it out when nothing names its labels *)
  out "\t.piece\n";
  out (name ^ ":\n\taddi\tsp, sp, " ^ string_of_int (- m) ^ "\n\tstw\tlr, "
       ^ string_of_int c ^ "(sp)\n\taddi\tr12, r12, " ^ string_of_int (4 * f)
       ^ "\n");
  out (Printf.sprintf "\tstw\tr13, %d(r12)\n" (-4 * f));
  for i = 1 to nparams do
    out (Printf.sprintf "\tstw\tr%d, %d(r12)\n" i (4 * (i - f)))
  done;
  (* the other slots zeroed: the collector scans them *)
  for i = nparams + 1 to f - 1 do
    out (Printf.sprintf "\tstw\tzero, %d(r12)\n" (4 * (i - f)))
  done;
  flush ();
  List.iter (fun l -> Buffer.add_string text (l f m c)) (List.rev !lines)

(*****************************************************************************)
(* Data: static blocks *)
(*****************************************************************************)

(* a word of data: a number, a function's code, or a static block's
 * value (its first field's address) *)
type dword = DNum of string | DCode of string | DVal of string

(* each a piece of its own, as a function is *)
let fields sym ws =
  Buffer.add_string data (sym ^ ":\n");
  List.iter (fun w ->
      Printf.bprintf data "\t.word\t%s\n"
        (match w with DNum x -> x | DCode x -> x | DVal x -> x))
    ws
let words sym ws = Buffer.add_string data "\t.piece\n"; fields sym ws

(* a static block, its header then its fields. Its symbol is the first
 * field's, the value itself (the assembler's expressions have no
 * sym+n) *)
let block sym hdr ws =
  Printf.bprintf data "\t.piece\n\t.word\t%s\n" hdr; fields sym ws

let header n tag = string_of_int ((n lsl 10) lor tag)
let closure_tag = 247 and string_tag = 252

(* a string: its words, the last byte the number of the others that are
 * padding, as OCaml's *)
let strings = Hashtbl.create 16
let static_string s =
  match Hashtbl.find_opt strings s with
  | Some sym -> sym
  | None ->
      let sym = (!unit_name ^ ".s" ^ string_of_int (Hashtbl.length strings)) in
      let n = (String.length s / 4) + 1 in
      let b = Bytes.make (4 * n) '\000' in
      Bytes.blit_string s 0 b 0 (String.length s);
      Bytes.set b ((4 * n) - 1) (Char.chr ((4 * n) - 1 - String.length s));
      block sym (header n string_tag)
        (List.init n (fun i ->
           let byte k = Char.code (Bytes.get b ((4 * i) + k)) in
           (* (old: Int32.to_string of Bytes.get_int32_le) *)
           DNum
             (Int64.to_string
                (low32
                   (Int64.logor (Int64.shift_left (Int64.of_int (byte 3)) 24)
                      (Int64.of_int
                         (byte 0 lor (byte 1 lsl 8) lor (byte 2 lsl 16))))))));
      Hashtbl.replace strings s sym;
      sym

(* the curry functions an arity needs (the program's, its main's to
 * make: each unit says the arities it needs) *)
let arities = ref []
let curry n k = (Printf.sprintf "ml_curry%d_%d" n k)
let entry n lab =
  if n = 1 then lab
  else (
    if not (List.mem n !arities) then arities := n :: !arities;
    curry n 0)
let closure_sym lab = lab ^ ".c"
let static_closure lab n =
  let sym = closure_sym lab in
  block sym (header 2 closure_tag) [ DCode (entry n lab); DCode lab ];
  sym

(* an exception: a block with its name, compared by address; its value
 * a block [the exception; its arguments], a static one without them *)
let exn_id c = "ml_exn_" ^ c
let exn_const c = "ml_exv_" ^ c

(* (old: 2L, 1L, literals tiny-ml does not read) *)
let tagged n = Int64.add (Int64.mul (Int64.of_int 2) (Int64.of_int n)) Int64.one

(*****************************************************************************)
(* From the tree to the stack machine *)
(*****************************************************************************)

(* where a name's value is, and, for a function whose code is known,
 * that code and its arity *)
type loc = Slot of int | Env of int | Glob of string * int | Static of string
type binding = Loc of loc * (string * int) option | Ext of string * int

(* the values' table, as the types' (tglobals) *)
let globals : (string, binding) Hashtbl.t = Hashtbl.create 1024

type fn =
  { mutable code : ir list; mutable nslots : int; mutable ntries : int }

let cur = ref { code = []; nslots = 1; ntries = 0 }
let emit i = (!cur).code <- i :: (!cur).code
let slot () = let s = (!cur).nslots in (!cur).nslots <- s + 1; s
(* the functions to compile, in their order: a queue as two lists, the
 * next ones and the ones added since, last first (old: OCaml's Queue,
 * which TinyLibCore does not have) *)
let queue : (unit -> unit) list ref = ref []
and queued : (unit -> unit) list ref = ref []
let enqueue f = queued := f :: !queued
let rec dequeue () =
  match !queue, !queued with
  | f :: rest, _ -> queue := rest; Some f
  | [], [] -> None
  | [], l -> queue := List.rev l; queued := []; dequeue ()
let nfuns = ref 0

let fun_label x =
  incr nfuns;
  (!unit_name ^ ".f" ^ string_of_int !nfuns ^ "_"
   ^ (String.map (fun c ->
          if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
             || (c >= '0' && c <= '9') || c = '_'
          then c
          else '_')
        x))

let lookup env x =
  match find_name env globals x with
  | Some b -> b
  | None -> error ("unbound " ^ x)

let rec pat_vars = function
  | PAny | PConst _ -> []
  | PVar x -> [ x ]
  | PCon (_, ps) -> List.concat_map pat_vars ps
  | PTuple ps -> List.concat_map pat_vars ps
  | PRecord (fs, _, _) -> List.concat_map (fun (_, p) -> pat_vars p) fs
  | PAlias (p, x) -> x :: pat_vars p
  | PAnnot (p, _) -> pat_vars p
  | POr (p, _) -> pat_vars p

(* the names free in e, each once, in their order *)
(* (old: or-patterns with names, Match (e, cs) | Try (e, cs): written
 * apart, as tiny-ml compiles this file too) *)
let rec free bound e acc =
  let fr = free bound in
  let cases e cs =
    List.fold_left (fun acc (p, g, b) ->
      let bound = pat_vars p @ bound in
      free bound b (match g with Some g -> free bound g acc | None -> acc))
      (fr e acc) cs in
  match e with
  | Const _ -> acc
  | Var (x, _) ->
      if List.mem x bound || List.mem x acc then acc else acc @ [ x ]
  | Con (_, l) -> List.fold_left (fun acc e -> fr e acc) acc l
  | Tuple l -> List.fold_left (fun acc e -> fr e acc) acc l
  | App (f, l) -> List.fold_left (fun acc e -> fr e acc) acc (f :: l)
  | Fun (xs, b) -> free (xs @ bound) b acc
  | Let (r, bs, b) ->
      let vs = List.concat_map (fun (p, _) -> pat_vars p) bs in
      let acc =
        List.fold_left
          (fun acc (_, e) -> free (if r then vs @ bound else bound) e acc)
          acc bs
      in
      free (vs @ bound) b acc
  | Match (e, cs) -> cases e cs
  | Try (e, cs) -> cases e cs
  | If (a, b, c) -> fr c (fr b (fr a acc))
  | Seq (a, b) -> fr b (fr a acc)
  | While (a, b) -> fr b (fr a acc)
  | For (x, a, b, _, body) -> free (x :: bound) body (fr b (fr a acc))
  | Record (fs, _) -> List.fold_left (fun acc (_, e) -> fr e acc) acc fs
  | With (e, fs, _, _) ->
      List.fold_left (fun acc (_, e) -> fr e acc) (fr e acc) fs
  | Dot (e, _, _) -> fr e acc
  | SetDot (e, _, _, v) -> fr v (fr e acc)

(* the free names a closure must hold: those of the enclosing function,
 * among the names free in it *)
let captured env names =
  List.filter (fun x ->
      match List.assoc_opt x env with
      | Some (Loc ((Slot _ | Env _), _)) -> true
      | _ -> false)
    names

(* a function's names: its closure's fields, then the others it names,
 * found now (the toplevel's table changes before its code is made;
 * old: the env's names that are not local, all of them) *)
let body_env env names fvs =
  List.mapi (fun j x ->
      x, match lookup env x with Loc (_, k) -> Loc (Env j, k) | b -> b)
    fvs
  @ List.filter_map
      (fun x -> if List.mem x fvs then None else Some (x, lookup env x))
      names

let rec refutable = function
  | PAny | PVar _ -> false
  | PAlias (p, _) -> refutable p
  | PAnnot (p, _) -> refutable p
  | PTuple ps -> List.exists refutable ps
  | PRecord (fs, _, _) -> List.exists (fun (_, p) -> refutable p) fs
  | PCon (c, ps) ->
      let ci = find_con c in
      ci.nconst + ci.nblock > 1 || ci.kind = KExn || List.exists refutable ps
  | PConst _ | POr _ -> true

(* the tests of p against the value in slot s, each jumping to fail;
 * its names bound to slots *)
let rec test acc s p fail =
  let check l = emit (Get s); List.iter emit l; emit (Jz fail) in
  let fields base ps acc =
    fst (List.fold_left (fun (acc, k) p ->
      (match p with
       | PAny -> acc
       | p ->
           let s' = slot () in
           emit (Get s); emit (Field k); emit (Set s');
           test acc s' p fail), k + 1)
      (acc, base) ps)
  in
  match p with
  | PAny -> acc
  | PVar x -> (x, Loc (Slot s, None)) :: acc
  | PAlias (p, x) -> test ((x, Loc (Slot s, None)) :: acc) s p fail
  | PAnnot (p, _) -> test acc s p fail
  | PConst (CInt n) -> check [ Imm (tagged n); Op (Cmp Eq) ]; acc
  | PConst (CChar n) -> check [ Imm (tagged n); Op (Cmp Eq) ]; acc
  | PConst (CStr str) ->
      check [ Addr (static_string str, 8); CallC ("ml_equal", 2) ]; acc
  | PTuple ps -> fields 0 ps acc
  (* a record is a tuple: the fields not named are _ *)
  | PRecord (fs, idxs, n) ->
      let at = List.combine !idxs (List.map snd fs) in
      fields 0 (List.init !n (fun k -> List.assoc_opt k at ||| PAny)) acc
  | PCon (c, ps) ->
      let ci = find_con c in
      (match ci.kind with
       | KConst n ->
           if ci.nconst + ci.nblock > 1 then check [ Imm (tagged n); Op (Cmp Eq) ]
       | KBlock t ->
           if ci.nconst > 0 then (emit (Get s); emit (Op IsInt); emit (Jnz fail));
           if ci.nblock > 1 then check [ Op Tag; Imm (tagged t); Op (Cmp Eq) ]
       | KExn -> check [ Field 0; Addr (exn_id c, 8); Op (Cmp Eq) ]);
      fields (if ci.kind = KExn then 1 else 0) ps acc
  | POr (a, b) ->
      let other = label () and ok = label () in
      ignore (test acc s a other);
      emit (Jmp ok);
      emit (Label other);
      ignore (test acc s b fail);
      emit (Label ok);
      acc

let match_failure () = emit (Addr (exn_const "Match_failure", 8)); emit Raise

(* a primitive: an instruction, or a call of the runtime; a comparison
 * of integers inlined, the others the runtime's compare *)
let prim p n ty =
  let int_arg =
    match repr ty with
    | TCon ("->", [ a; _ ]) ->
        (match repr a with
         | TCon (("int" | "char" | "bool" | "unit"), []) -> true
         | _ -> false)
    | _ -> false
  in
  let rel r =
    if int_arg then emit (Op (Cmp r))
    else
      match r with
      | Eq -> emit (CallC ("ml_equal", 2))
      | Ne -> emit (CallC ("ml_equal", 2)); emit (Op Not)
      | r ->
          (* compare's result r 0 is 0 r' compare's result *)
          emit (CallC ("ml_compare", 2)); emit (Imm (tagged 0));
          emit (Op (Cmp (match r with
            | Lt -> Gt | Gt -> Lt | Le -> Ge | Ge -> Le | r -> r)))
  in
  let ops = [ "%add", Add; "%sub", Sub; "%mul", Mul; "%div", Div; "%mod", Mod;
              "%and", And; "%or", Or; "%xor", Xor; "%lsl", Lsl; "%lsr", Lsr;
              "%asr", Asr; "%neg", Neg; "%lnot", Lnot; "%not", Not ] in
  let rels = [ "%eq", Eq; "%neq", Ne; "%lt", Lt; "%le", Le; "%gt", Gt; "%ge", Ge ] in
  match p with
  | _ when List.mem_assoc p ops -> emit (Op (List.assoc p ops))
  | _ when List.mem_assoc p rels -> rel (List.assoc p rels)
  | "%physeq" -> emit (Op (Cmp Eq))
  | "%physneq" -> emit (Op (Cmp Ne))
  | "%ref" -> emit (Alloc (0, 1))
  | "%field0" -> emit (Field 0)
  | "%field1" -> emit (Field 1)
  | "%setfield0" -> emit (SetField 0); emit (Imm (tagged 0))
  | "%raise" -> emit Raise
  | "%identity" -> ()
  | "%ignore" -> emit Drop; emit (Imm (tagged 0))
  | _ when p.[0] = '%' -> error ("unknown primitive " ^ p)
  | _ -> emit (CallC (p, n))

(* a closure: static, its symbol, when it captures nothing, else
 * built on the stack; each with its code's label and arity *)
type closure =
  | Closure_static of string * string * int
  | Closure_pushed of string * int

(* e's value pushed *)
let rec value env e =
  match e with
  | Const (CInt n) -> emit (Imm (tagged n))
  | Const (CChar n) -> emit (Imm (tagged n))
  | Const (CStr s) -> emit (Addr (static_string s, 8))
  | Var (x, _) -> var env x
  | Con (c, args) -> (
      match (find_con c).kind with
      | KConst n -> emit (Imm (tagged n))
      | KBlock t ->
          List.iter (value env) (List.rev args);
          emit (Alloc (t, List.length args))
      | KExn when args = [] -> emit (Addr (exn_const c, 8))
      | KExn ->
          List.iter (value env) (List.rev args);
          emit (Addr (exn_id c, 8));
          emit (Alloc (0, 1 + List.length args)))
  | Tuple es -> fields_block (List.map (fun e () -> value env e) es)
  (* a record is a tuple of its fields in their declaration's order,
   * evaluated as ocamlopt does, right to left *)
  | Record (fs, order) ->
      value env
        (Tuple
           (List.map snd
              (List.sort (fun (a, _) (b, _) -> compare a b)
                 (List.combine !order (List.map snd fs)))))
  (* the record copied first, kept in a slot (unless it is a variable,
   * read again for each field); then the fields, the new ones and the
   * copied ones, right to left as in a record *)
  | With (e, fs, idxs, n) ->
      let base = match e with
        | Var _ -> (fun () -> value env e)
        | _ ->
            value env e;
            let s = slot () in
            emit (Set s);
            (fun () -> emit (Get s)) in
      let given = List.combine !idxs (List.map snd fs) in
      fields_block (List.init !n (fun k () ->
        match List.assoc_opt k given with
        | Some v -> value env v
        | None -> base (); emit (Field k)))
  | Dot (e, _, i) -> value env e; emit (Field !i)
  | SetDot (e, _, i, v) ->
      value env v; value env e; emit (SetField !i); emit (Imm (tagged 0))
  | App (f, args) -> ignore (app env f args false)
  | Fun (xs, b) ->
      (match closure env "fun" xs b with
       | Closure_static (sym, _, _) -> emit (Addr (sym, 8))
       | Closure_pushed _ -> ())
  | Let _ | Match _ | If _ | Seq _ -> control env e false
  | Try (b, cases) ->
      let k = (!cur).ntries in
      (!cur).ntries <- k + 1;
      let handler = label () and out = label () in
      emit (TryEnter (k, handler));
      value env b;
      emit (TryExit k);
      emit (Jmp out);
      emit (Label handler);
      emit (Catch k);
      let s = slot () in
      emit (Set s);
      (* no clause matches: raised again *)
      match_cases env s cases false (fun () -> emit (Get s); emit Raise);
      emit (Label out)
  | While (c, b) ->
      let top = label () and out = label () in
      emit (Label top); value env c; emit (Jz out); value env b; emit Drop;
      emit (Jmp top); emit (Label out); emit (Imm (tagged 0))
  | For (x, a, b, up, body) ->
      value env a;
      let i = slot () in
      emit (Set i);
      value env b;
      let lim = slot () in
      emit (Set lim);
      let top = label () and out = label () in
      emit (Label top);
      emit (Get lim); emit (Get i); emit (Op (Cmp (if up then Gt else Lt)));
      emit (Jnz out);
      value ((x, Loc (Slot i, None)) :: env) body;
      emit Drop;
      emit (Imm (tagged 1)); emit (Get i); emit (Op (if up then Add else Sub));
      emit (Set i);
      emit (Jmp top);
      emit (Label out);
      emit (Imm (tagged 0))

(* e as a function's last: its value returned, or a call made a jump *)
(* A block of the fields given in their order, computed right to left
 * (ocamlopt's order): each on the stack of registers, then allocated
 * and filled. Past 11 fields there are not the registers: the block
 * allocated first, blank, kept in a slot, each field stored in it as
 * it is computed (a process of tiny-kernel's, 12) *)
and fields_block fields =
  let n = List.length fields in
  if n <= 11 then (List.iter (fun f -> f ()) (List.rev fields); emit (Alloc (0, n)))
  else begin
    emit (Blank (0, n));
    let s = slot () in
    emit (Set s);
    List.iteri (fun k f ->
      let k = n - 1 - k in
      f (); emit (Get s); emit (SetField k)) (List.rev fields);
    emit (Get s)
  end

and tail env e =
  match e with
  | App (f, args) -> if not (app env f args true) then emit Ret
  | Let _ | Match _ | If _ | Seq _ -> control env e true
  | _ -> value env e; emit Ret

and control env e tl =
  let k env e = if tl then tail env e else value env e in
  match e with
  | Seq (a, b) -> value env a; emit Drop; k env b
  | If (c, a, b) ->
      let other = label () in
      value env c;
      emit (Jz other);
      k env a;
      if tl then (emit (Label other); k env b)
      else (
        let out = label () in
        emit (Jmp out); emit (Label other); k env b; emit (Label out))
  | Let (r, bs, body) -> k (bind env r bs) body
  | Match (e, cases) ->
      value env e;
      let s = slot () in
      emit (Set s);
      match_cases env s cases tl match_failure
  | _ -> invalid_arg "control"

(* the clauses in order, each tests then its body; after an irrefutable
 * one, nothing *)
and match_cases env s cases tl on_fail =
  let out = label () in
  let rec go = function
    | [] -> on_fail ()
    | (p, g, body) :: rest ->
        let fail = label () in
        let env = test env s p fail in
        Option.iter (fun g -> value env g; emit (Jz fail)) g;
        if tl then tail env body else (value env body; emit (Jmp out));
        if refutable p || g <> None then (emit (Label fail); go rest)
  in
  go cases;
  if not tl then emit (Label out)

and var env x =
  match lookup env x with
  | Loc (Slot s, _) -> emit (Get s)
  | Loc (Env j, _) -> emit (Get 0); emit (Field (2 + j))
  | Loc (Glob (t, g), _) -> emit (GetG (t, g))
  | Loc (Static sym, _) -> emit (Addr (sym, 8))
  | Ext (_, n) ->
      (* a primitive as a value: the function that applies it *)
      let xs = List.init n (fun i -> Printf.sprintf "%%e%d" i) in
      value env (Fun (xs, App (var_ x, List.map var_ xs)))

and var_ x = Var (x, ref (tcon "?"))

(* f args: a primitive, a known function's code called with its
 * arguments, or the closure applied to one at a time; whether it ended
 * in a tail call *)
and app env f args tl =
  let m = List.length args in
  let rest k =
    let n = m - k in
    for i = 1 to n do emit (Call (Code 0, 1, tl && i = n)) done;
    tl && n > 0
  in
  let args_in k =
    let first = List.filteri (fun i _ -> i < k) args
    and later = List.filteri (fun i _ -> i >= k) args in
    List.iter (value env) (List.rev later);
    List.iter (value env) (List.rev first)
  in
  match f with
  | Var (x, ty) -> (
      match lookup env x with
      | Ext (p, n) when m >= n -> args_in n; prim p n !ty; rest n
      | Loc (_, Some (lab, n)) when m >= n ->
          args_in n;
          var env x;
          emit (Call (Direct lab, n, tl && m = n));
          if m = n then tl else rest n
      | _ -> args_in m; value env f; rest 0)
  | _ -> args_in m; value env f; rest 0

(* let: the values in env, then their names *)
and bind env r bs =
  if r then bind_rec env bs
  else
    List.concat_map (fun (p, e) ->
      match p, e with
      | PVar x, Fun (xs, b) -> (
          match closure env x xs b with
          | Closure_static (sym, lab, n) ->
              [ x, Loc (Static sym, Some (lab, n)) ]
          | Closure_pushed (lab, n) ->
              let s = slot () in
              emit (Set s);
              [ x, Loc (Slot s, Some (lab, n)) ])
      | PAny, _ -> value env e; emit Drop; []
      | _ ->
          value env e; let s = slot () in emit (Set s); irrefutably s p) bs
    @ env

and irrefutably s p =
  if not (refutable p) then test [] s p 0
  else begin
    let fail = label () and ok = label () in
    let bs = test [] s p fail in
    emit (Jmp ok); emit (Label fail); match_failure (); emit (Label ok);
    bs
  end

(* a function: its code compiled later; its closure static without
 * free variables, else allocated *)
and closure env name xs b =
  let lab = fun_label name and n = List.length xs in
  let names = free [] (Fun (xs, b)) [] in
  let fvs = captured env names in
  let benv = body_env env names fvs in
  enqueue (fun () -> compile_fun lab xs benv b);
  if fvs = [] then Closure_static (static_closure lab n, lab, n)
  else begin
    alloc_closure env lab n fvs;
    Closure_pushed (lab, n)
  end

(* (more than eight names: the block made blank, then each field set
 * through a slot of the frame, so that the names are not all in
 * registers at once; old: always on the stack, and a closure of ten
 * names too deep, tiny-db's parse) *)
and alloc_closure env lab n fvs =
  if List.length fvs <= 8 then begin
    List.iter (var env) (List.rev fvs);
    emit (Addr (lab, 0));
    emit (Addr (entry n lab, 0));
    emit (Alloc (closure_tag, 2 + List.length fvs))
  end
  else begin
    let s = slot () in
    let field k push = push (); emit (Get s); emit (SetField k) in
    emit (Blank (closure_tag, 2 + List.length fvs));
    emit (Set s);
    field 0 (fun () -> emit (Addr (entry n lab, 0)));
    field 1 (fun () -> emit (Addr (lab, 0)));
    List.iteri (fun j y -> field (2 + j) (fun () -> var env y)) fvs;
    emit (Get s)
  end

(* let rec: static if the functions need nothing but each other; else
 * their closures allocated, then those that name a later one patched *)
and bind_rec env bs =
  let fs =
    List.map
      (function
        | PVar x, Fun (xs, b) -> x, xs, b
        | _ -> error "let rec: only functions")
      bs
  in
  let labs = List.map (fun (x, xs, _) -> fun_label x, List.length xs) fs in
  let statics =
    List.map2
      (fun (x, _, _) (lab, n) ->
        x, Loc (Static (closure_sym lab), Some (lab, n)))
      fs labs
    @ env
  in
  let namess = List.map (fun (_, xs, b) -> free [] (Fun (xs, b)) []) fs in
  if List.for_all (fun names -> captured statics names = []) namess then begin
    List.iter2 (fun ((_, xs, b), names) (lab, n) ->
      ignore (static_closure lab n);
      let benv = body_env statics names [] in
      enqueue (fun () -> compile_fun lab xs benv b)) (List.combine fs namess) labs;
    statics
  end
  else begin
    let slots = List.map (fun _ -> slot ()) fs in
    let env =
      List.map2 (fun (x, _, _) ((lab, n), s) -> x, Loc (Slot s, Some (lab, n)))
        fs (List.combine labs slots)
      @ env
    in
    let names = List.map (fun (x, _, _) -> x) fs in
    let fvss = List.map (captured env) namess in
    List.iteri (fun i ((_, xs, b), fvs) ->
      let lab, n = List.nth labs i in
      let benv = body_env env (List.nth namess i) fvs in
      enqueue (fun () -> compile_fun lab xs benv b);
      alloc_closure env lab n fvs;
      emit (Set (List.nth slots i))) (List.combine fs fvss);
    List.iteri (fun i fvs ->
      List.iteri (fun j y ->
        let rec index k = function
          | [] -> None
          | z :: l -> if z = y then Some k else index (k + 1) l in
        match index 0 names with
        | Some m when m >= i ->
            emit (Get (List.nth slots m));
            emit (Get (List.nth slots i));
            emit (SetField (2 + j))
        | _ -> ()) fvs) fvss;
    env
  end

and compile_fun lab xs benv b =
  cur := { code = []; nslots = 1 + List.length xs; ntries = 0 };
  let env =
    List.rev (List.mapi (fun i x -> x, Loc (Slot (i + 1), None)) xs) @ benv in
  tail env b;
  machine lab (List.length xs) (!cur).nslots (List.rev (!cur).code)

(* ml_curry<n>_<k>: a closure of arity n given its k+1-th argument; a
 * block [the next one; the closure; the k arguments...], or the call *)
let curry_fun n k =
  cur := { code = []; nslots = 2; ntries = 0 };
  emit (Get 1);
  for i = k downto 1 do emit (Get 0); emit (Field (1 + i)) done;
  emit (Get 0);
  if k > 0 then emit (Field 1);
  if k < n - 1 then (
    emit (Addr (curry n (k + 1), 0));
    emit (Alloc (closure_tag, k + 3));
    emit Ret)
  else emit (Call (Code 1, n, true));
  machine (curry n k) 1 (!cur).nslots (List.rev (!cur).code)

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

(* A unit: its toplevel in <unit>.init, its names that are not static
 * (a value computed, a closure allocated) in its globals' table,
 * <unit>.globals, the collector's roots. What nothing uses is left out
 * by tiny-linker, piece by piece (a function, a static block): a
 * function of the toplevel has no free variable, so its closure is
 * static and the init names it not (old: prune, the program's
 * toplevel lets that nothing used dropped before the code was made,
 * when a program was compiled whole: a library cost a program only
 * what it called, which the link's pieces now do) *)
let compile_unit env (items : (item * int) list) =
  cur := { code = []; nslots = 1; ntries = 0 };
  arities := [];
  let table = !unit_name ^ ".globals" and nglobals = ref 0 in
  let rec arity = function TE ("->", [ _; r ]) -> 1 + arity r | _ -> 0 in
  let env, defs = List.fold_left (fun (env, defs) (it, l) ->
    try
      match it with
      | IOpen u -> opened globals u; env, defs
      | IExt (x, t, p) ->
          let b = Ext (p, arity t) in
          add_name globals x b;
          env, (x, b) :: defs
      | IExn c ->
          block (exn_id c) (header 1 0) [ DVal (static_string c) ];
          if (find_con c).arity = 0 then
            block (exn_const c) (header 1 0) [ DVal (exn_id c) ];
          env, defs
      | ILet (r, bs) ->
          (* (the names it adds, in the table: old, the env's first
           * names, counted) *)
          let added = List.map (function
            | x, Loc (Slot s, k) ->
                emit (Get s);
                emit (SetG (table, !nglobals));
                incr nglobals;
                x, Loc (Glob (table, !nglobals - 1), k)
            | b -> b) (bind env r bs) in
          List.iter (fun (x, b) -> add_name globals x b) (List.rev added);
          env, added @ defs
    with Failure m -> error (Printf.sprintf "line %d: %s" l m)) (env, []) items in
  emit (Imm (tagged 0));
  emit Ret;
  machine (!unit_name ^ ".init") 0 (!cur).nslots (List.rev (!cur).code);
  let rec drain () =
    match dequeue () with Some f -> f (); drain () | None -> () in
  drain ();
  env, defs, !nglobals

(* The program's main: ml_init, each unit's init in their order, in a
 * handler that prints an uncaught exception; the curry functions the
 * units need; the globals' tables one after the other, ml_globals, and
 * their count, ml_nglobals (what TinyMLRuntime/core.c scans) *)
let compile_main (units : (string * int) list) needed =
  unit_name := "ml";
  cur := { code = []; nslots = 1; ntries = 1 };
  let handler = label () in
  emit (TryEnter (0, handler));
  List.iter (fun (u, _) ->
      emit (Imm (tagged 0));
      emit (Call (Direct (u ^ ".init"), 0, false));
      emit Drop)
    units;
  emit (TryExit 0);
  emit (Imm (tagged 0));
  emit Ret;
  emit (Label handler);
  emit (Catch 0);
  emit (CallC ("ml_uncaught", 1));
  emit Ret;
  machine "ml_init" 0 (!cur).nslots (List.rev (!cur).code);
  List.iter (fun n -> for k = 0 to n - 1 do curry_fun n k done)
    (List.sort_uniq compare needed);
  let total = List.fold_left (fun t (_, n) -> t + n) 0 units in
  words "ml_nglobals" [ DNum (string_of_int total) ];
  Buffer.add_string data "\t.piece\nml_globals:\n";
  List.iter (fun (u, n) ->
      Buffer.add_string data
        (u ^ ".globals:\n\t.space\t" ^ string_of_int (4 * n) ^ "\n"))
    units;
  if total = 0 then Buffer.add_string data "\t.space\t4\n"

(*****************************************************************************)
(* Interfaces *)
(*****************************************************************************)

(* A unit's interface, M.tmi, what a unit compiled after it reads (as
 * OCaml's .cmi): its globals' count and the curry functions it needs;
 * the types, constructors, labels and abbreviations it added; each of
 * its names, where its value is (a static closure and its code, a
 * global, a primitive) and its type, M.mli's when there is one. A
 * record, Marshal's bytes (OCaml's on the host, the runtime's on
 * tiny-kernel: the same), a type in it as a type expression, its
 * variables 'v<number>, read as a type anew (of_texpr), as the text
 * was.
 * (old: a line each, printed and parsed again: half of a small unit's
 * compile was reading the interfaces) *)
type interface = {
  iname : string;
  iglobals : int;
  icurry : int list;
  icons : (string * kind * int * int * int * texpr) list;
  ilabels : (string * string * int * bool * string list * texpr) list;
  iabbrevs : (string * (string list * texpr)) list;
  iforgotten : string list;
  ivals : (string * binding * texpr) list;
}

(* a type as its expression: what is linked followed, a variable by its
 * number *)
let rec texpr_of_ty t =
  match repr t with
  | TVar { contents = Unbound (n, _) } -> TEVar ("v" ^ string_of_int n)
  | TCon (c, ts) -> TE (c, List.map texpr_of_ty ts)
  | TVar _ -> TE ("?", [])

(* what the program's tables held before a unit: its interface has only
 * what the unit added, as OCaml's .cmi (old: the whole program's so far,
 * each unit's .tmi repeating every one before it, all read again by
 * each unit after: 310 KB of interfaces for tiny-kernel's programs) *)
let snapshot () =
  let c = Hashtbl.copy cons and l = Hashtbl.copy record_labels
  and a = !abbreviations and f = !forgotten in
  (fun k ci ->
    match Hashtbl.find_opt c k with Some ci' -> ci' == ci | None -> false),
  (fun k li -> List.memq li (Hashtbl.find_all l k)),
  (fun ab -> List.memq ab a),
  (fun t -> List.mem t f)

let write_interface (old_con, old_label, old_abbrev, old_forgotten)
    (exports : (string * binding) list) types nglobals =
  (* the tables by their names, a label's records the latest first, as
   * the table has them (old: Hashtbl.iter's order, which is OCaml's
   * or TinyLibCore's: an interface was not the same from the two
   * builds of tiny-ml) *)
  let names tbl =
    List.sort_uniq compare (Hashtbl.fold (fun k _ acc -> k :: acc) tbl []) in
  let icons = List.filter_map (fun c ->
    let ci = Hashtbl.find cons c in
    if old_con c ci then None
    else
      Some (c, ci.kind, ci.arity, ci.nconst, ci.nblock, texpr_of_ty ci.scheme))
    (names cons) in
  let ilabels = List.concat_map (fun l -> List.filter_map (fun li ->
    if old_label l li then None
    else
      Some (l, li.lrec, li.idx, li.mut, li.lnames, texpr_of_ty li.lscheme))
    (Hashtbl.find_all record_labels l)) (names record_labels) in
  let ivals = List.filter_map (fun (x, bd) ->
    match List.assoc_opt x types, bd with
    | Some t, (Loc ((Static _ | Glob _), _) | Ext _) ->
        Some (qualify !unit_name x, bd, texpr_of_ty t)
    | _ -> None) exports in
  Marshal.to_string
    { iname = !unit_name; iglobals = nglobals; icurry = !arities; icons = icons;
      ilabels = ilabels;
      iabbrevs =
        List.filter (fun a -> not (old_abbrev a)) (List.rev !abbreviations);
      iforgotten = List.filter (fun t -> not (old_forgotten t)) !forgotten;
      ivals = ivals }
    (* (No_sharing: which of two equal names is the same string depends
     * on a table's order, OCaml's or TinyLibCore's; shared, the host's
     * and tiny-kernel's interfaces differed in 3 of the system's 40) *)
    [ Marshal.No_sharing ]

(* an interface read: its types the program's, its names in the tables
 * (globals, tglobals); its unit's name, globals and curry functions *)
let read_interface text env tenv =
  if String.length text < 4 || String.sub text 0 4 <> "\132\149\166\190" then
    error "not an interface of tiny-ml's";
  let (i : interface) = Marshal.from_string text 0 in
  let ty te = of_texpr (ref []) te in
  known_units := i.iname :: !known_units;
  List.iter (fun (c, kind, arity, nconst, nblock, te) ->
      Hashtbl.replace cons c
        { kind = kind; arity = arity; nconst = nconst; nblock = nblock;
          scheme = ty te })
    i.icons;
  List.iter (fun (l, r, idx, mut, lnames, te) ->
    let others =
      List.filter (fun li -> li.lrec <> r) (Hashtbl.find_all record_labels l) in
    while Hashtbl.mem record_labels l do Hashtbl.remove record_labels l done;
    List.iter (Hashtbl.add record_labels l) (List.rev others);
    Hashtbl.add record_labels l
      { lrec = r; idx = idx; mut = mut; lnames = lnames; lscheme = ty te })
    i.ilabels;
  List.iter (fun (t, (ps, te)) ->
    abbreviations :=
      (t, (ps, te))
      :: List.filter
           (fun (t', (ps', _)) -> t' <> t || List.length ps' <> List.length ps)
           !abbreviations)
    i.iabbrevs;
  List.iter (fun t ->
      if not (List.mem t !forgotten) then forgotten := t :: !forgotten)
    i.iforgotten;
  (* (a val's name is M.x already; Stdlib's x too) *)
  let n = String.length i.iname in
  List.iter (fun (x, b, te) ->
    let t = ty te in
    List.iter (fun x -> Hashtbl.replace globals x b; Hashtbl.replace tglobals x t)
      (if implicit i.iname then
         [ x; String.sub x (n + 1) (String.length x - n - 1) ]
       else [ x ]))
    i.ivals;
  env, tenv, (i.iname, i.iglobals), i.icurry

(* M.mli's vals, their types in place of what M.ml's inferred: its
 * types and exceptions are M.ml's too, and skipped *)
let mli_types text =
  toks := lex text; pos := 0;
  let starts () =
    match peek () with
    | LID "val" | KW ("type" | "exception" | "external") | EOF -> true
    | _ -> false
  in
  let rec go acc =
    match peek () with
    | EOF -> acc
    | LID "val" ->
        advance ();
        let x =
          match peek () with
          | LID x -> advance (); x
          | KW "(" ->
              advance ();
              let o = (match peek () with KW o -> advance (); o | _ -> fail ()) in
              expect (KW ")");
              o
          | _ -> fail ()
        in
        expect (KW ":");
        let t = ty () in
        go ((x, of_texpr (ref []) t) :: acc)
    | _ -> advance (); while not (starts ()) do advance () done; go acc in
  go []

(* ml_start called by C (the value stack's base at 0(sp)), ml_init's
 * closure slot 1, a unit (not what r13 held, which the collector would
 * scan); ml_raise: to the latest handler, the exception in r13 *)
let start =
  String.concat "\n\t"
    [ "ml_start:"; "ldw\tr12, 0(sp)"; "li\tr13, 1"; "la\tr11, ml_init";
      "jalr\tzero, 0(r11)";
      "ml_raise:\n\tla\tr1, ml_handler"; "ldw\tr1, 0(r1)"; "ldw\tsp, 0(r1)";
      "ldw\tr12, 4(r1)"; "ldw\tr2, 12(r1)"; "la\tr3, ml_handler";
      "stw\tr2, 0(r3)"; "ldw\tr2, 8(r1)"; "jalr\tzero, 0(r2)" ]
  ^ "\n"

let parse s = toks := lex s; pos := 0; items ()

(* a file's unit: its name without the directory and the extension,
 * capitalized, as OCaml's module *)
let unit_of f =
  String.capitalize_ascii (Filename.remove_extension (Filename.basename f))

(* the standard library, TinyLibCore/'s modules in their order, the
 * first units of every program: each compiled once, by tiny-ml -c
 * -nostdlib after the ones before it, and read as interfaces from a
 * directory, /lib/ml on tiny-kernel (-L another), its objects
 * linked as any unit's.
 * (old: their text the compiler's, TinyMLPrelude.ml made of them by the
 * build, compiled again at each run: a unit of one line took 47 s on
 * tiny-kernel, and every program's main the library's code, 420 KB of
 * assembly;
 * older: the prelude, TinyLibCore.ml, one unit, its List.map a name
 * with a dot) *)
let library =
  [ "Stdlib"; "Char"; "Seq"; "List"; "String"; "Bytes"; "Array"; "Option";
    "Int64"; "Filename"; "Buffer"; "Printf"; "Marshal"; "Hashtbl"; "Common";
    "Sha1" ]

(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

let main
    (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    =
  let output = ref "" and file = ref "" and files = ref []
  and separate = ref false and lib = ref (Some "/lib/ml") in
  let rec args l = match l with
    | "-o" :: o :: r -> output := o; args r
    | "-c" :: r -> separate := true; args r
    | "-L" :: d :: r -> lib := Some d; args r
    | "-nostdlib" :: r -> lib := None; args r
    | f :: r -> files := f :: !files; args r
    | [] -> ()
  in
  let argl = List.tl (TinyLibSystem.argv caps) in
  args argl;
  let files = List.rev !files in
  let read f =
    file := f;
    try TinyLibSystem.read_file caps f with Failure m -> raise (File_error m) in
  let tmis = List.filter (fun f -> Filename.check_suffix f ".tmi") files
  and mls = List.filter (fun f -> Filename.check_suffix f ".ml") files in
  if List.mem "-h" argl || List.mem "--help" argl then
    (TinyLibSystem.print caps help; 0)
  else if List.length mls + List.length tmis <> List.length files || files = []
          || (!separate && List.length mls <> 1) then
    (TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); 2)
  else
  let write f text =
    let fd =
      try TinyLibSystem.open_out caps f with Failure m -> raise (File_error m)
    in
    TinyLibSystem.write fd text; TinyLibSystem.close fd in
  try
    (* the interfaces read, in their order: the library's, then the
     * units before this one *)
    let lib =
      match !lib with
      | Some d -> List.map (fun m -> d ^ "/" ^ m ^ ".tmi") library
      | None -> []
    in
    let env, tenv, units, needed =
      List.fold_left (fun (env, tenv, units, needed) f ->
          let env, tenv, u, n = read_interface (read f) env tenv in
          env, tenv, units @ [ u ], needed @ n)
        ([], [], [], []) (lib @ tmis) in
    if !separate then begin
      (* one unit: its object and its interface *)
      let f = List.hd mls in
      Buffer.clear text; Buffer.clear data;
      unit_name := unit_of f;
      known_units := !unit_name :: !known_units;
      (* (before the parse: a type's constructors are the parser's) *)
      let old = snapshot () in
      let items = parse (read f) in
      let _, tdefs = type_unit tenv items in
      let _, exports, n = compile_unit env items in
      let mli = Filename.remove_extension f ^ ".mli" in
      (* (old: Sys.file_exists mli, then read) *)
      let mli_text =
        try Some (TinyLibSystem.read_file caps mli) with Failure _ -> None in
      let types =
        (match mli_text with Some t -> file := mli; mli_types t | None -> [])
        @ tdefs in
      let out =
        if !output = "" then
          Filename.remove_extension (Filename.basename f) ^ ".tm"
        else !output in
      write out (Buffer.contents text ^ Buffer.contents data);
      write (Filename.remove_extension out ^ ".tmi")
        (write_interface old exports types n)
    end else begin
      (* the files one after the other, a unit each, then the main *)
      let _, _, units, needed =
        List.fold_left (fun (env, tenv, units, needed) f ->
          unit_name := unit_of f;
          known_units := !unit_name :: !known_units;
          let items = parse (read f) in
          let _, tdefs = type_unit tenv items in
          let _, defs, n = compile_unit env items in
          unit_done ();
          export globals !unit_name defs env,
          export tglobals !unit_name tdefs tenv,
          units @ [ (!unit_name, n) ],
          needed @ !arities)
          (env, tenv, units, needed) mls in
      compile_main units needed;
      let asm = start ^ Buffer.contents text ^ Buffer.contents data in
      if !output = "" then TinyLibSystem.print caps asm else write !output asm
    end;
    0
  with
  | Failure m -> TinyLibSystem.eprint caps (!file ^ ": " ^ m ^ "\n"); 1
  | File_error m -> TinyLibSystem.eprint caps (Printf.sprintf "tiny-ml: %s\n" m); 1

let () = TinyLibSystem.main "tiny-ml" main
