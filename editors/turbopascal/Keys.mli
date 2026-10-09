(* The IDE with no screen: keys given to Tui_turbo's program one after
 * the other, and the screen it would show as text. A Tui program is a
 * function of its keys, so a session is a line and what it leaves a
 * text to compare, the same by OCaml's build and by mini-ml's, on
 * Linux and on mini-9pi.
 *
 * A script is words between spaces: a key's name as Vt.key knows it
 * (F9, Enter, ArrowDown, PageDown, a letter), C- and A- before it for
 * Control and Alt (C-F9, A-c), or =text, its characters typed (no
 * space in it). *)

(* the screen's rows after the script (trailing spaces removed), or the
 * word that is no key *)
val screen : string -> (string list, string) result
