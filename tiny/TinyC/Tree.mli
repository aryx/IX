(* tiny-cc's tree: the expressions, typed as the parser builds them (C's
 * conversions made then, explicit in the tree), and the statements.
 * Read Types.mli first. *)

type arith = Add | Sub | Mul | Div | Mod | And | Or | Xor | Shl | Shr
type rel = Lt | Gt | Le | Ge | Eq | Ne
type binop = A of arith | R of rel
type unop = Neg | Com
(* each operator's token *)
val binops : (string * binop) list
val binop_name : binop -> string
(* x op= y's tokens *)
val asg_ops : (string * arith) list

(* where a variable is: a global's label; a local's offset in bytes
 * down from the frame's top; a parameter's up from it *)
type place = Global of Types.sym | Local of int | Param of int

(* an assignment: x = y, or x op= y, whose new value reads the old one *)
type asg = Asg_set | Asg_update

type expr = { d : desc; t : Types.ty; }
and desc =
  | Const of int64
  | Addr of place
  | Deref of expr                     (* the object at an address: an lvalue *)
  | Cur                               (* in x op= y, x's value *)
  | Un of unop * expr
  | Bin of binop * expr * expr        (* both operands of one type *)
  | Cond of expr * expr * expr        (* && || ! are made of it *)
  | Asg of expr * expr * asg          (* an lvalue, its new value *)
  | Apply of Types.sym * expr list
  | ApplyPtr of expr * expr list      (* through a function's address *)
  | Conv of expr                      (* to the expression's type *)
  | Comma of expr * expr

val mk : desc -> Types.ty -> expr
val num : int64 -> Types.ty -> expr
(* an array its address, a function its pointer *)
val rv : expr -> expr
val conv : expr -> Types.ty -> expr
(* ANSI's integer promotion, and the usual arithmetic conversions *)
val promote : Types.ty -> Types.ty
val common : Types.ty -> Types.ty -> Types.ty
(* the expressions of C's operators, their operands converted; on
 * constants, a constant (folded), the operator's type's bits kept *)
val binary : binop -> expr -> expr -> expr
(* -e and ~e, folded the same way *)
val un : unop -> expr -> Types.ty -> expr
val addr : expr -> expr
val deref : expr -> expr
val assign : asg -> expr -> expr -> expr
val asg_op : arith -> expr -> expr -> expr
(* a variable, as an lvalue *)
val var : place -> Types.ty -> expr
(* !, && and ||, as conditions *)
val lnot : expr -> expr
val both : expr -> expr -> expr
val either : expr -> expr -> expr

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
