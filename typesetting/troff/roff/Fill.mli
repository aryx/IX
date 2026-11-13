(* Fill: the text being read, as troff has it under any macro package.
 * It holds the paragraph that the lines of text are added to and where
 * that paragraph is, and it does the requests of troff's own that a
 * document writes between the macros. Man and Ms are written on it.
 *
 *   .in +2       the text is 2 further right, from here on
 *   .ti -2       the same, for the next line only
 *   .nf / .fi    the lines as they are, or filled
 *   .ta 10n +6n  where a tab goes
 *   .ll -5n      the line's end, 5 to the left
 *   .br          the line ends
 *   .sp 2        the line ends, and two blank lines follow
 *   .ce          the next line in the middle
 *   .ft B  .ps -2
 *
 * A paragraph is what is between two breaks. Each paragraph is kept
 * with its place, that is how far right of the text's margin it is,
 * and the tree is made from the places at the end ([tree]). What is to
 * the right of the paragraph before it goes inside an [Indent], and a
 * paragraph that started with a tag becomes a [Tagged]; both close
 * where the text comes back to the left. So a package only says where
 * the text is (.RS: further right by so much), and a page that moves
 * its margin by hand comes out right in the same way.
 *
 * What a page looks like depends on rules of troff that no page states
 * and that every page counts on. These were found by setting
 * principia's 553 manual pages beside troff's own output
 * (tests/man.sh):
 *
 *   - the end of a line is a space. It is two spaces after a sentence
 *     (a dot, ? or !, maybe followed by a closing quote or
 *     parenthesis), but only one when the line ended with a blank,
 *     which is why "e.g. " is written with one;
 *   - .ns takes away the space of the next request, unless a line was
 *     being filled;
 *   - a tab in a filled line is as wide as it would be from the start
 *     of the line as written, not from where its words end up, and
 *     the line before may end in front of it;
 *   - a terminal has whole columns: 0.75i is 7, and 2.5 columns to the
 *     left of 12.5 is 9.
 *)

(* What is read, before it becomes a tree: each thing with how far
 * right of the text's margin it is. A tag has two places, its own and
 * its body's. [Open] and [Close] go around what a footnote has, or
 * around what is to stay on one sheet. *)
type item =
  | Par of float * Doc.par
  | Tag of float * float * Doc.inline list
  | Gap of float
  | Head of int * Doc.inline list
  | Open of wrapper
  | Close
  (* a block made elsewhere, at its place: a table *)
  | Whole of float * Doc.block

and wrapper = Footnote | Keep

type t = {
  roff : Roff.t;
  (* the text's margin, from which a place given alone is counted
   * (.in 7): the manual's 5 letters, or 0 for a paper *)
  base : float;
  (* the length of the line, for .ll given alone *)
  length : float;
  (* troff's own indent, from the text's margin *)
  mutable indent : float;
  mutable indent_before : float;
  (* .ti: the place of the next line *)
  mutable ti : float option;
  (* .ll: how much shorter than the others the lines are *)
  mutable short : float;
  mutable short_before : float;
  mutable fill : bool;
  mutable tabs : float list;
  mutable center : int;
  (* .ns: the spaces asked for are not made, until some text comes *)
  mutable no_space : bool;
  (* the paragraph being read, its last words first *)
  mutable par : Doc.inline list;
  mutable started : bool;
  mutable first : float;
  (* the tab stops there were when the paragraph started *)
  mutable par_tabs : float list;
  (* whether the line before ended a sentence, ended with \c, or ended
   * with a blank *)
  mutable sentence : bool;
  mutable glued : bool;
  mutable blank_end : bool;
  (* when set, the next line of text does not go to the paragraph but
   * to this function: a heading's words, a tag *)
  mutable capture : (Doc.inline list -> unit) option;
  (* a tag was just given, and no word of its body has come yet *)
  mutable tag_open : bool;
  (* a font was asked for one line only *)
  mutable one_line : bool;
  (* the paragraph being read is a heading, of this level *)
  mutable heading : int option;
  mutable items : item list;
}

(* [create roff base length tabs] *)
val create : Roff.t -> float -> float -> float list -> t

val emit : t -> item -> unit

(* ends the paragraph so far, as every request that ends a line does *)
val break : t -> unit

(* [gap t n] adds n lines of space, unless .ns is on. *)
val gap : t -> float -> unit

(* [text t words sentence glued] adds a line's words to the paragraph
 * (or gives them to what was waiting for them). [sentence] says
 * whether they end a sentence, and [glued] whether the line ended with
 * \c. *)
val text : t -> Doc.inline list -> bool -> bool -> unit

(* [aside t run] puts the text being read aside while [run] reads
 * another one (a table's cell of several lines, with the package's
 * macros in it), and then puts the first text back as it was. It
 * returns the other text's words, and what [run] returned. *)
val aside : t -> (unit -> 'a) -> Doc.inline list * 'a

(* a line of text as it was written *)
val line : t -> string -> unit

(* does one of troff's own requests; false if it is not one known
 * here *)
val request : t -> string -> string list -> bool

val ends_sentence : Doc.inline list -> bool

(* whether a macro's last argument ends with \c *)
val glued : string list -> bool

(* a length as written, in ens *)
val length : t -> string -> float

(* on a terminal, the column to the left of a place *)
val column : t -> float -> float

(* [moved t from s] is the place that [s] gives, either from the place
 * [from] (+2, -2) or on its own (7) *)
val moved : t -> float -> string -> float

(* the tree, made from the places *)
val tree : t -> Doc.block list
