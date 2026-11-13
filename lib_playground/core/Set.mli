(* Elm's Set, reduced to the three values that the playground's keyboard
 * uses (it keeps the keys that are down), and built over Set_. *)
(* ix: the playground has no interface for this module; ix has one for
 * each module, which gives what the .ml gives and no more. *)

type 'a t = 'a Set_.t

val empty : 'a t
val insert : 'a -> 'a t -> 'a t
val remove : 'a -> 'a t -> 'a t
