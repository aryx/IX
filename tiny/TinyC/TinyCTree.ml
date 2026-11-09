(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCTree.mli *)
module Ty = TinyCTypes

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

(* where a variable is: a global's label; a local's offset in bytes
 * down from the frame's top; a parameter's up from it (the caller's
 * outgoing arguments, 4 bytes each) *)
type place = Global of Ty.sym | Local of int | Param of int

(* an assignment: x = y, or x op= y, whose new value reads the old one
 * (Cur) *)
type asg = Asg_set | Asg_update

type expr = { d : desc; t : Ty.ty }

and desc =
  | Const of int64
  | Addr of place
  | Deref of expr          (* the object at an address: an lvalue *)
  | Cur                               (* in x op= y, x's value *)
  | Un of unop * expr
  | Bin of binop * expr * expr
      (* both operands of one type; a relation's value an int *)
  | Cond of expr * expr * expr        (* && || ! are made of it *)
  | Asg of expr * expr * asg
      (* an lvalue, its new value *)
  | Apply of Ty.sym * expr list       (* a call (old: Call, the stack machine's
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
  | Ty.Arr (t, _), Deref a -> { a with t = Ty.Ptr t }
  | Ty.Func _, Deref a -> { a with t = Ty.Ptr e.t }
  | _ -> e

let conv (e : expr) t =
  match e.t, t, e.d with
  | a, b, _ when Ty.same a b -> e
  | Ty.Int _, Ty.Int (n, sg), Const v ->
      (* a constant converted now: truncated, extended *)
      let bits = 8 * n in
      let v =
        if bits = 64 then v
        else if sg then
          Int64.shift_right (Int64.shift_left v (64 - bits)) (64 - bits)
        else Int64.logand v (Int64.pred (Int64.shift_left Int64.one bits)) in
      num v t
  | (Ty.Ptr _ | Ty.Arr _), Ty.Ptr _, _
  | Ty.Ptr _, Ty.Int (8, _), _
  | Ty.Int (8, _), Ty.Ptr _, _ ->
      { e with t }
  | _ -> mk (Conv e) t

(* ANSI's promotion, which keeps the value: uchar and ushort become int,
 * as the host's cc, the tests' reference, does
 * (old: Int (4, s), Plan 9's, which keeps the sign: uint, as 7c, the
 * reference while tiny-c had an arm64 back end; TinyC_fuzz.py's
 * x2 <= -128, x2 a uchar 0, was then 1) *)
let promote = function Ty.Int (n, _) when n < 4 -> Ty.Int (4, true) | t -> t

(* the usual arithmetic conversions: the wider, unsigned if either is *)
let common a b =
  match promote a, promote b with
  | Ty.Int (n, s), Ty.Int (m, u) -> Ty.Int (max n m, s && u)
  | t, _ -> t

let scale (i : expr) t =
  let w = Ty.vlong_t in
  if Ty.size t = 1 then conv i w
  else mk (Bin (A Mul, conv i w, num (Int64.of_int (Ty.size t)) w)) w

let rec binary op (a : expr) (b : expr) =
  let a = rv a and b = rv b in
  match op, a.t, b.t with
  | A (Add | Sub), Ty.Ptr t, Ty.Int _ -> mk (Bin (op, a, scale b t)) a.t
  | A Add, Ty.Int _, Ty.Ptr _ -> binary op b a
  | A Sub, Ty.Ptr t, Ty.Ptr _ ->
      let w = Ty.vlong_t in
      mk (Bin (A Div, mk (Bin (op, conv a w, conv b w)) w,
               num (Int64.of_int (Ty.size t)) w)) w
  | R _, Ty.Ptr _, _ | R _, _, Ty.Ptr _ ->
      let t = if Ty.is_ptr a.t then a.t else b.t in
      mk (Bin (op, conv a t, conv b t)) Ty.int_t
  | R _, Ty.Int _, Ty.Int _ ->
      let t = common a.t b.t in mk (Bin (op, conv a t, conv b t)) Ty.int_t
  | A o, Ty.Int _, Ty.Int _ ->
      let t = if o = Shl || o = Shr then promote a.t else common a.t b.t in
      mk (Bin (op, conv a t, conv b t)) t
  | _ -> Ty.error ("bad operands for " ^ binop_name op)

let addr (e : expr) =
  match e.d with
  | Deref a -> { a with t = Ty.Ptr e.t }
  | _ -> Ty.error "not an lvalue"
let deref (e : expr) =
  let e = rv e in
  match e.t with Ty.Ptr t -> mk (Deref e) t | _ -> Ty.error "not a pointer"

(* (old: ~cur, a label, which tiny-ml does not read) *)
let assign (kind : asg) (l : expr) (r : expr) =
  match l.d with
  | Deref _ -> mk (Asg (l, conv (rv r) l.t, kind)) l.t
  | _ -> Ty.error "not an lvalue"

(* x op= y: the value computed from x's, loaded once *)
let asg_op o (l : expr) r = assign Asg_update l (binary (A o) (mk Cur l.t) r)

(* a variable, as an lvalue *)
let var p t = mk (Deref (mk (Addr p) (Ty.Ptr t))) t

(* a condition's value, 1 or 0; !, && and || as ?: of them *)
let one () = num Int64.one Ty.int_t
let zero () = num Int64.zero Ty.int_t
let truth c = mk (Cond (rv c, one (), zero ())) Ty.int_t
let lnot c = mk (Cond (rv c, zero (), one ())) Ty.int_t
let both a b = mk (Cond (rv a, truth b, zero ())) Ty.int_t
let either a b = mk (Cond (rv a, one (), truth b)) Ty.int_t

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
(* The file *)
(*****************************************************************************)

(* a piece of a global's initial value: bytes, an integer of a size,
 * an address *)
type datum = Bytes of string | Value of int * int64 | Address of Ty.sym

(* what a declaration defines (a typedef, a prototype or an extern
 * nothing): a function, its label, its locals' bytes and its body; a
 * global, its label, its size, its data at their offsets (a string
 * literal one too) *)
type def =
  | Function of Ty.sym * int * stmt
  | Data of Ty.sym * int * (int * datum) list
