(* Several programs analyzed as one answer: each run of mini-analyze
 * writes what it says of its program as facts (-summary), and the
 * merge's rules combine them (datalog/dead_all.dl: what every program
 * that has the file says dead; datalog/said_all.dl: the other analyses'
 * lines, any program's, -exn's by program). The programs of a library's
 * file (Caller_finder's, or the manifests that link it), or those given
 * (Analyze_build). *)

(* a fact as a line, for -facts and -summary *)
val line : string -> Ix_analyze_c.Facts.arg list -> string

(* the analysis's flag (-dead), "" for Calls *)
val flag : Analyze_flags.analysis -> string

(* [summary caps out prog given reports said]: the run's facts, in out:
 * the files it reads (has) and reports on (own), an implementation
 * whose interface is elsewhere (implements), a file outside the project
 * (outside: no dune-project above it), each -dead report (report, or
 * report_one when only this program's is kept: a [@@for_testing]
 * function it calls), another analysis's lines (said) and the units it
 * could not read (unread) *)
val summary :
  < Cap.open_in; Cap.open_out; Cap.readdir; .. > -> string -> string ->
  string list -> (string * int * string * string * Dead_report.kept) list ->
  string list -> unit

(* Sys.is_directory's, false for what is not there (a flag, a typo) *)
val directory : < Cap.readdir; .. > -> string -> bool

(* words on lines within the console's 80 columns, each after a blank *)
val wrapped : string list -> string list

(* [merged_runs caps flags file mains]: each main (its name or "", its
 * file, its own flags) run by mini-analyze itself with the flags given,
 * at once; their summaries merged; the merged lines printed (of file
 * alone when given), then the programs. A run's report is left in the
 * run's directory if it failed; a unit not read is said; 1 then. *)
val merged_runs :
  < Analyze_flags.caps; .. > -> Analyze_flags.t -> string option ->
  (string * string * string list) list -> int
