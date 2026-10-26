(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyC.mli *)

open Common

let usage = "usage: tiny-c [-ir] [-o out.tm] file.c"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

A tiny C compiler: a C file to TinyCPU's assembly, for tiny-cpu, with its own
libc; -ir prints its stack machine's code instead. A fact.c that includes
tiny/TinyCRuntime/libc.h and prints fact(10):
  L=tiny/TinyCRuntime; (cd $L && tiny-c -o libc.tm libc.c)
  tiny-c -o fact.tm fact.c
  for f in $L/start $L/udivmod $L/libc fact
  do tiny-assembler -o $f.o $f.tm; done
  tiny-linker -o fact $L/start.o $L/udivmod.o $L/libc.o fact.o
  tiny-cpu fact                            fact 10 = 3628800
  tiny-c -ir fact.c                        fact: param 0, load 4, imm 0, ...
An error names the file and the line: fact.c: line 3: expected ;
|}

(* (old: a format, Printf.ksprintf's: tiny-ml reads a format only where
 * it is written, Printf.sprintf at the call) *)
let error s = failwith s

(* the machine, TinyCPU, has words of 4 bytes: pointers too, and no
 * long long *)
let unit_name = ref ""  (* the file's name, its local names' prefix *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type ty =
  | Void
  | Int of int * bool                 (* bytes, signed *)
  | Ptr of ty
  | Arr of ty * int
  | Struct of sdef
  | Func of ty * ty list * bool       (* result, parameters, variadic *)

and sdef = {
  mutable fields : (string * ty * int) list;
  mutable ssize : int;
  mutable salign : int }

let int_t = Int (4, true) and long_t = Int (8, true) and char_t = Int (1, true)
(* an int's largest value (old: 0x7fffffffL, a literal tiny-ml does
 * not read) *)
let int_max = Int64.of_string "0x7fffffff"
let rec size = function
  | Void -> 1 | Int (n, _) -> n | Ptr _ | Func _ -> 4
  | Arr (t, n) -> n * size t | Struct s -> s.ssize
let rec align = function
  | Int (n, _) -> n | Arr (t, _) -> align t | Struct s -> s.salign | _ -> 4
let round n a = (n + a - 1) / a * a
let is_int = function Int _ -> true | _ -> false
let is_ptr = function Ptr _ -> true | _ -> false
let unsigned = function Int (_, s) -> not s | Ptr _ -> true | _ -> false

