(* A tiny web browser, called www, that runs on tiny-kernel. The
 * full-size browser in ix lives in browsers/ (mini-netscape and
 * mini-lynx, built on the mini-chrome engine); this one keeps only the
 * essentials. The design is in docs/plans/done/plan_tiny_browser.md.
 *
 * The program has two parts. The reading turns the bytes of a page, as
 * they arrive, into the lines shown on the screen; it is most of what
 * follows, and the modules of TinyBrowser/. The browser around it, www,
 * this file, asks the wire's other end (TinyMachinePeer, which speaks
 * HTTPS for it) for the page and then its pictures, draws the lines as
 * they come, follows links (TinyBrowserAddress finds where they go),
 * and has TinyLibGUI's menus and an address field.
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
 *     (the tokens: TinyBrowserTokens; the open tags: TinyBrowserPage;
 *     the words, the lines and the tables: TinyBrowserLines; and
 *     TinyBrowserText under them all, the entities and UTF-8 to ASCII)
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
 * What is ours, against the twins: mini-netscape reads a page into a
 * tree (html's Dom), styles it by its style sheets, lays out boxes and
 * runs its scripts; even mini-lynx, the text one, builds that tree
 * first and walks it (Line_mode's render). Here the tree is never
 * made: a page costs what its lines cost, and a page cut anywhere
 * reads the same. Dropped with it: style sheets (but a display:none,
 * hidden), scripts, forms, a page's colours and fonts, anything but
 * ASCII.
 *
 * others:
 * Plan 9's mothra (principia's browsers/mothra/) reads a page the same
 * way: a table of the tags (html.syntax.c), a stack of looks pushed at
 * a tag and popped at its end, and each word given at once to
 * libpanel's rich text (rdhtml.c's plrtstr), with no tree. Its tables
 * are rows of cells one after the other, not columns. abaco, which
 * came after it, reads a page with libhtml's parsehtml into a list of
 * items, a table one of them, sized as a whole (abaco's html.c).
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
