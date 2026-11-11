(* tiny-c's C types, their sizes and alignments on TinyCPU, and the
 * names of the assembly: what every other part of the compiler uses
 * (TinyC.mli is the whole). *)

(* an error in the program compiled, its message, Common.Error (a bug a
 * Failure); TinyC.ml says where *)
val error : string -> 'a

(* the file's name, its statics' prefix *)
val unit_name : string ref

(* a global's name in the assembly, a label: a C name, or a static's,
 * made by static_sym *)
type sym = string
val static_sym : string -> sym

type ty =
  | Void
  | Int of int * bool                 (* bytes, signed *)
  | Ptr of ty
  | Arr of ty * int
  | Struct of sdef
  | Func of ty * ty list * bool       (* result, parameters, variadic *)

(* a structure, filled when its members are read *)
and sdef = {
  mutable fields : field list;
  mutable ssize : int;
  mutable salign : int;
}
and field = { fname : string; fty : ty; foff : int }

val int_t : ty
val char_t : ty
(* the compiler's wide integer, of 32 bits on TinyCPU *)
val vlong_t : ty
val int_max : int64
val uint_max : int64

val size : ty -> int
val align : ty -> int
(* [round n a]: n up to a multiple of a *)
val round : int -> int -> int
val is_int : ty -> bool
val is_ptr : ty -> bool
val unsigned : ty -> bool
(* a declared long long refused *)
val no_vlong : ty -> unit
(* the same type, a structure being itself *)
val same : ty -> ty -> bool
