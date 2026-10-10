(* Cascade: for each element and each property, the declaration that
   wins -- over the browser's style sheet and the page's, @media
   evaluated, the rules indexed.

   (notes_css_engine.md section 4.) The declarations that apply to an
   element are sorted, the last winning:

     1. origin and importance: the browser's sheet (the user agent's,
        ua.css), then the page's (its <style>s, its <link>ed sheets),
        then the page's !important, then the browser's !important;
     2. specificity (Selectors), an element's style="..." above any
        selector;
     3. the order in which they were written.

     p { color: black }  .x { color: green !important }  #a { color: red }
     <p id=a class=x>    green: !important beats a higher specificity

   **@media** rules count only if their query holds for this window:
   a list of queries, any of them true -- each a media type (screen,
   all, print never) and features joined by "and" (min-width,
   max-width, min-height, max-height, orientation,
   prefers-color-scheme: light, prefers-reduced-motion: reduce never),
   "not" and "only" understood. So (max-width: 800px) is false in
   TinyChrome's 976 pixels, and Wikipedia's rules for phones sleep.
   @supports is taken as true for what the query names (a browser that
   reads CSS3 syntax), @import's sheets are the caller's to fetch, and
   the rest of the at-rules (@font-face, @keyframes...) are skipped.

   **The index.** Trying every rule on every element is rules times
   elements: Wikipedia's 1,391 rules on an article's ten thousand
   elements are fourteen million tries. So each rule is filed under its
   last compound's most telling part -- its id, else its first class,
   else its name, else "any" -- and an element tries only the rules
   filed under its id, its classes, its name, and "any": a few dozen.
   WebKit's and Blink's rule sets do the same. And the **ancestor
   filter**: what a rule's selector asks of the element's ancestors (the
   ids, classes and names of its compounds joined by descendant and
   child combinators) is checked against the ancestors' own, kept as
   the tree is walked -- a long selector like Wikipedia's "html.night
   .mw-parser-output a" fails there at once, without walking up
   (WebKit's selector filter, a Bloom filter there; a counted table
   here). On a Wikipedia article (5,637 elements, 1,557 rules), the
   cascade went from 0.95 s to 0.54 s.

   **Presentational hints**: the attributes that were style before
   style sheets -- bgcolor=, width= and height=, align=, valign=,
   <table border= cellpadding=>, <font color= size=>, <body text=
   link=>, <br clear=> -- count as the page's declarations of
   specificity 0, under all its rules (WHATWG HTML, "Rendering"). Hacker
   News is made of them: <td bgcolor=#ff6600>.

   What is given back is the **declared value** of each property, still
   text (Css_syntax's components): Computed makes values of them,
   var() included, since a custom property is inherited like a colour.

   In the system, a style sheet's way from text to boxes:

     a sheet's text
        | Css_syntax    tokens, blocks, rules; what is not understood
        |               skipped
     rules
        | Selectors     which elements a rule is for, and how specific
        | Cascade       this module: for an element, the winner of
        |               each property
     declared values, text still
        | Css_values    var(), lengths, calc(), colours
        | Computed      a record a property a field, inherited down
        |               the tree
     a style an element
        | Box_layout    boxes, and Browser_boxes their shapes

   Browser_page finds the sheets (<style>, <link>, @import) and hands
   them here; Ua_sheet is the one always first. A script's
   matchMedia asks [media_matches] the same question an @media rule
   does (webapi's Script_window).

   cs-history:
   The word in the name. Hakon Wium Lie proposed "Cascading HTML Style
   Sheets" at CERN in October 1994, days before Netscape's first
   release; Bert Bos joined him, and CSS1 was a W3C Recommendation in
   December 1996. Other style languages were proposed in those years
   (DSSSL's, for one, a programming language). What set this one apart
   is in its first word: a page's look is not one party's to decide.
   The browser has a style sheet (its defaults), the author has
   others, and the reader may have one too (larger letters, for eyes
   that need them); they *cascade*, combined by a fixed order in which
   each can override the one before and the reader can have the last
   word (!important). That negotiation, and not the properties, is the
   idea -- and the part of CSS that authors find hardest, since which
   rule wins is decided far from where it is written.

   wib:
   No reader's sheet here: two origins, the browser's and the page's,
   where the standard has three. The reader's is the one the word
   cascade was made for, and the one browsers have since nearly
   dropped (a menu deep in the settings, where there is one).

   Reference: Hakon Wium Lie, "Cascading HTML Style Sheets -- a
   proposal" (1994), and his thesis, "Cascading Style Sheets" (Oslo,
   2005), on why this design and not the others; Lie and Bos,
   "Cascading Style Sheets, level 1" (W3C, 1996), section 3; W3C, CSS
   Cascading and Inheritance Level 4, section 6 (the
   cascade's order); Media Queries Level 3; notes_css_engine.md
   section 4. *)

type origin = User_agent | Author

(* a style sheet's rules, and whose they are *)
type sheet = { origin : origin; rules : Css_syntax.rule list }

(* the window's: its size in pixels *)
type media = { width : float; height : float }

(* whether a media query list holds: "screen and (max-width: 800px),
 * print" *)
val media_matches : media -> Css_syntax.component list -> bool

(* [cascade visited media sheets root]: each element's declared values,
 * the winning declaration of each property (custom properties
 * included), its style= counted *)
val cascade :
  (string -> bool) ->
  media ->
  sheet list ->
  Dom.element ->
  Dom.element ->
  (string * Css_syntax.component list) list

(* [find_element table e]: [e]'s value in a table filed by
 * [Hashtbl.hash], found by identity (two equal paragraphs are two) *)
val find_element : (int, Dom.element * 'a) Hashtbl.t -> Dom.element -> 'a option

(* the style rules of the sheets that count for [media], their @media
 * and @supports opened: how many a page has, for the devtools *)
val rules : media -> sheet list -> (origin * Selectors.complex * Css_syntax.declaration list) list

(* where a declaration came from: a sheet's rule (the sheet's index in
 * the list given), an attribute's hint, the element's style= *)
type source = Rule of { sheet : int; selector : Selectors.complex } | Hint | Style_attribute

(* [explain media sheets root e]: e's winning declarations, as [cascade]
 * gives them, each with where it came from and whether !important --
 * a developer tools' "Styles" pane; one element, its rules all tried *)
val explain :
  (string -> bool) -> media -> sheet list -> Dom.element -> Dom.element -> (string * Css_syntax.component list * source * bool) list
