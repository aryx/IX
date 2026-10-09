(* A Tui program in a window on Linux (SDL): its screen of cells painted
 * with Plan 9's default font (Cells, Picture), a cell 9 by 15 pixels,
 * shown [scale] times as large. The window's size is the screen's: made
 * larger or smaller by the mouse, the program has more rows and columns
 * or fewer (Tui.Resize), its letters the same. The keys are given as
 * the bytes a terminal sends (Cells.key), a character typed as its
 * bytes of UTF-8; with [mouse], a click and the wheel too (Cells.click).
 * Until the program is over, or the window closed. Dune's alone: SDL is
 * outside what mini-ml compiles; mini-9pi's host is ../draw.
 *
 * [run title ~mouse scale rows cols program] *)

val run : string -> mouse:bool -> int -> int -> int -> 'model Tui.program -> unit
