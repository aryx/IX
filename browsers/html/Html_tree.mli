(* Html_tree: from tokens to a tree, with the page's mistakes repaired.

   The tree a page means is not the one its tags spell. A page omits
   end tags (legal in SGML, and done in every page), omits <html>,
   <head> and <body>, and closes what it never opened. Here is the
   worked example of notes_browser.md section 4, also in the tests:

     <title>Lunch</title>            html
     <h1>Menu</h1>                    +- head
     <p>Soup of the day               |   +- title: "Lunch"
     <p>Salads:                       +- body
     <ul>                                 +- h1: "Menu"
     <li>tomato                           +- p: "Soup of the day\n"
     <li><b>cucumber</b>                  +- p: "Salads:\n"
     </ul>                                +- ul
                                              +- li: "tomato\n"
                                              +- li
                                                  +- b: "cucumber"

   (The whitespace-only text is left out of the picture.) Four repairs
   made it: <html>, <head> and <body> are implied; the second <p>
   closes the first; <ul> closes the open <p>; the second <li> closes
   the first.

   **The algorithm is a stack of open elements**, whose top is the
   element that new content goes into:

     a start tag x   1. while an open element y that x closes (Dtd.closes)
                        is found looking down the stack, before one that
                        stops the search (Dtd.stops): pop down to y, y
                        included;
                     2. x becomes a child of the top;
                     3. x is pushed, unless it is void (Dtd.is_void).
     an end tag x    pop down to the nearest open x, if there is one
                     before the search is stopped (a table cell, the
                     root); if there is none, **ignore it** (a stray
                     </b>). </p> with no open <p> makes an empty one,
                     as every browser does.
     text            appended to the top (next to the text before it,
                     if that is the top's last child).

   The head and the body: <html>, <head> and <body> are made at once,
   with the head on the stack. Head material (Dtd.is_head_element:
   title, meta, link, base, style, script) goes in the head while the
   body has not started. Anything else (a tag, or text that is not only
   spaces) starts the body, which pops the head and pushes the body.
   Later <html> and <body> tags only give their attributes (<body
   bgcolor=white>); </body> and </html> are ignored, so what follows
   them still lands in the body, as in every browser. Comments and the
   doctype are dropped. A newline right after <pre> is dropped too (as
   the spec says: "<pre>\n  x" starts with the two spaces).

   Ours and the WHATWG's differ on **misnested formatting**:

     <b><i>x</b>y</i>
       ours (and Mothra's): </b> pops i and b       b(i("x")), "y"
       the WHATWG's adoption agency algorithm:    b(i("x")), i("y")

   Every browser shows y in italics; reproducing that is
   notes_browser.md's first exercise.

   **Foreign content**: inside an <svg> (a picture in the page, which is
   how pages put their icons), XML's rules apply instead. An element
   closes only at its end tag or its "/>" (<path d="..."/>), and no HTML
   rule closes anything, so the picture's tree is whole for Box_layout
   and Svg. (The spec's MathML, and its fixing of the case of SVG's
   attribute names, are not done: attributes stay lower case, as Svg
   reads them.)

   Also not done: tables' implied <tbody> and the
   "foster parenting" of what is misplaced in a table (phase 10's),
   forms' rules, <frameset>, and the quirks of the spec's 23 insertion
   modes beyond the three above (before the body, in it, after it).

   In the system, Browser_page and mini-lynx (Lynx) call it on a page's
   text, and webapi's Script_dom calls it on the text a script gives
   (innerHTML): the same repairs are made for a page and for a piece of
   one. It reads Html_lexer's tokens and asks Dtd every question about
   an element; what it builds is a Dom.

   cs-history:
   Here is why a browser repairs. SGML let a DTD say that a tag may be
   left out when it can be inferred (</p>, </li>, <body>), and HTML
   used that from the start: a page with no <html> is a correct page.
   But authors left out far more than the DTD allowed, crossed their
   tags (<b><i></b></i>), and put <table> in <p>, and the browser that
   showed such a page looked better than the one that refused it. So
   all of them repaired, each in its own way. The W3C's answer was
   XHTML (2000): pages as XML, where one mistake means a page is not
   shown. Authors did not follow, and in 2004 people from Opera,
   Mozilla and Apple left to write down instead what browsers do with
   real pages (the WHATWG; Ian Hickson's "tree construction", with the
   insertion modes above). Since then the repairs are the standard:
   two browsers build the same tree from the same mistake. "Be liberal
   in what you accept" (Jon Postel, RFC 761, 1980) is nowhere taken
   further.

   Reference: Ian Hickson, "Tag Soup: How UAs handle
   <x> <y> </x> </y>" (2002), what each browser did before; WHATWG
   HTML, 13.2.6 "Tree construction" -- the stack of
   open elements, "has an element in scope", "generate
   implied end tags", the "in body" insertion mode; MMM's html_eval.ml,
   which does the same from its DTD; html5lib, the reference parser
   the tests' trees were compared with by hand. *)

(* the tree of a page's tokens: its root is always <html>, with a
 * <head> and a <body> *)
val parse : Html_lexer.token list -> Dom.element

(* Html_lexer.tokenize, then parse *)
val of_string : string -> Dom.element

(* ix: from mini-chrome's later Html_tree, for a page's scripts
 * (browsers/webapi). With [comments], a comment is kept as an element
 * named Dom.comment_name whose one child is its text (a script reads
 * them, because a framework uses comments as marks). *)
val parse_with : comments:bool -> Html_lexer.token list -> Dom.element
val of_string_with : comments:bool -> string -> Dom.element
