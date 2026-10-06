type t
type u = A | B of int and 'a v = | D of 'a and ('a, 'b, 'c) w
type d = { n : int; mutable m : int } [@@deriving show eq]
external three : int -> int -> int = "three_byte" "three" "noalloc";;
val x : t;;
val caps : < > -> < Cap.stdout > -> < Cap.stdout; Cap.stdin; .. > -> unit
module M : sig end
module N : sig val x : t;; val y : t end
