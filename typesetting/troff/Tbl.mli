(* Tbl: a table read -- what is between .TS and .TE, tbl's language.
 *
 *   .TS
 *   center, box;          the whole table: in the middle, in a box
 *   c s s                 its rows' formats, one line a row, the last
 *   l n n.                for the rows that are left: a column is l
 *   Table 1               (left), r, c (centered), n (numbers, their
 *   _                     points one under the other), or s (the cell
 *   Context switch	39	150     before it goes on across this one)
 *   System call	6	36
 *   .TE
 *
 * A row of the data is its cells with a tab between; a line that is
 * "_" or "=" is a rule. After a column's letter: fB or fCW its font,
 * w(1i) its width, p-2 its size; "|" between two is a line down the
 * table. A cell that ends with T{ is a text of several lines, to its
 * T}: filled in the column's width. .T& changes the formats part way.
 *
 * Read: the options center, box (allbox and doublebox as box) and
 * tab(c); the letters l r c n s (a as l, ^ as an empty cell), f, w
 * and p. Not kept: the lines down the table, a column's height or
 * space said by a number.
 *
 * cs-history:
 * tbl is Mike Lesk's (Bell Labs, 1975), a program that reads a
 * document, turns each table into the troff that draws it and leaves
 * the rest as it is: with eqn, of the year before, the first of the
 * "preprocessors", the way Unix had of adding a language to troff
 * without touching troff. Here a table is a value in the document,
 * read by the same pass. *)

(* [read roff block]: called after a .TS, reads to its .TE. [block]
 * reads a text block's lines, to the line that starts with T}, and
 * gives its words and what follows T} on that line: it is the
 * package's, a text block having the package's macros in it. *)
val read : Roff.t -> (unit -> Doc.inline list * string) -> Doc.table
