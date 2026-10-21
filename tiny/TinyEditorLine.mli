(* A tiny editor, in one file, that uses sam's command language rather
 * than ed's. mini-ed (editors/ed/) is a faithful copy of ed: a buffer
 * of lines, commands that apply to ranges of lines, and g to loop over
 * lines. This editor is what Rob Pike made of ed when he designed sam
 * ("The Text Editor sam", "Structural Regular Expressions", 1987), but
 * without the screen. The commands, with examples, and the usage are
 * the [help] string of the .ml, which is what ed -h prints.
 *
 * It is tiny-kernel's ed (and sam, the same program by another name):
 * as TinyShell.ml, it asks the system only through TinyLibSystem.
 *
 * Three ideas make it sam rather than ed, and they are the core of
 * this file:
 *
 * - {b The buffer is one string, and dot is a range of characters},
 *   not a line. A line is just one kind of address among others: 3 is
 *   the range covering the third line, including its newline; #10 is
 *   the empty range just before character 10; /re/ is the next match
 *   of re, wrapping around; a,b goes from the start of a to the end of
 *   b; a;b is the same, but dot is set to a before b is evaluated.
 * - {b Loops are commands that run over matches}: x/re/cmd runs cmd
 *   with dot set to each match of re inside dot, and y/re/cmd runs it
 *   on the text between the matches. g/re/cmd and v/re/cmd run cmd on
 *   dot as a whole, or not, depending on whether dot matches re. So
 *   ed's g/re/s/a/b/ becomes ,x/.*\n/g/re/s/a/b/, and loops can nest.
 * - {b Changes are made in parallel}: a command (including its loops)
 *   only records its changes, expressed against the text as it was
 *   when the command started, and all the changes are applied together
 *   at the end. So every address and every match in a loop sees the
 *   old text. The changes must come in order and must not overlap
 *   (otherwise the error is "changes not in sequence").
 *
 * Here are the three ideas at work on a file with the single line
 * "ab ab" and the command ,x/a/c/ba/ (in the whole file, replace each
 * a by ba):
 *
 *     the text before        a  b  _  a  b  \n       dot is #0,#6, set
 *                            0  1  2  3  4  5        by the comma address
 *     x finds the a's        #0,#1 and #3,#4, both in the old text
 *     c records a change     (0, 1, ba)   (3, 4, ba)        [change]
 *     for each match
 *     both applied at once   b  a  b  _  b  a  b  \n        [commit]
 *     their inverses, kept   (0, 2, a)    (4, 6, a)         for u
 *
 * A change is a triple (from, to, new text), where the positions refer
 * to the old text; its inverse is the same kind of triple, with
 * positions in the new text. If c had made its change immediately, the
 * second match would have been searched in a text already shifted by
 * the first change. Worse, a loop whose replacement contains its own
 * pattern (here ba contains a) could keep matching what it just wrote.
 *
 * What is dropped from sam: the screen; multiple files (the b B D n X
 * Y commands and addresses that name a file); the mark (k and its
 * address); ! < > |; and cd. In a few places sam sets dot oddly after
 * a loop or a move (the range of the first change after an x, an empty
 * range after t). Here dot is simply the text the command produced;
 * after u, dot is restored to what it was before the undone command.
 *
 * {b Undo is cheap for the same reason}: a command's changes are a
 * list against the old text, so their inverse (for each change, its
 * range in the new text and the text it replaced) is also a list, and
 * is applied the same way ([commit]). Undoing pushes the inverse of
 * the inverse, so a redo is just an undo that is undone. The regexp
 * matcher is TinyLibRegex's, which grep uses too: a small backtracker
 * that returns the leftmost-longest match like sam's, with a memo of
 * (node, position) pairs. libregexp gives different answers in some
 * corner cases (see mini-ed's Regex.mli).
 *
 * Exercises. Each is cheap because a command's changes are a list,
 * made against the old text and applied together:
 * - several files: one buffer and one dot per file, addresses that
 *   name a file ("name"), and X/re/cmd and Y/re/cmd that run cmd in
 *   each file whose name matches re, or does not (as in sam);
 * - | < > (as in sam): send dot to a command, replace dot by a
 *   command's output, or both. This is a change like any other, so it
 *   composes with x;
 * - store the buffer as a piece table (as Bravo, then Word did) or as
 *   a rope: a change then no longer copies the whole text, and undo
 *   gets to keep the old pieces for free;
 * - several dots instead of one: keep the matches of an x as a set of
 *   selections, and run the next command on each of them (the editing
 *   model of Kakoune and vis, which grew out of sam's x).
 *
 * Where it stands: ix has three editors, mini-ed (lines, an editor for
 * a teletype), this one (ranges, but still no screen) and mini-emacs
 * (with a screen). The regexp matcher is TinyLibRegex's; mini-ed's
 * Regex.mli is a twin of libregexp and documents where the two differ.
 * Recording changes and then applying them in one step is the same
 * idea as a statement in TinyDatabase and a command in TinyVCS:
 * nothing is ever half done, and undoing is cheap.
 *
 * cs-history:
 * The line as the unit of editing comes from the teletype. QED
 * (Butler Lampson and Peter Deutsch, Berkeley, 1960s) addressed lines
 * because a terminal printed lines. Ken Thompson's QED for CTSS added
 * regular expressions, compiled to machine code (his 1968 paper), and
 * his ed (1969) is a cut-down QED for the first Unix. Every Unix tool
 * that reads one line at a time (grep, whose name comes from ed's
 * g/re/p, sed, awk) inherited that unit. Rob Pike wrote sam in the
 * 1980s for the Blit, a terminal with a bitmap display and a mouse.
 * Once text is selected by sweeping the mouse over it, there is no
 * reason for a selection to be whole lines, and the command language
 * was designed to work on whatever the mouse can select.
 *
 * others:
 * Acme (Pike, 1994), Plan 9's other editor, kept sam's language as a
 * single command, Edit. Kakoune and vis turned sam's x into their
 * whole way of editing: every command works on a set of selections,
 * which x and y refine. vi and Emacs kept lines and a single point,
 * and loop by repeating a command or a macro. sed and awk are the loop
 * over lines turned into a program of its own.
 *
 * modern:
 * The buffer here is an OCaml string, rebuilt entirely by each command
 * that changes it: a one-megabyte file means a megabyte copied for
 * each character typed. An editor with a screen cannot afford this.
 * Emacs uses a gap buffer (free space kept at the place where one
 * types); Word and VS Code use a piece table (the original file is
 * never changed, and the text is a list of pieces of it and of what
 * was typed); others use a rope (a tree of strings). The third
 * exercise above is one of these.
 *
 * References:
 *  - Rob Pike, "The Text Editor sam" (Software -- Practice and
 *    Experience, 1987): the command language, addresses as character
 *    ranges, and applying a command's changes together at its end
 *  - Rob Pike, "Structural Regular Expressions" (EUUG, 1987): x and y,
 *    loops over matches rather than over lines, with ed's g becoming
 *    one loop among others
 *  - C. Crowley, "Data Structures for Text Sequences" (1998): the
 *    piece table
 *  - H. Boehm, R. Atkinson, M. Plass, "Ropes: an Alternative to
 *    Strings" (Software -- Practice and Experience, 1995)
 *)

(* a command, parsed: its address, its letter, what follows *)
type cmd

(* one command, done: its address found from dot, then the changes it
 * makes, all of them applied together at its end *)
val exec : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > -> cmd -> unit

(* the program: the files named, then the commands of its input *)
val main : Cap.all_caps -> int
