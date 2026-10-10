(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
open Scheme

(* See Scheme_secd.mli *)

(* the control's items *)
type item =
  | Expr of expr
  | Ap of int * Sexpr.span   (* the procedure and n arguments are on the stack *)
  | Sel of expr * expr       (* the test's value is on the stack *)
  | Pop                      (* a begin's value that is not its last *)
  | Assign of loc
  | Def of string

type frame = { fs : Scheme.t list; fe : env; fc : item list }

(* call/cc's: the four registers *)
type kept = { ks : Scheme.t list; ke : env; kc : item list; kd : frame list; kdepth : int }

type t = {
  mutable s : Scheme.t list;
  mutable e : env;
  mutable c : item list;
  mutable d : frame list;
  mutable depth : int;
  mutable deep : int;
  mutable store : Scheme.t array;
  mutable next : loc;
  globals : (string, loc) Hashtbl.t;
  conts : (int, kept) Hashtbl.t;
  mutable output : string list;
  mutable seed : int;
  mutable steps : int;
  tail : bool;
}

exception Fail of string * Sexpr.span

(*****************************************************************************)
(* The store *)
(*****************************************************************************)

let alloc (m : t) (v : Scheme.t) : loc =
  if m.next >= Array.length m.store then m.store <- Array.append m.store (Array.make (Array.length m.store) Void);
  m.store.(m.next) <- v;
  m.next <- m.next + 1;
  m.next - 1

let locate (m : t) (x : string) (span : Sexpr.span) : loc =
  match List.assoc_opt x m.e with
  | Some l -> l
  | None -> (
      match Hashtbl.find_opt m.globals x with
      | Some l -> l
      | None -> raise (Fail ("reference to an undefined identifier: " ^ x, span)))

let define (m : t) (x : string) (v : Scheme.t) : unit =
  match Hashtbl.find_opt m.globals x with
  | Some l -> m.store.(l) <- v
  | None -> Hashtbl.replace m.globals x (alloc m v)

(*****************************************************************************)
(* Apply *)
(*****************************************************************************)

let push (m : t) (v : Scheme.t) : unit = m.s <- v :: m.s

let pop (m : t) : Scheme.t =
  match m.s with
  | v :: rest -> m.s <- rest; v
  | [] -> Void

let const (v : Scheme.t) : item = Expr { desc = Quote v; span = Sexpr.nowhere }

(* a body: each expression's value dropped but the last's *)
let rec body_items (body : expr list) : item list =
  match body with
  | [] -> [ const Void ]
  | [ e ] -> [ Expr e ]
  | e :: rest -> Expr e :: Pop :: body_items rest

(* (the first machine's text) *)
let arity_error (name : string) (want : string) (args : Scheme.t list) (span : Sexpr.span) : unit =
  let name = if name = "" then "#<procedure>" else name in
  let given = if args = [] then "" else ": " ^ String.concat " " (List.map (print Write) args) in
  raise (Fail (Printf.sprintf "%s: expects %s, given %d%s" name want (List.length args) given, span))

(* a continuation as a value: its number, in the one constructor
 * Scheme has for one (the first machine's frames are not this one's) *)
let cont_value (n : int) : Scheme.t = Proc (Cont (K_set (n, Halt)))

let rec apply (m : t) (f : Scheme.t) (args : Scheme.t list) (span : Sexpr.span) : unit =
  match f with
  | Proc (Closure (l, env)) ->
      let n = List.length l.params in
      if (l.rest = None && List.length args <> n) || List.length args < n then
        arity_error l.name
          (Printf.sprintf "%s%d argument%s" (if l.rest = None then "" else "at least ") n (if n = 1 then "" else "s"))
          args span;
      let rec bind (env : env) (params : string list) (args : Scheme.t list) : env =
        match (params, args) with
        | p :: ps, a :: rest -> bind ((p, alloc m a) :: env) ps rest
        | _, rest -> ( match l.rest with Some r -> (r, alloc m (list rest)) :: env | None -> env) in
      let env = bind env l.params args in
      let env = List.fold_left (fun (env : env) (x : string) -> (x, alloc m Void) :: env) env l.locals in
      (* the caller's registers, for the return; not when it has nothing
       * left to do with them (a call in tail position) *)
      if not (m.tail && m.c = []) then begin
        m.d <- { fs = m.s; fe = m.e; fc = m.c } :: m.d;
        m.depth <- m.depth + 1;
        if m.depth > m.deep then m.deep <- m.depth
      end;
      m.s <- [];
      m.e <- env;
      m.c <- body_items l.body
  | Proc (Cont (K_set (n, _))) -> (
      match (args, Hashtbl.find_opt m.conts n) with
      | [ v ], Some k ->
          m.s <- v :: k.ks;
          m.e <- k.ke;
          m.c <- k.kc;
          m.d <- k.kd;
          m.depth <- k.kdepth
      | _ -> arity_error "continuation" "1 argument" args span)
  | Proc (Make (name, n)) ->
      if List.length args <> n then arity_error ("make-" ^ name) (Printf.sprintf "%d arguments" n) args span
      else push m (Struct (name, args))
  | Proc (Get (name, i, field)) -> (
      match args with
      | [ Struct (s, fields) ] when s = name -> push m (List.nth fields i)
      | [ v ] ->
          raise (Fail (Printf.sprintf "%s-%s: expects argument of type <struct:%s>; given %s" name field name (print Write v), span))
      | _ -> arity_error (name ^ "-" ^ field) "1 argument" args span)
  | Proc (Is name) -> (
      match args with
      | [ v ] -> push m (Bool (match v with Struct (s, _) -> s = name | _ -> false))
      | _ -> arity_error (name ^ "?") "1 argument" args span)
  | Proc (Prim name) -> prim m name args span
  | _ ->
      raise
        (Fail
           ( Printf.sprintf "procedure application: expected procedure, given: %s%s" (print Write f)
               (if args = [] then " (no arguments)" else "; arguments were: " ^ String.concat " " (List.map (print Write) args)),
             span ))

(* the built-ins that need the machine, then the others *)
and prim (m : t) (name : string) (args : Scheme.t list) (span : Sexpr.span) : unit =
  match (name, args) with
  | ("call/cc" | "call-with-current-continuation"), [ f ] ->
      let n = Hashtbl.length m.conts in
      Hashtbl.replace m.conts n { ks = m.s; ke = m.e; kc = m.c; kd = m.d; kdepth = m.depth };
      apply m f [ cont_value n ] span
  | "apply", f :: rest when rest <> [] -> (
      let firsts = List.rev (List.tl (List.rev rest)) and last = List.hd (List.rev rest) in
      match to_list last with
      | Some xs -> apply m f (firsts @ xs) span
      | None -> raise (Fail ("apply: expects a list as its last argument; given " ^ print Write last, span)))
  | "display", [ v ] -> m.output <- display v :: m.output; push m Void
  | "write", [ v ] -> m.output <- print Write v :: m.output; push m Void
  | "newline", [] -> m.output <- "\n" :: m.output; push m Void
  | "random", _ -> (
      m.seed <- m.seed * 48271 mod 2147483647;
      match args with
      | [ Int n ] when n > 0 -> push m (Int (m.seed mod n))
      | [] -> push m (Real (float_of_int m.seed /. 2147483647.))
      | _ -> raise (Fail ("random: expects argument of type <positive integer>", span)))
  | ("call/cc" | "call-with-current-continuation" | "apply" | "display" | "write" | "newline"), _ ->
      arity_error name "other arguments" args span
  | _ -> (
      match Scheme_prims.apply name args with
      | v -> push m v
      | exception Scheme_prims.Error msg -> raise (Fail (msg, span)))

let specials : string list = [ "call/cc"; "call-with-current-continuation"; "apply"; "display"; "write"; "newline"; "random" ]

(*****************************************************************************)
(* A step *)
(*****************************************************************************)

(* false: nothing left, the value is on the stack *)
let step (m : t) : bool =
  m.steps <- m.steps + 1;
  match m.c with
  | [] -> (
      match m.d with
      | [] -> false
      | f :: rest ->
          (* the return: the caller's registers, the result on its stack *)
          m.s <- pop m :: f.fs;
          m.e <- f.fe;
          m.c <- f.fc;
          m.d <- rest;
          m.depth <- m.depth - 1;
          true)
  | item :: c ->
      m.c <- c;
      (match item with
       | Expr x -> (
           match x.desc with
           | Quote v -> push m v
           | Var name -> push m m.store.(locate m name x.span)
           | Lambda l -> push m (Proc (Closure (l, m.e)))
           | If (test, a, b) -> m.c <- Expr test :: Sel (a, b) :: c
           | Set (name, e1) -> m.c <- Expr e1 :: Assign (locate m name x.span) :: c
           | App (f, args) ->
               m.c <- Expr f :: List.map (fun (a : expr) -> Expr a) args @ (Ap (List.length args, x.span) :: c)
           | Seq body -> m.c <- body_items body @ c
           | Define (name, e1) -> m.c <- Expr e1 :: Def name :: c
           | Define_struct (name, fields) ->
               define m ("make-" ^ name) (Proc (Make (name, List.length fields)));
               define m (name ^ "?") (Proc (Is name));
               List.iteri (fun (i : int) (f : string) -> define m (name ^ "-" ^ f) (Proc (Get (name, i, f)))) fields;
               push m Void
           | Big_bang _ -> raise (Fail ("big-bang: a world wants the first machine", x.span)))
       | Sel (a, b) -> m.c <- Expr (if truthy (pop m) then a else b) :: c
       | Pop -> ignore (pop m)
       | Assign l ->
           m.store.(l) <- pop m;
           push m Void
       | Def name ->
           (* a lambda defined is named by its definition *)
           let v = match pop m with Proc (Closure (l, env)) when l.name = "" -> Proc (Closure ({ l with name }, env)) | v -> v in
           define m name v;
           push m Void
       | Ap (n, span) ->
           let rec take (n : int) (acc : Scheme.t list) : Scheme.t list = if n = 0 then acc else take (n - 1) (pop m :: acc) in
           let args = take n [] in
           apply m (pop m) args span);
      true

(*****************************************************************************)
(* Running *)
(*****************************************************************************)

let start (m : t) (e : expr) : unit =
  m.s <- [];
  m.e <- [];
  m.c <- [ Expr e ];
  m.d <- [];
  m.depth <- 0

let run ~(fuel : int) (m : t) : Scheme_eval.outcome =
  let rec go (n : int) : Scheme_eval.outcome =
    if m.c = [] && m.d = [] then Scheme_eval.Done (match m.s with v :: _ -> v | [] -> Void)
    else if n = 0 then Scheme_eval.Running
    else
      match step m with
      | _ -> go (n - 1)
      | exception Fail (message, span) ->
          start m { desc = Quote Void; span };
          m.c <- [];
          Scheme_eval.Failed { message; at = Some span } in
  go fuel

let take_output (m : t) : string =
  let out = String.concat "" (List.rev m.output) in
  m.output <- [];
  out

let steps (m : t) : int = m.steps
let deepest (m : t) : int = m.deep

let create ~(tail : bool) : t =
  let m : t =
    { s = []; e = []; c = []; d = []; depth = 0; deep = 0; store = Array.make 1024 Void; next = 0;
      globals = Hashtbl.create 511; conts = Hashtbl.create 17; output = []; seed = 1; steps = 0; tail } in
  List.iter (fun (name : string) -> define m name (Proc (Prim name))) (Scheme_prims.names @ specials);
  List.iter
    (fun (x : Sexpr.t) ->
      start m (Scheme_syntax.top x);
      match run ~fuel:10_000_000 m with
      | Scheme_eval.Done _ -> ()
      | _ -> failwith "Scheme_prelude: not run by the SECD machine")
    (Sexpr_read.read_all Sexpr_read.Scheme Scheme_prelude.text);
  m.steps <- 0;
  m.deep <- 0;
  m

(*****************************************************************************)
(* The registers shown *)
(*****************************************************************************)

(* an expression as it was written, a lambda's body left out *)
let rec text (e : expr) : string =
  let all (es : expr list) : string = String.concat " " (List.map text es) in
  match e.desc with
  | Quote ((Sym _ | Pair _ | Nil) as v) -> "'" ^ print Write v
  | Quote v -> print Write v
  | Var x -> x
  | Lambda l -> "(lambda (" ^ String.concat " " l.params ^ ") ...)"
  | If (a, b, c) -> "(if " ^ all [ a; b; c ] ^ ")"
  | Set (x, e1) -> "(set! " ^ x ^ " " ^ text e1 ^ ")"
  | App (f, args) -> "(" ^ all (f :: args) ^ ")"
  | Seq body -> "(begin " ^ all body ^ ")"
  | Define (x, e1) -> "(define " ^ x ^ " " ^ text e1 ^ ")"
  | Define_struct (name, _) -> "(define-struct " ^ name ^ " ...)"
  | Big_bang _ -> "(big-bang ...)"

let show (m : t) : string =
  let or_dash (s : string) : string = if s = "" then "-" else s in
  let s = String.concat " " (List.map (print Write) m.s) in
  let e = String.concat " " (List.rev_map (fun ((x, l) : string * loc) -> x ^ "=" ^ print Write m.store.(l)) m.e) in
  let c =
    String.concat " "
      (List.map
         (fun (i : item) ->
           match i with
           | Expr x -> text x
           | Ap _ -> "ap"
           | Sel _ -> "sel"
           | Pop -> "pop"
           | Assign _ -> "assign"
           | Def x -> "define:" ^ x)
         m.c) in
  Printf.sprintf "S: %s | E: %s | C: %s | D: %d" (or_dash s) (or_dash e) (or_dash c) m.depth
