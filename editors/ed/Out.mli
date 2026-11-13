(* Printing, as ed.c's putchr does it: a line at a time to standard
 * output (or to standard error with -o, so that w can write to
 * standard output).
 *
 * With [listf] (the l command), a line is printed unambiguously:
 *
 *     "a\tb\\c\001d é"    ->   a\tb\\c\x0001d \x00e9
 *     "x ", 70 x's        ->   folded after 64 columns with a \, a
 *                              newline and a tab; a final blank gets \n
 *
 * and with [listn] (n) each line gets its number and a tab first --
 * both through the same putchr, so l and n together escape that tab
 * too ("1\ta\tb", checked on 9base). *)

val to_stderr : bool ref
val listf : bool ref
val listn : bool ref

(* prints a character (a rune), escaped as l wants it when [listf] is
 * set *)
val putchr : int -> unit

(* [putst s] prints s and a newline, from column 0 (s is a line of the
 * buffer, or a message) *)
val putst : string -> unit

(* prints a number, in decimal *)
val putd : int -> unit

(* writes what is buffered (before a fork, and at the end) *)
val flush : unit -> unit
