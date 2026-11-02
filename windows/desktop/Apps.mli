(* The table of programs a person opens, and the start menu's shape, without
 * a screen. The table is a text file, /lib/desktop/apps on the card, its
 * lines:
 *
 *     group | name | icon | size | command
 *
 *     games | Tetris | blocks | 400x560 | tetris
 *     games | Doom   | face   | max     | doom
 *
 * # starts a comment line. A group is a directory of the card's /progs
 * (apps, games, net, devtools, system, examples), or top: on the menu
 * itself, in no submenu.
 *
 * design:
 * Why a table and not a walk of /progs: a directory says what programs
 * there are, not which of them draw, what a person calls them, what they
 * look like or how large they want to be: curl and doom are both a file.
 * The groups stay /progs's, so that there is no second classification to
 * keep, and a test holds the table to the Makefile's lists of what is on
 * the card, so that a new game cannot be forgotten. What is not in the
 * table can still be reached: the menu has All programs, a file manager
 * on /progs.
 *
 * others:
 * freedesktop.org's .desktop files (1999 on) are the same table as a file a
 * program, installed with it: each program brings its own line, and a menu
 * is whatever is found. It suits software from many sources. Here all
 * of it is built together, and one file can be read at once. *)

type size = Max | Size of int * int

type entry = {
  group : string;
  name : string;
  icon : string;
  size : size;
  command : string;
}

(* a file's text; Failure with its line, for one that is not a table's *)
val parse : string -> entry list

(* the groups, by their directory and a person's name for them, in menu order *)
val groups : (string * string) list

(* the command's first word *)
val program : entry -> string

(* what to write to a wctl to open it: new, in the middle of what the screen
 * has, or all of it *)
val open_line : entry -> string

type item = Run of entry | Group of string * string | Exit

(* [left entries]: the menu's first column: those of top, the groups that have
 * entries, then Exit *)
val left : entry list -> item list
(* [right entries group]: the second, when that group is open *)
val right : entry list -> string -> item list

val row_h : int
val left_w : int
val right_w : int
(* the window's size for those entries: the longest of all the columns *)
val size_of : entry list -> int * int
(* [row_at top y]: which row a height is, the rows starting at [top] *)
val row_at : int -> int -> int

(* [desk_cell (x0, y0, x1, y1) i]: where the desk's icon i goes in that
 * rectangle, as (x0, y0, x1, y1): down the left side, then the next column *)
val desk_cell : int * int * int * int -> int -> int * int * int * int
(* [double_click t0 t1]: two presses at those milliseconds are one double
 * click *)
val double_click : int -> int -> bool
