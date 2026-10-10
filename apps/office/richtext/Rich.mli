(* A text with looks: the characters, and which of them are bold.
 *
 * The characters are gui/Text_edit's piece table -- the structure
 * Bravo introduced (Lampson and Simonyi, Xerox PARC, 1974) and Word
 * inherited through Simonyi -- with its caret and selection. The looks
 * are a second table beside it, of **runs**: stretches of characters
 * that all look the same, each stored once.
 *
 *   "The quick brown fox"
 *    |---|-----------|---|
 *    plain    bold    plain       3 runs, not 19 styles
 *
 * Every edit is then surgery on two tables at once, and it is the
 * same surgery the piece table does -- split at a position, keep what
 * is on either side:
 *
 *   restyle "brown fox" italic
 *    |---|------|-----|----|
 *    plain  bold  bold  italic       "quick " stays bold, "brown"
 *                +ital              becomes both, " fox" is
 *                                   split off the plain run
 *
 * and after every edit, two neighbours that have come to look the
 * same are merged, so the table stays as short as the text's looks
 * really are.
 *
 * The table is a list of (length, look): lengths and not positions,
 * so that a character typed changes one number and not the start of
 * every run after it. The two pictures above, and a letter typed:
 *
 *   [(4, plain); (11, bold); (4, plain)]       "The " "quick brown" " fox"
 *   restyle "brown fox" italic                 4, 6, 5, 4
 *   or type x inside "quick"                   4, 12, 4: the bold run
 *                                              split at the caret, a
 *                                              run of 1 put between,
 *                                              and the three merged
 *
 * ([runs] gives each run its start too. Lengths and offsets are
 * bytes, as Text_edit's.)
 *
 * Two rules every word processor has, and that are easy to get wrong:
 *
 *   - **what you type looks like what is before it.** Typing inside a
 *     bold word types bold; at the very start of the text, it takes
 *     the look of what comes after; typing over a selection, the look
 *     of its first character.
 *   - **a look set with nothing selected is for what you type next.**
 *     Press bold with the caret in plain text and nothing changes on
 *     the screen, but the next characters come out bold. That pending
 *     look is the "typing style", and moving the caret forgets it.
 *
 * A text with looks is a value, like everything else here, so undo is
 * appkits/document/Undo over it: the old characters and the old runs
 * together, kept -- not the command pattern's "and put the looks
 * back", which is where the bugs of rich text editors have always
 * lived.
 *
 * What it deliberately does not have: paragraph looks (alignment,
 * indents -- a paragraph is only text between newlines here), named
 * styles ("Heading 1", which is a look with a name and an
 * inheritance), and fonts: a look is weight, slant, rules and size,
 * because the stroke font it will be drawn in has one face.
 *
 * Where it stands (the names above are the playground's: gui/Text_edit
 * is lib_gui's Text_edit here, appkits/document/Undo is Undo):
 *
 *   Text_edit   the characters, caret, selection        lib_gui
 *   Style       a look
 *   Rich        the two together: this module
 *   Page        Rich -> lines of glyphs, each with its place
 *   Stroke_text a glyph in its look -> strokes
 *
 * Part_text is a Rich with a menu, a part of any document; a
 * document's body is a Rich for each slide, and its header and
 * footer are two more (Document). Nothing here measures or draws.
 *
 * cs-history:
 * Bravo (Butler Lampson and Charles Simonyi, Xerox PARC, 1974) ran
 * on the Alto, whose screen was a page standing up, 606 by 808 dots,
 * and was the first editor to show a text in its fonts, bold and
 * italic, as it would print. Its text was a piece table (the idea
 * is credited to J Strother Moore) and its looks were
 * runs over it. Simonyi went to Microsoft in 1981 and wrote Word
 * (1983) with Richard Brodie on the same two structures. Word's
 * files kept them as they were: a "fast save" wrote only the new
 * pieces at the end of the file, which was fast on a floppy, and is
 * how text someone had deleted could still be read in a document
 * sent out.
 *
 * others:
 * The other way to keep looks is a tree: HTML's. Runs are flat, each
 * carrying its whole look; elements nest, each adding one thing to
 * what is round it. The second picture above as a tree has to cut
 * the italic in two, since an element cannot start inside another
 * and end outside it:
 *
 *   The <b>quick <i>brown</i></b><i> fox</i>
 *
 * A tree is right for what really nests (a list in a table in a
 * page: Dom, in the browser), and wrong for a selection, which
 * starts and ends anywhere: an editor on a tree spends its code
 * cutting and joining elements, where [restyle] here is two splits
 * and a map. Word's and most editors' models are runs; the
 * browser's contenteditable is the tree.
 *
 * modern:
 * A list of pieces and a list of runs are both walked from the start
 * to find an offset, which is fine for a letter and slow for a book.
 * The cure is the same for both, a balanced tree whose nodes know the
 * length under them, so that an offset is found in a logarithm of
 * steps: the rope (Boehm, Atkinson and Plass, 1995) for the
 * characters, VS Code's tree of pieces (2018), and the same tree
 * for runs.
 *
 * References: the playground's appkits/richtext, and its TinyBravo
 * and TinyWord, the modal editor and the modeless one on this
 * module. Butler Lampson, "Personal Distributed Computing: The Alto
 * and Ethernet Software" (1986), for Bravo by one of its authors.
 * Hans Boehm, Russ Atkinson and Michael Plass, "Ropes: an
 * Alternative to Strings" (Software -- Practice and Experience,
 * 1995). Text_edit.mli, for the piece table worked out. *)

type t

(* a text in one look (the playground's default: [Style.plain]) *)
val of_string : style:Style.t -> string -> t

val to_string : t -> string
val length : t -> int

(* the characters, with their caret and selection *)
val edit : t -> Text_edit.t

(* (start, length, look), in order, covering the text exactly, no two
 * neighbours alike -- the worked example above as a list *)
val runs : t -> (int * int * Style.t) list

(* the look of the character starting at byte [i] *)
val style_at : t -> int -> Style.t

(*****************************************************************************)
(* {1 The caret and the selection} *)
(*****************************************************************************)
(* As Text_edit's -- and moving the caret forgets a pending look. *)

val caret : t -> int
val range : t -> int * int
val at : int -> t -> t
val select : anchor:int -> caret:int -> t -> t
val to_ : int -> t -> t

(*****************************************************************************)
(* {1 Editing} *)
(*****************************************************************************)

(* [insert s t]: [s] at the caret, replacing the selection, in the
 * typing style *)
val insert : string -> t -> t

val delete_backward : t -> t
val delete_forward : t -> t

(*****************************************************************************)
(* {1 Looks} *)
(*****************************************************************************)

(* [restyle f t]: [f] applied to the look of every character of the
 * selection -- or, with nothing selected, to the typing style, so
 * that it is what the next characters typed will look like *)
val restyle : (Style.t -> Style.t) -> t -> t

(* what the next character typed will look like *)
val typing_style : t -> Style.t
