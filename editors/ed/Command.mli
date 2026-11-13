(* The command loop, ed.c's commands(), and every command.
 *
 * A command is read and run at once: the loop reads the addresses
 * (Address.range), then the command's letter, and each command reads
 * the rest of its line itself: a file name, a pattern and a
 * replacement, or the text of a until ".". The loop returns at the end
 * of the input, and g runs it again on its command list, once per
 * marked line (Input.set_global).
 *
 *     1,$s/x/X/g          every x on every line
 *     g/^#/d              the comment lines deleted, in one pass
 *     /main/;/}/m0        from the next main to the } after it, moved first
 *
 * {b s} is the only complicated command. It handles:
 * - the n-th match (s2/a/X/), and all the later ones (g);
 * - the empty match (s/x*\/-/g gives -a-b-c-: after an empty match
 *   the search moves one character on);
 * - & and \1-\8 in the replacement;
 * - a \ then a newline in the replacement, which makes several lines
 *   of one.
 * The last line changed is kept, with the one it replaced, for u.
 *
 * Errors are Input.Error, caught by [run], which prints ? (or ?file)
 * and starts the loop again, after Input.recover.
 *
 * {b g}, the command that runs commands. It goes over the buffer
 * twice: first every line that matches is marked (Text's [global]),
 * then, from the top again, each line still marked is made dot, its
 * mark is taken off, and the command list is run on it. The list may
 * delete, move or add lines, the marked ones too, which is why they
 * are marked first and not counted: a mark is on the line, not at a
 * number (Text.mli).
 *
 *     with x1 y x2:   g/x/s//X/\
 *                     a\
 *                     new          gives X1 new y X2 new: the list
 *                                  has two commands, with a \ at the
 *                                  end of each line
 *
 * A command is a line, with addresses and then a letter. This shape is
 * QED's, and it came to ed through Ken Thompson's QED (CLI has the
 * history).
 *
 * cs-history:
 * g/re/p, the global command with p as its list, gave a program its
 * name. Printing the lines of a file that match was so common, and
 * the files were so often larger than ed's buffer, that Thompson took
 * ed's regular expression code out into a program of its own, grep
 * (in the fourth edition's manual, 1973). Lee McMahon's sed, soon
 * after, did the same for s and the other commands: they are ed's,
 * applied to each line of a stream as it passes, with no buffer, and
 * so with no address that looks back. Here they are Grep and Sed, on
 * the same Regex.
 *
 * others:
 * u undoes the last s only, on the one line it changed (Text's undo
 * pair), as in Plan 9's ed. GNU ed's u takes back the whole last
 * command, whatever it was, and u again redoes it. sam and mini-emacs
 * keep every change (the Text of mini-emacs).
 *
 * References: principia's ed.c (commands); M. D. McIlroy, "A Research
 * UNIX Reader: Annotated Excerpts from the Programmer's Manual,
 * 1971-1986" (1987), for grep's and sed's origins; for QED's papers,
 * see CLI. *)

type t

type caps = < Cap.fork; Cap.exec; Cap.wait; Cap.open_in; Cap.open_out >

(* [create caps input ~verbose ~filter]: [verbose] is ed.c's vflag. It
 * is off with - or -o, and then there are no counts and no !, and q and e
 * never complain. [filter] is -o. *)
val create : < caps; .. > -> Input.t -> verbose:bool -> filter:bool -> t

(* [run t ~file] runs the loop until q or the end of the input. Before
 * it, a first command is given as ed.c's globp: r, to read [file] (the
 * one named on the command line), or a for -o. The loop starts again
 * after each error, as ed.c's setjmp makes it do. *)
val run : t -> file:string option -> unit

(* writes the buffer to ed.hup, for a hangup *)
val rescue : t -> unit
