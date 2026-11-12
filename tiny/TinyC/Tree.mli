(* tiny-cc's tree: the expressions and the statements. Expressions are
 * typed as the parser builds them, and C's implicit conversions are
 * made explicit in the tree at that point. Read Types.mli first. *)

type arith = Add | Sub | Mul | Div | Mod | And | Or | Xor | Shl | Shr
type rel = Lt | Gt | Le | Ge | Eq | Ne
type binop = A of arith | R of rel
type unop = Neg | Com
val binops : (string * binop) list    (* by token *)
val binop_name : binop -> string
val asg_ops : (string * arith) list   (* the tokens of x op= y *)

(* A local is in bytes down from the top of the frame, a parameter up. *)
type place = Global of Types.sym | Local of int | Param of int

(* Asg_update is x op= y, whose new value reads the old one. *)
type asg = Asg_set | Asg_update

type expr = { d : desc; t : Types.ty; }
and desc =
  | Const of int64
  | Addr of place
  | Deref of expr                     (* the object at an address: an lvalue *)
  | Cur                               (* the value of x, in x op= y *)
  | Un of unop * expr
  | Bin of binop * expr * expr        (* both operands of one type *)
  | Cond of expr * expr * expr        (* && || ! are made with it *)
  | Asg of expr * expr * asg          (* an lvalue, its new value *)
  | Apply of Types.sym * expr list
  | ApplyPtr of expr * expr list      (* through a function's address *)
  | Conv of expr                      (* to the type of the Conv *)
  | Comma of expr * expr

val mk : desc -> Types.ty -> expr
val num : int64 -> Types.ty -> expr
(* An array becomes its address, a function its pointer. *)
val rv : expr -> expr
val conv : expr -> Types.ty -> expr
(* ANSI's integer promotion, and the usual arithmetic conversions. *)
val promote : Types.ty -> Types.ty
val common : Types.ty -> Types.ty -> Types.ty
(* The operands converted; constants folded, truncated to the bits of
 * the operator's type. un folds the same way. *)
val binary : binop -> expr -> expr -> expr
val un : unop -> expr -> Types.ty -> expr
val addr : expr -> expr
val deref : expr -> expr
val assign : asg -> expr -> expr -> expr
val asg_op : arith -> expr -> expr -> expr
val var : place -> Types.ty -> expr   (* as an lvalue *)
(* !, && and ||, built as conditionals. *)
val lnot : expr -> expr
val both : expr -> expr -> expr
val either : expr -> expr -> expr

type stmt =
  | Expr of expr
  | Block of stmt list
  | If of expr * stmt * stmt option
  | Do of stmt * expr
  | For of expr option * expr option * expr option * stmt   (* while too *)
  | Switch of expr * expr * stmt      (* a temporary, the value, the body *)
  | Case of int64 option              (* None for default *)
  | Break
  | Continue
  | Return of expr option

(* A piece of a global's initial value. *)
type datum = Bytes of string | Value of int * int64 | Address of Types.sym

(* A typedef, a prototype or an extern defines nothing. A Function has
 * the bytes of its locals; a Data (a string literal too) its size and
 * its data at their offsets. *)
type def =
  | Function of Types.sym * int * stmt
  | Data of Types.sym * int * (int * datum) list
