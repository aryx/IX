(* Grid_layout: a grid's arithmetic -- which cells each item takes, how
   wide each column and how high each row, where each starts.

   A grid container (display: grid) cuts its box into rows and columns,
   the **tracks**, and puts each child, an **item**, in a rectangle of
   their cells. Css_grid reads what the style sheet says of them;
   Box_layout lays the items out (its grid_children); this module is the numbers between, in
   and out, as Flex_layout is for a flex container and Table_layout
   for a table.

   1. **Placement** ([place]). An item with grid-area: a name takes the
      rectangle that name draws in grid-template-areas; one with
      "row / column" takes that cell; the others take the free cells in
      order, row by row. A row is added when the last is full.

        areas   'siteNotice  siteNotice'      columnStart: row 1, column 0
                'columnStart pageContent'     pageContent: row 1, column 1
                'footer      footer'          footer: row 2, columns 0-1

   2. **The columns' sizes** ([sizes], with the room: the container's
      width). Each track has a least and a most (Css_grid.track):
      - every track starts at its least: a length, or its content's
        narrowest (min-content, auto, and "1fr" which is auto at least);
      - the room left is given to the tracks that have a most above
        their least, a length or their content's widest, equally, each
        up to its most;
      - what is still left goes to the fr tracks, by their shares;
      - and if there is no fr track, the auto ones are stretched over
        the rest (unless justify-content packs them: [stretch] false).

        Wikipedia's page, 1400 wide, column-gap 24:
          columns  12.25rem (196)   minmax(0, 1fr)
          least    196              0
          the room left, 1400 - 24 - 196 = 1180, all to the fr: 196, 1180

        and inside the second, the article and its tools, 1180 wide:
          columns  minmax(0, 59.25rem)   min-content (nothing in it: 0)
          least    0                     0
          the first grows to its most, 948; no fr, no auto: 948, 0

   3. **The rows' sizes**: the same [sizes], each row's content being
      its items' heights once laid out at their columns' widths. With
      no room said (a container whose height is its content's) there is
      nothing to share: a track is its most, an fr one its content.

   4. **Where each starts** ([starts]): one after the other, a gap
      between two; packed at the start, the end or the centre of the
      room, or spread (justify-content for the columns, align-content
      for the rows -- example.com's "place-content: center" puts its
      two rows in the middle of the window's height).

   An item wider than one track ([contents]) gives its size to the last
   it spans, the others' taken off; not if one of them is an fr, which
   takes what it is given.

   Not done: grid-auto-flow: column and dense; an item's span said
   without a name ("span 2"); baseline alignment; subgrid.

   Reference: W3C, CSS Grid Layout Module Level 1, sections 8.5
   (placement), 12.3 to 12.7 (the track sizing algorithm), 11.8
   (packing). *)

(* the cells an item takes: its first row and column (from 0), and how
 * many of each *)
type cell = { row : int; column : int; rows : int; columns : int }

(* [place ~rows ~columns ~areas placements]: each item's cells, in the
 * items' order, and the grid's rows and columns: at least [rows] by
 * [columns] (the tracks the style sheet says), and those the areas and
 * the items need *)
val place : rows:int -> columns:int -> areas:string list list -> Css_grid.placement list -> cell list * int * int

(* what is in a track: the narrowest it can be and the widest it wants
 * (for a row: its height, both) *)
type content = { least : float; most : float }

(* each track's content, from its items': an item's first track, how
 * many it spans, its own; [base] what a percentage is of *)
val contents : base:float -> gap:float -> Css_grid.track array -> (int * int * content) list -> content array

(* each track's size, in a [room] ([None]: as large as its content),
 * [gap] between two *)
val sizes : room:float option -> base:float -> gap:float -> stretch:bool -> Css_grid.track array -> content array -> float array

(* each track's start in [room], their [sizes] given *)
val starts : align:Computed.align -> room:float -> gap:float -> float array -> float array
