(* Script_dom: the page's mutable copy, the tree that a script changes
   (see "The copy" in Browser_script.mli).

   The browser's tree (Dom) is a value. A script needs to change it, so
   it works on nodes, thawed from the page's tree, that know their
   parent and whose children and attributes can be changed. The
   browser takes the tree back, frozen, when it must lay the page out
   again:

     page's Dom  --thaw-->  nodes  --freeze-->  Dom  -->  layout

     <p id=a>one <b>two</b>   thawed: a node "p" with the attributes
                              [id=a] and two children, a text "one "
                              and a node "b", each with the p as its
                              parent
     inner_html of the p      one <b>two</b>
     html_of the p            <p id="a">one <b>two</b></p>

   A text is a node named "#text". Netscape's attributes sit with the
   others while the tree is thawed, and are put apart again when it is
   frozen (as the lexer has them). Nothing here runs a script: the host
   objects through which scripts reach these nodes are Script_host's. *)
(* ix: copied from src/webapi/dom/Script_dom.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Script_types

(* {1 Nodes} *)

val text_name : string
val is_text : node -> bool

(* a comment (whose text is kept and never shown) and a fragment (a
 * parent for nodes on their way into a tree) are nodes too, but not
 * elements *)
val comment_name : string
val fragment_name : string
val is_element : node -> bool

(* the top of the tree a node is in *)
val top : node -> node

(* [make_with text attributes name] makes a new node, with no parent
 * yet: an element of that name, or a text *)
val make_with : string -> (string * string) list -> string -> node

(* the same, with no text and no attribute (ix: make_with takes what
 * were make's optional arguments) *)
val make : string -> node

(* [thaw] copies the page's tree, and [freeze] copies it back *)
val thaw : Dom.element -> node

val freeze : node -> Dom.element

(* every element under a node (itself too), in document order *)
val elements : node -> node list

val text_content : node -> string
val attribute : node -> string -> string option

(* sets an attribute: it is changed in its place, or added last *)
val set_attribute : node -> string -> string -> unit

(* [detach] takes a node out of its parent. [adopt] gives nodes a
 * parent, which must also be given them as its children *)
val detach : node -> unit
val adopt : node -> node list -> unit

(* {1 HTML: innerHTML read and written} *)

(* [html_of] gives a node as HTML, with its tags; [inner_html] gives its
 * children alone *)
val html_of : node -> string
val inner_html : node -> string

(* the nodes a string of HTML stands for *)
val parse_fragment : string -> node list

(* {1 Selectors} *)

(* the elements matching a selector, in document order, among those
 * under [within] (but not [within] itself). They are matched with their
 * ancestors, as the page's style sheets are (Css.matches), in the tree
 * that [within] is in: the page's, or one that a script made and has
 * not put in the page. A selector that does not parse throws a
 * SyntaxError *)
val select : t -> string -> within:node -> node list

(* whether a node itself matches a selector (el.matches, el.closest) *)
val matches : string -> node -> bool
