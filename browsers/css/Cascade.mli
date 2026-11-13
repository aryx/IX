(* Cascade: for each element and each property, it finds the declaration
   that wins, over the browser's style sheet and the page's. @media
   rules are evaluated, and the rules are indexed.

   (See mini-chrome's notes_css_engine.md section 4.) The declarations
   that apply to an element are sorted, and the last one wins:

     1. by origin and importance: the browser's sheet (the user
        agent's, ua.css), then the page's (its <style>s, its <link>ed
        sheets), then the page's !important, then the browser's
        !important;
     2. by specificity (Selectors), with an element's style="..." above
        any selector;
     3. by the order in which they were written.

     p { color: black }  .x { color: green !important }  #a { color: red }
     <p id=a class=x>    green: !important beats a higher specificity

   **@media** rules count only if their query holds for this window.
   The query is a list of queries, and any of them may be true. Each
   is a media type (screen, all, but print never) and features joined
   by "and" (min-width, max-width, min-height, max-height,
   orientation, prefers-color-scheme: light, and
   prefers-reduced-motion: reduce never), with "not" and "only"
   understood. So (max-width: 800px) is false in a window of 976
   pixels, and Wikipedia's rules for phones sleep. @supports is taken
   as true for what the query names (for a browser that reads CSS3
   syntax), the sheets of @import are for the caller to fetch, and the
   rest of the at-rules (@font-face, @keyframes...) are skipped.

   **The index.** Trying every rule on every element costs rules times
   elements: Wikipedia's 1,391 rules on an article's ten thousand
   elements are fourteen million tries. So each rule is filed under its
   last compound's most telling part: its id, else its first class,
   else its name, else "any". An element then tries only the rules
   filed under its id, its classes, its name, and "any", which is a few
   dozen. WebKit's and Blink's rule sets do the same. Then there is the
   **ancestor filter**. What a rule's selector asks of the element's
   ancestors (the ids, classes and names of its compounds joined by
   descendant and child combinators) is checked against what the
   ancestors have, which is kept as the tree is walked. A long selector
   like Wikipedia's "html.night .mw-parser-output a" fails there at
   once, without walking up (this is WebKit's selector filter, which is
   a Bloom filter there and a counted table here). On a Wikipedia
   article (5,637 elements, 1,557 rules), the cascade went from 0.95 s
   to 0.54 s.

   **Presentational hints** are the attributes that were style before
   style sheets: bgcolor=, width= and height=, align=, valign=, <table
   border= cellpadding=>, <font color= size=>, <body text= link=>, and
   <br clear=>. They count as the page's declarations of specificity 0,
   under all its rules (WHATWG HTML, "Rendering"). Hacker News is made
   of them: <td bgcolor=#ff6600>.

   What is given back is the **declared value** of each property, which
   is still text (Css_syntax's components). Computed makes values of
   them, var() included, since a custom property is inherited like a
   colour.

   In the system, here is a style sheet's way from text to boxes:

     a sheet's text
        | Css_syntax    tokens, blocks, rules; what is not understood
        |               is skipped
     rules
        | Selectors     which elements a rule is for, and how specific
        | Cascade       this module: for an element, the winner of
        |               each property
     declared values, still text
        | Css_values    var(), lengths, calc(), colours
        | Computed      a record with a field for each property,
        |               inherited down the tree
     a style for each element
        | Box_layout    boxes, and Browser_boxes their shapes

   Browser_page finds the sheets (<style>, <link>, @import) and hands
   them here; Ua_sheet is the one that is always first. A script's
   matchMedia asks [media_matches] the same question that an @media
   rule does (webapi's Script_window).

   cs-history:
   The word in the name. Hakon Wium Lie proposed "Cascading HTML Style
   Sheets" at CERN in October 1994, days before Netscape's first
   release; Bert Bos joined him, and CSS1 was a W3C Recommendation in
   December 1996. Other style languages were proposed in those years
   (DSSSL, for one, was a programming language). What set this one
   apart is in its first word: a page's look is not one party's to
   decide. The browser has a style sheet (its defaults), the author has
   others, and the reader may have one too (larger letters, for eyes
   that need them). They *cascade*: they are combined in a fixed order
   in which each can override the one before, and the reader can have
   the last word (!important). That negotiation, and not the
   properties, is the idea. It is also the part of CSS that authors
   find hardest, since which rule wins is decided far from where it is
   written.

   wib:
   There is no reader's sheet here: there are two origins, the
   browser's and the page's, where the standard has three. The reader's
   sheet is the one the word cascade was made for, and the one browsers
   have since nearly dropped (it is a menu deep in the settings, where
   there is one).

   Reference: Hakon Wium Lie, "Cascading HTML Style Sheets -- a
   proposal" (1994), and his thesis, "Cascading Style Sheets" (Oslo,
   2005), on why this design and not the others; Lie and Bos,
   "Cascading Style Sheets, level 1" (W3C, 1996), section 3; W3C, CSS
   Cascading and Inheritance Level 4, section 6 (the
   cascade's order); Media Queries Level 3; mini-chrome's notes_css_engine.md
   section 4. *)

type origin = User_agent | Author

(* a style sheet's rules, and whose they are *)
type sheet = { origin : origin; rules : Css_syntax.rule list }

(* the window's media: its size in pixels *)
type media = { width : float; height : float }

(* whether a media query list holds, such as "screen and (max-width:
 * 800px), print" *)
val media_matches : media -> Css_syntax.component list -> bool

(* [cascade visited media sheets root]: each element's declared values,
 * which are the winning declaration of each property (custom
 * properties included), with its style= counted *)
val cascade :
  (string -> bool) ->
  media ->
  sheet list ->
  Dom.element ->
  Dom.element ->
  (string * Css_syntax.component list) list

(* [find_element table e]: [e]'s value in a table filed by
 * [Hashtbl.hash], found by identity (two equal paragraphs are two
 * elements) *)
val find_element : (int, Dom.element * 'a) Hashtbl.t -> Dom.element -> 'a option

(* the style rules of the sheets that count for [media], with their
 * @media and @supports opened. The devtools use it to show how many
 * rules a page has. *)
val rules : media -> sheet list -> (origin * Selectors.complex * Css_syntax.declaration list) list

(* where a declaration came from: a sheet's rule (with the sheet's index
 * in the list given), an attribute's hint, or the element's style= *)
type source = Rule of { sheet : int; selector : Selectors.complex } | Hint | Style_attribute

(* [explain visited media sheets root e]: e's winning declarations, as
 * [cascade] gives them, each with where it came from and whether it is
 * !important. This is a developer tools' "Styles" pane: it is for one
 * element, and every rule is tried on it (no index). *)
val explain :
  (string -> bool) -> media -> sheet list -> Dom.element -> Dom.element -> (string * Css_syntax.component list * source * bool) list
