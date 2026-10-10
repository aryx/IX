(* A tiny editor, in one file, in sam's command language rather than
 * ed's. mini-ed (editors/ed/) is ed, faithfully: a buffer of lines, commands on
 * line ranges, g to loop over lines. This is what Rob Pike made of ed
 * in sam ("The Text Editor sam", "Structural Regular Expressions",
 * 1987), without the screen. Its commands, by example, and its usage
 * are [help] below, what tiny-editor -h prints.
 *
 * What makes it sam's, and why it is the core:
 *
 * - {b The buffer is one string, and dot is a range of characters}, not
 *   a line. A line is one address among others: 3 is the range of the
 *   third line, newline included; #10 the empty range before character
 *   10; /re/ the next match, wrapping; a,b from the start of a to the
 *   end of b; a;b the same, with dot set to a before b is evaluated.
 * - {b Loops are commands over matches}: x/re/cmd runs cmd with dot on
 *   each match of re in dot, y/re/cmd on the text between them, and
 *   g/re/cmd and v/re/cmd run cmd, or not, on dot as a whole. So ed's
 *   g/re/s/a/b/ is ,x/.*\n/g/re/s/a/b/, and the loops nest.
 * - {b Changes are made in parallel}: a command (with its loops) only
 *   records its changes, against the text as it was when it started,
 *   and they are applied together at the end. So every address and
 *   every match in a loop sees the old text, and the changes must come
 *   in order, not overlapping ("changes not in sequence" otherwise).
 *
 * The three at once, on a file of one line, ab ab, and the command
 * ,x/a/c/ba/ (in all of it, each a made ba):
 *
 *     the text as it was      a  b  _  a  b  \n       dot is #0,#6: the
 *                             0  1  2  3  4  5        comma's address
 *     x's matches of a        #0,#1 and #3,#4, both in the old text
 *     c records, for each     (0, 1, ba)   (3, 4, ba)        [change]
 *     applied together        b  a  b  _  b  a  b  \n        [commit]
 *     their inverse, kept     (0, 2, a)    (4, 6, a)         for u
 *
 * A change is (from, to, the new text), positions in the old text; its
 * inverse the same in the new one. Had c been made at once, the second
 * match would have been looked for in a text the first had moved, and
 * a loop whose replacement holds its own pattern (here ba holds a)
 * could go on matching what it wrote.
 *
 * Dropped from sam: the screen, several files (b B D n X Y, and
 * addresses naming a file), the mark (k and its address), ! < > |, cd.
 * Where sam's dot after a loop or a move is odd (the first change's
 * range after an x, an empty range after t), dot is here simply the
 * text the command made; after u, the dot before the command undone.
 *
 * {b Undo is cheap for the same reason}: a command's changes are a list
 * against the old text, so their inverse, each change's range in the
 * new text and the text it replaced, is a list too, applied the same
 * way ([commit]); undoing pushes the inverse of the inverse, so a redo
 * is an undo undone. The matcher is a small backtracker, leftmost-
 * longest like sam's, with a memo of (node, position) pairs; libregexp's
 * answers differ from it in corner cases (mini-ed's Regex.mli).
 *
 * Exercises, each cheap because a command's changes are a list, made
 * against the old text and applied together:
 * - several files: a buffer and a dot per file, the addresses naming a
 *   file ("name"), X/re/cmd and Y running cmd in each file whose name
 *   matches, or not (sam's);
 * - | < > (sam's): dot sent to a command, or replaced by its output, or
 *   both; a change like any other, so it composes with x;
 * - the buffer as a piece table (Bravo's, then Word's), or a rope: a
 *   change no longer copies the whole text, and undo keeps the old
 *   pieces for nothing;
 * - dots, not a dot: the matches of an x kept as a set of selections,
 *   and the next command run on each (Kakoune's and vis's editing
 *   model, grown from sam's x).
 *
 * The test: test.sh runs scripts through it and through 9base's sam -d.
 *
 * Where it stands: ix's editors are mini-ed (lines, a teletype's
 * editor), this one (ranges, still no screen) and mini-emacs (a
 * screen). The matcher is this file's own; mini-ed's Regex.mli is
 * libregexp's twin and says where the two differ. Changes recorded
 * then applied in one step are TinyDatabase's statement and TinyVCS's
 * command again: nothing is half done, and undoing is cheap.
 *
 * cs-history:
 * The line is the teletype's. QED (Butler Lampson and Peter Deutsch,
 * Berkeley, 1960s) addressed lines because a terminal printed lines;
 * Ken Thompson's QED for CTSS added regular expressions, compiled
 * to machine code (his 1968 paper), and his ed (1969) is QED cut down
 * for the first Unix. Every Unix tool that reads a line at a time
 * (grep, whose name is ed's g/re/p, sed, awk) inherits the unit.
 * Rob Pike wrote sam in the 1980s for the Blit, a terminal with a
 * bitmap and a mouse: once text is selected by sweeping it, a
 * selection has no reason to be whole lines, and the command language
 * was made to work on what the mouse can make.
 *
 * others:
 * Acme (Pike, 1994), Plan 9's other editor, kept sam's language as
 * one command, Edit. Kakoune and vis grew its x into the way of
 * editing: every command works on a set of selections, which x and y
 * refine. vi and Emacs kept lines and a point, and loop by repeating
 * a command or a macro; sed and awk are the loop over lines made a
 * program of its own.
 *
 * modern:
 * The buffer here is an OCaml string, built again whole by each
 * command that changes it: a megabyte copied for a character typed.
 * An editor with a screen cannot: Emacs has a gap buffer (the free
 * space kept where one types), Word and VS Code a piece table (the
 * file never changed, the text a list of pieces of it and of what was
 * typed), others a rope (a tree of strings). The third exercise above
 * is one of them.
 *
 * References: Rob Pike, "The Text Editor sam" (Software -- Practice and
 * Experience, 1987), for the command language, the addresses as
 * character ranges, and a command's changes applied together at its
 * end; Rob Pike, "Structural Regular Expressions" (EUUG, 1987), for x
 * and y, loops over the matches rather than over lines -- ed's g
 * turned into one loop among others; C. Crowley, "Data Structures for
 * Text Sequences" (1998), the piece table; H. Boehm, R.
 * Atkinson, M. Plass, "Ropes: an Alternative to Strings" (Software --
 * Practice and Experience, 1995). *)

(* a command, parsed: its address, its letter, what follows *)
type cmd

(* one command, done: its address found from dot, then the changes it
 * makes, all of them applied together at its end *)
val exec : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.exit; .. > -> cmd -> unit

(* the program: the files named, then the commands of its input *)
val main : < Cap.argv; Cap.stdin; Cap.stdout; Cap.stderr; Cap.open_in; Cap.open_out; Cap.exit; .. > -> unit
