(* Script_element: an element's members that came after the first DOM,
   which libraries reach for.

   Script_host has the tree as the 1998 DOM gave it: parentNode,
   appendChild, getAttribute. Twenty years of libraries (jQuery first)
   showed what was missing, and browsers took it in: trying a selector
   on an element, putting nodes beside one another without naming the
   parent, copying a subtree, and the data-* attributes as an object.
   jQuery, htmx, Alpine and Vue use these when they are there, and some
   use only these:

   evolution:
   The standard here follows its users, by name. Trying a selector from
   a script came from Sizzle, jQuery's engine, and became
   querySelectorAll (2008) and matches. jQuery's addClass became
   classList (HTML5), its .closest() (2009) became closest, its
   .append() and .before() became the methods of the same names (2016),
   and its .data() became dataset. Each was first a function in a
   library that millions of pages loaded, and then a method that every
   element has. This is the web's way of growing, which HTML's design
   principles call paving the cowpaths, and it is why jQuery, having
   won, is needed less each year.

     el.matches("li.done")      whether the selector selects it
     el.closest("form")         itself or its first ancestor that matches
     el.contains(other)         whether other is it, or under it
     el.append(a, "text", b)    adds at its end (prepend adds at its
                                start); a string becomes a text node
     el.before(a) .after(b)     put nodes beside it, in its parent
     el.replaceWith(a)  .replaceChild(new, old)  .replaceChildren()
     el.cloneNode(true)         a copy, with its subtree if true; the
                                listeners are not copied
     el.dataset.userId          its data-user-id attribute
     el.hasAttribute, .attributes, .toggleAttribute, .getAttributeNames
     el.isConnected             whether it is in the page
     el.compareDocumentPosition(other)   which one is first, which one
                                is inside; jQuery sorts what it found
                                with it
     el.dispatchEvent(ev)  el.click()    Script_events

   getBoundingClientRect and offsetWidth give the element's box in the
   browser's layout of the page as it is now, when the browser has given
   a way to measure (Browser_script.set_measure). Without one they are
   all zeros, and a library that measures to decide gets "not shown".

   Worked example (mini-chrome's tests/browser/Unit_script_element.ml,
   not among the tests taken in ix):

     <ul id=l><li class=a>1</li><li>2</li></ul>
     const l = document.getElementById("l"), first = l.firstElementChild
     first.matches("ul > li.a")                      // true
     first.closest("ul") === l                       // true
     l.append("3", document.createElement("li"))     // 1, 2, "3", <li>
     first.after(l.lastElementChild)                 // 1, <li>, 2, "3"

   Reference: DOM Living Standard, sections 4.2.6 (ParentNode: append,
   prepend), 4.2.8 (ChildNode: before, after, replaceWith, remove),
   4.9 (Element: matches, closest). *)
(* ix: copied from src/webapi/dom/Script_element.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* [get t n k] is the member [k] of [n], if it is one of these *)
val get : t -> node -> string -> value option
