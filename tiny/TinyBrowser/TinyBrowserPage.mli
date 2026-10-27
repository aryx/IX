(* A page being read, TinyBrowser's reading as a whole: the tokens of
 * TinyBrowserTokens given, one after the other, to a stack of open
 * elements, and each word of a text sent to TinyBrowserLines' flow
 * (or to a table's cell, or to a large heading). What the browser
 * keeps of a page is its lines, its title, its anchors and its
 * pictures; there is no tree.
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

(* A page being read and turned into lines of [width] columns. *)
type page
val create : int -> page

(* [feed page bytes] gives the next message of the page; [finish page]
 * says that the page has ended. *)
val feed : page -> string -> unit
val finish : page -> unit

(* The page's <title>; the address in its <base>; where its <meta>
 * refresh sends us at once ("" when it does not). *)
val title : page -> string
val base : page -> string
val refresh : page -> string

(* how many lines there are so far; the lines from the a-th to before
 * the b-th, from the top (what the screen shows) *)
val count : page -> int
val lines_between : page -> int -> int -> TinyBrowserLines.line list

(* the line where the element with that id starts, if it came *)
val anchor : page -> string -> int option

(* The page's pictures: how many, and one by its number. A picture's
 * pc_got is -1 before it is asked for, -3 once asked, -2 when there is
 * none to be had, and the rows received so far after that. *)
type picture = {
  pc_src : string; pc_w : int; pc_h : int; pc_alt : string;
  mutable pc_got : int
}
val pictures : page -> int
val picture_of : page -> int -> picture
