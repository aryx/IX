(* mini-emacs: an Emacs in small, written after efuns (Fabrice Le
 * Fessant's Emacs in OCaml, INRIA, 1998). A screen editor: the text
 * is shown as it is, a key typed changes it where the cursor is, and
 * the screen follows. Every key is a command looked up in a table,
 * and a command is a function on the editor's structure: the whole
 * of Emacs's idea, here without its Lisp.
 *
 *     the keyboard                      the modules, a key's way
 *        | a host                       Tty_unix (a terminal),
 *        |                              Window_sdl, Window_draw (a
 *        |                              window on Linux, on mini-9pi)
 *     bytes, a terminal's:  ^X ^S       Tui's Key events
 *        | Keymap.of_bytes              the key's name
 *     C-x, then C-s
 *        | Top_window.handle_key        looked up in the buffer's map,
 *        |                              its modes', the editor's; C-x
 *        |                              is a prefix: the next awaited
 *     a command: frame -> unit          Multi_buffers.save_buffer
 *        | features/, modes/            it changes a Text, moves a
 *        |                              point, asks in the Minibuffer,
 *        |                              and draws nothing
 *     the editor (Efuns's records)      one structure, changed in place
 *        | Top_window.display           each frame of the Window tree:
 *        | Frame.display                its text's rows from its first
 *        | Ebuffer.colors               line on, colored by its mode
 *     a screen of cells (Curses.t)      a value, made whole
 *        | the host                     what differs from the screen
 *     the screen                        before, sent or painted
 *
 * The directories are the layers: core/ is the structure (Efuns, the
 * types; Text, Ebuffer, Frame, Window, Top_window, Keymap, Action),
 * features/ the commands over it, a file a family (Move, Edit,
 * Copy_paste, Search, Minibuffer...), modes/ what a kind of buffer
 * adds (a language's colors, a directory's keys), and Config and
 * Config_pad bind the keys. tty/, sdl/ and draw/ are three mains,
 * one a host; a host knows nothing of editing and the editor nothing
 * of a terminal or a window (Tui.mli).
 *
 * design:
 * A command changes the text and moves the point; it never draws.
 * After each key the screen is made again from the structure, and
 * what makes it (Frame) sees that the point is no longer in the rows
 * shown and moves the frame over the text. M-> is one line: the
 * point at the text's end. This division, the commands on one side
 * and a redisplay that looks at the result on the other, is in every
 * Emacs, and is what makes a command short enough that a user
 * writes his own.
 *
 * evolution:
 * Emacs, from TECO to here. TECO (Dan Murphy, MIT, 1962) was an
 * editor of the kind ed is, whose commands were a programming
 * language, each a character; on a display it could show the text
 * after each one, and a key could be given a program of them, a
 * macro. EMACS (Richard Stallman and Guy Steele, MIT, 1976: Editor
 * MACroS) was the sets of such macros people had written, made one,
 * with the rule that a user could look at any of them and replace
 * it. TECO was no language to write large programs in, and the
 * later ones took Lisp: Multics Emacs (Bernard Greenberg, 1978),
 * James Gosling's for Unix (1981, in C, its Lisp a small one), then
 * GNU Emacs (Stallman, 1985), a core in C for the text and the
 * screen and everything else, down to what most keys do, in Lisp.
 * efuns (1998) is that architecture in one typed language, and
 * mini-emacs is efuns' ideas and vocabulary written anew, a small
 * part of its size: the screen is a value made at each key (efuns keeps
 * what is on it and repairs it), the colors are a highlighter's
 * asked when a frame is drawn (efuns keeps one with each
 * character), and what efuns is to its author alone is left out.
 *
 * design:
 * No extension language. GNU Emacs has two languages because C was
 * not one to write an editor's thousand commands in, nor one a user
 * could change while the editor ran. When the editor is in OCaml
 * that reason is gone: a command, a mode or a configuration is a
 * module compiled with the rest (Config, Config_pad), checked by
 * the compiler and debugged as any program. What is lost is
 * Emacs's most particular trait: nothing is changed while the
 * editor runs, and there is no C-h k that shows a key's source.
 *
 * others:
 * vi (Bill Joy, Berkeley, 1976) is the other answer to what a key
 * means. In Emacs a key is always a command, and a letter's command
 * is to insert itself (Keymap.any_char); so every other command
 * needs Control, Meta or a prefix. In vi a key is a command in one
 * mode and itself in another (i enters it, Escape leaves it), and
 * the commands are sentences: an operator (d, c, y) then a motion (w
 * a word, $ the line's end), with counts, so that d2w is said and
 * not looked up. No key here does more than it says: no key indents
 * or closes a parenthesis by itself (Indent).
 *
 * [editor] is mini-emacs started, for a host to run (a terminal, a
 * window): the
 * configuration (Config; the author's, Config_pad, unless told not),
 * a first buffer (the file's or the directory's; with none, one of no
 * file) in a top
 * window of 24 rows by 80 columns until the host says its size.
 *
 * References: Richard Stallman, "EMACS: The Extensible, Customizable,
 * Self-Documenting Display Editor" (MIT AI Memo 519a, 1981): why an
 * editor is a set of replaceable commands over an interpreter, and
 * what a display editor asks of its language. Craig Finseth, "The
 * Craft of Text Editing" (1991): the book on how an Emacs is made,
 * the gap buffer and redisplay. Bernard Greenberg, "Multics Emacs:
 * The History, Design and Implementation" (1979, multicians.org).
 * The author's efuns and its book (docs/efuns.nw there), whose
 * chapters are these modules; docs/plans/plan_emacs.md, what was
 * kept of efuns and what was not. *)
val editor : Efuns.caps -> pad:bool -> string option -> Top_window.model Tui.program
