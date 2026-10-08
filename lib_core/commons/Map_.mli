(* Map_: a map that is a value, as OCaml's Map without its functor
   (which mini-ml has not; Set_ is its Set the same way): the keys are
   compared by [compare], whatever their type. For what a program
   copied from the author's playground made with Map.Make: a Scheme
   machine's store and its globals (Scheme_eval), a sheet's cells
   (Sheet).

   A value: adding a binding gives a new map and leaves the old one as
   it was, which is what lets a machine keep a state and come back to
   it. So it is no Hashtbl but a balanced binary tree (an AVL tree:
   Adelson-Velsky and Landis, 1962), where adding a binding copies the
   path from the root to it, some twenty nodes of a million, and
   shares the rest. *)

type ('k, 'v) t

val empty : ('k, 'v) t

(* [add k v m]: [m] with [k] bound to [v], in place of what it was
   bound to *)
val add : 'k -> 'v -> ('k, 'v) t -> ('k, 'v) t

(* Not_found if [k] is not bound *)
val find : 'k -> ('k, 'v) t -> 'v
val find_opt : 'k -> ('k, 'v) t -> 'v option

(* [m] without [k]'s binding; [m] if it has none *)
val remove : 'k -> ('k, 'v) t -> ('k, 'v) t

(* every binding, by increasing key *)
val bindings : ('k, 'v) t -> ('k * 'v) list
