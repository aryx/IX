(* A document, whatever it was written in: what every reader makes
 * (Man, Ms, Ixdoc, Latex) and every writer takes (To_text, To_pdf, and
 * Ixdoc again).
 *
 *   man pages --Man----+                          +--To_text--> a terminal
 *   papers ----Ms------+--> Doc.t --Layout--> lines
 *   Markdown --Ixdoc---+      |                   +--To_pdf---> a PDF file
 *   books -----Latex---+      +--Ixdoc--> Markdown
 *
 * It is a tree. A paragraph is its text in fonts; what is to its right
 * of the paragraphs around it is inside an [Indent]; a paragraph that
 * hangs from a word (an option and what it does) is a [Tagged]:
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
 * Nothing here is troff's: no request, no register. A blank line is a
 * [Space], said by the reader and not guessed by the layout, so that a
 * page whose author closed up a list (.PD 0) stays closed up.
 *
 * Widths and indents are in ens: the width of a letter of a terminal
 * (where an em, a letter's height, is taken to be the same). A
 * [Space] is in lines.
 *
 * (docs/plans/plan_typesetting.md; its other blocks, a table, a
 * figure, a footnote, come with the readers that need them) *)

(* Mono is the font of what is typed: Plan 9's manual sets a command's
 * name and its options in it, where Unix's had bold *)
type font = Roman | Italic | Bold | Mono

(* size: points more than the text around, or less; shift: half lines
 * up (an exponent) or down *)
type style = { font : font; size : int; shift : int }

type inline =
  (* a line may be broken at a space of it, and after a hyphen inside
   * a word. Unicode's own characters say the rest:
   *   U+00A0  a space where it may not be broken
   *   U+2011  a hyphen after which it may not
   *   U+2212  a minus (the same)
   *   U+00AD  where a word may be cut, a hyphen added if it is
   *   U+200B  where it may be broken with nothing added
   *   U+2060  nothing at all; after a dot, no sentence ends there
   * and a tab goes to the paragraph's next stop. *)
  | Text of style * string
  (* the line ends here: between the lines of a paragraph that is not
   * filled *)
  | Break

type par = {
  (* filled: the words put on lines as they fit. Not filled: the lines
   * as they were written (a program's text, an example) *)
  fill : bool;
  (* how far right of the others the first line starts; less than 0:
   * to their left *)
  first : float;
  (* how much shorter than the others its lines are: a quotation, an
   * abstract, set in from both sides *)
  short : float;
  (* where a tab goes, from the paragraph's left *)
  tabs : float list;
  center : bool;
  body : inline list;
}

(* A table: rows of cells in columns as wide as their widest cell.
 *
 *     Variable   Default   Meaning
 *     CFLAGS      -FVw     C compiler flags
 *     LDFLAGS              Loader flags
 *
 * A cell is at its column's left, right or middle, or is a number
 * with its decimal point under the others'; it may go across several
 * columns (a title over the table); and it may be a text that is
 * filled in its column's width, on as many lines as it takes. *)
type align = Left | Right | Center | Numeric

type cell = {
  align : align;
  (* how many columns it goes across: 1 *)
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
  (* each column's width when the table says it (0 when not: its
   * widest cell's) *)
  widths : float list;
  rows : table_row list;
}

(* A picture: lines and words, placed in inches from its lower left
 * corner, up being up. *)
type mark =
  (* a line through points *)
  | Stroke of (float * float) list
  (* words on one line, their middle at a point (0), or their left
   * end (-1), or their right end (1) *)
  | Label of float * float * int * inline list

type picture = { wide : float; high : float; marks : mark list }

type block =
  (* 1: a section's (NAME, SYNOPSIS), 2: a subsection's *)
  | Heading of int * inline list
  | Para of par
  (* the tag at the left, the body [width] to its right, starting on
   * the tag's line when the tag is shorter than that *)
  | Tagged of tagged
  | Indent of float * block list
  | Space of float
  (* said where its mark is in the text; written at the foot of the
   * sheet (at the document's end, on a terminal) *)
  | Footnote of block list
  (* what is not to be cut by the end of a sheet: a display, a figure *)
  | Keep of block list
  | Table of table
  | Picture of picture

and tagged = { tag : inline list; width : float; body : block list }

type t = {
  (* what is at the top of each page, at its left, in its middle and
   * at its right ("WC(1)", "", "WC(1)"); nothing if all are empty *)
  header : string * string * string;
  (* the lines' length: 65 letters for the manual on a terminal, 60 for
   * a paper; 6.5 inches and 6 on paper *)
  width : float;
  (* where the text is, from the left: a manual page's is to the right
   * of its headings, a section's at 0, a subsection's at [sub]; a
   * paper's is at 0 as its headings *)
  margin : float;
  sub : float;
  body : block list;
}

(* the text's own: Roman, its size, on the line *)
val plain : style

(* a text without the three characters that are not seen (U+00AD,
 * U+200B, U+2060): what is measured, and written *)
val letters : string -> string

(* the same document, each text of it changed *)
val map_text : (style -> string -> string) -> t -> t
