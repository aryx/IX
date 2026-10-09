(* TinyLib: lib_core/commons/Common, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* What nearly every file wants, to open: so, very little.
 *
 *   Hashtbl.find_opt t x ||| 0      the value, or 0 when there is none
 *   let* x = find a in              None when there is no x, else what follows
 *   let* y = find x in Some (x, y)  (OCaml's binding operators) *)

(* an option's value, or a default: Option.value without its label *)
val ( ||| ) : 'a option -> 'a -> 'a

(* options in sequence: Option.bind, as a binding operator *)
val ( let* ) : 'a option -> ('a -> 'b option) -> 'b option
