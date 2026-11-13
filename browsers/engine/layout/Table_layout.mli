(* Table_layout: a table's grid, and how wide its columns are.

   Tables came with Netscape 1.1 (1995, after the HTML 3.0 draft; they
   became standard in HTML 3.2), and pages used them at once for what
   they were not meant for: the layout of the whole page, with columns
   side by side, the first "web design". A table is rows (<tr>) of
   cells (<td>, or <th> for a heading cell), and a cell is as wide as
   n columns with <td colspan=n>.

   **The grid**: the rows and cells are read from the tree, through the
   groups that HTML 4 added around rows (<thead>, <tbody>, <tfoot>).
   Each cell goes at the first column that its row has free:

     <tr><td colspan=2>a<td>b     row 0: a at 0 (2 columns), b at 2
     <tr><td>c<td>d<td>e          row 1: c at 0, d at 1, e at 2

   **The widths** come from the automatic table layout (CSS 2.1 section
   17.5.2.2, which wrote down what Netscape did). A column's width
   depends on its cells' contents, and a cell's height on its width, so
   each cell is asked two widths: its **minimum** (its widest word,
   because it can wrap down to that but not further) and its
   **maximum** (everything on one line). Box_layout gets them by
   laying the cell out at width 0 and at a width without limit. A
   column's minimum and maximum are the largest of its cells'. Then,
   given the table's room W and the columns' sums of both:

     W >= sum of max    every column is at its max (the table shrinks
                        to its content, unless it has width=: then the
                        room left is shared in proportion to the maxes)
     W <= sum of min    every column is at its min, and the table
                        overflows
     between            each column gets its min, and the room left is
                        shared in proportion to (max - min), so a column
                        that wraps more gets more

   When a cell of several columns needs more than they give, the
   difference is spread over them evenly.

   Worked example (notes_browser.md section 12, and the tests):

     | a            | 3.50 |   column 1: min 60 ("tomato"), max 110
     | tomato soup  | 4.20 |   column 2: min 40,            max 40
                               sums: min 100, max 150
     W = 200:  150 <= 200: 110 and 40
     W = 120:  between: 20 beyond the mins, shared 50 : 0: 80 and 40
     W =  90:  90 < 100: 60 and 40, and the table overflows

   Not done: rowspan= (a cell down several rows), the fixed layout
   (table-layout: fixed, where the first row decides), and a column's
   width=.

   In the system: numbers in, numbers out. Box_layout lays a cell out
   twice to measure it, asks [widths] here, then lays it out a third
   time at its column's width; Flex_layout is the same bargain for a
   flex container's items. The two passes of measuring are why a table
   nested in a table nested in a table was slow in every browser: each
   level doubles the work of the one inside.

   cs-history:
   For eight years the table was the web's layout engine. A page's
   columns, its margin down the left, a picture cut into pieces and put
   back edge to edge: all were tables, nested five deep, with their
   cells propped open by a transparent picture one pixel wide stretched
   to size (the "spacer GIF"; David Siegel's "Creating Killer Web
   Sites", 1996, was the manual, and he wrote "The Web Is Ruined and I
   Ruined It" the next year). It worked in every browser, which CSS did
   not. It also tied a page's look to its markup for good, read badly
   to a screen reader, and could not be drawn until its last cell had
   come. Two things of 2003 turned the trade: Jeffrey Zeldman's
   "Designing with Web Standards", and Dave Shea's CSS Zen Garden, one
   page of HTML shown under hundreds of style sheets. Tables went back
   to being for tables; what they had been used for is now done by
   flexbox and the grid.

   Reference: W3C, CSS 2.1, section 17.5.2.2 (automatic table layout);
   HTML 3.2, "Tables"; notes_browser.md section 12. *)

(* a cell of the grid: its element, its row, its first column, and its
 * number of columns *)
type cell = { element : Dom.element; row : int; column : int; span : int }

(* the table's cells, row by row (the caption apart), and its number of
 * columns *)
val grid : Dom.element -> cell list * int

(* the table's <caption>, if it has one *)
val caption : Dom.element -> Dom.element option

(* [columns n cells]: each column's min and max, from each cell's min
 * and max (with the spacing between the columns it spans included) *)
val columns : int -> (cell * (float * float)) list -> spacing:float -> (float * float) array

(* [widths ~room ~fixed columns]: each column's width. [room] is the
 * table's width (with its cells' spacing taken out), and [fixed] is
 * true when the table gave its width (width=): then it takes all of
 * [room] *)
val widths : room:float -> fixed:bool -> (float * float) array -> float array
