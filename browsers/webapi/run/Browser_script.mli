(* Browser_script: a page's scripts, and the page they see -- the DOM.

   cs-history:
   What scripts were given, in order. Netscape 2 (1995) let a script
   reach the page's forms, and write into the page as it loaded
   (document.write); Netscape 3 its images (the "rollover", a picture
   changed under the mouse, was the web's first animation). That was
   all a script could touch -- "DOM Level 0", named afterwards. Then
   "Dynamic HTML" (1997): any element, changed after the page was
   shown -- in two incompatible ways, Netscape 4's and Internet
   Explorer 4's, the worst of the browser wars for those who wrote
   pages. The W3C's DOM (Level 1, 1998; Dom.mli) is the common tree
   that ended it, and what is here: getElementById, createElement,
   appendChild. The rest came from what libraries had to invent over
   it (Script_element.mli), and innerHTML, Internet Explorer's
   shortcut (1997), which every browser copied years before any
   standard said so (HTML5).

   (mini-chrome's notes_javascript.md section 9 and
   plan_tiny_firefox.md J3.) The engine (Js_eval, with Js_value's
   values) knows nothing of pages; this module gives it one. A script
   reaches the page through **host objects**:
   [document], and an object per element it asks for, whose properties
   and methods are OCaml functions over the page's tree:

     document.getElementById("count")     the element whose id= is "count"
     document.querySelector("ul li.done") the first one Css.matches
     el.textContent = "3"                 its children replaced by the text "3"
     el.innerHTML = "<b>3</b>"            by Html_tree's parse of the string
     el.style.color = "red"               "color: red" in its style= (Css, N5)
     el.className = "done"                its class=: another rule may match now
     el.appendChild(document.createElement("li"))

   **The copy.** The browser's tree (Dom) is a value, built once and
   read by everything since TinyMosaic: the looks, the layout, the hit
   test, the forms. A script needs to change it. So the script works on
   a **mutable copy** -- nodes with a parent, their children and
   attributes changeable -- thawed from the page's tree, and [tree]
   freezes it back into a Dom.element when the browser wants to lay the
   page out again ([changed] says whether it must). An element keeps the
   same host object for as long as it lives, so [getElementById("x") ===
   getElementById("x")] and a variable holding an element stays good.
   Real engines mutate one tree and lay it out again incrementally;
   here the pages are small and a whole layout is milliseconds.

     page's Dom  --thaw-->  nodes  <--  scripts (through the host objects)
                              |
       layout  <--  Dom  <--freeze (when changed)

   **The code** is ten modules over Script_types' types, each using
   only those before it:

     Script_dom       the copy: thawed, changed, frozen, its HTML, a
                      selector's elements
     Script_host      an element's host object as the first DOM had it
                      (parentNode, appendChild, getAttribute), location,
                      a URL
     Script_events    an event as a script makes one (new CustomEvent)
     Script_element   an element's members since (matches, closest,
                      append, cloneNode, dataset, dispatchEvent)
     Script_document  document
     Script_window    window and its globals (the classes Node,
                      HTMLElement...; getComputedStyle, localStorage,
                      MutationObserver, matchMedia)
     Script_fetch     a script asking the network: the request out,
                      the answer back, who may read it (CORS); fetch
     XMLHttpRequest   the same request, the first way
     WebSocket        a connection that stays, messages both ways
                      (mini-chrome's; not taken in ix)
     Script_url       URLSearchParams
     Browser_script   this one: the tasks (the page's scripts, an event
                      dispatched, the timers) and what the browser asks

   Two of them are reached from one before: an element's later members
   (Script_host asks Script_element) and an event a script dispatches
   (Script_element asks this module), through two functions kept in the
   page's state and set here.

   **The scripts** of the page, its <script> elements, run in order once
   the page is read -- as the attribute defer asks, rather than as the
   parser meets them, so a script can find every element whatever its
   place. An error goes to the console (its line and message) and the
   next script still runs, as in every browser.

   **Events** (notes_javascript.md section 10; Event_loop.mli tells
   the loop and the timers). The browser runs one
   thing at a time, a **task**: the page's scripts at load, one event's
   handlers, one timer's function, each run to its end (a script is
   never interrupted: while it runs, the page does not move); then, if
   the tree changed, the browser lays the page out again -- once,
   however many changes. A click is found in the layout (Hit.element_at)
   and dispatched here ([click]); it **bubbles**: the handlers of the
   element it fell on, then of its parent, up to the document, unless
   one calls event.stopPropagation(); event.preventDefault() -- or an
   onclick="..." returning false, Netscape 2's way -- cancels what the
   browser would have done next (follow the link). HyperCard's path,
   a quarter century before (the playground's languages/hypertalk):

     HyperCard (1987)                        the DOM (1998)
     button -> card -> background -> stack   element -> parents -> body -> document
     "pass mouseUp" goes on                  bubbling goes on unless stopped
     the card's script answers every button  a handler on <ul> answers every <li>

   Handlers are addEventListener's (in order), el.onclick = f, and the
   onclick="..." attribute, its text compiled once into a function of
   event. setTimeout and setInterval run on the page's clock, which the
   host moves ([advance]): the frame clock in TinyFirefox, so that a
   golden frame sees the same ticks each run. alert only queues its
   message for the browser to show after the task ([take_alerts]): a
   real one stops the script until OK, which a script that is an OCaml
   call cannot do.

   What it keeps of the DOM (plan_tiny_firefox.md): document's
   getElementById, querySelector, querySelectorAll, createElement,
   createTextNode, body, title; an element's tagName, id, className,
   textContent, innerHTML, getAttribute, setAttribute, removeAttribute,
   style, value, children, firstChild, parentNode, appendChild,
   removeChild, insertBefore, remove, addEventListener,
   removeEventListener; setTimeout, setInterval, clearTimeout,
   clearInterval, alert. And, for the web's old scripts (TinyChrome's
   C8, Hacker News' hn.js): getElementsByClassName and ByTagName (the
   document's and an element's), nextSibling, nextElementSibling and
   their previous, classList, an a's href resolved, insertAdjacentHTML,
   scrollIntoView and focus (nothing to do), event.stopImmediatePropagation;
   window (the global object, its size, its listeners the document's),
   location, navigator, new URL(href, base) and its searchParams;
   XMLHttpRequest and fetch (their own modules, XMLHttpRequest and
   Script_fetch), whose requests the browser sends ([take_requests])
   and whose answers it gives back ([answer]). Not: the node types but elements
   and text, NodeList's liveness, ranges, the forms' own interface. A
   form's field typed into keeps its text in the browser (Browser_page's
   values), not in the tree; [value] reads the value= attribute.

   **In ix.** The names above that are not ix's are the playground's
   teaching browsers, where this module grew a browser at a time:
   TinyMosaic, TinyNetscape, TinyFirefox, TinyChrome. Beside the ten
   modules, six more of this directory: Event_loop (the timers),
   Script_modules (a page's modules), LocalStorage, Cors, Shadow_tree,
   and Script_prelude (what could be written in JavaScript, in a
   string). Under them, the engine (Js_eval), the page's tree and its
   reader (Dom, Html_tree: innerHTML is a parse), a selector tried on
   an element (Css.matches). Above them, one caller: Tab, of
   mini-netscape, and what it calls is the life of a page's scripts:

     the page read and laid out      create_with options tree
                                     script_sources: the files to fetch
     ... Tab fetches them, a piece each
     all had                         run_scripts_with: a task
     after every task                take_alerts, take_requests,
                                     changed and tree (laid out again),
                                     take_submission, take_navigation
     a click at a point (Hit)        click element: true if a handler
                                     prevented the browser's own
     a field typed in                input element text
     each frame                      advance ms: the timers due
     a request's bytes come          answer number result

   Every arrow goes one way: the scripts never call the browser, they
   leave what they ask in the page's state (Script_types) and the
   browser takes it when the task is over. That is what lets this
   directory have no capability at all, no network and no file: a
   page's scripts, the least trusted code of the whole system, run in
   modules that cannot reach the system (the types say so, where a
   browser in C++ needs a sandboxed process to say it). *)
(* ix: the author's mini-chrome's src/webapi/run/Browser_script.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* a page with its scripts: the engine, the copy of its tree, the console *)
type t

(* how a page's scripts are started: Math.random's [seed]; the
 * console's lines also given to [log] as they come; [base] the page's
 * address (an a's href, location, new URL resolved against it); Date's
 * clock the page's from [epoch] (ms since 1970); [viewport] the
 * window's size; [cookies]: what document.cookie reads ("a=1; b=2")
 * and what an assignment to it does with its string (one "name=value;
 * Path=/"), the browser's jar for this page
 * (ix: a record, where they were create's optional arguments) *)
type options = {
  seed : int;
  log : string -> unit;
  base : string;
  epoch : float;
  viewport : float * float;
  cookies : (unit -> string) * (string -> unit);
}

(* 1, nothing, about:blank, 0., 1000 by 768, no jar ("", nothing kept) *)
val defaults : options

(* [create_with options tree]: the tree thawed, document and window
 * defined *)
val create_with : options -> Dom.element -> t

(* the same with [defaults] *)
val create : Dom.element -> t

(* ix: how many steps a page's run may take, a host's to set (it was the
 * environment's JS_BUDGET; no bound by default) *)
val page_budget : int ref

(* the addresses of the page's scripts of their own file (<script
 * src=...>, JavaScript by their type=), resolved: for the browser to
 * fetch before [run_scripts] *)
val script_sources : t -> string list

(* the page's <script>s, in order, a <script src> its text by [source]
 * (its resolved address; one it cannot give said in the console),
 * those of another type= (JSON, modules) not: each one's error in the
 * console; then the document's DOMContentLoaded and load listeners *)
val run_scripts_with : (string -> string option) -> t -> unit

(* the same for a page whose scripts are all written in it *)
val run_scripts : t -> unit

(* a script of the host's (a console's line typed, a test's): its value,
 * or its error; errors also in the console *)
val eval : t -> string -> (Js_value.value, Js_eval.error) result

(* the tree as the scripts left it, frozen; its elements are the ones
 * [click] and [input] take (the layout of this tree gives them) *)
val tree : t -> Dom.element

(* a click on an element of the last [tree]: dispatched, bubbling;
 * whether a handler prevented the default (the link not followed).
 * [at]: where in the page's window (clientX, clientY) *)
val click : t -> Dom.element -> bool

(* the same, the pointer's place said (ix: it was click's ?at) *)
val click_at : (float * float) option -> t -> Dom.element -> bool

(* a key pressed ("a", "Enter", "ArrowUp"): keydown at the body,
 * bubbling to the document, event.key the key; whether prevented *)
val key : t -> string -> bool

(* whether a script listens on the window for events of that type *)
val listens : t -> string -> bool

(* an event of the window's, told to its listeners (those of
 * window.addEventListener and document's): a key down or up
 * ("keydown", its field "key" the platform's name of the key, made the
 * web's: "return" is "Enter"), the pointer moved, pressed or let go
 * ("mousemove", "mousedown", "mouseup": clientX, clientY, button,
 * buttons), the wheel ("wheel": deltaY). What a page that is a
 * program listens to: a game, the Playground's web platform
 * (docs/plans/plan_tinybox.md). Nothing is done, and false, if no
 * script listens; else whether one prevented what the browser does *)
(* [at]: the element under the pointer, the event's target (what a
 * page asks to know whether a press was inside its menu or outside) *)
val window_event : t -> string -> (string * Js_value.value) list -> bool

(* the same, the element it is at said (ix: it was window_event's ?at) *)
val window_event_at : Dom.element option -> t -> string -> (string * Js_value.value) list -> bool

(* a form's field typed into: its value= the text, then its input
 * event *)
val input : t -> Dom.element -> string -> unit

(* an attribute of an element of the last [tree] set, or removed
 * (None), by the browser itself: a <details> opened by a click *)
val set_attribute : t -> Dom.element -> string -> string option -> unit

(* the page's clock moved on by [ms]: the timers due run, the earliest
 * first, each a task (a thousand at most per call): the event loop's
 * turn for them (Event_loop.mli) *)
val advance : t -> float -> unit

(* the GETs XMLHttpRequest and fetch queued since the last call, the
 * oldest first, resolved: for the browser to send (their answers are
 * not given back) *)
(* where a script sent the page since the last time (location.href =
 * url, assign, replace, reload): the address, and whether it takes
 * the page's place in the history instead of being after it *)
(* [set_measure t f]: f, given the tree as it is, says where each of
 * its elements is laid out (x, y, width, height); asked when a script
 * reads a size or a position, at most once between two changes *)
val set_measure : t -> (Dom.element -> Dom.element -> (float * float * float * float) option) -> unit

(* [scrolled t y]: the window shows the page from [y] down. A number
 * kept (scrollY, and a getBoundingClientRect is from the window's
 * top), no event: the wheel turns while a script runs, and what waits
 * for a place to come into view looks again by itself
 * (IntersectionObserver, data/prelude/web/) *)
val scrolled : t -> float -> unit

(* [submit t form]: the form is about to be sent -- its submit event,
 * bubbling; whether a script prevented it. [value_now t e]: a
 * control's value as the scripts have left it *)
val submit : t -> Dom.element -> bool
val value_now : t -> Dom.element -> string option

val take_navigation : t -> (string * bool) option

(* a form a script sent itself (form.submit()), taken: the address, and
 * a POST's content type and body *)
val take_submission : t -> (string * (string * string) option) option

(* [popstate t url]: the browser went back or forward to [url], a
 * state of this same document: location is that address, and the
 * window's popstate listeners are told *)
val popstate : t -> string -> unit

(* [picture t url size]: the picture of that address has come, of that
 * size (None: it could not be had): the page's <img>s of it get their
 * load event (or error), and say complete, naturalWidth, naturalHeight *)
val picture : t -> string -> (float * float) option -> unit

(* the addresses the page gave itself since last asked, in order
 * (history.pushState; true: replaceState), no page being loaded: the
 * browser shows the last, and Back comes back through the others *)
val take_address : t -> (string * bool) list


(* Frames. [adopt page ~key frame]: the world of the document one of
   the page's <iframe>s shows ([key]: its srcdoc's text, or its src's
   address), linked to the page's -- its timers on the page's clock,
   its requests sent and answered with the page's, a key told to both,
   and the two talking by postMessage alone (the frame's window.parent,
   the page's iframe.contentWindow). [frame_tree]: that document as its
   scripts have it now *)
val adopt : t -> key:string -> t -> unit
val frame_tree : t -> string -> Dom.element option
val frames : t -> (string * t) list

val take_requests : t -> Script_types.request list

(* [answer t rid result]: the answer of the request of that number (its
 * status, headers, body and final URL), or why there is none, given
 * to the script that asked -- a task: XMLHttpRequest's onload called,
 * fetch's promise settled and its thens run *)
val answer : t -> int -> (Script_types.answer, string) result -> unit

(* the messages alert() queued since the last call, the oldest first *)
val take_alerts : t -> string list

(* whether a script changed the tree since the last [tree] *)
val changed : t -> bool

(* what the console printed, the oldest first: console.log's lines, and
 * the errors as "Uncaught TypeError: ... (line 3)" *)
val console : t -> string list

(* a line of the host's in the console: a command line's echo *)
val print : t -> string -> unit

(* the engine: a console's line typed, the host calling a script's
 * function *)
val engine : t -> Js_eval.t
