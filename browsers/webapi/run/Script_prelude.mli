(* Script_prelude: small web APIs written in JavaScript. They are
   data/prelude/web/, embedded here and run in every page before its
   scripts.

   In ix, mini-chrome's files of that directory are put in one string,
   [text], of about 530 lines, where mini-chrome's build embeds them.
   Browser_script parses the string once, and runs it in each page's
   engine as the page's scripts are made. So about an eighth of the
   lines of webapi/ (4,400 without its tests) are in the language they
   serve.

   This module is to the browser's library what Js_prelude is to the
   language's library (Js_prelude says why a library is written in its
   own language). It holds what a page's scripts expect to find on
   window and that needs nothing but what is already there.

     atob, btoa                    base64, the old way to put bytes in
                                   a string (Netscape's)
     TextEncoder, TextDecoder      text to bytes and back, UTF-8
     AbortController, AbortSignal  a way to tell what was started to
                                   stop: it is handed a signal, which
                                   whoever holds the controller aborts
     structuredClone               a copy all the way down
     Headers, FormData             a request's headers and a form's
                                   fields, as objects
     crypto.getRandomValues,       random bytes, from Math.random here,
       crypto.randomUUID           so they are the same at each run and
                                   are not a secret
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
   element's. This is the way a page's own script extends them, used
   here on the browser's side.

   What needs the browser itself is in OCaml, in the modules beside
   this one (Script_window, Script_fetch, and mini-chrome's WebSocket).
   What would need more than this engine has (workers, storage,
   streams, files) is not there, and a script that asks with typeof
   finds undefined, which is the honest answer.

   design:
   The web platform grows by names on one global object, and a script
   finds out what a browser has by looking: typeof AbortController,
   "fetch" in window. Feature detection, in place of asking the
   browser its name (mini-chrome's Browser_agent.mli; Script_window
   tells the user agent's story), is why a small browser can
   run a modern script at all: the script takes the old road when the
   new name is missing. Each name added here moves some script onto
   its newer road, and that road then expects the rest of what
   browsers of that year had. *)
(* ix: copied from src/webapi/Script_prelude.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

(* the files of data/prelude/web/, in one string *)
val text : string
