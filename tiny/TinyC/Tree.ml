(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tree.mli *)

(*****************************************************************************)
(* Expressions, typed as they are built *)
(*****************************************************************************)

(* the operators: an arithmetic one's value is of its operands' type,
 * a relation's an int; >> is logical, / % and the relations unsigned,
 * for an unsigned type *)
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
type place = Global of Types.sym | Local of int | Param of int

(* an assignment: x = y, or x op= y, whose new value reads the old one
 * (Cur) *)
type asg = Asg_set | Asg_update

type expr = { d : desc; t : Types.ty }

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
  | Apply of Types.sym * expr list
      (* a call; not named Call, the stack machine's name: tiny-ml's
       * constructors are one name space *)
  | ApplyPtr of expr * expr list      (* through a function's address *)
  | Conv of expr                      (* to t *)
  | Comma of expr * expr

let mk (d : desc) t = { d; t }
let num v t = mk (Const v) t

(* an array is its address, a value of a small integer an int *)
let rv (e : expr) =
  match e.t, e.d with
  | Types.Arr (t, _), Deref a -> { a with t = Types.Ptr t }
  | Types.Func _, Deref a -> { a with t = Types.Ptr e.t }
  | _ -> e

(* a constant's value as an integer type keeps it: truncated to its
 * bits, then extended by its sign *)
let fit v t =
  match t with
  | Types.Int (n, sg) ->
      let bits = 8 * n in
      if bits = 64 then v
      else if sg then
        Int64.shift_right (Int64.shift_left v (64 - bits)) (64 - bits)
      else Int64.logand v (Int64.pred (Int64.shift_left Int64.one bits))
  | _ -> v

(* a constant converted now *)
let conv (e : expr) t =
  match e.t, t, e.d with
  | a, b, _ when Types.same a b -> e
  | Types.Int _, Types.Int _, Const v -> num (fit v t) t
  | (Types.Ptr _ | Types.Arr _), Types.Ptr _, _
  | Types.Ptr _, Types.Int (8, _), _
  | Types.Int (8, _), Types.Ptr _, _ ->
      { e with t }
  | _ -> mk (Conv e) t

(* ANSI's promotion, which keeps the value: uchar and ushort become int,
 * as the host's cc, the tests' reference, does *)
let promote = function
  | Types.Int (n, _) when n < 4 -> Types.Int (4, true)
  | t -> t

(* the usual arithmetic conversions: the wider, unsigned if either is *)
let common a b =
  match promote a, promote b with
  | Types.Int (n, s), Types.Int (m, u) -> Types.Int (max n m, s && u)
  | t, _ -> t

(* Constants folded as the tree is built: an operator on constants is
 * their value, of the operator's type, so that a constant expression
 * is a Const wherever it is written (a global's initializer, a case, an
 * array's size, p + 1's scaled 1). *)
let compute o a b : int64 option =
  match o with
  | Add -> Some (Int64.add a b)
  | Sub -> Some (Int64.sub a b)
  | Mul -> Some (Int64.mul a b)
  (* left to the program, which divides at run time: a division by
   * zero is an error only where a constant is needed (const_expr) *)
  | Div | Mod when b = Int64.zero -> None
  | Div -> Some (Int64.div a b)
  | Mod -> Some (Int64.rem a b)
  | And -> Some (Int64.logand a b)
  | Or -> Some (Int64.logor a b)
  | Xor -> Some (Int64.logxor a b)
  | Shl -> Some (Int64.shift_left a (Int64.to_int b))
  | Shr -> Some (Int64.shift_right a (Int64.to_int b))

let bin op (a : expr) (b : expr) t =
  match op, a.d, b.d with
  | A o, Const x, Const y ->
      (match compute o x y with
       | Some v -> num (fit v t) t
       | None -> mk (Bin (op, a, b)) t)
  | _ -> mk (Bin (op, a, b)) t

let un o (a : expr) t =
  match o, a.d with
  | Neg, Const v -> num (fit (Int64.neg v) t) t
  | Com, Const v -> num (fit (Int64.lognot v) t) t
  | _ -> mk (Un (o, a)) t

let scale (i : expr) t =
  let w = Types.vlong_t in
  if Types.size t = 1 then conv i w
  else bin (A Mul) (conv i w) (num (Int64.of_int (Types.size t)) w) w

let rec binary op (a : expr) (b : expr) =
  let a = rv a and b = rv b in
  match op, a.t, b.t with
  | A (Add | Sub), Types.Ptr t, Types.Int _ -> bin op a (scale b t) a.t
  | A Add, Types.Int _, Types.Ptr _ -> binary op b a
  | A Sub, Types.Ptr t, Types.Ptr _ ->
      let w = Types.vlong_t in
      bin (A Div) (bin op (conv a w) (conv b w) w)
        (num (Int64.of_int (Types.size t)) w) w
  | R _, Types.Ptr _, _ | R _, _, Types.Ptr _ ->
      let t = if Types.is_ptr a.t then a.t else b.t in
      mk (Bin (op, conv a t, conv b t)) Types.int_t
  | R _, Types.Int _, Types.Int _ ->
      let t = common a.t b.t in mk (Bin (op, conv a t, conv b t)) Types.int_t
  | A o, Types.Int _, Types.Int _ ->
      let t = if o = Shl || o = Shr then promote a.t else common a.t b.t in
      bin op (conv a t) (conv b t) t
  | _ -> Types.error ("bad operands for " ^ binop_name op)

let addr (e : expr) =
  match e.d with
  | Deref a -> { a with t = Types.Ptr e.t }
  | _ -> Types.error "not an lvalue"
let deref (e : expr) =
  let e = rv e in
  match e.t with
  | Types.Ptr t -> mk (Deref e) t
  | _ -> Types.error "not a pointer"

let assign (kind : asg) (l : expr) (r : expr) =
  match l.d with
  | Deref _ -> mk (Asg (l, conv (rv r) l.t, kind)) l.t
  | _ -> Types.error "not an lvalue"

(* x op= y: the value computed from x's, loaded once *)
let asg_op o (l : expr) r = assign Asg_update l (binary (A o) (mk Cur l.t) r)

(* a variable, as an lvalue *)
let var p t = mk (Deref (mk (Addr p) (Types.Ptr t))) t

(* a condition's value, 1 or 0; !, && and || as ?: of them *)
let one () = num Int64.one Types.int_t
let zero () = num Int64.zero Types.int_t
let truth c = mk (Cond (rv c, one (), zero ())) Types.int_t
let lnot c = mk (Cond (rv c, zero (), one ())) Types.int_t
let both a b = mk (Cond (rv a, truth b, zero ())) Types.int_t
let either a b = mk (Cond (rv a, one (), truth b)) Types.int_t

(*****************************************************************************)
(* Statements *)
(*****************************************************************************)

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
type datum = Bytes of string | Value of int * int64 | Address of Types.sym

(* what a declaration defines (a typedef, a prototype or an extern
 * nothing): a function, its label, its locals' bytes and its body; a
 * global, its label, its size, its data at their offsets (a string
 * literal one too) *)
type def =
  | Function of Types.sym * int * stmt
  | Data of Types.sym * int * (int * datum) list
