(* Elm's Set, the three of it the playground's keyboard uses (the keys
 * down), over Set_. *)
(* ix: the playground has no interface for this module; ix has one for
 * each (what the .ml gives, no more). *)

type 'a t = 'a Set_.t

val empty : 'a t
val insert : 'a -> 'a t -> 'a t
val remove : 'a -> 'a t -> 'a t
