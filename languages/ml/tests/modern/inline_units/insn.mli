(* a type with inline records, its labels shared, declared here and
 * used by another unit *)

type t =
  | Mov of { rd : int; imm : int }
  | Add of { rd : int; rn : int; rm : int }
  | Branch of { target : int; mutable taken : bool }
  | Nop

val show : t -> string
val decode : int -> t
