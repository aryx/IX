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
   shares the rest.

   A node is its left tree (the smaller keys), a binding, its right
   tree (the larger ones) and its height. Keys added in order would
   make a list of a plain binary tree, and a search as long as the
   list. Here a node's two sides never differ by more than 1 in
   height: when an addition makes them differ by 2, the node is
   turned, a *rotation*, which keeps the keys' order and takes a
   level off the tall side. Adding 1, 2, then 3:

       1               1                    2
        \               \                  / \
         2               2                1   3
                          \
                           3
                    1's right side is     turned to the left:
                    2 higher than its     2 is the root, 1 its
                    left: not allowed     left side

   (a key that went left then right, 3 then 1 then 2, takes two
   turns: [balance]'s second case; the answer is the same tree).
   With that rule a tree of n bindings is at most about 1.44 log2 n
   high, so [find], [add] and [remove] look at a few tens of nodes
   whatever the order the keys came in.

   And what sharing means, [add 4] on that tree: the two nodes on
   the way to 4 are made again, and 1 is the old tree's, in both:

       before:   2             after:   2'
                / \                    / \
               1   3                  1   3'       1: the same node
                                           \
                                            4

   others:
   OCaml's own Map is this tree with a looser rule: its sides may
   differ by 2, which turns less often for a tree a little higher.
   The red-black tree (Bayer, 1972; named by Guibas and Sedgewick,
   1978) keeps a bit a node where this one keeps a height, and is
   what the usual C++ std::map and the Linux kernel use. A Hashtbl (the
   stdlib's) finds faster and is changed in place: it has no order,
   and no old version to come back to.

   design:
   A structure that is never changed can be shared without care: by
   two states of a machine, by an undo's history, by two threads.
   The price is the path copied at each addition, which the collector
   takes back when the old map is dropped. It is the usual trade of
   a functional language (Okasaki's book is about it).

   References: G. M. Adelson-Velsky and E. M. Landis, "An algorithm
   for the organization of information" (1962, in Russian): the
   balance by heights and the rotations; OCaml's stdlib, map.ml (the
   function bal); Chris Okasaki, "Purely Functional Data Structures"
   (1998). *)

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
