(* TinyOffice's sheet: its data, its formulas, how a cell is edited, and
 * its view, a grid of the cells' values.
 *
 * A sheet's data is a line a cell, its name and what was typed in it:
 *
 *     a1 3
 *     a2 Rent
 *     b1 =a1*2+sum(a1:a3)
 *
 * what was typed being a number, a formula (after an =, as in every
 * spreadsheet since VisiCalc's +), or text. A cell's name is its
 * column, a to z, and its row, 1 to 99. The numbers are integers:
 * tiny-ml's, 31 bits on tiny-machine, no floating point.
 *
 * A formula is read and computed at once, by recursive descent, with no
 * tree; a cell it names is computed first, each cell once (values
 * keeps them), and a cell being computed is #CYCLE meanwhile, which is
 * what a cell that needs itself gets:
 *
 *     b1 =a1*2+sum(a1:a3)     b1 needs a1, a2, a3: each computed once
 *     c1 =c1+1                #CYCLE
 *
 * The values are computed again at each view: a sheet is small, and it
 * has no other place for them. TinyOfficeChart draws a sheet's cells,
 * TinyOfficeFile writes it as a Markdown table.
 *
 * cs-history:
 * VisiCalc (Dan Bricklin and Bob Frankston, 1979, on the Apple II): a
 * grid of cells, a formula in a cell, the values computed again at each
 * change; its formulas started with a +, Lotus 1-2-3's with a + or an
 * @, Excel's with the = this one has.
 *)

(* a cell's value: a number, text (an empty cell is "", 0 in a sum), or
 * an error, said in the cell: #SYNTAX, #REF, #TEXT (text in a sum),
 * #DIV0, #CYCLE (a cell that needs itself) *)
type value = Num of int | Str of string | Err of string

(* a cell's name, from its column and its row (from 0): name 1 2 is
 * "b3" *)
val name : int -> int -> string

(* the cells typed in: their names and what was typed *)
val cells : string -> (string * string) list

(* what was typed in a cell ("" when nothing) *)
val typed_in : string -> string -> string

(* the values of a sheet's cells, by name *)
val values : string -> string -> value

(* a column's width in pixels *)
val cell_w : int

(* [put_cell office c r typed]: what is typed in cell (c, r) of the
 * selected sheet put in it *)
val put_cell : TinyOfficeModel.office -> int -> int -> string -> unit

(* [choose office i x y]: the cell of box i under (x, y) chosen,
 * nothing typed in it yet *)
val choose : TinyOfficeModel.office -> int -> int -> int -> unit

(* [cell_key office c r typed key]: a key at a cell, as in a
 * spreadsheet: a character starts what is typed there, Enter puts it in
 * the cell and goes down, an arrow puts it and goes that way, C-g
 * forgets it *)
val cell_key :
  TinyOfficeModel.office -> int -> int -> string option -> int -> unit

(* [sheet_view box chosen]: the grid, each cell's value, the chosen cell
 * in a blue frame *)
val sheet_view :
  TinyOfficeModel.obj -> (int * int) option -> TinyLibPlayground.shape list
