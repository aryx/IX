(* A document, whatever it was written in. Every reader makes one (Man,
 * Ms, Ixdoc, Latex) and every writer takes one (To_text, To_pdf, and
 * Ixdoc again).
 *
 *   man pages --Man----+                          +--To_text--> a terminal
 *   papers ----Ms------+--> Doc.t --Layout--> lines
 *   Markdown --Ixdoc---+      |                   +--To_pdf---> a PDF file
 *   books -----Latex---+      +--Ixdoc--> Markdown
 *
 * It is a tree. A paragraph is its text, in fonts. What is set to the
 * right of the paragraphs around it is inside an [Indent]. A paragraph
 * that hangs from a word (an option and what it does) is a [Tagged]:
 *
 *   .PP                      Para "Any combination of the options..."
 *   Any combination ...      Space 1
 *   .TP                      Tagged { tag = "-c"; width = 5;
 *   .B -c                             body = [ Para "Complement..." ] }
 *   Complement ...
 *
 *        Any combination of the options -cds may be used:
 *
 *        -c   Complement string1: replace it with a
 *        |<5>|ordered list of all other characters.
 *
 * Nothing here comes from troff: there is no request and no register.
 * A blank line is a [Space], given by the reader and not guessed by
 * the layout, so that a page whose author closed up a list (.PD 0)
 * stays closed up.
 *
 * Widths and indents are in ens. An en is the width of a letter on a
 * terminal (where an em, the height of a letter, is taken to be the
 * same). A [Space] is in lines.
 *
 * (See docs/plans/done/plan_typesetting.md.) *)

(* Mono is the font of what is typed. Plan 9's manual sets a command's
 * name and its options in it, where Unix's manual used bold. *)
type font = Roman | Italic | Bold | Mono

(* size is how many points more (or less) than the text around; shift
 * is how many half lines up (an exponent) or down. *)
type style = { font : font; size : int; shift : int }

type inline =
  (* A line may be broken at one of its spaces, and after a hyphen
   * inside a word. Unicode's own characters say the rest:
   *   U+00A0  a space where the line may not be broken
   *   U+2011  a hyphen after which it may not be broken
   *   U+2212  a minus (the same)
   *   U+00AD  where a word may be cut, with a hyphen added if it is
   *   U+200B  where it may be broken with nothing added
   *   U+2060  nothing at all; after a dot, no sentence ends there
   * A tab goes to the paragraph's next stop. *)
  | Text of style * string
  (* The line ends here. It is used between the lines of a paragraph
   * that is not filled. *)
  | Break
  (* The number of the sheet that an [Anchor] of this name is on,
   * written when the sheets are made (To_pdf). Where there are no
   * sheets (on a terminal), or the name is on none, the text is
   * written instead. *)
  | Page of style * string * string

type par = {
  (* When filled, the words are put on lines as they fit. When not
   * filled, the lines stay as they were written (a program's text, an
   * example). *)
  fill : bool;
  (* how far to the right of the other lines the first line starts;
   * less than 0 means to their left *)
  first : float;
  (* how much shorter than the others its lines are, for a quotation
   * or an abstract, set in from both sides *)
  short : float;
  (* where each tab stop is, from the paragraph's left *)
  tabs : float list;
  center : bool;
  body : inline list;
}

(* A table has rows of cells, in columns as wide as their widest cell.
 *
 *     Variable   Default   Meaning
 *     CFLAGS      -FVw     C compiler flags
 *     LDFLAGS              Loader flags
 *
 * A cell is at its column's left, right or middle, or it is a number
 * with its decimal point under those of the others. It may go across
 * several columns (a title over the table). It may also be a text that
 * is filled in its column's width, on as many lines as it takes. *)
type align = Left | Right | Center | Numeric

type cell = {
  align : align;
  (* how many columns it goes across, usually 1 *)
  span : int;
  (* a text filled in the column's width *)
  filled : bool;
  body : inline list;
}

type table_row = Cells of cell list | Rule

type table = {
  centered : bool;
  (* a rule over it and under it *)
  boxed : bool;
  (* the width of each column when the table gives it (0 when it does
   * not, and then it is the width of the widest cell) *)
  widths : float list;
  rows : table_row list;
}

(* A picture has lines, words, and pictures from files, placed in
 * inches from its lower left corner, with up being up. *)
type mark =
  (* a line through points *)
  | Stroke of (float * float) list
  (* words on one line, with their middle at a point (0), or their left
   * end (-1), or their right end (1) *)
  | Label of float * float * int * inline list
  (* a picture from a file: its lower left corner, how wide and how
   * high it is shown, the file's name, and its pixels *)
  | Image of float * float * float * float * string * Rgba_image.t

type picture = { wide : float; high : float; marks : mark list }

type block =
  (* 1 is a section's heading (NAME, SYNOPSIS), 2 a subsection's *)
  | Heading of int * inline list
  | Para of par
  (* The tag is at the left, and the body is [width] to its right. The
   * body starts on the tag's line when the tag is shorter than that. *)
  | Tagged of tagged
  | Indent of float * block list
  | Space of float
  (* Its mark is shown in the text, and it is written at the foot of
   * the sheet (at the end of the document, on a terminal). *)
  | Footnote of block list
  (* what must not be cut by the end of a sheet: a display, a figure *)
  | Keep of block list
  | Table of table
  | Picture of picture
  (* A place that a [Page] names: the sheet of the next line. The bool
   * says it is lettered: a chunk of noweb's, whose number is the
   * sheet's number with a letter when the sheet has several (12a,
   * 12b). *)
  | Anchor of string * bool

and tagged = { tag : inline list; width : float; body : block list }

type t = {
  (* What is at the top of each page, at its left, in its middle and
   * at its right ("WC(1)", "", "WC(1)"). Nothing is shown if all three
   * are empty. *)
  header : string * string * string;
  (* The length of the lines: 65 letters for the manual on a terminal,
   * 60 for a paper; 6.5 inches and 6 inches on paper. *)
  width : float;
  (* Where the text is, from the left. A manual page's text is to the
   * right of its headings, with a section's heading at 0 and a
   * subsection's at [sub]. A paper's text is at 0, like its
   * headings. *)
  margin : float;
  sub : float;
  body : block list;
}

(* the style of plain text: Roman, at its normal size, on the line *)
val plain : style

(* a text without the three characters that are not seen (U+00AD,
 * U+200B, U+2060). This is what is measured, and written. *)
val letters : string -> string

(* the letters of a text, without its looks; the end of a line becomes
 * a space *)
val words : inline list -> string

(* the same document, with each of its texts changed *)
val map_text : (style -> string -> string) -> t -> t
val map_inline : (inline -> inline) -> t -> t

(* each [Page] replaced by a text: the sheet its name is on, or its own
 * text *)
val pages : (string -> string option) -> t -> t
