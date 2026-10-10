(* Script_prelude: small web APIs written in JavaScript -- data/prelude/web/,
   embedded, run in every page before its scripts.

   As Js_prelude is for the language's library (its .mli says why a
   library is written in its own language), this is for the browser's:
   what a page's scripts expect to find on window and that needs
   nothing but what is already there.

     atob, btoa                    base64, the old way to put bytes in
                                   a string (Netscape 2's)
     TextEncoder, TextDecoder      text to bytes and back, UTF-8
     AbortController, AbortSignal  a way to say stop to what was
                                   started: a signal handed to it,
                                   aborted by who holds the controller
     structuredClone               a copy all the way down
     Headers, FormData             a request's headers and a form's
                                   fields, as objects
     crypto.getRandomValues,       random bytes -- Math.random's here,
       crypto.randomUUID           the same at each run: not a secret
     requestIdleCallback,
       reportError
     Intl                          dates, numbers, plurals and lists
                                   written for a reader: here in
                                   English only, by the plainest rule
     document's, an element's      the members a script reads or calls
       and navigator's small       in passing and that have one honest
       members                     answer here: document.domain, a
                                   TreeWalker over the page's nodes,
                                   el.role and its like (attributes
                                   read as properties), el.animate
                                   (an animation already finished),
                                   navigator.onLine

   The DOM's objects are OCaml's (Script_host: an element is a host
   object over its node), but their prototypes are ordinary objects
   (Script_window: Node, Element, HTMLElement, Document), so a method
   or an accessor put on Element.prototype in JavaScript is every
   element's: the way a page's own script extends them, used on the
   browser's side.

   What needs the browser itself is in OCaml beside (Script_window,
   Script_fetch, WebSocket); what would need more than this engine
   has -- workers, storage, streams, files -- is not there, and a
   script that asks typeof finds undefined, which is the honest
   answer.

   design:
   The web platform grows by names on one global object, and a script
   finds out what a browser has by looking: typeof AbortController,
   "fetch" in window. Feature detection, in place of asking the
   browser its name (Browser_agent.mli), is why a small browser can
   run a modern script at all: the script takes the old road when the
   new name is missing. Each name added here moves some script onto
   its newer road -- which then expects the rest of what browsers of
   that year had. *)
(* ix: the author's mini-chrome's src/webapi/Script_prelude.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* data/prelude/web/ *)
val text : string
