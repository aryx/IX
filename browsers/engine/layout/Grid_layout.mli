(* Grid_layout: a grid's arithmetic. It says which cells each item
   takes, how wide each column is and how high each row is, and where
   each one starts.

   A grid container (display: grid) cuts its box into rows and columns,
   the **tracks**, and puts each child, an **item**, in a rectangle of
   their cells. Css_grid reads what the style sheet says of them, and
   Box_layout lays the items out (in its grid_children). This module is
   the numbers in between, in and out, as Flex_layout is for a flex
   container and Table_layout for a table.

   1. **Placement** ([place]). An item with grid-area: a name takes the
      rectangle that the name draws in grid-template-areas; an item with
      "row / column" takes that cell; the others take the free cells in
      order, row by row. A row is added when the last one is full.

        areas   'siteNotice  siteNotice'      columnStart: row 1, column 0
                'columnStart pageContent'     pageContent: row 1, column 1
                'footer      footer'          footer: row 2, columns 0-1

   2. **The columns' sizes** ([sizes], with the container's width as
      the room). Each track has a least and a most (Css_grid.track):
      - every track starts at its least: a length, or its content's
        narrowest size (for min-content, auto, and "1fr", which is auto
        at least);
      - the room left is given equally to the tracks whose most is
        above their least (a length or their content's widest size),
        each up to its most;
      - what is still left goes to the fr tracks, by their shares;
      - and if there is no fr track, the auto ones are stretched over
        the rest (unless justify-content packs them: [stretch] is
        false).

        Wikipedia's page, 1400 wide, column-gap 24:
          columns  12.25rem (196)   minmax(0, 1fr)
          least    196              0
          the room left, 1400 - 24 - 196 = 1180, all to the fr: 196, 1180

        and inside the second, the article and its tools, 1180 wide:
          columns  minmax(0, 59.25rem)   min-content (nothing in it: 0)
          least    0                     0
          the first grows to its most, 948; no fr, no auto: 948, 0

   3. **The rows' sizes** use the same [sizes], where each row's content
      is the heights of its items once they are laid out at their
      columns' widths. When no room is given (for a container whose
      height is its content's), there is nothing to share: a track is
      its most, and an fr track is its content.

   4. **Where each track starts** ([starts]): one after the other, with
      a gap between two. They are packed at the start, the end or the
      centre of the room, or spread (justify-content for the columns,
      align-content for the rows: example.com's "place-content: center"
      puts its two rows in the middle of the window's height).

   An item wider than one track ([contents]) gives its size to the last
   track it spans, less the sizes of the others. It does not if one of
   them is an fr track, which takes what it is given.

   Not done: grid-auto-flow: column and dense; an item's span given
   without a name ("span 2"); baseline alignment; subgrid.

   Reference: W3C, CSS Grid Layout Module Level 1, sections 8.5
   (placement), 12.3 to 12.7 (the track sizing algorithm), 11.8
   (packing). *)

(* the cells an item takes: its first row and column (from 0), and how
 * many of each it spans *)
type cell = { row : int; column : int; rows : int; columns : int }

(* [place ~rows ~columns ~areas placements]: the cells of each item, in
 * the items' order, and the grid's numbers of rows and columns. The
 * grid is at least [rows] by [columns] (the tracks the style sheet
 * gives), and has those that the areas and the items need *)
val place : rows:int -> columns:int -> areas:string list list -> Css_grid.placement list -> cell list * int * int

(* what is in a track: the narrowest it can be and the widest it wants
 * to be (for a row, both are its height) *)
type content = { least : float; most : float }

(* each track's content, from its items'. Each item is given by its
 * first track, how many tracks it spans, and its own content. [base]
 * is what a percentage is of *)
val contents : base:float -> gap:float -> Css_grid.track array -> (int * int * content) list -> content array

(* each track's size in a [room] (with [None], as large as its
 * content), with [gap] between two *)
val sizes : room:float option -> base:float -> gap:float -> stretch:bool -> Css_grid.track array -> content array -> float array

(* each track's start in [room], given their [sizes] *)
val starts : align:Computed.align -> room:float -> gap:float -> float array -> float array
