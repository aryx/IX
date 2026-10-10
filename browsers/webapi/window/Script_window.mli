(* Script_window: the globals of a page -- what a library looks for on
   window before it does anything.

   A script in a page has, besides the language's own globals
   (Js_globals, the engine's) and document, a crowd of things that are the
   browser's: classes to test a value against, the window's size,
   places to keep a little data, ways to be told of a change. A library
   takes stock of them as it starts, and one that is missing ends it at
   its first line. So they are here, most of them less than the real
   thing, each as much as a page here can mean:

   cs-history:
   Two of these names are fossils. navigator is Netscape Navigator,
   whose scripts could ask it what it was; every browser since has an
   object of that name. And its userAgent begins "Mozilla/5.0" in all
   of them, ours too. Mozilla was Netscape's code name ("Mosaic
   killer"); servers sent their good pages (with frames, in 1996) to
   browsers that said "Mozilla", so Internet Explorer said "Mozilla/2.0
   (compatible; MSIE 3.0...)" to get them; later sites sent their good
   pages to Gecko, so KHTML said "like Gecko", and to Safari, so Chrome
   says "Safari" and "KHTML, like Gecko" besides. Each browser's string
   is the list of those it once had to pass for. The lesson was drawn
   late: ask whether the feature is there ("typeof fetch"), not who
   the browser is.

     Node, Element, HTMLElement, Text, Document, EventTarget ...
         the classes of the host objects: el instanceof HTMLElement,
         Node.ELEMENT_NODE, and a method a library adds to
         Element.prototype is every element's. Every element is an
         HTMLElement and nothing more precise (no HTMLInputElement of
         its own)
     getComputedStyle(el)
         what the element's own style= says, and the defaults of a few
         properties (display: block). The cascade's answer is the
         browser's, after the script: a script cannot ask for it
     MutationObserver, ResizeObserver, IntersectionObserver
         can be made and told to observe; are never called back
     localStorage, sessionStorage
         kept as long as the page is, not after (LocalStorage.mli)
     matchMedia(query)       never matches
     history.pushState       the address does not change
     performance.now()       the page's clock
     screen, devicePixelRatio, scrollX, scrollY, getSelection,
     customElements, CSS.supports, requestIdleCallback's absence...

   and window itself: an object through which every global is read and
   set (window.x = 1 makes the global x), with its size, its location,
   and the document's listeners for its own.

   Reference: Aaron Andersen, "History of the browser user-agent
   string" (2008); HTML Living Standard, section 7.2 (the Window object);
   CSSOM, section 7.2 (getComputedStyle); Web IDL, for what "an
   interface object" such as Node is. *)
(* ix: the author's mini-chrome's src/webapi/window/Script_window.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* the globals above defined, the host objects' prototypes noted in the
 * page's state; the window object, for a viewport's width and height *)
val install : t -> viewport:float * float -> (string -> value -> unit) -> value
