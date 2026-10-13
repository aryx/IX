(* A document, whatever it was written in: what every reader makes
 * (Man, of a manual page) and every writer takes (To_text).
 *
 *   man pages --Man--+
 *                    +--> Doc.t --Layout--> lines --To_text--> a terminal
 *   (.ms, ...)  -----+
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
  (* where a tab goes, from the paragraph's left *)
  tabs : float list;
  center : bool;
  body : inline list;
}

type block =
  (* 1: a section's (NAME, SYNOPSIS), 2: a subsection's *)
  | Heading of int * inline list
  | Para of par
  (* the tag at the left, the body [width] to its right, starting on
   * the tag's line when the tag is shorter than that *)
  | Tagged of tagged
  | Indent of float * block list
  | Space of float

and tagged = { tag : inline list; width : float; body : block list }

(* [header]: what is at the top of each page, at its left, in its
 * middle and at its right ("WC(1)", "", "WC(1)") *)
type t = { header : string * string * string; body : block list }

(* the text's own: Roman, its size, on the line *)
val plain : style

(* a text without the three characters that are not seen (U+00AD,
 * U+200B, U+2060): what is measured, and written *)
val letters : string -> string
