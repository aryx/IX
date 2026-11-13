(* Box_layout: a page laid out by CSS 2.1's box model. This is
   mini-netscape's layout, done over each element's computed style
   (Computed).

   (See mini-chrome's notes_css_engine.md section 7.) It reads nothing
   but the computed style, so that a page gets what its style sheets
   say. It gives its boxes as Html_layout's lines and fragments (a
   fragment is a word, a picture or a control, and where it goes),
   which Hit, the form controls and the drawing of words read
   ([as_html_layout]).

   **The box.** Every block is a content box inside its padding, its
   border and its margin. The box kept here is the border box (what a
   background fills), with the widths of its border:

     margin-left | border | padding | content | padding | border | margin-right

   Their sum is the containing block's width. This is CSS 2.1's section
   10.3.3: one equation, whose unknowns are the autos. A width that is
   auto takes what the margins, borders and paddings leave. When a
   width is given and both margins are auto, the margins share the rest
   between them, which centres the box:

     containing block 976, width 400, padding 10, border 1, margins auto
       (976 - 400 - 22) / 2 = 277 each: the box at x 277, 422 wide

   box-sizing: border-box counts the padding and the border inside the
   width (GitHub's and Google's sheets set it everywhere). min-width and
   max-width clamp the width (max-width: 100% is the responsive
   picture).

   **Vertical margins collapse** where two of them touch: the larger
   counts (and a negative one is subtracted). This happens between
   siblings, and between a block and its first child (or its last) when
   no border or padding comes between them. So the body's 8 and an h1's
   21.4 give 21.4 above the h1, not 29.4, and the h1's margin shows
   outside the body. The two margins of an empty block are one. A block
   whose own layout is apart keeps its margins inside it; that is a
   block formatting context: an overflow other than visible, a float,
   an inline-block, a table cell, or the root.

   **Inline content** is set on lines as in Html_layout: words are cut
   at spaces, a unit is the words with no space between them, and the
   words share a baseline. But the room of each word above and below
   the baseline comes from its own element's line-height (normal is
   1.2 em), split as half-leading around its font's ascent and descent
   (0.8 and 0.2 em). The block's own font gives every line a minimum
   (the "strut": an empty line is as tall as a line of the block's
   text). The white-space values are normal, nowrap (no break between
   its words), pre and pre-wrap (the lines are kept), and pre-line (the
   spaces are collapsed and the newlines kept). Also done are
   text-align, text-transform: uppercase, and vertical-align: sub and
   super (which move the baseline).

   **An inline element's box** (a <code> on a grey background, a badge,
   a navigation's link with its padding) is not a block. Its left
   margin, border and padding become a spacer word joined to its first
   word, and its right ones a spacer joined to its last, so the line
   makes room for them. Its background and border, if it has them, are
   drawn as a box for each line it is on ([backdrops]), from its first
   word there to its last. That box is as tall as its font plus its
   vertical padding and border, which do not make the line taller and
   may overlap the lines around, as in every browser:

     a <span style="padding: 0 5px; background: yellow">b</span> c
       "a" at 0, the span's box from 20 (the space after "a") to 40,
       "b" at 25, "c" after the box and a space: 50

   **An inline-block** (a button, a navigation's item) is laid out as a
   block of its own width, and set in the line as one unit, with its
   last line's baseline on the line's. Its width is given, or is
   **shrink-to-fit**: its content's widest line, at most the room there
   is, and at least its widest word. A picture is a unit of its own
   size. That size is its width and height (the page's attributes,
   which are style through Cascade's presentational hints), or one of
   them and the picture's ratio, or the picture's own size once it has
   come. A form's control is a unit of one of Html_layout.control_size's
   sizes.

   **Floats** are taken out of the flow, laid out shrink-to-fit, and put
   against the left or right edge where they meet a line (below a line
   that has begun). The lines beside them are shortened until the
   float's bottom, but the boxes of the blocks are not (only their
   lines are: this is the clearfix's story). clear moves a block below
   them. A block formatting context beside a float is narrowed instead
   (overflow: hidden beside a sidebar), and it holds its own floats,
   with its height enclosing them.

     float: left, width 40, height 30; then "aa bb cc", a page 200
       the float at x 8..48; the line beside it from 48, 144 wide

   **Positioning**: relative moves a box by its offsets after it is
   laid out (what is around it stays). Absolute takes the box out of
   the flow and places it by its offsets in the padding box of the
   nearest positioned ancestor (at its place in the flow where the
   offsets are auto); the box is laid out shrink-to-fit and drawn after
   the rest (as the last boxes of the page's root). Fixed is absolute
   in the window's first screen (here it scrolls with the page, which
   is an exercise).

   **Tables** (display: table): the grid and the widths of the columns
   come from Table_layout, and each cell is asked its minimum and
   maximum by being laid out at width 0 and without limit. Each row is
   as tall as its tallest cell, and the cell's content is at its top,
   middle or bottom (vertical-align).
   The cells are cellspacing= apart (2), and a cell without a
   background shows its row's.

   **Lists**: a list-item's marker (a bullet, or its number when its
   list-style-type counts: decimal, lower-alpha...) is drawn outside,
   left of its first line.

   **A flex container** (display: flex, inline-flex) lays its children
   out as items. Each one is blockified (a run of its text becomes an
   anonymous item) and measured here. Its base size is its flex-basis,
   its width, or its content's (shrink-to-fit at an unlimited width),
   and its minimum is its widest word, measured only when the line is
   too full. Then Flex_layout's arithmetic gives the lines, shares the
   room by grow and shrink, and places the items along the line
   (justify-content, auto margins) and across it (align-items,
   stretched). A single line is as tall as its container when that
   height is given. The items of a column are laid out at their width
   first, and their heights are then their base sizes.

   **Measuring** (for shrink-to-fit, a flex item's base, or a table's
   column) lays the content out at a width without limit (which gives
   its widest line) and at 0 (which gives its widest word). So a few
   things are taken differently there, as CSS's intrinsic sizes say, or
   nearly: the lines are on the left, a <center> does not centre, a
   percentage width is taken as auto (it would be a percentage of the
   size being measured), a right float is on the left, and a flex row
   neither grows nor shrinks nor is spread by justify-content, while
   its end, including its last item's margin, is marked by an empty
   box.

   Not done: rowspan=, the bottom and right of an absolute box whose top
   and left are auto, fixed boxes staying on screen, z-index (the page's
   order is the drawing's order), and flex's order and baseline
   alignment.

   Worked example (the tests'): a character is as wide as its size, the
   root's font is 10 (line-height normal: 12), and the page is 200
   wide:

     <body style="margin: 8px"><div style="width: 100px; margin: 0
       auto; padding: 5px; border: 2px solid">ab</div>

     body   x 8, width 184
     div    margins (184 - 100 - 14) / 2 = 35: x 43, width 114 (its
            border box), y 8 (the body's margin and the div's 0
            collapsed); "ab" at x 43 + 2 + 5 = 50, its line from 15, 12
            high: the div 12 + 14 = 26 high

   cs-history:
   Where the box model came from. Before CSS, a page was laid out by
   its tags (Html_layout.mli: Mosaic's flow) and, from 1995, by tables
   used for what they were not meant for (Table_layout.mli). CSS1
   (1996) gave every element a box (content, padding, border, margin),
   and CSS2 (1998) gave the rules by which boxes are placed: blocks are
   stacked, inline boxes flow into lines, and there are floats (born as
   Netscape's <img align=left>, with text flowing round a picture) and
   positioning. Browsers disagreed on it for a decade. Internet
   Explorer 5 counted padding and border inside "width", and the
   standard counts them outside. Pages were written for each, and to
   keep the old ones working, browsers took the page's <!DOCTYPE> as a
   switch between "quirks" and "standards" (2000), which is still
   there. CSS 2.1 (a Recommendation only in 2011) is CSS2 corrected to
   what browsers could be made to agree on, chapter 9 above all; the
   Acid2 test (2005) is how they were held to it. Its vocabulary (block
   formatting context, containing block, margin collapsing) is this
   module's.

   comeback:
   Internet Explorer 5's width, with padding and border counted inside,
   was the bug of the story above, and it was the one authors wanted: a
   column "50% wide with 10 pixels of padding" cannot be written the
   standard's way without calc(). CSS3 gave it back as a property,
   box-sizing: border-box, and the sheets of today set it on every
   element, as said above.

   Reference: Bert Bos, Tantek Celik, Ian Hickson and Hakon Wium Lie
   (editors), CSS 2.1 (W3C, 2011), chapters 8 (the box model, collapsing
   margins), 9 (the visual formatting model: block and inline
   formatting contexts, floats, positioning), 10 (widths and heights:
   10.3.3's equation, shrink-to-fit in 10.3.5, line height in 10.8) and
   17 (tables); Web Browser Engineering, chapters 5 and 6;
   mini-chrome's notes_css_engine.md section 7. *)

type box = {
  element : Dom.element option; (* None for an anonymous box of lines *)
  style : Computed.t; (* its element's; an anonymous box has its block's *)
  x : float; (* the border box, in the page's coordinates (y down) *)
  y : float;
  width : float;
  height : float;
  border : float * float * float * float; (* its widths: top, right, bottom, left *)
  children : box list; (* its blocks; for an anonymous box, its inline-blocks and floats *)
  lines : Html_layout.line list; (* an anonymous box's lines *)
  backdrops : box list; (* for an anonymous box, the boxes of its inline elements, one piece for each line, drawn under its words *)
  marker : Html_layout.marker option; (* a list item's marker *)
}

(* [layout metrics picture_size ~viewport styles root]: the page laid
 * out in a window [viewport] (width, height). [styles e] is each
 * element's computed style (Computed.styles), and [picture_size src] is
 * a picture's own size if it has come (with Html_layout.no_picture,
 * none has) *)
val layout :
  Html_layout.metrics ->
  (string -> (float * float) option) ->
  viewport:float * float ->
  (Dom.element -> Computed.t) ->
  Dom.element ->
  box

(* a picture's address: its src=, or else the first of its srcset=
 * (for the pages that give only srcset=, where the browser chooses
 * among the sizes) *)
val picture_src : Dom.element -> string option

(* the look a fragment of text in this style is drawn with (Browser_draw
 * draws looks): its size, weight, slant, face, colour and decoration.
 * [link] is the href around it *)
val look_of : Computed.t -> link:string option -> Looks.t

(* the same page as Html_layout's boxes (with their borders and styles
 * dropped), for Hit, the form controls and the anchors *)
val as_html_layout : box -> Html_layout.box

(* every fragment of the page: each box's lines, then its children's
 * (an inline-block's words come after those of its line) *)
val fragments : box -> Html_layout.fragment list
