(* One program, by its files (the C and ML given, and the units the ML
 * names, found: Ml_front), analyzed: its facts made by the front ends,
 * the analysis's rules of datalog/ evaluated on them in this process,
 * and the analysis's report; or (-flow, -flow-answers) its functions'
 * code as facts. Analyze_build gives it a program by its build, its
 * files as linked; Analyze_merge runs it once a program. *)

(* a file's unit: Bugs.ml, Bugs *)
val unit_of_file : string -> string

(* the standard library when none is found: the analyzer's tree's
 * lib_core (Analyze_flags.home) *)
val lib_core : Analyze_flags.t -> string

(* the program analyzed, its report printed; 1 when a file could not be
 * read. No -L: the standard library nearest the first ML file. *)
val run : < Analyze_flags.caps; .. > -> Analyze_flags.t -> int
