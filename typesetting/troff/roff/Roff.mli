(* Roff reads troff's input as lines, telling which ones are requests
 * and which are text, and turns a line of text into words in fonts.
 * The readers of the macro packages (Man) stand on it. It is not
 * troff.
 *
 *   .TP 10          Request ("TP", ["10"])
 *   .B -c           Request ("B", ["-c"])
 *   Complement      Text "Complement"
 *   .IR string1 :   Request ("IR", ["string1"; ":"])
 *
 * A line that starts with a dot (or a quote) is a request: a name of
 * one or two letters, then its arguments, split at the spaces. An
 * argument with spaces in it is put between double quotes. Any other
 * line is text, with escapes in it: \fI for a font, \(em for a
 * character by its name, \- for a minus, \& for nothing at all (so
 * that a line can start with a dot and still be text).
 *
 * What is done here, before a package sees the line, is the part of
 * troff's language that a page's author uses to write his own
 * shorthand. None of what the packages themselves were written in is
 * done here:
 *
 *   .de XX ... ..     a macro of the page: its lines are read again
 *                     each time .XX is met, and \$1 is its first
 *                     argument
 *   .ds x text        a string, \*x                 (\*(xx: two letters)
 *   .nr x 5           a register, \nx               (\n(xx)
 *   .if t ...         a line for the typesetter only; .if n is for a
 *   .ie / .el         terminal; 'a'b' tests that two strings are the
 *                     same; a number tests that it is more than 0.
 *                     \{ and \} go around several lines
 *   .ig ... ..        lines that are skipped
 *   .ec c  .eo        another character than the backslash, or none
 *   .tr ab            a is written as b
 *   .hc c             c in a word marks where it may be cut
 *   \ and a double quote: a comment, to the end of the line
 *
 * A text's words come out in Doc's terms. What troff says with an
 * escape that is not a letter is said with the character that Unicode
 * has for it, which the layout knows (Doc.mli lists them):
 *
 *   \ and a space: a space the line is not broken at  U+00A0
 *   \-     a minus, not a hyphen                      U+2212
 *   \%     inside a word: where it may be cut         U+00AD
 *          before a word: its hyphens may not be cut  U+2011
 *   \&     nothing; no sentence ends after it         U+2060
 *
 * Some things are not done, and are reported by name ([unknown]): text
 * set aside and brought back (.di), a macro run when the page reaches
 * a line (.wh), a second set of parameters (.ev), and adding to a
 * macro (.am). The packages are written with those (tmac.an's .TP
 * sets its tag aside to measure it), which is why the packages are
 * not run here but read as cases
 * (docs/plans/done/plan_typesetting.md).
 *
 * cs-history:
 * The dot at the start of a line is older than Unix. RUNOFF, which
 * Jerome Saltzer wrote at MIT for CTSS (1964), had ".ctr" and ".sp"
 * between the lines of a text, to be "run off" on a typewriter. roff
 * was its descendant on the first Unix (1971), and it was what the
 * PDP-11 was bought for: a system to prepare the patent department's
 * applications. Joe Ossanna wrote nroff ("new roff") in 1972, with
 * the macros and the registers, and troff (1973) is the same language
 * for a phototypesetter. A name has two letters because two bytes are
 * one word of the PDP-11. *)

(* Who reads the page. A page says ".if n" and ".if t", and a length is
 * not the same on the two devices (an inch is 10 ens of a terminal's
 * letters, and 14.4 ens of a text of 10 points). *)
type device = Terminal | Typesetter

type line =
  (* its name without the dot, and its arguments as they were written;
   * [inlines] and [number] read what is in them *)
  | Request of string * string list
  | Text of string

type t

(* [create device source] prepares a file's text to be read line by
 * line. *)
val create : device -> string -> t

val device : t -> device

(* the next line that this module does not handle itself; None at the
 * end *)
val next : t -> line option

(* the number of the source line that [next] last gave (the lines of a
 * macro have the number of the line that called it) *)
val line_number : t -> int

(*****************************************************************************)
(* What is in a line *)
(*****************************************************************************)

(* a text, or an argument, as words in the font and the size that the
 * escapes before them set. The font stays set for the next call. *)
val inlines : t -> string -> Doc.inline list

(* the same, for an argument that is to be set in one font. The font
 * afterwards is the one from before. *)
val inlines_in : t -> Doc.font -> string -> Doc.inline list

val font : t -> Doc.font
val set_font : t -> Doc.font -> unit

(* .ps's argument: +2, -2, 10, or nothing (the text's own size) *)
val resize : t -> string -> unit

(* a register's value, in troff's basic units if it is a length; None
 * if it was never set *)
val register : t -> string -> float option

(* goes back to the text's own font and size *)
val reset_style : t -> unit

(* the font of a name as \f and .ft take it: I, 2, CW, or P (the one
 * before) *)
val font_named : t -> string -> Doc.font

(* whether the line ends with \c, meaning that what follows goes on the
 * same word *)
val continues : string -> bool

(* [number t unit text] reads a length as troff writes it (5n, 1.5i,
 * or the width of a text plus 2n, written \w, the text between two
 * quotes, then u+2n) and returns it in troff's basic units. [unit] is
 * the unit of a number that has none ('n', 'm', 'v'). [ens] and
 * [lines] are the two ways out of the basic units. *)
val number : t -> char -> string -> float
val ens : t -> float -> float
val lines : t -> float -> float

(* How a file is read by its name, for .so and for a picture kept in a
 * file of its own. Nothing is read until a program that may open
 * files says how (until then [load] gives None). *)
val set_loader : t -> (string -> string option) -> unit
val load : t -> string -> string option

(* how wide a text is, in ens, for \w. Every character is one en wide
 * until a writer that has fonts says otherwise. *)
val set_measure : t -> (Doc.inline list -> float) -> unit

(* a text read a second time, as a macro's lines are: its \\ become \,
 * and the strings and registers named after them are put in. troff
 * reads a table's data this way, because tbl has put it inside a
 * macro. *)
val again : t -> string -> string

(* the registers and the strings; a package sets its own (\n(PD) *)
val set_register : t -> string -> float -> unit
val set_string : t -> string -> string -> unit

(*****************************************************************************)
(* What was not understood *)
(*****************************************************************************)

(* [unknown t what] is called by a package for a request it does not
 * know. *)
val unknown : t -> string -> unit

(* each complaint, with its line, in the page's order *)
val complaints : t -> (int * string) list
