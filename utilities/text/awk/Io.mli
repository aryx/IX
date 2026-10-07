(* What awk reads and writes: the records of the files of ARGV (lib.c's
 * getrec and readrec), and the files and commands a program names
 * (run.c's table: print > "f", "cmd" | getline, close). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr; Cap.fork; Cap.exec; Cap.wait; Cap.env >

(* how a name is used: one name is one stream until it is closed, and
 * > then >> go on in the same file *)
type mode = Read | Write | Append | Command_in | Command_out

type stream

(* the name's stream, opened if it is not; None if it cannot be *)
val open_ : < caps; .. > -> mode -> string -> stream option
(* a stream being written under that name, if any (fflush's) *)
val written : string -> stream option

val write : stream -> string -> unit
val flush : stream -> unit
val stdout : stream
(* (what is said of an error is kept too, to the end or to a print > "/dev/stderr") *)
val stderr : stream
val is_stdout : stream -> bool
(* every stream being written *)
val flush_all : unit -> unit

(* the name's streams closed; a command is waited for *)
val close : < caps; .. > -> string -> unit
val close_all : < caps; .. > -> unit

(* a command run by the shell, to its end: 0, or 1 if it failed *)
val system : < caps; .. > -> string -> int

(* the next record of a stream, by RS (a character; empty: a
 * paragraph); None at its end *)
val read_record : stream -> string option

(* the next record of the input: the files ARGV names in turn (a
 * var=value among them is an assignment done when it is reached; - or
 * none: the standard input), FILENAME, NR and FNR kept; None at the end *)
val next_record : < caps; .. > -> string option
(* the rest of the current file is passed *)
val next_file : unit -> unit

(* name=value: is an argument one, and the assignment (the value's
 * escapes done) *)
val is_assignment : string -> bool
val assign : string -> unit
(* a value's escapes done (-F's too) *)
val unquote : string -> string
