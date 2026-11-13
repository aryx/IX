(* Script_window: the globals of a page, which a library looks for on
   window before it does anything.

   Besides the language's own globals (Js_globals, in the engine) and
   document, a script in a page has a crowd of things that are the
   browser's: classes to test a value against, the window's size,
   places to keep a little data, and ways to be told of a change. A
   library takes stock of them as it starts, and if one is missing, the
   library stops at its first line. So they are here. Most of them do
   less than the real thing: each does as much as it can mean for a
   page here:

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
         the classes of the host objects, for el instanceof HTMLElement
         and Node.ELEMENT_NODE; a method that a library adds to
         Element.prototype is every element's. An element's prototype
         is its tag's (HTMLInputElement for an <input>), or
         HTMLElement for a tag without one
     getComputedStyle(el)
         gives what the element's own style= says, and the defaults of
         a few properties (display: block). The cascade's answer is the
         browser's, computed after the script, so a script cannot ask
         for it
     MutationObserver, ResizeObserver, IntersectionObserver
         can be made and told to observe; only IntersectionObserver
         is called back (Script_prelude's, which says all is in view)
     localStorage, sessionStorage
         kept as long as the page is, not after (LocalStorage.mli)
     matchMedia(query)       matches by the window's size
     history.pushState       changes the address, with no page loaded
     performance.now()       the page's clock
     screen, devicePixelRatio, scrollX, scrollY, getSelection,
     customElements, CSS.supports, requestIdleCallback...

   and window itself, an object through which every global is read and
   set (window.x = 1 makes the global x). It has its size and its
   location, and its listeners are the document's.

   Reference: Aaron Andersen, "History of the browser user-agent
   string" (2008); HTML Living Standard, section 7.2.2 (the Window object);
   CSSOM, section 7.2 (getComputedStyle); Web IDL, for what "an
   interface object" such as Node is. *)
(* ix: copied from src/webapi/window/Script_window.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* defines the globals above, and notes the host objects' prototypes in
 * the page's state. It returns the window object, made for a viewport
 * of that width and height *)
val install : t -> viewport:float * float -> (string -> value -> unit) -> value
