(* Roff: troff's input read as lines -- which are requests, which are
 * text -- and a line of text turned into words in fonts. What the
 * macro packages' readers (Man) stand on; not troff.
 *
 *   .TP 10          Request ("TP", ["10"])
 *   .B -c           Request ("B", ["-c"])
 *   Complement      Text "Complement"
 *   .IR string1 :   Request ("IR", ["string1"; ":"])
 *
 * A line that starts with a dot (or a quote) is a request: a name of
 * one or two letters, then its arguments, split at the spaces, an
 * argument with spaces in it between double quotes. Any other line is
 * text, with escapes in it: \fI a font, \(em a character by its name,
 * \- a minus, \& nothing at all (so that a line can start with a dot
 * and be text).
 *
 * What is done here, before a package sees the line, is the part of
 * troff's language that a page's author uses to write his own
 * shorthand, and nothing of what the packages themselves were written
 * in:
 *
 *   .de XX ... ..     a macro of the page: its lines, read again each
 *                     time .XX is met, \$1 its first argument
 *   .ds x text        a string, \*x                 (\*(xx: two letters)
 *   .nr x 5           a register, \nx               (\n(xx)
 *   .if t ...         a line for the typesetter only; .if n: for a
 *   .ie / .el         terminal; 'a'b': two strings the same; a number
 *                     more than 0. \{ and \} round several lines
 *   .ig ... ..        lines passed over
 *   .ec c  .eo        another character than the backslash, or none
 *   .tr ab            a written as b
 *   .hc c             c in a word: where it may be cut
 *   \ and a double quote: a comment, to the line's end
 *
 * A text's words come out in Doc's terms, and what troff says by an
 * escape that is not a letter is said by the character Unicode has
 * for it, which the layout knows (Doc.mli lists them):
 *
 *   \ and a space: one the line is not broken at  U+00A0
 *   \-     a minus, not a hyphen                  U+2212
 *   \%     in a word: where it may be cut         U+00AD
 *          before one: its hyphens are not        U+2011
 *   \&     nothing; no sentence ends after it     U+2060
 *
 * Not done, and said so by name ([unknown]): text set aside and brought
 * back (.di), a macro run when the page reaches a line (.wh), a second
 * set of parameters (.ev), a macro added to (.am). The packages are
 * written with those -- tmac.an's .TP sets its tag aside to measure
 * it -- which is why the packages are not run here but read as cases
 * (docs/plans/plan_typesetting.md).
 *
 * cs-history:
 * The dot at the start of a line is older than Unix: RUNOFF, Jerome
 * Saltzer's at MIT for CTSS (1964), had ".ctr" and ".sp" between the
 * lines of a text, to be "run off" on a typewriter. roff was its
 * descendant on the first Unix (1971), and what the PDP-11 was asked
 * for: a system to prepare the patent department's applications.
 * nroff ("new roff") was Joe Ossanna's of 1972, with the macros and
 * the registers, and troff (1973) the same language for a
 * phototypesetter. A name is two letters: two bytes, one word of the
 * PDP-11. *)

(* who reads the page: a page says ".if n" and ".if t", and a length
 * is not the same on the two (an inch is 10 ens of a terminal's
 * letters, 14.4 of a text of 10 points) *)
type device = Terminal | Typesetter

type line =
  (* its name without the dot, its arguments as they were written:
   * [inlines] and [number] read what is in them *)
  | Request of string * string list
  | Text of string

type t

(* [create device source]: a file's text, to be read line by line *)
val create : device -> string -> t

val device : t -> device

(* the next line that is not this module's own business; none at the
 * end *)
val next : t -> line option

(* the number of the source's line that [next] last gave (a macro's
 * lines have the number of the line that called it) *)
val line_number : t -> int

(*****************************************************************************)
(* What is in a line *)
(*****************************************************************************)

(* a text, or an argument, as words in the font and the size that the
 * escapes before them said; the font stays for the next call *)
val inlines : t -> string -> Doc.inline list

(* the same in one font, of an argument that is to be set in it:
 * the font is as it was after *)
val inlines_in : t -> Doc.font -> string -> Doc.inline list

val font : t -> Doc.font
val set_font : t -> Doc.font -> unit

(* .ps's argument: +2, -2, 10, or nothing (the text's own size) *)
val resize : t -> string -> unit

(* a register's value, in troff's basic units if it is a length; none
 * if it was never set *)
val register : t -> string -> float option

(* back to the text's own font and size *)
val reset_style : t -> unit

(* the font of a name as \f and .ft have it: I, 2, CW, P (the one
 * before) *)
val font_named : t -> string -> Doc.font

(* does the line end with \c: what follows goes on the same word *)
val continues : string -> bool

(* [number t unit text]: a length as troff writes it, 5n, 1.5i, or the
 * width of a text and 2n more (\w and the text between two quotes,
 * then u+2n), in troff's basic units; [unit] is the one of a
 * number with none ('n', 'm', 'v'). [ens] and [lines] are the two
 * ways out of the basic units. *)
val number : t -> char -> string -> float
val ens : t -> float -> float
val lines : t -> float -> float

(* how a file is read by its name, for .so and for a picture kept in
 * a file of its own: nothing is read until a program that may open
 * files says how ([load] gives none) *)
val set_loader : t -> (string -> string option) -> unit
val load : t -> string -> string option

(* how wide a text is, in ens, for \w: every character one, until a
 * writer that has fonts says otherwise *)
val set_measure : t -> (Doc.inline list -> float) -> unit

(* a text read a second time, as a macro's lines are: its \\ are \, and
 * the strings and registers named after them are put in. A table's
 * data is read so by troff, tbl having put it inside a macro. *)
val again : t -> string -> string

(* the registers and the strings: a package has its own (\n(PD) *)
val set_register : t -> string -> float -> unit
val set_string : t -> string -> string -> unit

(*****************************************************************************)
(* What was not understood *)
(*****************************************************************************)

(* [unknown t what]: said by a package of a request it does not know *)
val unknown : t -> string -> unit

(* each, with its line, in the page's order *)
val complaints : t -> (int * string) list
