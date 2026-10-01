(* What nearly every file wants, to open: so, very little.
 *
 *   Hashtbl.find_opt t x ||| 0      the value, or 0 when there is none *)

(* an option's value, or a default: Option.value without its label *)
val ( ||| ) : 'a option -> 'a -> 'a
