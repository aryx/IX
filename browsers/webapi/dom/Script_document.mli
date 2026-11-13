(* Script_document: the document object, where a script enters the
   page.

     document.getElementById("count")       an element, by its id
     document.querySelector("ul li.done")   by a selector
     document.createElement("li")           a new one, in no tree yet
     document.body, .head, .documentElement, .title, .cookie, .location

   and the document as a node, because a library asks what kind of
   thing it was given before anything else. The document has nodeType
   9, its one child is the <html> element, and its ownerDocument is
   null. jQuery's selector engine keeps no document that fails that
   test.

   What makes nodes that are not elements is here too:

     document.createTextNode("3")
     document.createComment("a mark")        Vue and Alpine leave
                                             comments where a part of
                                             the page will come
     document.createDocumentFragment()       a parent for nodes on
                                             their way; when it is
                                             appended, its children go
                                             in its place
     document.createEvent("CustomEvent")     Script_events
     document.implementation.createHTMLDocument("")   a page of its own,
                                             where a library parses
                                             HTML it does not trust
     new DOMParser().parseFromString(html, "text/html")   the same,
                                             with the HTML in its body

   Its listeners are the page's (DOMContentLoaded, and every event
   that bubbles ends there); window's are the same list.

   Reference: DOM Living Standard, section 4.5 (Document); HTML Living
   Standard, section 3.1 (the Document object). *)
(* ix: copied from src/webapi/dom/Script_document.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

val document : t -> value
