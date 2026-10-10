(* Shadow trees: an element whose inside is its own, and the tree that
   is drawn made of two.

   A <video> has buttons, a slider, a time: elements, drawn by the
   browser, that the page's script does not find in the page and the
   page's style does not reach. Web components give a page's own
   elements the same: an element (the {host}) has, beside its children
   in the page (its {light} tree), a second tree attached to it (its
   {shadow} tree), and it is the shadow tree that is drawn in its
   place. The component's author writes the shadow tree; the page's
   author writes the children; and a <slot> in the shadow tree says
   where the children show through:

     the page                         the component's shadow tree
       <user-card>                      <div class="card">
         <span slot="name">Ada</span>     <b><slot name="name">?</slot></b>
         born in 1815                     <p><slot></slot></p>
       </user-card>                     </div>

     what is drawn (the composed, or flat, tree)
       <user-card>
         <div class="card">
           <b><span slot="name">Ada</span></b>
           <p>born in 1815</p>
         </div>
       </user-card>

   The rules, which [distribute] is:
     - a child with slot="x" goes to the shadow tree's <slot name="x">;
     - the others (text too) go to the slot with no name;
     - a slot given nothing shows its own content (the "?" above, had
       there been no name);
     - a child no slot takes is not drawn.
   The page's tree is not changed: the span is still user-card's child
   for the script, and document.querySelector(".card") still finds
   nothing. Only what is laid out is composed.

   How a host gets its shadow tree:
     - by its script: host.attachShadow({ mode: "open" }) gives the
       root, filled as any element is (src/webapi's Script_dom keeps it
       beside the host; Browser_script composes when it freezes the
       tree for the layout);
     - by the HTML itself, with no script: a <template
       shadowrootmode="open"> as the host's child is its shadow tree
       ("declarative shadow DOM"), which [composed] finds in a tree as
       the parser left it.

   What is not done. A shadow tree's own <style> should style it and
   nothing else, and the page's style should stop at the host; here
   the composed tree is styled as one page (a component's rules leak
   out, the page's leak in), and :host and ::slotted() are not read.
   Events are not retargeted (a click inside is seen as inside). A
   slot is replaced by what it is given, where a browser keeps the
   <slot> element as a box around it.

   With them, **custom elements**: a name with a dash (user-card) that
   a script gives a class to (customElements.define("user-card", class
   extends HTMLElement { ... })), whose constructor and
   connectedCallback then run for each such element of the page -- it
   is there that a component attaches its shadow tree. The registry is
   written in JavaScript (data/prelude/web/); this module is only
   the tree.

   cs-history:
   Mozilla's XBL (2001) bound hidden content to XUL's and HTML's
   elements; it is how Firefox's own widgets were made. Alex Russell
   proposed the same for the web's authors (Web Components, Fronteers,
   2011): custom elements, the shadow DOM, <template>. Chrome shipped
   a first version in 2013 and 2014; the one agreed between the
   browsers ("v1": attachShadow, <slot>, customElements.define) is of
   2016 in Chrome and Safari, 2018 in Firefox. The declarative form,
   for pages made on a server, is of 2021 in Chrome and in every
   browser since 2024. YouTube was written on the first version
   (Polymer), GitHub's own elements on the second.

   Reference: the DOM Standard, "Shadow trees"
   (https://dom.spec.whatwg.org/#shadow-trees). *)
(* ix: the author's mini-chrome's libs/dom/Shadow_tree.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* [distribute ~shadow ~light]: the shadow tree's nodes, each <slot> in
 * them replaced by the light nodes it is given (by its name: slot=
 * of an element; no name: the rest), or by its own children if it is
 * given none *)
val distribute : shadow:Dom.node list -> light:Dom.node list -> Dom.node list

(* a tree as the parser left it, each element that has a <template
 * shadowrootmode> for child composed with it; the very tree (==) if it
 * has none *)
val composed : Dom.element -> Dom.element
