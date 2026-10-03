# lib_core/collections

The collections of the OCaml stdlib that mini-ml compiles ix with:
`List`, `Array`, `Hashtbl`, `Queue`, `Stack`, `Seq`.

**No `Set`, no `Map`.** OCaml's are functors (`Set.Make`, `Map.Make`),
and neither mini-ml nor ocaml-light has functors. ix's programs use
instead:

- [`commons/Set_`](../commons/Set_.mli): OCaml's `set.ml` without its
  functor, a set of any type ordered by `compare` (`'a Set_.t`);
- `Hashtbl`, or a sorted association list, where OCaml's code would
  use a `Map`.

ocaml-light's own `Set` and `Map` (polymorphic too, but under OCaml's
names and with another interface than OCaml 4.14's) were here until
2026-10-04; no program of ix named them, and a file that did would not
have compiled with OCaml, where ix must build too.
