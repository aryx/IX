(* A tiny web browser, called www, that runs on tiny-kernel. It is
 * written in the subset of ML that both tiny-ml and OCaml accept. The
 * full-size browser in ix lives in browsers/ (mini-netscape and
 * mini-lynx, built on the mini-chrome engine); this one keeps only the
 * essentials. The design is in docs/plans/done/plan_tiny_browser.md.
 *
 * So far this file only does the reading part: it turns the bytes of a
 * page, as they arrive, into the lines shown on the screen. Fetching
 * pages, drawing, following links, and pictures are the next steps of
 * the plan.
 *
 * The main idea: {b a page is read only once, as it arrives, and turned
 * directly into lines}. There is no document tree and no style sheet.
 * Instead, the meaning of each tag is a row in a table that says
 * whether it starts a block, whether it is bold, monospace or hidden,
 * and how much it indents a list. What we keep of a page is exactly
 * what gets drawn: a list of lines, where each line is a few runs of
 * text, and each run has a column, a look (bold, etc.) and an optional
 * link.
 *
 *     messages ──► tokens ──► open tags ──► words ──► lines
 *     (raw bytes   (a tag and  (a stack giving  (wrapped    (each line a
 *      of the page, its attri-  the current     at the      list of runs,
 *      cut          butes, or   look, link and   screen      each run a text
 *      anywhere)    some text)  indentation)     width)      at a column)
 *                                                  │
 *                                          inside a table: the cells'
 *                                          words are kept and laid out
 *                                          at </table>
 *
 * A message can end anywhere, even in the middle of a tag, of an
 * entity like &amp;, or of a multi-byte UTF-8 character. The reader
 * keeps the unfinished end and re-reads it together with the next
 * message. This way the resulting lines are the same no matter how the
 * page was split (the tests check this by feeding a page one byte at a
 * time).
 *
 * Tables are the one place where we cannot produce a line right away,
 * because a column must be as wide as its widest cell, which we only
 * know at the end of the table. So the words of each cell are kept
 * until </table>. Then each column gets a width: at least its longest
 * word, its whole text if there is room, and otherwise a share of the
 * remaining room proportional to what it would need. Finally the rows
 * are laid out side by side.
 *
 * Characters: the machine's font has only 128 characters, so UTF-8 and
 * HTML entities are converted to ASCII here. A dash becomes -, a curly
 * quote becomes a straight one, an accented letter loses its accent,
 * and anything else becomes ?.
 *
 * cs-history:
 * Mosaic (1993) displayed a page progressively as it came over the
 * modem, and this browser works the same way: there are no style sheets
 * (CSS arrived in 1996), and the browser alone decides how each tag
 * looks. The name www comes from the command of CERN's line-mode
 * browser (1991), which wrapped pages to a terminal's 80 columns, just
 * as this one does on an 80-column screen of 8x16 characters.
 *
 * References:
 *  - docs/plans/done/plan_tiny_browser.md: the reasons for each choice, and
 *    what Wikipedia actually sends
 *  - browsers/README.md: the full-size browser this one is a tiny
 *    version of
 *  - the "tokenization" chapter of the HTML standard: everything a
 *    tokenizer must accept; we handle only the part that well-formed
 *    pages use
 *)

(* The look of a run is a combination of these bits. *)
val bold : int
val emph : int
val code : int

(* A run is a piece of text at a column, with a look and the address it
 * links to ("" if it is not a link); or, when [pic] is not -1, a slice
 * of a picture 16 pixels high: the picture's number times 256, plus
 * which slice. A line is a list of runs, from left to right. A rule is
 * a line drawn across the screen, under a heading or for an <hr>. *)
type run = { col : int; text : string; look : int; link : string; pic : int }
type line = { runs : run list; rule : bool }

(* A page being read and turned into lines of [width] columns. *)
type page
val create : int -> page

(* [feed page bytes] gives the next message of the page; [finish page]
 * says that the page has ended. *)
val feed : page -> string -> unit
val finish : page -> unit

(* The lines made so far, from the top of the page; the page's <title>;
 * the address in its <base>. *)
val lines : page -> line list
val title : page -> string
val base : page -> string

(* how many lines there are so far; the lines from the a-th to before
 * the b-th, from the top (what the screen shows) *)
val count : page -> int
val lines_between : page -> int -> int -> line list

(* the line where the element with that id starts, if it came *)
val anchor : page -> string -> int option

(* The page's pictures: how many, and one by its number. A picture's
 * pc_got is -1 before it is asked for, -3 once asked, -2 when there is
 * none to be had, and the rows received so far after that. *)
type picture = { pc_src : string; pc_w : int; pc_h : int; pc_alt : string; mutable pc_got : int }
val pictures : page -> int
val picture_of : page -> int -> picture

(* Converts a text to ASCII: entities and UTF-8 characters become what
 * the font can show. *)
val ascii : string -> string

(* The lines as plain text, one per line (a rule becomes dashes). *)
val dump : page -> string

(* The program www: the page at [address] asked of the wire's other end
 * (the line "www address" on port 70: TinyMachinePeer.www_address says
 * what an address can be), and drawn as it arrives on the screen, or in
 * the window, the program's descriptor 3. At the top, TinyLibGUI's
 * menus (the page: back, top, reload, quit; a few articles to go to;
 * the pages seen before) and a toolbar: Back, the address in a field
 * (a click in it, or g, gives it the keys; Enter goes there), Go.
 * Space and - show the next and the previous screenful, the arrows a
 * line; q quits and clears. When
 * the keys end (a recorded session's) and the page is all there, the
 * program ends and leaves the page on the screen. *)
val browse : string -> unit
