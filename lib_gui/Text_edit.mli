(* A text being edited is a piece table, a caret, a selection, and
 * every earlier version of itself (notes_gui.md section 7).
 *
 * A text editor's data structure is the whole lesson, and there are
 * three answers:
 *
 *   a string       "Hello world"      insert in the middle: copy it all
 *   a gap buffer   "Hello[    ] world"  insert at the gap: free
 *                  (Emacs, 1976; one cursor, cheap while you type in
 *                   one place, and the gap must be moved when you
 *                   click somewhere else)
 *   a piece table  the ORIGINAL text, never touched, an APPEND
 *                  buffer, only ever added to, and a list of pieces
 *                  saying what to read from where
 *
 * The piece table is the one Word used, and the one VS Code went back
 * to in 2018 (as a tree of pieces). Insert "there " after "Hello ":
 *
 *   original: "Hello world"      added: "there "
 *   pieces:   [original 0..6] [added 0..6] [original 6..11]
 *   reads as: "Hello "        + "there "  + "world"
 *
 * Nothing was copied and nothing was overwritten: an edit is a new
 * *list*, and the two buffers are shared. That is the property worth
 * the whole structure, and the reason this module is here rather than
 * a gap buffer:
 *
 *   **undo is keeping the old list.** There are no inverse
 *   operations, no journal of what-was-deleted, and no copying of the
 *   document. The past is a list of piece lists, the future is the
 *   half you popped off, and a document is a value (which is what
 *   appkits/document is built on, and what lets Inspect scrub an
 *   application as it scrubs a game).
 *
 * The append buffer is mutable and shared by every version, and that
 * is safe for exactly one reason: it is only ever *appended to*, so
 * a piece written down by an old version still says what it said.
 * That one-way rule is what makes the rest a value.
 *
 * Here is a worked example of the piece count. It is the number to
 * watch, since all the reading costs are counted in pieces:
 *
 *   of_string "Hello world"          1 piece
 *   insert "there " at 6             3 pieces  (split, then the new one)
 *   type "x" five times at the end   4 pieces, not 8: the first x
 *                                    adds one, and the four after it
 *                                    extend it instead of adding
 *   delete 5 in the middle           4 pieces
 *
 * Here is what it deliberately does not do:
 *   - coalescing several keystrokes into one undo step (every edit is
 *     its own; a real editor groups a word or a pause);
 *   - a piece *tree* rather than a list (VS Code's, which is what
 *     makes a big file's edits O(log n) rather than O(n));
 *   - anything about styles: a run of bold is another table, and that
 *     is TinyWord's problem, not this one's.
 *
 * Where it stands: Immediate's text area and mini-drscheme's two
 * texts use this module. Rich, the office suite's styled text, is
 * these pieces with a second table of runs over them. And the other
 * answer is in ix too, to read beside this one: mini-emacs's Text is
 * a gap buffer, and its undo is the journal this module does without.
 * Each change is written down ("inserted so many bytes here",
 * "deleted these bytes there") so that its inverse can be played.
 *
 * cs-history:
 * The piece table is Bravo's (Butler Lampson and Charles Simonyi,
 * Xerox PARC, 1974), the first editor where the screen showed the
 * page as it would print; Simonyi took the design to Microsoft, and
 * Word kept it. It suits a small machine for a reason other than
 * undo: the document need never be in memory. The original stays on
 * the disk and is read where a piece says, and only what was typed is
 * kept. The structure itself is credited to J Strother Moore, who
 * had it in an editor at Edinburgh before he came to PARC.
 *
 * References: Charles Crowley, "Data Structures for Text Sequences"
 * (1998), which measures the string, the gap, the pieces and the rest
 * against each other; the VS Code team's "Text Buffer
 * Reimplementation" (2018), on why they left an array of lines for
 * a tree of pieces.
 *)

type t

(* a text with one piece, a caret at 0, and no history *)
val of_string : string -> t

val to_string : t -> string
val length : t -> int

(* how many pieces the table has, as in the worked example above; the
 * tests watch it *)
val pieces : t -> int

(*****************************************************************************)
(* {1 The caret and the selection} *)
(*****************************************************************************)
(* A caret is a selection of length zero, so there is one idea here
 * and not two: the [anchor] is where the selection started and the
 * [caret] is where it ends -- which may be *before* the anchor, when
 * a selection was dragged backwards. *)

val caret : t -> int
val anchor : t -> int

(* the two in order, whichever way round they are *)
val range : t -> int * int
val selected : t -> string

(* [at pos t] puts the caret at [pos], with nothing selected. *)
val at : int -> t -> t

(* [select ~anchor ~caret t] sets both ends at once. *)
val select : anchor:int -> caret:int -> t -> t

(* [to_ pos t] moves the caret to [pos] and leaves the anchor where it
 * is, which is what shift-clicking and shift-arrows do. *)
val to_ : int -> t -> t

(*****************************************************************************)
(* {1 Editing} *)
(*****************************************************************************)

(* [insert s t] inserts [s] at the caret, replacing the selection if
 * there is one. *)
val insert : string -> t -> t

(* backspace and delete; when there is a selection, both delete it *)
val delete_backward : t -> t
val delete_forward : t -> t

(* [delete ~from ~len t] is for a caller that knows what it wants
 * gone. *)
val delete : from:int -> len:int -> t -> t

(*****************************************************************************)
(* {1 The past} *)
(*****************************************************************************)

(* the versions it can go back to, and forward to again *)
val undo : t -> t
val redo : t -> t
val undos : t -> int
val redos : t -> int

(*****************************************************************************)
(* {1 What a view needs} *)
(*****************************************************************************)

(* [lines ~width t] breaks the text into lines of at most [width]
 * characters, each with the offset it starts at. It uses greedy word
 * wrap (it breaks at the last space that fits, and mid-word only when
 * a word is longer than the line), plus the breaks the text asks for
 * itself with "\n".
 *
 * Greedy is what browsers and most editors do, and it is what leaves
 * the rivers and the lonely short lines that Knuth and Plass's
 * algorithm exists to fix (appkits/typeset, and
 * examples/TypesetParagraph to see the difference). *)
val lines : width:int -> t -> (int * string) list

(* [place ~width t pos] is the line [pos] is on, and how far along it,
 * both counted in characters. It is for drawing the caret. *)
val place : width:int -> t -> int -> int * int

(* [offset ~width t ~line ~column] goes the other way round, for a
 * click. *)
val offset : width:int -> t -> line:int -> column:int -> int
