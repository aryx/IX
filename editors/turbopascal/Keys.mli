(* The IDE with no screen: keys given to Tui_turbo's program one after
 * the other, and the screen it would show as text. A Tui program is a
 * function of its keys, so a session is a line and what it leaves a
 * text to compare, the same by OCaml's build and by mini-ml's, on
 * Linux and on mini-9pi.
 *
 * A script is words between spaces: a key's name as Vt.key knows it
 * (F9, Enter, ArrowDown, PageDown, a letter), C- and A- before it for
 * Control and Alt (C-F9, A-c), =text, its characters typed (no space
 * in it), 16x60, the screen made 16 rows of 60 columns (a window
 * resized), or a dot: time passes (a key is followed by a tick, a
 * twentieth of a second of what runs; a dot is one more). *)

(* [key alt ctrl name]: a key as the bytes a terminal sends for it, what
 * a Tui program reads (a host with a keyboard of its own makes them):
 * Vt.key's names, or a character; None: no such key *)
val key : bool -> bool -> string -> string option

(* the screen after the script, or the word that is no key *)
val run : string -> (Curses.t, string) result

(* the same, a function given the model after each key: a host's work
 * then (the screen drawn, what changed of it), to be timed *)
val run_each : (Tui_turbo.model -> unit) -> string -> (Curses.t, string) result

(* its rows as text (trailing spaces removed) *)
val screen : string -> (string list, string) result
