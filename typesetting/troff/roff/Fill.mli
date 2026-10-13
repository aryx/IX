(* Fill: the text being read, as troff has it under any macro package --
 * the paragraph that the lines of text are added to, where it is, and
 * the requests of troff's own that a document writes between the
 * macros. What Man and Ms are written on.
 *
 *   .in +2       the text is 2 further right, from here on
 *   .ti -2       the next line only
 *   .nf / .fi    the lines as they are, or filled
 *   .ta 10n +6n  where a tab goes
 *   .ll -5n      the line's end, 5 to the left
 *   .br          the line ends
 *   .sp 2        and two blank lines
 *   .ce          the next line in the middle
 *   .ft B  .ps -2
 *
 * A paragraph is what is between two breaks. Each is kept with its
 * place, how far right of the text's margin it is, and the tree is
 * made at the end from the places ([tree]): what is to the right of
 * the paragraph before it is inside an [Indent], a paragraph that
 * started with a tag a [Tagged], and both close where the text comes
 * back to the left. So a package only says where the text is (.RS:
 * further right by so much), and a page that moves its margin by hand
 * comes out right the same way.
 *
 * What a page looks like depends on rules of troff's that no page
 * says and every page counts on. Those found by setting principia's
 * 553 manual pages beside troff's own output (tests/man.sh):
 *
 *   - a line's end is a space; two after a sentence (a dot, ? or !,
 *     and a quote or a parenthesis closing after it); one when the
 *     line ended with a blank, which is why "e.g. " is written with
 *     one;
 *   - .ns takes the space of the next request, unless a line was
 *     being filled;
 *   - a tab in a filled line is as wide as it would be from the start
 *     of the line as written, not from where its words end up, and
 *     the line before may end in front of it;
 *   - a terminal has whole columns: 0.75i is 7, and 2.5 columns to the
 *     left of 12.5 is 9.
 *)

(* What is read, before it is a tree: each thing with how far right of
 * the text's margin it is. A tag has two places, its own and its
 * body's. [Open] and [Close] are round what a footnote has, or what
 * is to stay on one sheet. *)
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
  (* the text's margin, from where a place said alone counts (.in 7):
   * the manual's 5 letters, a paper's 0 *)
  base : float;
  (* the line's length, for .ll said alone *)
  length : float;
  (* troff's own indent, from the text's margin *)
  mutable indent : float;
  mutable indent_before : float;
  (* .ti: the next line's place *)
  mutable ti : float option;
  (* .ll: how much shorter than the others the lines are *)
  mutable short : float;
  mutable short_before : float;
  mutable fill : bool;
  mutable tabs : float list;
  mutable center : int;
  (* .ns: the spaces asked are not made, until some text *)
  mutable no_space : bool;
  (* the paragraph being read, its last words first *)
  mutable par : Doc.inline list;
  mutable started : bool;
  mutable first : float;
  (* the stops there were when it started *)
  mutable par_tabs : float list;
  (* the line before ended a sentence; it ended with \c; with a blank *)
  mutable sentence : bool;
  mutable glued : bool;
  mutable blank_end : bool;
  (* the next line of text is not the paragraph's but this one's: a
   * heading's words, a tag *)
  mutable capture : (Doc.inline list -> unit) option;
  (* a tag was just said, and no word of its body yet *)
  mutable tag_open : bool;
  (* a font asked for one line *)
  mutable one_line : bool;
  (* the paragraph being read is a heading, of this level *)
  mutable heading : int option;
  mutable items : item list;
}

(* [create roff base length tabs] *)
val create : Roff.t -> float -> float -> float list -> t

val emit : t -> item -> unit

(* the paragraph so far is one: every request that ends a line *)
val break : t -> unit

(* [gap t n]: n lines of space, unless .ns *)
val gap : t -> float -> unit

(* [text t words sentence glued]: a line's words, added to the
 * paragraph (or given to what was waiting for them); whether they end
 * a sentence, and whether the line ended with \c *)
val text : t -> Doc.inline list -> bool -> bool -> unit

(* [aside t run]: the text being read put aside, [run] reads another
 * (a table's cell of several lines, with the package's macros in it),
 * and the first is back as it was: the other's words, and what [run]
 * gave *)
val aside : t -> (unit -> 'a) -> Doc.inline list * 'a

(* a line of text as it was written *)
val line : t -> string -> unit

(* one of troff's own requests; false if it is not one known here *)
val request : t -> string -> string list -> bool

val ends_sentence : Doc.inline list -> bool

(* does a macro's last argument end with \c *)
val glued : string list -> bool

(* a length as written, in ens *)
val length : t -> string -> float

(* on a terminal, the column on the left of a place *)
val column : t -> float -> float

(* [moved t from s]: a place said from the one there is: +2, -2, or 7 *)
val moved : t -> float -> string -> float

(* the tree, from the places *)
val tree : t -> Doc.block list
