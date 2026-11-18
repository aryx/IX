(* TinyOffice's sheet. This module handles its data, its formulas, how
 * a cell is edited, and its view, which is a grid of the cells' values.
 *
 * A sheet's data has one line per cell, with the cell's name and what
 * was typed in it:
 *
 *     a1 3
 *     a2 Rent
 *     b1 =a1*2+sum(a1:a3)
 *
 * What was typed is a number, a formula (after an =; every spreadsheet
 * since VisiCalc has had such a sign, and VisiCalc's was +), or text. A
 * cell's name is its column, a to z, followed by its row, 1 to 99. The
 * numbers are tiny-ml's integers, 31 bits on tiny-machine; there is no
 * floating point.
 *
 * A formula is parsed and computed in the same pass, by recursive
 * descent, without building a tree. A cell that the formula names is
 * computed first, and each cell only once ([values] remembers them).
 * While a cell is being computed its value is #CYCLE, so a cell that
 * depends on itself gets #CYCLE:
 *
 *     b1 =a1*2+sum(a1:a3)     b1 needs a1, a2, a3: each computed once
 *     c1 =c1+1                #CYCLE
 *
 * The values are computed again at each view, because a sheet is small
 * and there is no other place to keep them. Chart draws a sheet's cells,
 * and File writes the sheet as a Markdown table.
 *
 * cs-history:
 * VisiCalc (Dan Bricklin and Bob Frankston, 1979, on the Apple II)
 * introduced the grid of cells, with a formula in a cell and the values
 * computed again at each change. Its formulas started with a +. Those of
 * Lotus 1-2-3 started with a + or an @, and those of Excel with the =
 * that we use here.
 *)

(* A cell's value. An empty cell is the text "", which counts as 0 in a
 * sum. An error is shown in the cell: #SYNTAX, #REF, #TEXT (text in a
 * sum), #DIV0, or #CYCLE (a cell that depends on itself). *)
type value = Num of int | Str of string | Err of string

(* [name c r] is a cell's name, with the column and the row counted
 * from 0: name 1 2 is "b3". *)
val name : int -> int -> string

(* the cells that were typed in: their names and what was typed *)
val cells : string -> (string * string) list

(* what was typed in a cell ("" when nothing was) *)
val typed_in : string -> string -> string

(* Each cell is computed once, the first time it is asked for. *)
val values : string -> string -> value

(* a column's width in pixels *)
val cell_w : int

(* [put_cell office c r typed] stores what was typed in a cell of the
 * selected sheet. *)
val put_cell : Model.office -> int -> int -> string -> unit

(* [choose office i x y] chooses the cell of box i under (x, y), with
 * nothing typed in it yet *)
val choose : Model.office -> int -> int -> int -> unit

(* A range of cells goes from the chosen cell to the mark, the cell
 * where the left button went down; they are any two opposite corners,
 * and the same cell when no range was dragged. [extend office mark x y]
 * makes the cell under (x, y) the chosen one, the left button held.
 *
 * [copy_range data c r mark] puts what is typed in the range's cells
 * in the clipboard, which is the text's, a row a line, a tab between
 * two cells; so a text's lines can be pasted in cells.
 * [clear_range] empties the cells, in one change. [paste_range] puts
 * the clipboard's text in the cells from the range's top left corner
 * on; a formula is pasted as it was typed, the cells it names
 * unchanged (a spreadsheet moves them with the formula). *)
val extend : Model.office -> int * int -> int -> int -> unit
val copy_range : string -> int -> int -> int * int -> unit
val clear_range : Model.office -> int -> int -> int * int -> unit
val paste_range : Model.office -> int -> int -> int * int -> unit

(* [cell_key office c r typed mark key] handles a key in a cell. A
 * character starts a new entry, Enter stores it and moves down, an
 * arrow stores it and moves that way, and C-g forgets it. With nothing
 * typed, Backspace empties the range's cells, C-w cuts them and C-y
 * pastes. A key that moves or types ends the range. *)
val cell_key :
  Model.office -> int -> int -> string option -> int * int
  -> TinyLibPlayground.key -> unit

(* [sheet_view box chosen] draws a blue frame around the range, from
 * the chosen cell to the mark. *)
val sheet_view :
  Model.obj -> ((int * int) * (int * int)) option
  -> TinyLibPlayground.shape list
