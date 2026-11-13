(* What nearly every file wants when it opens this module. Because every
 * file opens it, it holds very little.
 *
 *   Hashtbl.find_opt t x ||| 0      the value, or 0 when there is none
 *   let* x = find a in              None when there is no x, else what follows
 *   let* y = find x in Some (x, y)  (OCaml's binding operators) *)

(* The value of an option, or a default. It is Option.value without its
 * label. *)
val ( ||| ) : 'a option -> 'a -> 'a

(* Options in sequence: Option.bind, as a binding operator *)
val ( let* ) : 'a option -> ('a -> 'b option) -> 'b option

(* What a tool finds wrong in its input (a command, a file, a query).
 * The tool's command loop or main tells it to the person. A bug raises
 * a Failure instead. *)
exception Error of string
val error : string -> 'a
