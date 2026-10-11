(* Css_grid: a grid's values read -- its tracks, its named areas, where
   an item goes.

   CSS Grid (2017) lays a container's children in rows *and* columns,
   which the container declares; where flexbox says "these, in a row",
   a grid says "three rows and two columns, and this child there". It
   is how a page is cut into its header, its side column, its article
   and its footer -- Wikipedia's, since 2022:

     .mw-page-container-inner {
       display: grid;
       column-gap: 24px;
       grid-template: min-content 1fr min-content / 12.25rem minmax(0, 1fr);
       grid-template-areas: 'siteNotice  siteNotice'
                            'columnStart pageContent'
                            'footer      footer' }
     .vector-column-start  { grid-area: columnStart }
     .mw-content-container { grid-area: pageContent }

   read here as

     rows     [ min-content; 1fr; min-content ]         (before the /)
     columns  [ 12.25rem (196 px); minmax(0, 1fr) ]     (after it)
     areas    [ [siteNotice; siteNotice]; [columnStart; pageContent]; [footer; footer] ]
     and the two children's places, Area "columnStart" and Area "pageContent"

   A **track** is a row or a column, and its size a pair, its least and
   its most: "minmax(0, 1fr)" says them both, and a size alone is both
   ("12.25rem": never less, never more; "1fr", an [Fr], is "auto" at
   the least). The sizes:

     a length     12.25rem, 200px, 30% (of the grid)
     fr           a share of the room left once the others are served,
                  as flex-grow: 1fr 2fr is a third and two thirds
     min-content  the narrowest its content can be (its longest word)
     max-content  the widest it wants to be (nothing wrapped)
     auto         its content's, between the two, and what room is left

   What the arithmetic does with them is Grid_layout's (browsers/engine).

   Read: grid-template-columns and -rows (lengths, fr, min-content,
   max-content, auto, minmax(), repeat(n, ...), fit-content() as auto),
   grid-template-areas, the shorthand grid-template as "rows / columns"
   (Computed cuts it), and grid-area as a name or as "row / column".
   Not read: line names ("[main-start]"), repeat(auto-fill, ...),
   spans ("span 2"), grid-row and grid-column, grid-auto-flow (rows),
   grid-auto-rows and -columns (auto).

   Reference: W3C, CSS Grid Layout Module Level 1, sections 7.2 (the
   track sizes), 7.3 (the named areas), 8.3 and 8.4 (placement). *)

(* one end of a track's size *)
type breadth = Length of Css_values.length | Fr of float | Min_content | Max_content | Auto

(* a track: the least it is, the most *)
type track = { min : breadth; max : breadth }

(* "auto": an implicit track's size, a row that no grid-template-rows
 * names *)
val auto : track

(* grid-template-columns' or -rows' value: its tracks, in order; [] if
 * "none" or not understood *)
val tracks : Css_values.context -> Css_syntax.component list -> track list

(* grid-template-areas' value: a row a string, a cell a word ("." a
 * cell of no area) *)
val areas : Css_syntax.component list -> string list list

(* where an item goes: where the next free cell is, in the area of that
 * name, or at a row and a column (from 1, as CSS counts its lines) *)
type placement = Auto_placed | Area of string | Cell of { row : int; column : int }

(* grid-area's value *)
val placement : Css_syntax.component list -> placement
