(* Looks: what a word is drawn in. That is its size, its weight and
   slant, its colour, whether it is a link (and the colours of links),
   and whether its spaces are kept. Box_layout gives one to each
   fragment of a line, from the element's computed style (Computed);
   Browser_draw and Browser_text draw and measure the word in it.

   cs-history:
   Before style sheets, the browser decided the looks. Mosaic's looks
   were in its X resources (the font of each heading, the colour of a
   link), and the page could only choose among elements. Every browser
   since has kept the same table as its default: CSS 2.1 wrote it down
   in its appendix D, "Default style sheet for HTML 4", which is ua.css
   here, the first sheet of the cascade (Computed.browser_sheets).
   Netscape let a page change some of it in the HTML itself, tag by tag
   (<font size= color=>, <center>, <body text= link= vlink=>), and its
   [font_scale] is still how Cascade reads <font size=>. The first
   version of mini-chrome computed the looks down the tree from that
   table here, for Mosaic's layout (Html_layout.mli); the computing
   went away with that layout (2026-10-19, docs/plans/plan_browser.md,
   "Smaller").

   Reference: W3C, CSS 2.1, appendix D (the default style sheet for
   HTML 4); HTML 3.2 (<font>); Mosaic's Mosaic.ad resources. *)

type color = int * int * int (* red, green, blue, 0-255 *)
type align = Left | Center | Right

type t = {
  size : float; (* an em, in the page's units *)
  bold : bool;
  italic : bool;
  underline : bool;
  strike : bool;
  monospace : bool;
  color : color;
  link : string option; (* the href of the link the text is in *)
  pre : bool; (* spaces and newlines are kept, lines are never broken *)
  align : align; (* where a block's lines go *)
  link_color : color; (* the colour of a link: blue, or body link= *)
  visited_color : color; (* of a visited link: purple, or body vlink= *)
  base : float; (* the root's size, which is <font size=3> *)
  extensions : bool; (* whether Netscape's extensions are honoured *)
}

(* the root's look: black text of [size], with every flag off *)
val root : float -> t

(* the factor of the root's size that <font size=> gives: "1" to "7",
 * or "+n" and "-n" counted from 3, kept within 1..7 *)
val font_scale : string -> float option

(* the height of a line, in ems: CSS's "normal", which is about what
 * fonts ask for *)
val leading : float
