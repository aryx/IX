(* The runtime of mini-datalog -dotnet's programs (Compile_il): the
 * calls the compiled rules make on mini-datalog's relations, and the
 * program's entry. Compiled by mini-ml -dotnet with mini-datalog's
 * units into datalog_rt.dll, beside the program; .NET only (dune
 * checks its types, the native mini-datalog has no use of it).
 *
 * Its functions are the compiled code's: their types are what mini-ml
 * makes of them (an int an int64, a relation the class
 * Datalog/relation), and the code names them so. *)

(* the program: the rules' texts (file, text, file, text...), the
 * queries, the rules compiled (run once the facts given are read);
 * the answers printed *)
val main : string array -> string array -> (Datalog.t -> unit) -> unit

(* a relation, a constant's symbol by its text *)
val relation : Datalog.t -> string -> int -> Datalog.relation
val symbol : Datalog.t -> string -> int

(* the tuples: their number, the last round's new ones' range, a
 * tuple's column *)
val count : Datalog.relation -> int
val delta_from : Datalog.relation -> int
val delta_to : Datalog.relation -> int
val get : Datalog.relation -> int -> int -> int

(* the numbers of the tuples whose mask's columns are the keys (an
 * index, made the first time); a tuple there; none such (a negation:
 * the mask's columns, 0 for none) *)
val lookup : Datalog.relation -> int -> int array -> int array
val mem : Datalog.relation -> int array -> bool
val absent : Datalog.relation -> int -> int array -> bool

(* two symbols in the standard order (numbers, then atoms) *)
val compare : Datalog.t -> int -> int -> int

(* a tuple added, if new *)
val add : Datalog.relation -> int array -> unit

(* a stratum's rounds: its heads' ranges set; a round's end, true if a
 * head has new tuples; the stratum's end *)
val begin_stratum : Datalog.relation array -> unit
val turn : Datalog.relation array -> bool
val end_stratum : Datalog.relation array -> unit
