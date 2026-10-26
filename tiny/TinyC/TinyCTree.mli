type arith = Add | Sub | Mul | Div | Mod | And | Or | Xor | Shl | Shr
type rel = Lt | Gt | Le | Ge | Eq | Ne
type binop = A of arith | R of rel
type unop = Neg | Com
val binops : (string * binop) list
val binop_name : binop -> string
val asg_ops : (string * arith) list
type place = Global of string | Local of int | Param of int
type expr = { d : desc; t : TinyCTypes.ty; }
and desc =
    Const of int64
  | Addr of place
  | Deref of expr
  | Cur
  | Un of unop * expr
  | Bin of binop * expr * expr
  | Cond of expr * expr * expr
  | Asg of expr * expr * bool
  | Apply of string * expr list
  | ApplyPtr of expr * expr list
  | Conv of expr
  | Comma of expr * expr
val mk : desc -> TinyCTypes.ty -> expr
val num : int64 -> TinyCTypes.ty -> expr
val rv : expr -> expr
val conv : expr -> TinyCTypes.ty -> expr
val promote : TinyCTypes.ty -> TinyCTypes.ty
val common : TinyCTypes.ty -> TinyCTypes.ty -> TinyCTypes.ty
val binary : binop -> expr -> expr -> expr
val addr : expr -> expr
val deref : expr -> expr
val assign : bool -> expr -> expr -> expr
val asg_op : arith -> expr -> expr -> expr
val var : place -> TinyCTypes.ty -> expr
val lnot : expr -> expr
val both : expr -> expr -> expr
val either : expr -> expr -> expr
type stmt =
    Expr of expr
  | Block of stmt list
  | If of expr * stmt * stmt option
  | Do of stmt * expr
  | For of expr option * expr option * expr option * stmt
  | Switch of expr * expr * stmt
  | Case of int64 option
  | Break
  | Continue
  | Return of expr option
