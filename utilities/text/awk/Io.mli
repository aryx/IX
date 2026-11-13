(* This module is what awk reads and writes: the records of the files
 * of ARGV (lib.c's getrec and readrec), and the files and commands
 * that a program names (run.c's table: print > "f", "cmd" | getline,
 * close). *)

type caps =
  < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr; Cap.fork;
    Cap.exec; Cap.wait; Cap.env; Cap.clock; Cap.pipe >

(* how a name is used. One name is one stream until it is closed, so
 * > then >> go on writing in the same file. *)
type mode = Read | Write | Append | Command_in | Command_out

type stream

(* the name's stream, opened if it is not; None if it cannot be *)
val open_ : < caps; .. > -> mode -> string -> stream option
(* the stream being written under that name, if any (for fflush) *)
val written : string -> stream option

val write : stream -> string -> unit
val flush : stream -> unit
val stdout : stream
(* (what is said of an error is kept too, until the end or until a
 * print > "/dev/stderr") *)
val stderr : stream
val is_stdout : stream -> bool
(* every stream being written *)
val flush_all : unit -> unit

(* close the name's streams; a command is waited for *)
val close : < caps; .. > -> string -> unit
val close_all : < caps; .. > -> unit

(* run a command by the shell, to its end, and give 0, or 1 if it
 * failed *)
val system : < caps; .. > -> string -> int

(* the next record of a stream, by RS (a character, or a paragraph when
 * RS is empty), or None at its end *)
val read_record : stream -> string option

(* the next record of the input, or None at the end. The input is the
 * files that ARGV names, in turn. A var=value among them is an
 * assignment done when it is reached, and - or no file at all means
 * the standard input. FILENAME, NR and FNR are kept up to date. *)
val next_record : < caps; .. > -> string option
(* skip the rest of the current file *)
val next_file : unit -> unit

(* name=value: whether an argument is one, and doing the assignment
 * (with the value's escapes done) *)
val is_assignment : string -> bool
val assign : string -> unit
(* a value with its escapes done (-F's value too) *)
val unquote : string -> string
