(* Css_grid: reading a grid's values, which are its tracks, its named
   areas, and where an item goes.

   CSS Grid (2017) lays a container's children in rows *and* columns,
   which the container declares. Where flexbox says "these, in a row",
   a grid says "three rows and two columns, and this child there". It
   is how a page is cut into its header, its side column, its article
   and its footer; Wikipedia's page is cut so since 2022:

     .mw-page-container-inner {
       display: grid;
       column-gap: 24px;
       grid-template: min-content 1fr min-content / 12.25rem minmax(0, 1fr);
       grid-template-areas: 'siteNotice  siteNotice'
                            'columnStart pageContent'
                            'footer      footer' }
     .vector-column-start  { grid-area: columnStart }
     .mw-content-container { grid-area: pageContent }

   This is read here as

     rows     [ min-content; 1fr; min-content ]         (before the /)
     columns  [ 12.25rem (196 px); minmax(0, 1fr) ]     (after it)
     areas    [ [siteNotice; siteNotice]; [columnStart; pageContent]; [footer; footer] ]
     and the two children's places, Area "columnStart" and Area "pageContent"

   A **track** is a row or a column, and its size is a pair: its least
   and its most. "minmax(0, 1fr)" gives them both, and a size alone is
   both ("12.25rem" is never less and never more). "1fr", an [Fr], has
   "auto" as its least. The sizes are:

     a length     12.25rem, 200px, 30% (of the grid)
     fr           a share of the room left once the others are served,
                  as with flex-grow: 1fr 2fr is a third and two thirds
     min-content  the narrowest its content can be (its longest word)
     max-content  the widest it wants to be (nothing wrapped)
     auto         its content's size, between the two, and it takes
                  what room is left

   What the arithmetic does with them is Grid_layout's business
   (browsers/engine).

   What is read: grid-template-columns and -rows (lengths, fr,
   min-content, max-content, auto, minmax(), repeat(n, ...), and
   fit-content() as auto), grid-template-areas, the shorthand
   grid-template as "rows / columns" (Computed cuts it), and grid-area
   as a name or as "row / column". repeat(auto-fill, ...) and
   repeat(auto-fit, ...) are read apart, because their count is known
   only at layout (auto_repeat and repetitions); auto-fit's empty
   tracks are not collapsed.
   What is not read: line names ("[main-start]"), spans ("span 2"),
   grid-row and grid-column, grid-auto-flow (taken as rows), and
   grid-auto-rows and -columns (taken as auto).

   Reference: W3C, CSS Grid Layout Module Level 1, sections 7.2 (the
   track sizes), 7.3 (the named areas), 8.3 and 8.4 (placement). *)

(* one end of a track's size *)
type breadth = Length of Css_values.length | Fr of float | Min_content | Max_content | Auto

(* a track: the least it is, and the most *)
type track = { min : breadth; max : breadth }

(* "auto": the size of an implicit track, a row that no
 * grid-template-rows names *)
val auto : track

(* the value of grid-template-columns or -rows: its tracks, in order;
 * [] if it is "none" or not understood *)
val tracks : Css_values.context -> Css_syntax.component list -> track list

(* [auto_repeat ctx value]: for a repeat(auto-fill or auto-fit, ...) in
   the value, how many tracks come before it, and its tracks *)
val auto_repeat : Css_values.context -> Css_syntax.component list -> (int * track list) option

(* [repetitions ~room ~gap repeated]: how many times the tracks fit in
 * room *)
val repetitions : room:float -> gap:float -> track list -> int

(* the value of grid-template-areas: each row is a string, and each cell
 * a word ("." is a cell of no area) *)
val areas : Css_syntax.component list -> string list list

(* where an item goes: in the next free cell, in the area of that name,
 * or at a row and a column (counted from 1, as CSS counts its lines) *)
type placement = Auto_placed | Area of string | Cell of { row : int; column : int }

(* the value of grid-area *)
val placement : Css_syntax.component list -> placement
