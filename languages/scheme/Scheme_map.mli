(* Scheme_map: a map that is a value, for the machine's store and its
   globals (Scheme_eval).

   The machine's state is a value: a step gives a new state and leaves
   the old one as it was, which is what lets a host keep a state and
   come back to it. So its store cannot be a Hashtbl; it is a balanced
   binary tree (an AVL tree: Adelson-Velsky and Landis, 1962), where
   adding a binding copies the path from the root to it, some twenty
   nodes of a million, and shares the rest.

   The keys are compared by [compare], whatever their type: the
   playground's two maps are OCaml's Map.Make (String) and Map.Make
   (Int), a functor, which mini-ml has not. *)

type ('k, 'v) t

val empty : ('k, 'v) t

(* [add k v m]: [m] with [k] bound to [v], in place of what it was
   bound to *)
val add : 'k -> 'v -> ('k, 'v) t -> ('k, 'v) t

(* Not_found if [k] is not bound *)
val find : 'k -> ('k, 'v) t -> 'v
val find_opt : 'k -> ('k, 'v) t -> 'v option

(* every binding, by increasing key *)
val bindings : ('k, 'v) t -> ('k * 'v) list
