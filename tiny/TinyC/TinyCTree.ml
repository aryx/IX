(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCTree.mli *)
open TinyCTypes

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
