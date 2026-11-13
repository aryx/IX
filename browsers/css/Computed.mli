(* Computed: each element's style as values, which is what layout reads.

   (See mini-chrome's notes_css_engine.md section 6.) The cascade gives
   each property's winning declaration as text, and this module makes a
   value of each one, in a record. Lengths are in pixels (or pixels
   plus a percentage that the layout resolves, as in Css_values),
   colours are numbers, and keywords are variants.

   What no declaration gives is either **inherited** from the parent
   (the colour, the font, the alignment, white-space, line-height,
   visibility, list-style, and the custom properties) or takes its
   **initial value** (display inline, margins 0, background
   transparent...), as each property's definition says. The keywords
   inherit, initial and unset ask for one or the other. font-size is
   computed first, because an em everywhere else is this element's
   size, but in font-size it is its parent's.

   **Shorthands** are expanded before:
   - margin and padding (one to four values: top, right, bottom, left);
   - border, border-top and the other sides (a width, a style and a
     colour, in any order);
   - border-width, border-style, border-color;
   - background (its colour; the rest is ignored);
   - font (style, weight, size, "/" line-height, family);
   - flex (grow, shrink, basis);
   - gap, inset, and list-style (its type).

   The page's defaults are a style sheet like its own, the user agent's
   (ua.css, embedded as Ua_sheet). It is CSS 2.1's appendix D, the
   table of Looks.mli written in the language the pages use.

   Not computed: the properties that layout does not use yet
   (transforms, shadows, animations, grid's), and the content of
   ::before and ::after.

   In the system, Cascade gives the text, Css_values reads a length or
   a colour in it, and this record is all that Box_layout and
   Flex_layout know of CSS: they never see a declaration. Looks' style,
   which Html_layout used, is the same idea before style sheets: a
   record for each element, filled from a table by the element's name.

   terminology:
   A property has four values, and the words are the standard's (CSS
   2.1, section 6.1). The **specified** value is what the cascade
   gave, or the inherited or initial one: "width: 50%", "font-size:
   1.2em". The **computed** value is that value made as absolute as it
   can be without laying anything out (1.2em is 19.2px; 50% stays 50%),
   and it is what a child inherits (this module's record). The **used**
   value is the one after layout: 50% of a 600 px block is 300px. The
   **actual** value is what the screen can show: 300 dots, or 600 on a
   screen of double density. What a script reads with getComputedStyle
   is, for most properties and despite its name, the used value.

   design:
   Here is why the computed value, and not the specified one, is
   inherited. "font-size: 1.2em" on a list, inherited as text, would
   make each nested item a fifth larger than its parent; inherited as
   19.2px, it is one size for the whole list. And a percentage is kept
   a percentage for the opposite reason: what it is a part of is not
   known until the layout, and it differs for the child.

   Reference: W3C, CSS 2.1 (2011), sections 6.1 (the four values) and
   6.2 (inheritance), and appendix D (the default sheet for HTML 4);
   mini-chrome's notes_css_engine.md section 6. *)

type display =
  | Inline
  | Block
  | Inline_block
  | List_item
  | Flex
  | Inline_flex
  | Grid
  | Table
  | Table_row_group
  | Table_row
  | Table_cell
  | Table_caption
  | Display_none
  | Contents (* no box of its own: its children's boxes are in its place *)

type position = Static | Relative | Absolute | Fixed | Sticky

(* a length, or auto (for widths, margins, offsets) or none (for
 * max-width) *)
type size = Auto | Len of Css_values.length

type family = Serif | Sans_serif | Monospace
type white_space = Normal | Pre | Nowrap | Pre_wrap | Pre_line
type text_align = Align_left | Align_right | Align_center | Align_justify
type vertical_align = Baseline | Middle | Top | Bottom | Text_top | Text_bottom | Sub | Super
type line_height = Line_normal | Factor of float | Line_px of float
type side = Side_none | Side_left | Side_right | Side_both
type flex_direction = Row | Row_reverse | Column | Column_reverse
type align = Start | End | Center | Stretch | Space_between | Space_around | Space_evenly | Align_baseline

type t = {
  display : display;
  position : position;
  float : side; (* Side_left, Side_right or Side_none *)
  clear : side;
  top : size;
  right : size;
  bottom : size;
  left : size;
  width : size;
  height : size;
  min_width : Css_values.length;
  min_height : Css_values.length;
  max_width : size; (* Auto means none *)
  max_height : size;
  margin : size * size * size * size; (* top, right, bottom, left *)
  padding : Css_values.length * Css_values.length * Css_values.length * Css_values.length;
  border_width : float * float * float * float; (* 0 where the style is none or hidden *)
  border_color : Css_values.color * Css_values.color * Css_values.color * Css_values.color;
  border_box : bool; (* box-sizing: border-box *)
  color : Css_values.color;
  background : Css_values.color;
  background_image : string option; (* its url(), as written (Browser_page resolves a sheet's url() against the sheet) *)
  mask_image : string option; (* the url() of mask-image (or -webkit-mask-image): the box's background shows only through its picture *)
  font_size : float;
  bold : bool; (* font-weight 600 or more *)
  italic : bool;
  family : family;
  line_height : line_height;
  text_align : text_align;
  underline : bool;
  line_through : bool;
  uppercase : bool; (* text-transform: uppercase *)
  white_space : white_space;
  vertical_align : vertical_align;
  list_style : string; (* disc, circle, square, decimal, none... *)
  visible : bool; (* visibility: visible, and opacity not 0 *)
  overflow_hidden : bool; (* overflow other than visible (hidden, clip, auto, scroll): clipped, with no scrollbar *)
  flex_direction : flex_direction;
  flex_wrap : bool;
  justify_content : align;
  align_items : align;
  align_self : align option; (* None means the container's align-items *)
  flex_grow : float;
  flex_shrink : float;
  flex_basis : size;
  row_gap : Css_values.length;
  column_gap : Css_values.length;
  (* for a grid (Css_grid): its columns and its rows ([] when none are
   * given), its named areas, where the element goes in its parent's
   * grid, and how the tracks are packed in the room across (None means
   * normal, which stretches them) *)
  grid_columns : Css_grid.track list;
  (* the place of a repeat(auto-fill, ...) among the columns, and its
   * tracks; the layout decides how many of them fit *)
  grid_columns_repeat : (int * Css_grid.track list) option;
  grid_rows : Css_grid.track list;
  grid_areas : string list list;
  grid_area : Css_grid.placement;
  align_content : align option;
  custom : (string * Css_syntax.component list) list; (* the custom properties, which are inherited *)
}

(* the style of the root's parent, which is what the root inherits (the
 * initial values, and a font of 16 pixels) *)
val initial : t

(* [compute media ~root_font_size ~parent declared]: an element's
 * style, where [declared] is its cascaded declarations (from
 * Cascade) *)
val compute : Cascade.media -> root_font_size:float -> parent:t -> (string * Css_syntax.component list) list -> t

(* the browser's own style sheet, parsed *)
val user_agent_sheet : Cascade.sheet

(* the browser's sheets that come before the page's: the user agent's
 * and, with [quirks], quirks mode's (the list given to
 * Cascade.explain starts the same way) *)
val browser_sheets : quirks:bool -> Cascade.sheet list

(* [styles media sheets root]: every element's computed style, with the
 * browser's sheet first, then [sheets] (the page's). styles_with also
 * takes whether a link was visited and, with [quirks], adds quirks
 * mode's rules for a page without a DOCTYPE (a table's fonts and
 * alignment are not inherited). For styles, no link is visited and
 * there are no quirks. (ix: these are two functions, where the two
 * arguments were optional.) *)
val styles : Cascade.media -> Cascade.sheet list -> Dom.element -> Dom.element -> t
val styles_with : (string -> bool) -> quirks:bool -> Cascade.media -> Cascade.sheet list -> Dom.element -> Dom.element -> t
