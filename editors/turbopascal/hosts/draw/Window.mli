(* A Tui program in a window of mini-rio's, under mini-9pi (or on all
 * the screen, with no window system): a Plan 9 program over ix's
 * lib_graphics. Its screen of cells is painted by the draw device with
 * Plan 9's default font (Cells: a cell a character, 9 by 15 pixels);
 * what changed only, as Curses does for a terminal. The window's size
 * is the screen's: resized, the program has more rows and columns or
 * fewer (Tui.Resize), its letters the same.
 *
 * The keys are the console's (/dev/cons, raw), given to the program as
 * the bytes a terminal sends (Keys.key): Plan 9's runes for the arrows,
 * Home, End, the pages, Insert and the F keys. A function key is taken
 * from /dev/kbd where there is one (mini-9pi's kernel, mini-rio's
 * windows), which says whether Control is down with it (the console
 * gives the F key's rune with Control or without: mini-9pi's; Plan 9's
 * gives a control character, Control-F9 a carriage return). Alt is
 * Plan 9's compose key: not a key of the program's (F10 opens the
 * menus).
 *
 * [run caps program]: until the program is over. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork >

val run : < caps; .. > -> 'model Tui.program -> unit
