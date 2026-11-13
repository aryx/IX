(* Css: style sheets. This module reads CSS1's rules and matches them
   against the tree. It is what a script's selectors use (querySelector
   and matches, in Script_dom), and it reads a style= attribute's
   declarations. The cascade of the page's sheets is done by Cascade,
   and the meaning of the properties is given by Computed.

   Mosaic's looks were chosen by the browser (Looks.mli); Netscape let
   the page choose some of them (<font>, <center>, bgcolor=) by writing
   them into the HTML, tag by tag. Cascading Style Sheets took the
   looks out of the HTML and into rules of their own (Håkon Wium Lie's
   proposal, 1994; CSS1, W3C, December 1996; Internet Explorer 3 had it
   that year, and Netscape 4 the next):

     p.note, blockquote { color: #660000; font-style: italic }
     ^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     selectors            declarations: a property, a value

   The rules are in a <style> element of the page (or a file it links
   to), or in the style="..." attribute of one element. Here are the
   words of CSS1 kept here:

     selector      what it matches                  specificity
     p             an element of that name          (0, 0, 1)
     .note         class="note" (one of its words)  (0, 1, 0)
     #top          id="top"                         (1, 0, 0)
     p.note        both: the counts added           (0, 1, 1)
     ul li         an li inside a ul, at any depth  (0, 0, 2)
     *             any element                      (0, 0, 0)

   **The cascade**, for one element and one property: of the rules
   whose selector matches the element, the one with the highest
   **specificity** wins, comparing (ids, classes, names) from left to
   right. Between equals, the later one in the sheet wins, and the
   element's style="..." beats them all. Here is a worked example
   (notes_browser.md section 10, also in the tests):

     p        { color: black }       (0, 0, 1)
     .intro   { color: green }       (0, 1, 0)
     p.intro  { color: red }         (0, 1, 1)
     #top     { color: blue }        (1, 0, 0)

     <p class=intro>              red: p.intro beats .intro and p
     <p class=intro id=top>       blue
     <p id=top style="color: gray">  gray

   When no rule says anything about an element, **inheritance** gives
   the value (for the colour, the font and the alignment, it is the
   parent's), or else the property's initial value does (for margins).
   That is Computed's business, as is what each property means. And
   before the page's rules come the browser's own: ua.css, the "user
   agent style sheet", which is what Mosaic's table of looks always
   was.

   The sheet is read by Css_syntax (tokens and blocks, as in CSS Syntax
   Level 3, so nothing is cut in the wrong place and what does not
   parse is skipped). The selectors are read by Selectors (Level 3: > +
   ~, attributes, :not(), :first-child, :link...). A declaration marked
   !important beats every one that is not, whatever its specificity.
   Not done here: @media (it is skipped, because Cascade evaluates it),
   @import, <link rel=stylesheet> (a sheet fetched like a picture), and
   the shorthand properties other than margin.

   Reference: W3C, "Cascading Style Sheets, level 1" (1996), sections
   1 (the basic concepts), 3 (the cascade: 3.2, the order) and 5 (the
   properties); Håkon Wium Lie's thesis, "Cascading Style Sheets"
   (2005), chapter 6. *)

(* a rule for one selector (a group such as "h1, h2 { }" gives a rule
 * for each selector): its declarations, and the names of those that
 * are marked !important *)
type rule = { selector : Selectors.complex; declarations : (string * string) list; important : string list }

type sheet = rule list

(* the rules of a style sheet's text; what does not parse is skipped *)
val parse : string -> sheet

(* "color: red; font-size: 2em": the properties are lowercased, and the
 * values trimmed *)
val declarations : string -> (string * string) list

(* (ids, classes, names) *)
val specificity : Selectors.complex -> int * int * int

(* [matches selector ancestors e]: [ancestors] are the element's
 * ancestors, the nearest first *)
val matches : Selectors.complex -> Dom.element list -> Dom.element -> bool
