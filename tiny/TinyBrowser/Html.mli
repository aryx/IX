(* HTML, as TinyBrowser reads it: a page being read, and the reading as
 * a whole. The module is named after the language, as a browser's HTML
 * parser usually is, because what each tag means is decided here. The
 * tokens from Tokens are given, one after the other, to a stack of open
 * elements. Each word of a text is sent to Lines' flow (or to a table's
 * cell, or to a large heading). What the browser keeps of a page is its
 * lines, its title, its anchors and its pictures; there is no tree.
 *
 * The meaning of each tag is a row in a table (kinds) that says
 * whether it starts a block, wants a blank line around it, hides its
 * text, indents its lines, and what look it gives its text. An open
 * element combines what it says with what its parents say, so the top
 * of the stack alone tells how to show the next text:
 *
 *     <ul><li>An <b><a href="x">old</a> page</b>
 *
 *     stack (top first)        the word "old" gets
 *       a   href x               look bold, link x,
 *       b   bold                 at column 3 (the ul's margin),
 *       li                       after the bullet in the margin
 *       ul  margin 3
 *
 * Some elements close implicitly when another one opens (a paragraph
 * when a block starts, a list item at the next one, a cell at the
 * next one), the way pages written by hand expect.
 *
 * A page cut anywhere reads the same: the tests feed one a byte at a
 * time and compare its lines.
 *)

(* [create width] reads a page into lines of width columns *)
type page
val create : int -> page

(* [feed] takes the page one message at a time *)
val feed : page -> string -> unit
val finish : page -> unit

(* [refresh] is where a <meta> refresh sends us at once, "" if none *)
val title : page -> string
val base : page -> string
val refresh : page -> string

(* lines so far; [lines_between page a b] is lines a to b-1, the screen *)
val count : page -> int
val lines_between : page -> int -> int -> Lines.line list

(* the line where the element with that id starts, if it has arrived *)
val anchor : page -> string -> int option

(* Pic_rows counts the rows received; the image is made at the answer's
 * first line. *)
type got = Pic_unasked | Pic_asked | Pic_failed | Pic_rows of int

type picture = {
  pc_src : string; pc_w : int; pc_h : int; pc_alt : string;
  mutable pc_got : got
}
val pictures : page -> int
val picture_of : page -> int -> picture
