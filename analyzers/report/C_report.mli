(* A C program's analysis said (mini-analyze's report, Analyze.mli):
 * each call through a pointer, where, through what, and the functions
 * it may reach (points_to/'s target); then what bugs/pointers.dl finds, a free
 * of what no allocator gave, a function returning its frame's address.
 * And the facts as Facts finds them given to Datalog as values, with
 * bugs/pointers.dl's heap, local and literal of each place. Both of
 * mini-analyze's roads use it: the native one, whose rules
 * mini-datalog's evaluator runs, and the .NET one, whose rules are
 * compiled (analyzers/dotnet/Analyze_rt). *)

(* a global line of a file read with its #includes: the file and its
 * own line, by the history (the oldest first) *)
val locate : (string option * int) list -> int -> (string * int) option

(* a symbol's text *)
val name : Datalog.t -> int -> string

(* s after pre, if it starts so *)
val prefix : string -> string -> string option

(* a place's kind, by Facts's names: an allocator's, a string's, a
 * function's local (the function, the name), a global's *)
type place = Heap | Literal | Local of string * string | Global

val place : string -> place

(* a fact added, a tuple of symbols, and bugs/pointers.dl's kinds of
 * its places *)
val given : Datalog.t -> string -> Facts.arg list -> unit

(* a function's global line, its file's and its line there *)
val where : string -> int -> string * int

(* a variable of a function said as the C says it, a temporary by what
 * it was loaded from (the facts' assign_load_field, assign_array_elt) *)
val through : (string, string * string) Hashtbl.t -> string -> string -> string

(* the report, on the facts and the rules' answers *)
val report : < Cap.stdout; .. > -> Datalog.t -> unit