(* a declared long long refused (its values live in 32-bit registers);
 * the compiler's own long temporaries are 32 bits there *)
let rec no_vlong t =
  match t with
  | Int (8, _) -> error "long long: not on TinyCPU (a 32-bit machine)"
  | Arr (t, _) -> no_vlong t
  | Ptr t -> no_vlong t
  | Func (r, ps, _) -> no_vlong r; List.iter no_vlong ps
  | _ -> ()

(* a structure is itself: struct node { struct node *next; } *)
let rec same a b =
  match a, b with
  | Struct s, Struct t -> s == t
  | Ptr a, Ptr b -> same a b
  | Arr (a, n), Arr (b, m) -> n = m && same a b
  | Func (r, p, v), Func (s, q, w) ->
      v = w && same r s && List.length p = List.length q
      && List.for_all2 same p q
  | a, b -> a = b

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

(*****************************************************************************)
(* Expressions, typed as they are built *)
(*****************************************************************************)

(* the operators: an arithmetic one's value is of its operands' type,
 * a relation's an int; >> is logical, / % and the relations unsigned,
 * for an unsigned type *)
(* old: strings ("+", "<="): a misspelled operator was a runtime error,
 * and the machine's match over them needed a catch-all *)
type arith = Add | Sub | Mul | Div | Mod | And | Or | Xor | Shl | Shr
type rel = Lt | Gt | Le | Ge | Eq | Ne
type binop = A of arith | R of rel
type unop = Neg | Com

let binops = [ "+", A Add; "-", A Sub; "*", A Mul; "/", A Div; "%", A Mod;
               "&", A And; "|", A Or; "^", A Xor; "<<", A Shl;
               ">>", A Shr; "<", R Lt; ">", R Gt; "<=", R Le; ">=", R Ge;
               "==", R Eq; "!=", R Ne ]
let binop_name o = fst (List.find (fun (_, o') -> o' = o) binops)

(* x op= y's tokens *)
let asg_ops =
  List.filter_map (function s, A o -> Some (s ^ "=", o) | _ -> None) binops

(* where a variable is: a global's name in the assembly, a local's
 * offset below SP, a parameter's from FP *)
type place = Global of string | Local of int | Param of int

type expr = { d : desc; t : ty }

and desc =
  | Const of int64
  | Addr of place
  | Deref of expr          (* the object at an address: an lvalue *)
  | Cur                               (* in x op= y, x's value *)
  | Un of unop * expr
  | Bin of binop * expr * expr
      (* both operands of one type; a relation's value an int *)
  | Cond of expr * expr * expr        (* && || ! are made of it *)
  | Asg of expr * expr * bool
      (* an lvalue, its new value, which uses Cur *)
  | Apply of string * expr list       (* a call (old: Call, the stack machine's
                                       * name too: tiny-ml's constructors are
                                       * one name space) *)
  | ApplyPtr of expr * expr list      (* through a function's address *)
  | Conv of expr                      (* to t *)
  | Comma of expr * expr

let mk (d : desc) t = { d; t }
let num v t = mk (Const v) t

(* an array is its address, a value of a small integer an int *)
let rv (e : expr) =
  match e.t, e.d with
  | Arr (t, _), Deref a -> { a with t = Ptr t }
  | Func _, Deref a -> { a with t = Ptr e.t }
  | _ -> e

let conv (e : expr) t =
  match e.t, t, e.d with
  | a, b, _ when same a b -> e
  | Int _, Int (n, sg), Const v ->
      (* a constant converted now: truncated, extended *)
      let bits = 8 * n in
      let v =
        if bits = 64 then v
        else if sg then
          Int64.shift_right (Int64.shift_left v (64 - bits)) (64 - bits)
        else Int64.logand v (Int64.pred (Int64.shift_left Int64.one bits)) in
      num v t
  | (Ptr _ | Arr _), Ptr _, _ | Ptr _, Int (8, _), _ | Int (8, _), Ptr _, _ ->
      { e with t }
  | _ -> mk (Conv e) t

(* ANSI's promotion, which keeps the value: uchar and ushort become int,
 * as the host's cc, the tests' reference, does
 * (old: Int (4, s), Plan 9's, which keeps the sign: uint, as 7c, the
 * reference while tiny-c had an arm64 back end; TinyC_fuzz.py's
 * x2 <= -128, x2 a uchar 0, was then 1) *)
let promote = function Int (n, _) when n < 4 -> Int (4, true) | t -> t

(* the usual arithmetic conversions: the wider, unsigned if either is *)
let common a b =
  match promote a, promote b with
  | Int (n, s), Int (m, u) -> Int (max n m, s && u)
  | t, _ -> t

let scale (i : expr) t =
  if size t = 1 then conv i long_t
  else
    mk (Bin (A Mul, conv i long_t, num (Int64.of_int (size t)) long_t)) long_t

let rec binary op (a : expr) (b : expr) =
  let a = rv a and b = rv b in
  match op, a.t, b.t with
  | A (Add | Sub), Ptr t, Int _ -> mk (Bin (op, a, scale b t)) a.t
  | A Add, Int _, Ptr _ -> binary op b a
  | A Sub, Ptr t, Ptr _ ->
      mk (Bin (A Div, mk (Bin (op, conv a long_t, conv b long_t)) long_t,
               num (Int64.of_int (size t)) long_t)) long_t
  | R _, Ptr _, _ | R _, _, Ptr _ ->
      let t = if is_ptr a.t then a.t else b.t in
      mk (Bin (op, conv a t, conv b t)) int_t
  | R _, Int _, Int _ ->
      let t = common a.t b.t in mk (Bin (op, conv a t, conv b t)) int_t
  | A o, Int _, Int _ ->
      let t = if o = Shl || o = Shr then promote a.t else common a.t b.t in
      mk (Bin (op, conv a t, conv b t)) t
  | _ -> error ("bad operands for " ^ binop_name op)

let addr (e : expr) =
  match e.d with Deref a -> { a with t = Ptr e.t } | _ -> error "not an lvalue"
let deref (e : expr) =
  let e = rv e in
  match e.t with Ptr t -> mk (Deref e) t | _ -> error "not a pointer"

(* (old: ~cur, a label, which tiny-ml does not read) *)
let assign cur (l : expr) (r : expr) =
  match l.d with
  | Deref _ -> mk (Asg (l, conv (rv r) l.t, cur)) l.t
  | _ -> error "not an lvalue"

(* x op= y: the value computed from x's, loaded once *)
let asg_op o (l : expr) r = assign true l (binary (A o) (mk Cur l.t) r)

(* a variable, as an lvalue *)
let var p t = mk (Deref (mk (Addr p) (Ptr t))) t

(* a condition's value, 1 or 0; !, && and || as ?: of them *)
let truth c = mk (Cond (rv c, num Int64.one int_t, num Int64.zero int_t)) int_t
let lnot c = mk (Cond (rv c, num Int64.zero int_t, num Int64.one int_t)) int_t
let both a b = mk (Cond (rv a, truth b, num Int64.zero int_t)) int_t
let either a b = mk (Cond (rv a, num Int64.one int_t, truth b)) int_t

(*****************************************************************************)
(* Statements *)
(*****************************************************************************)

(* old: none, the parser emitted the stack machine's code as it read,
 * with break's and continue's targets on global stacks *)
type stmt =
  | Expr of expr
  | Block of stmt list
  | If of expr * stmt * stmt option
  | Do of stmt * expr
  | For of expr option * expr option * expr option * stmt   (* while too *)
  | Switch of expr * expr * stmt      (* its temporary, its value, its body *)
  | Case of int64 option              (* default: None *)
  | Break
  | Continue
  | Return of expr option

(*****************************************************************************)
(* The stack machine *)
(*****************************************************************************)

type ir =
  | Imm of int64
  | Place of place                    (* a variable's address *)
  | Load of ty                        (* the address on top by its value *)
  | Store of ty                       (* value and address by the value *)
  | Op of binop * ty
      (* a b by a op b, of the operands' type; a relation 1 or 0 *)
  | Unop of unop * ty
  | Ext of ty                         (* the value on top to a type *)
  | Dup | Drop
  | Call of string option * int * bool
      (* the name, or the address on top of the arguments; their number;
       * a result *)
  | Label of int | Jmp of int | Jz of int | Jnz of int
  | Ret of bool

let show i =
  let w t = string_of_int (size t) ^ (if unsigned t then "u" else "") in
  let l k = Printf.sprintf "L%d" k in
  match i with
  | Imm v -> "imm " ^ Int64.to_string v | Place (Global s) -> "addr " ^ s
  | Place (Local o) -> Printf.sprintf "frame -%d" o
  | Place (Param o) -> Printf.sprintf "param %d" o
  | Load t -> "load " ^ w t | Store t -> "store " ^ w t
  | Op (o, t) -> "op " ^ binop_name o ^ " " ^ w t
  | Unop (o, _) -> if o = Neg then "neg" else "com" | Ext t -> "ext " ^ w t
  | Dup -> "dup" | Drop -> "drop"
  | Call (f, n, r) ->
      Printf.sprintf "call %s %d%s" (f ||| "*") n (if r then " ->" else "")
  | Label k -> l k ^ ":" | Jmp k -> "jmp " ^ l k | Jz k -> "jz " ^ l k
  | Jnz k -> "jnz " ^ l k | Ret v -> if v then "ret value" else "ret"

(* the current function's, the last first *)
let code : ir list ref = ref []
let emit i = code := i :: !code
let labels = ref 0
let label () = incr labels; !labels

(* the value of e, pushed *)
let rec value (e : expr) : unit =
  match e.d with
  | Const v -> emit (Imm v)
  | Addr p -> emit (Place p)
  | Deref a ->
      value a;
      (match e.t with Arr _ | Struct _ | Func _ -> () | t -> emit (Load t))
  | Cur -> emit (Load e.t)
  | Un (o, a) -> value a; emit (Unop (o, e.t))
  | Bin (o, a, b) -> value a; value b; emit (Op (o, a.t))
  | Cond (c, a, b) ->
      let other = label () and out = label () in
      value c;
      emit (Jz other);
      value a;
      emit (Jmp out);
      emit (Label other);
      value b;
      emit (Label out)
  | Asg (l, r, cur) ->
      value (addr l);
      if cur then emit Dup;
      value r;
      emit (Store l.t)
  | Apply (f, args) ->
      List.iter value args; emit (Call (Some f, List.length args, e.t <> Void))
  | ApplyPtr (f, args) ->
      List.iter value args; value f;
      emit (Call (None, List.length args, e.t <> Void))
  | Conv a ->
      value a;
      (match a.t, e.t with
       | (Arr _ | Ptr _ | Void), _ | _, Void -> ()
       | _ -> emit (Ext e.t))
  | Comma (a, b) -> value a; if a.t <> Void then emit Drop; value b

(* an expression as a statement *)
let for_effect (e : expr) = value e; if e.t <> Void then emit Drop

(* where break and continue go; the labels of a switch's cases *)
type targets = {
  brk : int option; cont : int option; cases : (int64 option * int) list ref }

let rec lower (k : targets) (s : stmt) =
  let jump = function
    | Some l -> emit (Jmp l)
    | None -> error "break or continue outside a loop" in
  match s with
  | Expr e -> for_effect e
  | Block l -> List.iter (lower k) l
  | If (c, a, b) ->
      let other = label () in
      value c;
      emit (Jz other);
      lower k a;
      (match b with
       | Some b ->
           let out = label () in
           emit (Jmp out); emit (Label other); lower k b; emit (Label out)
       | None -> emit (Label other))
  | Do (body, c) ->
      let top = label () and cont = label () and out = label () in
      emit (Label top);
      lower { k with brk = Some out; cont = Some cont } body;
      emit (Label cont); value c; emit (Jnz top); emit (Label out)
  | For (init, c, step, body) ->
      Option.iter for_effect init;
      let top = label () and cont = label () and out = label () in
      emit (Label top);
      Option.iter (fun c -> value c; emit (Jz out)) c;
      lower { k with brk = Some out; cont = Some cont } body;
      emit (Label cont);
      Option.iter for_effect step;
      emit (Jmp top); emit (Label out)
  | Switch (tmp, v, body) ->
      (* the value in a temporary, the cases after the body *)
      for_effect (assign false tmp v);
      let dispatch = label () and out = label () in
      emit (Jmp dispatch);
      let cases = ref [] in
      lower { k with brk = Some out; cases } body;
      let mine = List.rev !cases in
      emit (Jmp out);
      emit (Label dispatch);
      List.iter (fun (c, l) ->
        match c with
        | Some v -> value (binary (R Eq) tmp (num v long_t)); emit (Jnz l)
        | None -> ()) mine;
      emit (Jmp (match List.assoc_opt None mine with
                 | Some l -> l
                 | None -> out));
      emit (Label out)
  | Case v ->
      let l = label () in k.cases := (v, l) :: !(k.cases); emit (Label l)
  | Break -> jump k.brk
  | Continue -> jump k.cont
  | Return None -> emit (Ret false)
  | Return (Some e) -> value e; emit (Ret true)

(*****************************************************************************)
(* The parser: declarations, and statements *)
(*****************************************************************************)

type storage = Auto | Static | Extern | Typedef

type var = { vty : ty; where : place }

let toks : token array ref = ref (Array.of_list []) and pos = ref 0
(* each token's, for the errors *)
let locs : loc array ref = ref (Array.of_list [])
let peek () = if !pos < Array.length !toks then (!toks).(!pos) else EOF
let next () = let t = peek () in incr pos; t
let accept p = if peek () = P p then (incr pos; true) else false
let expect p = if not (accept p) then error ("expected " ^ p)
let ident () = match next () with Id x -> x | _ -> error "expected a name"

let globals : (string, var) Hashtbl.t = Hashtbl.create 64
let typedefs : (string, ty) Hashtbl.t = Hashtbl.create 16
(* an enum's constants, ints *)
let enums : (string, int64) Hashtbl.t = Hashtbl.create 16
let structs : (string, sdef) Hashtbl.t = Hashtbl.create 16
let scopes : (string, var) Hashtbl.t list ref = ref []
let frame = ref 0                         (* the current function's locals *)
let result = ref Void
let data = Buffer.create 4096             (* the DATA and GLOBL *)

(* a global's name in the assembly: Plan 9's name<> for a static is,
 * the link being one namespace, the file's name and the name *)
let sym s =
  if Filename.check_suffix s "<>" then
    !unit_name ^ "." ^ Filename.chop_suffix s "<>"
  else s

type datum = Bytes of string | Value of int * int64 | Address of string

(* each global's data, at their offsets, until its label is written
 * (a string in an initializer is written before its array) *)
let pending : (string, (int * datum) list) Hashtbl.t = Hashtbl.create 16

let datum name off d =
  Hashtbl.replace pending name
    ((off, d) :: (Hashtbl.find_opt pending name ||| []))

(* a value's low 32 bits, signed, in decimal (old: Printf's %ld of
 * Int64.to_int32) *)
let word v = Int64.to_string (Int64.shift_right (Int64.shift_left v 32) 32)

(* a global of n bytes: its label and its data, the gaps zeros *)
let globl name n =
  let line s = Printf.bprintf data "\t%s\n" s in
  Buffer.add_string data ("\t.align\t4\n" ^ sym name ^ ":\n");
  let bytes l =
    line (".byte\t" ^ String.concat ", " (List.map string_of_int l)) in
  let at = List.fold_left (fun at (off, d) ->
    if off > at then line (Printf.sprintf ".space\t%d" (off - at));
    match d with
    | Bytes b ->
        bytes (List.map Char.code (List.init (String.length b) (String.get b)));
        off + String.length b
    | Value (1, v) -> bytes [ Int64.to_int v land 0xff ]; off + 1
    | Value (2, v) ->
        bytes [ Int64.to_int v land 0xff; (Int64.to_int v lsr 8) land 0xff ];
        off + 2
    | Value (k, v) ->
        line (".word\t" ^ word v);
        if k = 8 then line (".word\t" ^ word (Int64.shift_right v 32));
        off + k
    | Address s -> line (".word\t" ^ sym s); off + 4)
    0 (List.sort (fun (a, _) (b, _) -> compare a b)
         (List.rev (Hashtbl.find_opt pending name ||| []))) in
  if n > at then line (Printf.sprintf ".space\t%d" (n - at));
  Hashtbl.remove pending name
let strings = ref 0
let tags = ref 0                          (* the anonymous structures' *)

let lookup x =
  match List.find_map (fun s -> Hashtbl.find_opt s x) !scopes with
  | Some v -> v
  | None ->
      (match Hashtbl.find_opt globals x with
       | Some v -> v
       | None -> error ("undeclared: " ^ x))

(* a local's place, below SP at its alignment *)
let local t =
  frame := round (!frame + size t) (max 1 (min 8 (align t))); Local !frame

(* a string, as a static array of bytes *)
let string_lit s =
  incr strings;
  let name = Printf.sprintf "s%d<>" !strings in
  let s = s ^ "\000" in
  for i = 0 to (String.length s - 1) / 8 do
    datum name (8 * i)
      (Bytes (String.sub s (8 * i) (min 8 (String.length s - (8 * i)))))
  done;
  globl name (String.length s);
  var (Global name) (Arr (char_t, String.length s))

let is_type () =
  match peek () with
  | Id ("void" | "char" | "short" | "int" | "long" | "unsigned" | "signed"
        | "struct" | "enum" | "static" | "extern" | "const" | "typedef") -> true
  | Id x ->
      Hashtbl.mem typedefs x
      && not (List.exists (fun s -> Hashtbl.mem s x) !scopes)
  | _ -> false

(* the words before a declarator: the type, and static, extern, typedef *)
let rec base_type () =
  let storage = ref Auto and words = ref [] and t = ref None in
  let rec go () =
    match peek () with
    | Id (("static" | "extern" | "typedef") as w) ->
        ignore (next ());
        storage :=
          List.assoc w
            [ "static", Static; "extern", Extern; "typedef", Typedef ];
        go ()
    | Id ("const" | "volatile") -> ignore (next ()); go ()
    | Id (("void" | "char" | "short" | "int" | "long" | "unsigned" | "signed")
          as w) ->
        ignore (next ()); words := w :: !words; go ()
    | Id "struct" -> ignore (next ()); t := Some (struct_type ()); go ()
    | Id "enum" -> ignore (next ()); t := Some (enum_type ()); go ()
    | Id x when !words = [] && !t = None && Hashtbl.mem typedefs x ->
        ignore (next ()); t := Some (Hashtbl.find typedefs x); go ()
    | _ -> ()
  in
  go ();
  let w = !words in
  let signed = not (List.mem "unsigned" w) in
  let longs = List.length (List.filter (( = ) "long") w) in
  let width =
    if List.mem "char" w then 1 else if List.mem "short" w then 2
    else if longs >= 2 then 8 else 4 in
  let t =
    match !t with
    | Some t -> t
    | None -> if List.mem "void" w then Void else Int (width, signed) in
  !storage, t

and struct_type () =
  let tag =
    match peek () with
    | Id x -> ignore (next ()); x
    | _ -> incr tags; Printf.sprintf ".%d" !tags in
  let s =
    match Hashtbl.find_opt structs tag with
    | Some s -> s
    | None ->
        let s = { fields = []; ssize = 0; salign = 1 } in
        Hashtbl.replace structs tag s; s in
  if accept "{" then begin
    (* each member at its size's alignment, the whole rounded to 8, as 7c *)
    let off = ref 0 in
    while not (accept "}") do
      let _, bt = base_type () in
      let rec members () =
        let name, t = declarator bt in
        no_vlong t;
        off := round !off (align t);
        s.fields <- s.fields @ [ name, t, !off ];
        off := !off + size t;
        s.salign <- max s.salign (align t);
        if accept "," then members ()
      in
      members ();
      expect ";"
    done;
    s.ssize <- round !off 8
  end;
  Struct s

(* enum tag { A, B = 5, C }: its constants numbered from 0, or from the
 * last given; the type an int *)
and enum_type () =
  (match peek () with Id _ -> ignore (next ()) | _ -> ());
  if accept "{" then begin
    let rec go v =
      if not (accept "}") then
        (let x = ident () in
         let v = if accept "=" then const_expr () else v in
         Hashtbl.replace enums x v;
         ignore (accept ",");
         go (Int64.succ v)) in
    go Int64.zero
  end;
  int_t

(* * name [n]... or name(params), with the parameters' names *)
and declarator bt = let name, t, _ = declarator3 bt in name, t

and declarator3 bt =
  let name, wrap, pnames = declarator_rec () in
  name, wrap bt, pnames

(* C's declarators, inside out: stars, then a name or a parenthesized
 * declarator, then ( params ) or [ n ]...; the type is built from the
 * base outward, the parenthesized one applied last: int ( *f[3])(int)
 * is an array of pointers to functions. The parameters' names are the
 * innermost function's (a definition's) *)
and declarator_rec () : string * (ty -> ty) * string list =
  let stars = ref 0 in
  while accept "*" do incr stars; ignore (accept "const") done;
  let ptrs t = let t = ref t in for _i = 1 to !stars do t := Ptr !t done; !t in
  let name, inner, inner_names =
    if peek () = P "("
       && (incr pos; let star = peek () = P "*" in decr pos; star)
    then begin
      ignore (next ());
      let r = declarator_rec () in
      expect ")";
      r
    end
    else
      ((match peek () with Id x -> ignore (next ()); x | _ -> ""),
       (fun t -> t), []) in
  if accept "(" then begin
    (* the parameters, named or not, an array's as a pointer; ... *)
    let rec params () =
      if accept ")" then [], false
      else if accept "..." then (expect ")"; [], true)
      else begin
        let _, pt = base_type () in
        let pname, pt = declarator pt in
        let pt = match pt with Arr (e, _) -> Ptr e | t -> t in
        ignore (accept ",");
        let rest, variadic = params () in
        (if pt <> Void || pname <> "" then (pname, pt) :: rest else rest),
        variadic
      end
    in
    let ps, variadic = params () in
    name, (fun t -> inner (Func (ptrs t, List.map snd ps, variadic))),
    (if inner_names <> [] then inner_names else List.map fst ps)
  end
  else begin
    let rec dims () =
      if accept "[" then
        (let n =
           if peek () = P "]" then 0 else Int64.to_int (const_expr ()) in
         expect "]";
         n :: dims ())
      else [] in
    let ds = dims () in
    name,
    (fun t -> inner (List.fold_right (fun n t -> Arr (t, n)) ds (ptrs t))),
    inner_names
  end

(* expressions, by precedence climbing *)
and expr () =
  let e = assign_expr () in
  if accept "," then (let r = expr () in mk (Comma (e, r)) r.t) else e

and assign_expr () =
  let l = cond_expr () in
  match peek () with
  | P "=" -> ignore (next ()); assign false l (assign_expr ())
  | P op when List.mem_assoc op asg_ops ->
      ignore (next ()); asg_op (List.assoc op asg_ops) l (assign_expr ())
  | _ -> l

and cond_expr () =
  let c = binary_expr 0 in
  if accept "?" then begin
    let a = rv (expr ()) in
    expect ":";
    let b = rv (cond_expr ()) in
    let t =
      if is_int a.t && is_int b.t then common a.t b.t
      else if is_ptr a.t then a.t
      else b.t in
    mk (Cond (rv c, conv a t, conv b t)) t
  end
  else c

and binary_expr min =
  let levels = [ [ "||" ]; [ "&&" ]; [ "|" ]; [ "^" ]; [ "&" ]; [ "=="; "!=" ];
                 [ "<"; ">"; "<="; ">=" ]; [ "<<"; ">>" ]; [ "+"; "-" ];
                 [ "*"; "/"; "%" ] ] in
  let rec loop l =
    match peek () with
    | P op -> (
        let rec index i = function
          | [] -> None
          | l :: r -> if List.mem op l then Some i else index (i + 1) r in
        match index 0 levels with
        | Some lv when lv >= min ->
            ignore (next ());
            let r = binary_expr (lv + 1) in
            loop (match op with
                  | "&&" -> both l r
                  | "||" -> either l r
                  | op -> binary (List.assoc op binops) l r)
        | _ -> l)
    | _ -> l
  in
  loop (unary ())

and unary () =
  match peek () with
  | P "-" ->
      ignore (next ());
      let e = rv (unary ()) in
      let t = promote e.t in
      (match e.d with
       | Const v -> num (Int64.neg v) t
       | _ -> mk (Un (Neg, conv e t)) t)
  | P "+" -> ignore (next ()); let e = rv (unary ()) in conv e (promote e.t)
  | P "~" ->
      ignore (next ());
      let e = rv (unary ()) in
      let t = promote e.t in
      mk (Un (Com, conv e t)) t
  | P "!" -> ignore (next ()); lnot (unary ())
  | P "*" -> ignore (next ()); deref (unary ())
  | P "&" -> ignore (next ()); addr (unary ())
  | P (("++" | "--") as op) ->
      ignore (next ());
      asg_op (if op = "++" then Add else Sub) (unary ()) (num Int64.one int_t)
  | Id "sizeof" ->
      ignore (next ());
      let t = if paren_type () then type_name () else (unary ()).t in
      num (Int64.of_int (size t)) (Int (4, false))
  | P "(" when paren_type () -> let t = type_name () in conv (rv (unary ())) t
  | _ -> postfix (primary ())

(* ( type ...: a cast, or sizeof's type *)
and paren_type () =
  peek () = P "(" && (incr pos; let ty = is_type () in decr pos; ty)

(* a type in parentheses: a cast's, sizeof's *)
and type_name () =
  expect "(";
  let _, bt = base_type () in
  let t = snd (declarator bt) in
  expect ")"; t

(* a call's arguments, after its (: each to its declared parameter's
 * type, else promoted *)
and call_args ps =
  let rec go () =
    let a = rv (assign_expr ()) in
    if accept "," then a :: go () else (expect ")"; [ a ]) in
  let args = if accept ")" then [] else go () in
  List.mapi (fun i (a : expr) ->
    match List.nth_opt ps i with
    | Some t -> conv a t
    | None -> conv a (promote a.t)) args

and postfix e =
  match peek () with
  | P "(" ->
      (* a call through a function's address: a pointer, or ( *f ) *)
      ignore (next ());
      let f = rv e in
      let rt, ps =
        match f.t with
        | Ptr (Func (r, p, _)) -> r, p
        | _ -> error "not a function" in
      postfix (mk (ApplyPtr (f, call_args ps)) rt)
  | P "[" ->
      ignore (next ());
      let i = expr () in
      expect "]"; postfix (deref (binary (A Add) e i))
  | P "." -> ignore (next ()); postfix (member e (ident ()))
  | P "->" -> ignore (next ()); postfix (member (deref e) (ident ()))
  | P (("++" | "--") as op) ->
      ignore (next ());
      (* x++ is (x += 1) - 1, and so on *)
      let o, back = if op = "++" then Add, Sub else Sub, Add in
      postfix
        (conv (binary (A back) (asg_op o e (num Int64.one int_t))
                 (num Int64.one int_t)) e.t)
  | _ -> e

and member e f =
  match e.t with
  | Struct s -> (
      match List.find_opt (fun (n, _, _) -> n = f) s.fields with
      | Some (_, t, off) ->
          mk (Deref (mk (Bin (A Add, conv (addr e) long_t,
                              num (Int64.of_int off) long_t)) (Ptr t))) t
      | None -> error ("no member " ^ f))
  | _ -> error "not a structure"

and primary () =
  match next () with
  | Num (v, ll) ->
      num v (if ll || Int64.compare v int_max > 0 then long_t else int_t)
  | Str s -> string_lit s
  | P "(" -> let e = expr () in expect ")"; e
  | Id f when peek () = P "("
              && (match (try Some (lookup f) with Failure _ -> None) with
                  | Some { vty = Func _; _ } | None -> true
                  | _ -> false) ->
      ignore (next ());
      let rt, ps, sym =
        match (try Some (lookup f) with Failure _ -> None) with
        | Some { vty = Func (r, p, _); where = Global s } -> r, p, s
        | _ -> int_t, [], f in
      mk (Apply (sym, call_args ps)) rt
  | Id x when Hashtbl.mem enums x
              && not (List.exists (fun s -> Hashtbl.mem s x) !scopes
                      || Hashtbl.mem globals x) ->
      num (Hashtbl.find enums x) int_t
  | Id x -> let v = lookup x in var v.where v.vty
  | _ -> error "expected an expression"

(* a constant expression, folded: an array's size, a case, an enum's
 * value (NDIRECT + 1, sizeof a / sizeof a[0]); 64-bit arithmetic, as the
 * values are *)
and const_expr () =
  let rec fold (e : expr) =
    match e.d with
    | Const v -> v
    | Conv a -> fold a
    | Un (Neg, a) -> Int64.neg (fold a)
    | Un (Com, a) -> Int64.lognot (fold a)
    | Bin (A o, a, b) ->
        let a = fold a and b = fold b in
        (match o with
         | Add -> Int64.add a b | Sub -> Int64.sub a b | Mul -> Int64.mul a b
         | Div ->
             if b = Int64.zero then error "division by zero" else Int64.div a b
         | Mod ->
             if b = Int64.zero then error "division by zero" else Int64.rem a b
         | And -> Int64.logand a b | Or -> Int64.logor a b
         | Xor -> Int64.logxor a b
         | Shl -> Int64.shift_left a (Int64.to_int b)
         | Shr -> Int64.shift_right a (Int64.to_int b))
    | _ -> error "not a constant" in
  fold (cond_expr ())

(* statements *)
let cond () = expect "("; let c = rv (expr ()) in expect ")"; c

let rec statement () : stmt =
  match next () with
  | P "{" -> block ()
  | P ";" -> Block []
  | Id "if" ->
      let c = cond () in
      let a = statement () in
      If (c, a,
          if peek () = Id "else" then (ignore (next ()); Some (statement ()))
          else None)
  | Id "while" -> let c = cond () in For (None, Some c, None, statement ())
  | Id "do" ->
      let body = statement () in
      ignore (next ());
      let c = cond () in
      expect ";"; Do (body, c)
  | Id "for" ->
      (* an expression, or none, then the token that ends it *)
      let opt close =
        let e = if peek () = P close then None else Some (expr ()) in
        expect close; e in
      expect "(";
      let init = opt ";" in
      let c = Option.map rv (opt ";") in
      let step = opt ")" in
      For (init, c, step, statement ())
  | Id "switch" ->
      let v = conv (cond ()) long_t in
      let tmp = var (local long_t) long_t in
      Switch (tmp, v, statement ())
  | Id "case" ->
      let v = const_expr () in expect ":"; Block [ Case (Some v); statement () ]
  | Id "default" -> expect ":"; Block [ Case None; statement () ]
  | Id "break" -> expect ";"; Break
  | Id "continue" -> expect ";"; Continue
  | Id "return" ->
      if accept ";" then Return None
      else (let e = conv (rv (expr ())) !result in expect ";"; Return (Some e))
  | _ ->
      decr pos;
      if is_type () then Block (locals ())
      else (let e = expr () in expect ";"; Expr e)

and block () =
  scopes := Hashtbl.create 8 :: !scopes;
  let rec go acc =
    if accept "}" then List.rev acc else go (statement () :: acc) in
  let l = go [] in
  scopes := List.tl !scopes;
  Block l

(* a declaration of locals: their initializations *)
and locals () =
  let storage, bt = base_type () in
  let rec go () =
    let name, t = declarator bt in
    let init =
      if storage = Typedef then (Hashtbl.replace typedefs name t; [])
      else begin
        no_vlong t;
        let p = local t in
        Hashtbl.replace (List.hd !scopes) name { vty = t; where = p };
        if accept "=" then [ Expr (assign false (var p t) (assign_expr ())) ]
        else []
      end
    in
    init @ (if accept "," then go () else [])
  in
  let l = go () in
  expect ";";
  l

(*****************************************************************************)
(* The machine: TinyCPU, the stack in r1..r12 *)
(*****************************************************************************)

let out = Buffer.create 65536

(* TinyCPU (TinyMachineCPU.ml) has 32-bit registers, r0 zero, no flags, and
 * no unsigned division; its calling convention is ours, simpler than
 * 7c's: every argument in memory, 4 bytes each, the result in r13. The
 * frame, sp at its bottom: the outgoing arguments from 0(sp), the saved
 * lr, the saves of what is live across a call, the locals at its top;
 * above it, the parameters (the caller's outgoing arguments). A
 * variadic function (print) walks its arguments from its last named
 * one's address. *)

let machine name locals (body : ir list) =
  let sp = ref 0 and saves = ref 0 and outgoing = ref 0
  and dead = ref false in
  let depth_at = Hashtbl.create 16 in
  let top () = !sp in
  let push () =
    incr sp;
    if !sp > 12 then error (name ^ ": an expression too deep");
    !sp in
  let jump l = Hashtbl.replace depth_at l !sp in
  let lab l = !unit_name ^ ".L" ^ string_of_int l in
  (* a register's name, a number's text (old: Printf's formats, %d) *)
  let r k = Printf.sprintf "r%d" k and n k = string_of_int k in
  (* the code, each line a function of the frame's size (known at the
   * end); slot k the k-th save, below the locals; lr above the
   * outgoing arguments *)
  let lines = ref [] in
  let at f = lines := f :: !lines in
  let ins s = at (fun _ -> Printf.sprintf "\t%s\n" s) in
  let slot k = locals + (4 * k) in
  (* a value extended from its type: the registers are 32 bits, so only
   * a char's and a short's need it *)
  let extend t a =
    match t with
    | Int (k, s) when k < 4 ->
        if s then
          (ins ("shli\t" ^ r a ^ ", " ^ r a ^ ", " ^ n (32 - (8 * k)));
           ins ("sari\t" ^ r a ^ ", " ^ r a ^ ", " ^ n (32 - (8 * k))))
        else ins ("andi\t" ^ r a ^ ", " ^ r a ^ ", " ^ n ((1 lsl (8 * k)) - 1))
    | _ -> () in
  let lr_at () = !outgoing in
  let epilogue () =
    at (fun f ->
      "\tldw\tlr, " ^ n (lr_at ()) ^ "(sp)\n\taddi\tsp, sp, " ^ n f
      ^ "\n\tret\n") in
  (* an instruction of three registers *)
  let three op a b c = ins (op ^ "\t" ^ r a ^ ", " ^ r b ^ ", " ^ r c) in
  List.iter (fun i ->
    match i with
    | Label l ->
        (match Hashtbl.find_opt depth_at l with
         | Some d when !dead -> sp := d
         | _ -> ());
        dead := false;
        at (fun _ -> lab l ^ ":\n")
    | _ when !dead -> ()
    | Imm v -> let a = push () in ins ("li\t" ^ r a ^ ", " ^ word v)
    | Place (Global s) -> let a = push () in ins ("la\t" ^ r a ^ ", " ^ sym s)
    | Place (Local o) ->
        let a = push () in
        at (fun f -> "\taddi\t" ^ r a ^ ", sp, " ^ n (f - o) ^ "\n")
    | Place (Param o) ->
        let a = push () in
        at (fun f -> "\taddi\t" ^ r a ^ ", sp, " ^ n (f + (4 * (o / 8))) ^ "\n")
    | Load t ->
        let a = top () in
        (match t with
         | Int (1, _) -> ins ("ldb\t" ^ r a ^ ", 0(" ^ r a ^ ")")
         | Int (2, _) ->
             ins ("ldb\tr13, 0(" ^ r a ^ ")");
             ins ("ldb\t" ^ r a ^ ", 1(" ^ r a ^ ")");
             ins ("shli\t" ^ r a ^ ", " ^ r a ^ ", 8");
             ins ("or\t" ^ r a ^ ", " ^ r a ^ ", r13")
         | _ -> ins ("ldw\t" ^ r a ^ ", 0(" ^ r a ^ ")"));
        extend t a
    | Store t ->
        let v = top () in
        decr sp;
        let a = top () in
        (match size t with
         | 1 -> ins ("stb\t" ^ r v ^ ", 0(" ^ r a ^ ")")
         | 2 ->
             ins ("stb\t" ^ r v ^ ", 0(" ^ r a ^ ")");
             ins ("shri\tr13, " ^ r v ^ ", 8");
             ins ("stb\tr13, 1(" ^ r a ^ ")")
         | _ -> ins ("stw\t" ^ r v ^ ", 0(" ^ r a ^ ")"));
        ins ("mov\t" ^ r a ^ ", " ^ r v)
    | Op (o, t) -> (
        let b = top () in
        decr sp;
        let a = top () and u = unsigned t in
        let slt = if u then "sltu" else "slt" in
        match o with
        | R Lt -> three slt a a b
        | R Gt -> three slt a b a
        | R Le -> three slt a b a; ins ("xori\t" ^ r a ^ ", " ^ r a ^ ", 1")
        | R Ge -> three slt a a b; ins ("xori\t" ^ r a ^ ", " ^ r a ^ ", 1")
        | R Eq -> three "sub" a a b; ins ("sltiu\t" ^ r a ^ ", " ^ r a ^ ", 1")
        | R Ne -> three "sub" a a b; ins ("sltu\t" ^ r a ^ ", zero, " ^ r a)
        | A ((Div | Mod) as o) when u ->
            (* TinyCPU divides signed only: the runtime's __udivmod, its
             * operands and the remainder below sp, the quotient in r13 *)
            ins ("stw\t" ^ r a ^ ", -4(sp)"); ins ("stw\t" ^ r b ^ ", -8(sp)");
            ins "call\t__udivmod";
            if o = Div then ins ("mov\t" ^ r a ^ ", r13")
            else ins ("ldw\t" ^ r a ^ ", -4(sp)");
            extend t a
        | A o ->
            three
              (match o with
               | Add -> "add" | Sub -> "sub" | Mul -> "mul" | Div -> "div"
               | Mod -> "rem" | And -> "and" | Or -> "or" | Xor -> "xor"
               | Shl -> "shl" | Shr -> if u then "shr" else "sar")
              a a b;
            extend t a)
    | Unop (o, t) ->
        let a = top () in
        if o = Neg then ins ("sub\t" ^ r a ^ ", zero, " ^ r a)
        else
          (ins "addi\tr13, zero, -1";
           ins ("xor\t" ^ r a ^ ", " ^ r a ^ ", r13"));
        extend t a
    | Ext t -> extend t (top ())
    | Dup ->
        let a = top () in let d = push () in ins ("mov\t" ^ r d ^ ", " ^ r a)
    | Drop -> decr sp
    | Call (f, k, res) ->
        let base = !sp - k - (if f = None then 1 else 0) in
        saves := max !saves base;
        for j = 1 to base do
          at (fun fr -> "\tstw\t" ^ r j ^ ", " ^ n (fr - slot j) ^ "(sp)\n")
        done;
        for j = 0 to k - 1 do
          ins ("stw\t" ^ r (base + 1 + j) ^ ", " ^ n (4 * j) ^ "(sp)")
        done;
        outgoing := max !outgoing (4 * k);
        (match f with
         | Some f -> ins ("call\t" ^ sym f)
         | None -> ins ("jalr\tlr, 0(" ^ r (base + k + 1) ^ ")"));
        for j = 1 to base do
          at (fun fr -> "\tldw\t" ^ r j ^ ", " ^ n (fr - slot j) ^ "(sp)\n")
        done;
        sp := base;
        if res then (let d = push () in ins ("mov\t" ^ r d ^ ", r13"))
    | Jmp l -> jump l; ins ("j\t" ^ lab l); dead := true
    | Jz l ->
        let a = top () in
        decr sp; jump l; ins ("beq\t" ^ r a ^ ", zero, " ^ lab l)
    | Jnz l ->
        let a = top () in
        decr sp; jump l; ins ("bne\t" ^ r a ^ ", zero, " ^ lab l)
    | Ret v ->
        if v then (ins ("mov\tr13, " ^ r (top ())); decr sp);
        epilogue (); dead := true)
    body;
  if not !dead then epilogue ();
  let frame = round (!outgoing + 4 + (4 * !saves) + locals) 8 in
  Buffer.add_string out
    (sym name ^ ":\n\taddi\tsp, sp, " ^ n (- frame) ^ "\n\tstw\tlr, "
     ^ n (lr_at ()) ^ "(sp)\n");
  List.iter (fun f -> Buffer.add_string out (f frame)) (List.rev !lines)

(*****************************************************************************)
(* The file: globals and functions *)
(*****************************************************************************)

(* -ir: the stack machine's code instead of the machine's *)
let ir_only = ref false

let asm_name storage name = if storage = Static then name ^ "<>" else name

(* a global's init_data, as DATA at offsets *)
let rec init_data name t off =
  match t, peek () with
  | Arr (e, _), P "{" ->
      ignore (next ());
      (* the elements, counted *)
      let rec elems i =
        if accept "}" then i
        else
          (ignore (init_data name e (off + (i * size e)));
           ignore (accept ",");
           elems (i + 1)) in
      elems 0
  | Arr (Int (1, _), n), Str s ->
      ignore (next ());
      String.iteri (fun i c ->
        datum name (off + i) (Value (1, Int64.of_int (Char.code c)))) s;
      max n (String.length s + 1)
  | _ ->
      let e = rv (assign_expr ()) in
      (match e.d, e.t with
       | Const v, _ -> datum name off (Value (size t, v))
       | Addr (Global s), _ -> datum name off (Address s)
       | _ -> error (name ^ ": not a constant init_data"));
      1

let external_decl () =
  let storage, bt = base_type () in
  let rec go () =
    let name, t, pnames = declarator3 bt in
    if storage <> Typedef then no_vlong t;
    match t with
    | Func (rt, ps, _) when storage <> Typedef && peek () = P "{" ->
        (* a definition *)
        Hashtbl.replace globals name
          { vty = t; where = Global (asm_name storage name) };
        ignore (next ());
        let params = List.combine pnames ps in
        scopes := [ Hashtbl.create 8 ];
        List.iteri (fun i (p, pt) ->
          Hashtbl.replace (List.hd !scopes) p
            { vty = pt; where = Param (8 * i) }) params;
        frame := 0;
        result := rt;
        let body = block () in
        code := [];
        lower { brk = None; cont = None; cases = ref [] } body;
        if !ir_only then
          (Buffer.add_string out (name ^ ":\n");
           List.iter (fun i -> Buffer.add_string out ("\t" ^ show i ^ "\n"))
             (List.rev !code))
        else machine (asm_name storage name) (round !frame 8) (List.rev !code);
        scopes := []
    | _ ->
        let sym = asm_name storage name in
        (match storage, t with
         | Typedef, _ -> Hashtbl.replace typedefs name t
         | _, Func _ ->
             Hashtbl.replace globals name { vty = t; where = Global sym }
         | _ ->
             let t =
               if accept "=" then
                 (match t with
                  | Arr (e, 0) -> let n = init_data sym t 0 in Arr (e, n)
                  | _ -> ignore (init_data sym t 0); t)
               else t in
             Hashtbl.replace globals name { vty = t; where = Global sym };
             if storage <> Extern then globl sym (size t));
        if accept "," then go () else expect ";"
  in
  if not (accept ";") then go ()

(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

let main
    (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    =
  let output = ref "" and file = ref "" in
  let rec args l = match l with
    | "-ir" :: r -> ir_only := true; args r
    | "-o" :: o :: r -> output := o; args r
    | f :: r -> file := f; args r
    | [] -> ()
  in
  let argl = List.tl (TinyLibSystem.argv caps) in
  if List.mem "-h" argl || List.mem "--help" argl then
    (TinyLibSystem.print caps help; 0)
  else begin
    args argl;
    if !file = "" then (TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); 2)
    else begin
      unit_name := Filename.remove_extension (Filename.basename !file);
      (* intptr, Plan 9's uintptr's signed twin: an integer as wide as a
       * pointer (TinyMLRuntime/'s values, a word each) *)
      Hashtbl.replace typedefs "intptr" int_t;
      let read f =
        try TinyLibSystem.read_file caps f
        with Failure m -> raise (File_error m) in
      try
        let ts = tokens (Hashtbl.create 16) read !file in
        toks := Array.of_list (List.map fst ts);
        locs := Array.of_list (List.map snd ts);
        while peek () <> EOF do external_decl () done;
        let text =
          Buffer.contents out
          ^ (if !ir_only then "" else "\t.data\n" ^ Buffer.contents data)
        in
        if !output = "" then TinyLibSystem.print caps text
        else begin
          let fd =
            try TinyLibSystem.open_out caps !output
            with Failure m -> raise (File_error m) in
          TinyLibSystem.write fd text; TinyLibSystem.close fd
        end;
        0
      with
      | Failure m ->
          (* where: the last token read (a missing ; is then on its line, not
           * the next one's), in its file (an #include's); the lexer's errors
           * have none *)
          let ls = !locs in
          if Array.length ls = 0 then
            TinyLibSystem.eprint caps (!file ^ ": " ^ m ^ "\n")
          else
            (let f, l = ls.(max 0 (min (!pos - 1) (Array.length ls - 1))) in
             TinyLibSystem.eprint caps
               (f ^ ": line " ^ string_of_int l ^ ": " ^ m ^ "\n"));
          1
      | File_error m ->
          TinyLibSystem.eprint caps (Printf.sprintf "tiny-c: %s\n" m); 1
    end
  end

let () = TinyLibSystem.main "tiny-c" main
