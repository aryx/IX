(* Script_dom: the page's mutable copy -- the tree a script changes
   (Browser_script.mli's "The copy").

   The browser's tree (Dom) is a value. A script needs to change it, so
   it works on nodes that know their parent and whose children and
   attributes can be changed, thawed from the page's tree; the browser
   takes it back frozen when it must lay the page out again:

     page's Dom  --thaw-->  nodes  --freeze-->  Dom  -->  layout

     <p id=a>one <b>two</b>   thawed: a node "p", its attributes
                              [id=a], its children a text "one " and a
                              node "b", each with the p as parent
     inner_html of the p      one <b>two</b>
     html_of the p            <p id="a">one <b>two</b></p>

   A text is a node named "#text". Netscape's attributes sit with the
   others while thawed, and are put apart again when frozen (as the
   lexer has them). Nothing here runs a script: the host objects that
   scripts reach these nodes through are Script_host's. *)
(* ix: the author's mini-chrome's src/webapi/dom/Script_dom.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Script_types

(* {1 Nodes} *)

val text_name : string
val is_text : node -> bool

(* a comment (its text kept, never shown) and a fragment (a parent for
 * nodes on their way into a tree) are nodes too, and not elements *)
val comment_name : string
val fragment_name : string
val is_element : node -> bool

(* the top of the tree a node is in *)
val top : node -> node

(* a node of its own, no parent yet: an element named so, or a text *)
val make_with : string -> (string * string) list -> string -> node

(* the same, with no text and no attribute (ix: they were make's optional arguments) *)
val make : string -> node

(* the page's tree copied, and back *)
val thaw : Dom.element -> node

(* [attach_shadow host children]: a shadow tree's root given to
 * [host], a fragment holding [children] (Shadow_tree.mli); its parent
 * is said to be the host, so that what is in it is in the page *)
val attach_shadow : node -> node list -> unit
val freeze : node -> Dom.element

(* every element under a node (itself too), in document order *)
val elements : node -> node list

val text_content : node -> string
val attribute : node -> string -> string option

(* an attribute set: changed in its place, or added last *)
val set_attribute : node -> string -> string -> unit

(* a node taken out of its parent; nodes given a parent (which must be
 * given them as children too) *)
val detach : node -> unit
val adopt : node -> node list -> unit

(* {1 HTML: innerHTML read and written} *)

(* a node as HTML, with its tags; its children alone *)
val html_of : node -> string
val inner_html : node -> string

(* the nodes a string of HTML stands for *)
val parse_fragment : string -> node list

(* {1 Selectors} *)

(* the elements matching a selector, in document order, among those
 * under [within] (not itself): matched with their ancestors, as the
 * page's style sheets are (Css.matches), in the tree [within] is in --
 * the page's, or one a script made and has not put in the page. A
 * selector that does not parse: a SyntaxError thrown *)
val select : t -> string -> within:node -> node list

(* whether a node itself matches a selector (el.matches, el.closest) *)
val matches : string -> node -> bool
