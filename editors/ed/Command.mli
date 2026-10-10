(* The command loop, ed.c's commands(), and every command.
 *
 * A command is read and run at once: [loop] reads the addresses
 * (Address.range), then the command's letter, and each command reads
 * the rest of its line itself -- a file name, a pattern and a
 * replacement, the text of a until ".". The loop returns at the end of
 * the input, and g runs it again on its command list, once per marked
 * line (Input.set_global).
 *
 *     1,$s/x/X/g          every x on every line
 *     g/^#/d              the comment lines deleted, in one pass
 *     /main/;/}/m0        from the next main to the } after it, moved first
 *
 * {b s}, the only complicated command: the n-th match (s2/a/X/), all
 * the later ones (g), the empty match (s/x*\/-/g gives -a-b-c-: after
 * an empty match the search moves one character on), & and \1-\8 in
 * the replacement, and a \ then a newline in it, which makes several
 * lines of one; the last line changed is kept, with the one it
 * replaced, for u.
 *
 * Errors are Input.Error, caught by [run], which prints ? (or ?file)
 * and starts the loop again, after Input.recover.
 *
 * {b g}, the command that runs commands. It goes over the buffer
 * twice: first every line that matches is marked (Text's [global]),
 * then, from the top again, each line still marked is made dot, its
 * mark taken off, and the command list run on it. The list may
 * delete, move or add lines, the marked ones too, which is why they
 * are marked first and not counted: a mark is on the line, not at a
 * number (Text.mli).
 *
 *     with x1 y x2:   g/x/s//X/\
 *                     a\
 *                     new          X1 new y X2 new: a list of two
 *                                  commands, a \ at each line's end
 *
 * A line at a time, addresses then a letter: the shape is QED's, and
 * came to ed through Ken Thompson's QED (the history: CLI).
 *
 * cs-history:
 * g/re/p, the global command with p as its list, gave a program its
 * name. Printing the lines of a file that match was so common, and
 * the files larger than ed's buffer, that Thompson took ed's regular
 * expression code out into a program of its own, grep (in the fourth
 * edition's manual, 1973). Lee McMahon's sed, soon after, did the
 * same for s and the other commands: ed's, applied to each line of
 * a stream as it passes, with no buffer and so no address that looks
 * back. Here they are Grep and Sed, on the same Regex.
 *
 * others:
 * u undoes the last s only, on the one line it changed (Text's undo
 * pair), as Plan 9's ed; GNU ed's u takes back the whole last
 * command, whatever it was, and u again redoes it; sam and mini-emacs
 * keep every change (the Text of mini-emacs).
 *
 * References: principia's ed.c (commands); M. D. McIlroy, "A Research
 * UNIX Reader: Annotated Excerpts from the Programmer's Manual,
 * 1971-1986" (1987), for grep's and sed's origins; QED's papers: CLI. *)

type t

type caps = < Cap.fork; Cap.exec; Cap.wait; Cap.open_in; Cap.open_out >

(* [create caps input ~verbose ~filter]: verbose is ed.c's vflag (off
 * with -: no counts, no !, q and e never complain), filter -o *)
val create : < caps; .. > -> Input.t -> verbose:bool -> filter:bool -> t

(* [run t ~file]: the loop, until q or the end of the input, after a
 * first command as ed.c's globp: r, to read [file] (the one named on
 * the command line), or a for -o; the loop starts again after each
 * error, as ed.c's setjmp does *)
val run : t -> file:string option -> unit

(* the buffer written to ed.hup, for a hangup *)
val rescue : t -> unit
