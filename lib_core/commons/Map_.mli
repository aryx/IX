(* Map_: a map that is a value, like OCaml's Map but without its functor,
   which mini-ml does not have (Set_ is OCaml's Set made the same way).
   The keys are compared by [compare], whatever their type. It is for
   the programs, copied from the author's playground, that used
   Map.Make: a Scheme machine's store and its globals (Scheme_eval),
   and a sheet's cells (Sheet).

   A map is a value: adding a binding gives a new map and leaves the
   old one as it was, and that is what lets a machine keep a state and
   come back to it. So it is not a Hashtbl but a balanced binary tree
   (an AVL tree, from Adelson-Velsky and Landis, 1962). Adding a
   binding copies the path from the root to it, some twenty nodes out
   of a million, and shares the rest.

   A node has its left tree (the smaller keys), a binding, its right
   tree (the larger keys) and its height. In a plain binary tree, keys
   added in order would make a list, and a search would be as long as
   the list. Here the two sides of a node never differ by more than 1
   in height. When an addition makes them differ by 2, the node is
   turned. This is a *rotation*: it keeps the keys in order and takes
   a level off the tall side. Adding 1, 2, then 3:

       1               1                    2
        \               \                  / \
         2               2                1   3
                          \
                           3
                    1's right side is     turned to the left:
                    2 higher than its     2 is the root, 1 its
                    left: not allowed     left side

   (When a key went left then right, as with 3, then 1, then 2, it
   takes two turns, which is [balance]'s second case; the result is
   the same tree.) With that rule a tree of n bindings is at most
   about 1.44 log2 n high, so [find], [add] and [remove] look at a few
   tens of nodes, whatever order the keys came in.

   Here is what sharing means, with [add 4] on that tree. The two
   nodes on the way to 4 are made again, and node 1 is the old tree's
   node, used in both trees:

       before:   2             after:   2'
                / \                    / \
               1   3                  1   3'       1: the same node
                                           \
                                            4

   others:
   OCaml's own Map is this tree with a looser rule: its sides may
   differ by 2, so it turns less often, and the tree is a little
   higher. The red-black tree (Bayer, 1972; named by Guibas and
   Sedgewick, 1978) keeps one bit in each node where this one keeps a
   height; it is what the usual C++ std::map and the Linux kernel use.
   The stdlib's Hashtbl finds faster and is changed in place, but it
   has no order, and no old version to come back to.

   design:
   A structure that is never changed can be shared without care: by
   two states of a machine, by an undo's history, by two threads.
   The price is the path copied at each addition, which the collector
   takes back when the old map is dropped. It is the usual trade of
   a functional language (Okasaki's book is about it).

   References: G. M. Adelson-Velsky and E. M. Landis, "An algorithm
   for the organization of information" (1962, in Russian), for the
   balance by heights and the rotations; OCaml's stdlib, map.ml (the
   function bal); Chris Okasaki, "Purely Functional Data Structures"
   (1998). *)

type ('k, 'v) t

val empty : ('k, 'v) t

(* [add k v m] is [m] with [k] bound to [v], in place of what it was
   bound to *)
val add : 'k -> 'v -> ('k, 'v) t -> ('k, 'v) t

(* Not_found if [k] is not bound *)
val find : 'k -> ('k, 'v) t -> 'v
val find_opt : 'k -> ('k, 'v) t -> 'v option

(* [m] without the binding of [k]; [m] itself if [k] has none *)
val remove : 'k -> ('k, 'v) t -> ('k, 'v) t

(* Every binding, by increasing key *)
val bindings : ('k, 'v) t -> ('k * 'v) list
