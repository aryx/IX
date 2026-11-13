(* Tbl reads a table: what is between .TS and .TE, in tbl's language.
 *
 *   .TS
 *   center, box;          the whole table: in the middle, in a box
 *   c s s                 the formats of its rows, one line for each
 *   l n n.                row, the last one for the rows that are
 *   Table 1               left. A column is l (left), r, c
 *   _                     (centered), n (numbers, with their points
 *   Context switch	39	150     one under the other), or s (the cell
 *   System call	6	36      before it goes on across this one)
 *   .TE
 *
 * A row of the data is its cells, with a tab between them; a line that
 * is "_" or "=" is a rule. After a column's letter, fB or fCW gives its
 * font, w(1i) its width, and p-2 its size; a "|" between two columns
 * is a line down the table. A cell that ends with T{ is a text of
 * several lines, up to its T}, filled in the column's width. .T&
 * changes the formats part way through.
 *
 * What is read: the options center, box (allbox and doublebox are read
 * as box) and tab(c); the letters l r c n s (a is read as l, and ^ as
 * an empty cell), f, w and p. What is not kept: the lines down the
 * table, and a column's height or space given by a number.
 *
 * cs-history:
 * Mike Lesk wrote tbl (Bell Labs, 1975), a program that reads a
 * document, turns each table into the troff that draws it, and leaves
 * the rest as it is. With eqn, of the year before, it was the first of
 * the "preprocessors", the way Unix had of adding a language to troff
 * without touching troff. Here a table is a value in the document,
 * read by the same pass. *)

(* [read roff block] is called after a .TS, and reads up to its .TE.
 * [block] reads the lines of a text block, up to the line that starts
 * with T}, and gives its words and what follows T} on that line. It
 * is the package's function, because a text block has the package's
 * macros in it. *)
val read : Roff.t -> (unit -> Doc.inline list * string) -> Doc.table
