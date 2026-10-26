val error : string -> 'a
val unit_name : string ref
type ty =
    Void
  | Int of int * bool
  | Ptr of ty
  | Arr of ty * int
  | Struct of sdef
  | Func of ty * ty list * bool
and sdef = {
  mutable fields : (string * ty * int) list;
  mutable ssize : int;
  mutable salign : int;
}
val int_t : ty
val long_t : ty
val char_t : ty
val int_max : int64
val size : ty -> int
val align : ty -> int
val round : int -> int -> int
val is_int : ty -> bool
val is_ptr : ty -> bool
val unsigned : ty -> bool
val no_vlong : ty -> unit
val same : ty -> ty -> bool
