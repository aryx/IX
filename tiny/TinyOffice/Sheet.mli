(* TinyOffice's sheet: its data, its formulas, how a cell is edited, and
 * its view, a grid of the cells' values.
 *
 * A sheet's data has one line per cell: its name and what was typed in
 * it:
 *
 *     a1 3
 *     a2 Rent
 *     b1 =a1*2+sum(a1:a3)
 *
 * What was typed is a number, a formula (after an =; every spreadsheet
 * since VisiCalc has had such a sign, VisiCalc's being +), or text. A
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
 * The values are computed again at each view: a sheet is small, and
 * there is no other place to keep them. Chart draws a sheet's cells,
 * and File writes the sheet as a Markdown table.
 *
 * cs-history:
 * VisiCalc (Dan Bricklin and Bob Frankston, 1979, on the Apple II)
 * introduced the grid of cells, with a formula in a cell and the values
 * computed again at each change. Its formulas started with a +, Lotus
 * 1-2-3's with a + or an @, and Excel's with the = that we use here.
 *)

(* A cell's value. An empty cell is the text "", which counts as 0 in a
 * sum. An error is shown in the cell: #SYNTAX, #REF, #TEXT (text in a
 * sum), #DIV0, or #CYCLE (a cell that depends on itself). *)
type value = Num of int | Str of string | Err of string

(* column and row counted from 0: name 1 2 is "b3" *)
val name : int -> int -> string

(* the cells that were typed in: their names and what was typed *)
val cells : string -> (string * string) list

(* what was typed in a cell ("" when nothing was) *)
val typed_in : string -> string -> string

(* Each cell is computed once, the first time it is asked for. *)
val values : string -> string -> value

(* a column's width in pixels *)
val cell_w : int

(* [put_cell office c r typed], in the selected sheet *)
val put_cell : Model.office -> int -> int -> string -> unit

(* [choose office i x y] chooses the cell of box i under (x, y), with
 * nothing typed in it yet *)
val choose : Model.office -> int -> int -> int -> unit

(* [cell_key office c r typed key]: a character starts a new entry,
 * Enter stores it and moves down, an arrow stores it and moves that
 * way, C-g forgets it. *)
val cell_key :
  Model.office -> int -> int -> string option -> TinyLibPlayground.key
  -> unit

(* [sheet_view box chosen] draws the chosen cell in a blue frame. *)
val sheet_view :
  Model.obj -> (int * int) option -> TinyLibPlayground.shape list
