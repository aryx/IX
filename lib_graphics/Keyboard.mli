(* The keyboard (Plan 9's /dev/cons, raw: libdraw's keyboard.c; xix's
 * lib_graphics/input): what is typed, as it is typed (no line kept by
 * the kernel, no echo), each read a message. Read by a Source.
 *
 * A key is a character, and a character is its UTF-8 bytes: a is 61,
 * e with an acute accent C3 A9, and a key that has no character (an
 * arrow, a function key) is one all the same, a code of Unicode's
 * private use area that Plan 9 chose, three bytes: up, 0xF00E, is EF
 * 80 8E. No escape sequence, so no time to wait to tell the Escape
 * key from the start of an arrow, as a terminal's program must. A
 * read gives the bytes that are there, and may end inside a
 * character: [receive] keeps the start for the next.
 *
 * Where it stands: the same split as the mouse's (Mouse.mli): the
 * kernel's console, or the one mini-rio serves to a window's program
 * (Virtual_cons), which is where a line is kept, edited and given
 * whole at a newline when the program has not asked for the keys.
 * The shell reads lines; mini-emacs, a game and mini-rio itself read
 * keys.
 *
 * terminology:
 * Cooked and raw. By default the console gives a line when it is
 * finished: the keys are shown as they are typed, a backspace takes
 * one back, and the program reads nothing until the newline; that
 * is cooked, a word of Unix's terminal driver. Raw is each key as it
 * comes, not shown: for a program that draws its own text. The one
 * file serves both, and the word written to /dev/consctl says which.
 *
 * plan9-is-cleaner:
 * Unix sets the mode by an ioctl on the terminal with a structure of
 * dozens of flags (termios: ICANON, ECHO, the characters that erase
 * and interrupt, the speed of a line that is no longer a wire), which
 * stays as it was set when the program dies: hence stty sane. Here
 * it is five characters written to a file, and the mode lasts as
 * long as the file is open: a program that dies has closed it.
 *
 * others:
 * What is held. A console is a typewriter: it says that a was typed,
 * and again if the key repeats, never that it was let go. A game
 * asks another question, whether left is down now. X and SDL send a
 * key's press and its release as two events; 9front added /dev/kbd,
 * read by [held] below, which says at each change all the keys that
 * are down, as /dev/mouse says the buttons.
 *
 * References: cons(3) of Plan 9's manual (cons, consctl); keyboard(2)
 * and keyboard(6), the library followed and the codes of the keys;
 * kbdfs(8) of 9front's manual (from memory), /dev/kbd. *)

type t

(* the console made raw (/dev/consctl's "rawon", for as long as the
 * program runs) *)
val init : < Cap.keyboard; Cap.fork; .. > -> t
(* the next keys: a read's characters, each its bytes (one for ASCII,
 * more for the others: UTF-8), whole (none, when a read ended inside
 * one: it comes with the next) *)
val receive : t -> string list Event.event

(* the arrows, as Plan 9's keyboard gives them (its runes: up 0xF00E,
 * down 0xF800, left 0xF011, right 0xF012) *)
val up : string
val down : string
val left : string
val right : string

(* The keys held (/dev/kbd, 9front's file, which mini-9pi's kernel and
 * mini-rio's windows have): the console gives what is typed, and no
 * key's release; this file says, each time a key goes down or comes up,
 * which keys are down. For a game, which asks whether left is held. *)
type held
(* (None: no such file here) *)
val held : < Cap.keyboard; Cap.fork; .. > -> held option
(* the next change, as the file gives it: k or K, the keys, a zero byte *)
val message : held -> string Event.event
(* a message's keys: the ones down now, each its character's bytes (a
 * letter is its small one, whatever Shift does) *)
val keys : string -> string list
(* Shift, Ctl and Alt, as keys (Plan 9's runes 0xF860, 0xF862, 0xF863) *)
val shift : string
val ctrl : string
val alt : string
