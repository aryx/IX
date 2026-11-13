(* Html_layout: a page laid out, as what comes after the layout reads
   it. Every block is a box with a place and a size, and every word is
   a fragment on a line.

   Box_layout lays the page out by CSS's box model, and also gives its
   boxes as these types ([Box_layout.as_html_layout]). Browser_draw's
   words, Hit (a click's fragment), Browser_forms and Tab (a #fragment's
   line, a script asking where an element is) read only these. The
   coordinates are the typesetter's (as in Page.mli): x goes from the
   page's left, and y goes **down** from its top; the app turns them
   over to draw.

   The words of a line share a **baseline**. Each word's look gives its
   ascent (0.8 em) and descent (0.2 em), and the line height (1.2 em,
   Looks.leading) spreads the rest half above and half below (CSS's
   "half-leading"). A picture (<img>, from Mosaic, 1993) and a form's
   control (from Mosaic 2.0) are fragments too, with no text: each is a
   word that is a box of its own size. A list item's marker belongs to
   its box, and is drawn to the left of its first line.

   cs-history:
   These types were first those of Mosaic's layout, the web's first
   with pictures in the text. Mosaic (Marc Andreessen and Eric Bina,
   NCSA, 1993) laid a page out in one pass over its elements, with the
   look of each kind fixed by the browser (Looks.mli): there were no
   boxes to speak of, and no style sheet. What Netscape (1994, made by
   the same two and most of their team) added to the model was less the
   tags than the timing. It laid out and drew the page as its bytes
   arrived, text first with the pictures filling in, where Mosaic
   waited for everything. On a modem, that was the difference between a
   web that felt slow and one that felt alive. mini-chrome's first
   version had that layout here, with its floats (Netscape 1.0's <img
   align=left>) and its tables (Netscape 1.1's), beside Box_layout,
   CSS's layout, which replaced it. No page that mini-netscape reads
   used it, and it went (2026-10-19, docs/plans/plan_browser.md,
   "Smaller"). It is still in mini-chrome.

   Reference: W3C, CSS 2.1, chapters 9.2 (block and inline boxes) and
   10.8 (line height, half-leading); Web Browser Engineering, chapter 3
   ("Formatting Text"). *)

(* the width of a string in a look, given by the caller's font *)
type metrics = Looks.t -> string -> float

(* an image in a line: its src (as the page wrote it), its size, and
 * whether its middle or its bottom is on the baseline (align=middle,
 * or bottom, which is Mosaic's default) *)
type picture = { src : string; height : float; middle : bool }

(* a form's control in a line (Forms): the page's element (which is the
 * key of its value, kept by the browser), and its height. Its bottom
 * is a quarter of its height below the baseline, where the baseline of
 * its own text falls *)
type control = { element : Dom.element; control_height : float }

(* a word (or, in <pre>, a line's text; or an image or a control, whose
 * [text] is ""), and where it goes *)
type fragment = {
  text : string;
  look : Looks.t;
  x : float; (* its left edge *)
  width : float;
  baseline : float;
  picture : picture option;
  control : control option;
  element : Dom.element; (* the innermost element it is in: a click on it is on that *)
}

(* a line, and the names on it that a #fragment can scroll to: <a
 * name=x>, or an inline element's id=x (an anchor alone, with no text
 * before it, is a line of no height where it is) *)
type line = { top : float; height : float; baseline : float; fragments : fragment list; anchors : string list }

type kind =
  | Block of Dom.element
  | Anonymous (* the lines of a run of inline content *)
  | Rule of Dom.element (* hr *)

(* a list item's marker: a bullet (ul, dir, menu), or its number (ol) *)
type marker = Bullet | Number of int

type box = {
  kind : kind;
  x : float;
  y : float;
  width : float;
  height : float;
  children : box list; (* its blocks, in order *)
  lines : line list; (* an Anonymous box's lines *)
  floats : fragment list; (* an Anonymous box's floats (pictures), placed *)
  marker : marker option; (* a list item's marker *)
  background : Looks.color option; (* a style sheet's background-color *)
}

(* the size (width, height) of a form's control in the look it is in,
 * by its kind; None for a hidden one, or for what is not a control *)
val control_size : metrics -> Looks.t -> Dom.element -> (float * float) option

(* every fragment of the page, in document order (a box's floats come
 * after its lines) *)
val fragments : box -> fragment list

(* the size when no picture's size is known: every image is the size of
 * its width= and height=, or of its alt text (for the tests and the
 * tools) *)
val no_picture : string -> (float * float) option
