(* tiny-cc's C types, their sizes and alignments on TinyCPU, and the
 * names used in the assembly. Every other module of the compiler uses
 * them (TinyC.mli describes the whole compiler). *)

(* Raises Common.Error, for an error in the program being compiled (a
 * bug in tiny-cc raises Failure); TinyC.ml prints where it is. *)
val error : string -> 'a

val unit_name : string ref            (* the prefix of the file's statics *)

(* A global's label is its C name, or the name static_sym gives for a
 * static. *)
type sym = string
val static_sym : string -> sym

type ty =
  | Void
  | Int of int * bool                 (* bytes, signed *)
  | Ptr of ty
  | Arr of ty * int
  | Struct of sdef
  | Func of ty * ty list * bool       (* result, parameters, variadic *)

(* Filled in when its members are read. *)
and sdef = {
  mutable fields : field list;
  mutable ssize : int;
  mutable salign : int;
}
and field = { fname : string; fty : ty; foff : int }

val int_t : ty
val char_t : ty
val vlong_t : ty                      (* the wide integer, 32 bits here *)
val int_max : int64
val uint_max : int64

val size : ty -> int
val align : ty -> int
val round : int -> int -> int         (* rounds n up to a multiple of a *)
val is_int : ty -> bool
val is_ptr : ty -> bool
val unsigned : ty -> bool
val no_vlong : ty -> unit             (* refuses a long long variable *)
(* A structure is the same only as itself. *)
val same : ty -> ty -> bool
