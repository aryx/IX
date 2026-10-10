(* A text with looks, laid out: where every character sits on the page,
 * and -- the half that makes it WYSIWYG -- the way back, from a point
 * on the page to a place in the text.
 *
 *   caret_at     offset 12  ->  (x, baseline, height)   to draw the caret
 *   offset_at    a click    ->  offset 12               to put it there
 *
 * Both are needed because what is edited is not what is shown: the
 * text is a sequence of characters, the page is lines of glyphs of
 * different sizes, broken where the words stopped fitting. Bravo
 * (Xerox PARC, 1974) was the first editor where the two were the same
 * picture, and keeping them the same picture after every keystroke --
 * relaying out, putting the caret back where the person expects it --
 * is the part of a word processor that is harder than it looks.
 *
 * The page's coordinates are the typesetter's: x from the left edge of
 * the text to the right, y from its top *downwards*, since a page is
 * read top to bottom. (The playground's y is up; the caller turns the
 * page over when it draws it.)
 *
 * Lines are broken greedily, word by word -- what Bravo did and what
 * Word does -- and a word too long for the line is broken where it
 * reaches the edge. A newline ends its line and is itself a glyph of
 * no width, so that the caret can sit just before it, at the end of
 * the line it ends.
 *
 * It never sees a font. The width of a character in a look is the
 * caller's [metrics], which is how this stays a library the web
 * backend can use: the applications give Hershey's real widths, the
 * tests give ten units per character, which a person can check.
 *
 * Worked example, "ab cd ef" with every character 10 wide, a line 50
 * wide, plain looks of size 16 (a line 16 * 1.4 = 22.4 high, its
 * baseline 16 below its top):
 *
 *   line 1, top 0:     a(0) b(10) space(20) c(30) d(40)     -- "ab cd "
 *   line 2, top 22.4:  e(0) f(10)                           -- "ef"
 *
 * the space after "cd" does not fit and is not drawn (a space at the
 * end of a line is not part of the picture), and the caret at offset
 * 6, between the space and "e", is at the start of line 2.
 *
 * Where it stands, a text's way to the screen and a click's way back:
 *
 *   Rich.t  --[layout], widths from [metrics]-->  Page.t: lines of
 *     ^                                           glyphs, each placed
 *     |                                             |
 *   [offset_at]                                   Stroke_text.glyph:
 *     |                                           each one's strokes
 *   a click, in the page's coordinates              |
 *   (Office_page.to_page)                         Playground shapes
 *
 * Part_text lays out a text box so; Office_page lays out a document's
 * body, and gives [around] two kinds of boxes: the objects floating
 * on the page, and one across the whole width between every two
 * pages, so that the lines go on at the top of the next. There are
 * no pages in this module: a page break is a box nobody drew. The
 * browser has its own layout (Html_layout), of boxes in boxes; this
 * one is a single column of lines.
 *
 * A layout is made whole at each change of the text: no line is kept
 * from the one before. That is the simple way and it is enough for a
 * few pages; Office_page keeps the last layout while the document
 * is the same value.
 *
 * cs-history:
 * WYSIWYG, what you see is what you get: a comedian's line (Flip
 * Wilson's, on television, about 1970: from memory) taken up at
 * Xerox PARC for what Bravo did. Before it a text was typed with its
 * commands in it (.ce to centre a line, in the roff family) and seen
 * only when printed. Bravo could show the page because PARC had built the
 * three things it takes: a screen of dots and not of characters (the
 * Alto's), fonts as pictures of letters, and a printer that put the
 * same dots on paper (Gary Starkweather's laser printer).
 *
 * others:
 * Greedy breaking is first fit: a line takes every word that fits
 * and never looks back. Knuth and Plass (1981) choose all the breaks
 * of a paragraph together, scoring how far each line's spaces are
 * stretched: total fit, what TeX does, and Linebreak (the browser's)
 * is that algorithm here, with a worked paragraph where the two
 * differ. It sets better lines and editors do not use it, for a
 * reason that is not speed: a letter typed at the end of a paragraph
 * may then move the breaks of its first lines, and the text jumps
 * above the caret. With first fit nothing above the line before the
 * caret ever moves.
 *
 * modern:
 * A character is a glyph here, placed left to right, its width its
 * own. A real layout has a step before this one, shaping, which
 * turns a run of characters in a font into glyphs: fi as one
 * ligature, a pair like AV moved closer (kerning), Arabic letters
 * taking the form their neighbours ask for, right-to-left stretches
 * put in their order. And one after: hyphenation, which gives the
 * breaker more places to break.
 *
 * References: Donald Knuth and Michael Plass, "Breaking Paragraphs
 * into Lines" (Software -- Practice and Experience, 1981): first
 * fit, best fit and total fit are its words. The playground's
 * appkits/richtext/Page, and its Flow, which pours one text through
 * several columns and is not here. *)

(* how wide a character is, in a look: the caller's font *)
type metrics = Style.t -> string -> float

(* Where a line's slack goes -- the room between its last letter and
 * the edge:
 *
 *   Left     all of it on the right: ragged right, a typewriter's
 *   Center   half on each side
 *   Right    all of it on the left
 *   Justify  shared between the line's spaces, so that both edges are
 *            straight -- except on the last line of a paragraph,
 *            which is set Left, since stretching three words across
 *            the page is worse than a short line
 *
 * Justified here is justification of greedy lines: the breaks are
 * made as Left makes them, and only then stretched. Choosing the
 * breaks *for* justification is Knuth and Plass's idea (appkits/
 * typeset, and examples/TypesetParagraph), which Word never used. *)
type align = Left | Center | Right | Justify

type glyph = {
  offset : int; (* where in the text *)
  text : string; (* the character; "\n" for the end of a line *)
  style : Style.t;
  x : float; (* its left edge *)
  baseline : float; (* its line's baseline, from the top of the page *)
  advance : float; (* how far the next one starts *)
}

(* a line: where it is (from the top of the page), how tall, its
 * baseline, its glyphs, and the offsets it covers, [first, stop) --
 * what Flow cuts a text into columns by *)
type line = { top : float; height : float; baseline : float; cells : glyph list; first : int; stop : int }

type t

(* how a text is laid out: [plain] is aligned [Left], round nothing,
 * and one says what differs, [{ Page.plain with align = Center }] *)
type options = {
  align : align;
  (* the boxes the text goes round *)
  around : (float * float * float * float) list;
  (* a line on both sides of a box *)
  both : bool;
}

val plain : options

(* [layout options ~metrics ~width text]: [text] set in lines of at
 * most [width], aligned as [options.align] says. For example,
 * "ab cd" in a line 60 wide (every character 10) has 10 of slack:
 * Center starts it at x = 5, Right at 10, and Justify widens its one
 * space from 10 to 20 -- except that a one-line paragraph is its own
 * last line, and so stays Left.
 *
 * [around]: boxes the text must go round -- pictures, sheets floating
 * on a page, as in Publisher and Pages -- each (x0, y0, x1, y1) in the
 * page's coordinates, y down. The lines are then laid one at a time:
 * at each line's height, the width is cut by the boxes that reach it,
 * and the line takes the widest free stretch left; where none is wide
 * enough to hold text, the line goes on below the box in the way.
 *
 *     +-----------+  a line beside the box starts after it
 *     |  box      |  ......................
 *     +-----------+  ......................
 *     .....................................  and below it, the whole
 *
 * [both]: a line fills every stretch wide enough,
 * left to right, rather than only the widest -- the text on both sides
 * of a box standing in the middle of a column, as Word's "Square" and
 * Pages' "Around" do. Each stretch is aligned on its own; a line is
 * still one [line], its glyphs in x order, so the caret goes from the
 * left stretch to the right one as it goes along a line.
 *
 *     ..........  +-------+  ..........
 *     ..........  |  box  |  ..........
 *     ..........  +-------+  ..........
 *
 * A word too long for its stretch is set whole and runs over it. With
 * no boxes ([around = []]) the text is laid out exactly as before. *)
val layout : options -> metrics:metrics -> width:float -> Rich.t -> t

(* every glyph, in order *)
val glyphs : t -> glyph list

(* the lines, top to bottom *)
val lines : t -> line list

(* how tall the whole page is *)
val height : t -> float

(* [caret_at page offset]: where the caret before the character at
 * [offset] goes -- its x, its line's baseline, and its line's height *)
val caret_at : t -> int -> float * float * float

(* [offset_at page (x, y)]: the place in the text nearest to a point on
 * the page, for a click *)
val offset_at : t -> float * float -> int
