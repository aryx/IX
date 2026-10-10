(* Selectors: which elements a rule is for -- CSS's selectors, Level 3.

   (notes_css_engine.md section 3.) A selector is **compounds joined by
   combinators**:

     ul > li.item:not(.done)
       compound "ul"; combinator ">" (a child); compound "li.item:not(.done)":
       the name li, the class item, and :not(.done)

   Combinators: a space (a descendant, at any depth), ">" (a child),
   "+" (the sibling just before), "~" (any sibling before). A compound: a
   name or "*", then any of #id, .class, [attr], [attr=v], [attr~=v]
   (one of its words), [attr|=v], [attr^=v], [attr$=v], [attr*=v]
   (starts, ends, contains; "i" before the "]" to ignore case),
   pseudo-classes -- :first-child, :last-child, :only-child,
   :nth-child(an+b), :not(...), :is(...) and :where(...) (any of a
   list, :where counting nothing in specificity), :link, :visited,
   :hover, :active, :focus, :root, :empty, :checked, :disabled,
   :enabled -- and a pseudo-element
   at its end (::before, ::after: boxes the element makes).

   **Matching goes right to left**: the element must match the last
   compound; then, for a descendant combinator, some ancestor the one
   before it (the nearest that matches, then further up if what is left
   fails: backtracking), for a child its parent, for siblings the
   elements before it in its parent. Right to left, because most
   elements fail the last compound at once -- it names a class they do
   not have -- and nothing further is looked at.

   **Specificity** is (ids, classes + attributes + pseudo-classes, names
   + pseudo-elements), compared left to right; :not(x) counts as its
   most specific x; "*" nothing:

     ul > li.item:not(.done)     (0, 2, 2)
     #nav a:hover                (1, 1, 1)

   :first-of-type and :last-of-type are read as :first-child and
   :last-child (the same on most pages; the difference an exercise).
   The pages are static here: :hover, :active and :focus never match
   (a pointer's state would make every move restyle the page: an
   exercise), and :visited is the host's.

   In the system: Cascade matches every rule of every sheet with
   this, and files the rules by what their last compound names (an
   id, a class, a name); Css is the same matching for the first
   lessons;
   and a script's querySelector and closest are this matching too,
   through Css (webapi's Script_dom).

   evolution:
   How they grew. CSS1 (1996) could name an element by its type, its
   class, its id, and by an ancestor ("ul li"). CSS2 (1998) added the
   child (>), the next sibling (+), attributes ([href]) and :first-child;
   Level 3 (written from 1999, a Recommendation in 2011) the rest of
   what is here: ~, the attribute's substrings, :not(), :nth-child().
   The same little language then left style sheets: a script finds
   elements with it (John Resig's jQuery, 2006, whose $("ul > li.item")
   made selectors the way to say "these elements"; then the browsers'
   own querySelector, 2008), and so do tests and scrapers. It is the
   web's query language, and it was designed to be matched fast on one
   element at a time, from the right: is this an li.item? is its
   parent a ul? -- never by searching the tree.

   Reference: W3C, "Selectors Level 3" (2018), sections 3 to 16;
   notes_css_engine.md section 3. *)

type attr_op = Exists | Equals | Includes | Dash | Prefix | Suffix | Substring

type pseudo_class =
  | First_child
  | Last_child
  | Only_child
  | Nth_child of int * int (* an+b *)
  | Not of complex list
  | Is of complex list * bool (* :is(), counting as its most specific; :where(), counting nothing *)
  | Link
  | Visited
  | Hover
  | Active
  | Focus
  | Root
  | Empty
  | Checked
  | Disabled
  | Enabled

and simple =
  | Type of string (* lowercased *)
  | Universal
  | Id of string
  | Class of string
  | Attr of string * attr_op * string * bool (* the name, the test, the value, case ignored *)
  | Pseudo of pseudo_class
  | Pseudo_element of string (* "before", "after" *)

and combinator = Descendant | Child | Next_sibling | Subsequent_sibling

(* compounds from left to right, each with the combinator joining it to
 * the next: "ul > li" is [ ([Type "ul"], Some Child); ([Type "li"], None) ] *)
and complex = (simple list * combinator option) list

(* a selector list, "h1, h2": None if any part is not understood (the
 * whole rule is then dropped, as CSS says) *)
val parse : Css_syntax.component list -> complex list option
val parse_string : string -> complex list option

val specificity : complex -> int * int * int

(* the pseudo-element a selector ends with, if any: its rule styles
 * that generated box, not the element *)
val pseudo_element : complex -> string option

(* [matches sel ancestors e]: [ancestors] the element's, the nearest
 * first. A selector with a pseudo-element matches the element whose
 * box it is. matches_visited: [visited] says whether a link's href
 * was visited (matches: never). (ix: two functions, where [visited]
 * was optional.) *)
val matches : complex -> Dom.element list -> Dom.element -> bool
val matches_visited : (string -> bool) -> complex -> Dom.element list -> Dom.element -> bool

(* written back: "ul > li.item:not(.done)" *)
val to_string : complex -> string
