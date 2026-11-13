(* Browser_script: a page's scripts, and the page they see -- the DOM.

   cs-history:
   Here is what scripts were given, in order. Netscape 2 (1995) let a
   script reach the page's forms, and write into the page as it loaded
   (document.write); Netscape 3 let it reach the page's images (the
   "rollover", a picture changed under the mouse, was the web's first
   animation). That was all a script could touch, and it was named
   "DOM Level 0" afterwards. Then came "Dynamic HTML" (1997), where any
   element could be changed after the page was shown, but in two
   incompatible ways, Netscape 4's and Internet Explorer 4's. It was
   the worst of the browser wars for those who wrote pages. The W3C's
   DOM (Level 1, 1998; Dom.mli) is the common tree that ended it, and
   it is what is here: getElementById, createElement, appendChild. The
   rest came from what libraries had to invent over it
   (Script_element.mli), and from innerHTML, Internet Explorer's
   shortcut (1997), which every browser copied years before any
   standard said so (HTML5).

   (See mini-chrome's notes_javascript.md, section 9, and
   plan_tiny_firefox.md, J3.) The engine (Js_eval, with Js_value's
   values) knows nothing of pages; this module gives it one. A script
   reaches the page through **host objects**: [document], and an
   object for each element that it asks for, whose properties and
   methods are OCaml functions over the page's tree:

     document.getElementById("count")     the element whose id= is "count"
     document.querySelector("ul li.done") the first one Css.matches
     el.textContent = "3"                 its children replaced by the text "3"
     el.innerHTML = "<b>3</b>"            by Html_tree's parse of the string
     el.style.color = "red"               "color: red" in its style= (Css)
     el.className = "done"                its class=: another rule may match now
     el.appendChild(document.createElement("li"))

   **The copy.** The browser's tree (Dom) is a value, built once and
   read by everything: the looks, the layout, the hit test, the forms.
   A script needs to change it. So the script works on a **mutable
   copy**, thawed from the page's tree, made of nodes that have a
   parent and whose children and attributes can be changed. [tree]
   freezes it back into a Dom.element when the browser wants to lay
   the page out again ([changed] says whether it must). An element
   keeps the same host object for as long as it lives, so
   [getElementById("x") === getElementById("x")] and a variable
   holding an element stays good. Real engines mutate one tree and lay
   it out again incrementally; here the pages are small, and a whole
   layout takes milliseconds.

     page's Dom  --thaw-->  nodes  <--  scripts (through the host objects)
                              |
       layout  <--  Dom  <--freeze (when changed)

   **The code** is ten modules over Script_types' types, each using
   only those before it:

     Script_dom       the copy: thawed, changed and frozen; its HTML;
                      the elements that a selector picks
     Script_host      an element's host object as the first DOM had it
                      (parentNode, appendChild, getAttribute), location,
                      a URL
     Script_events    an event as a script makes one (new CustomEvent)
     Script_element   an element's members that came later (matches,
                      closest, append, cloneNode, dataset, dispatchEvent)
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

   Two of them are reached from a module before them, through two
   functions kept in the page's state and set here: an element's later
   members (Script_host asks Script_element), and an event that a
   script dispatches (Script_element asks this module).

   **The scripts** of the page, its <script> elements, run in order
   once the page is read, as the attribute defer asks, rather than as
   the parser meets them; so a script can find every element, whatever
   its place. An error goes to the console (with its line and message)
   and the next script still runs, as in every browser.

   **Events** (see mini-chrome's notes_javascript.md, section 10;
   Event_loop.mli tells the loop and the timers). The browser runs one
   thing at a time, a **task**: the page's scripts at load, one event's
   handlers, or one timer's function. Each one runs to its end (a
   script is never interrupted: while it runs, the page does not
   move). Then, if the tree changed, the browser lays the page out
   again, once, however many changes there were. A click is found in
   the layout (Hit.element_at) and dispatched here ([click]). It
   **bubbles**: the handlers of the element it fell on run, then those
   of its parent, up to the document, unless one of them calls
   event.stopPropagation(). event.preventDefault(), or an onclick="..."
   that returns false (Netscape 2's way), cancels what the browser
   would have done next (follow the link). HyperCard had the same path
   a decade before (see the playground's languages/hypertalk):

     HyperCard (1987)                        the DOM (1998)
     button -> card -> background -> stack   element -> parents -> body -> document
     "pass mouseUp" goes on                  bubbling goes on unless stopped
     the card's script answers every button  a handler on <ul> answers every <li>

   Handlers are those added by addEventListener (in order),
   el.onclick = f, and the onclick="..." attribute, whose text is
   compiled once into a function of event. setTimeout and setInterval
   run on the page's clock, which the host moves ([advance]). In
   mini-netscape it is the frame clock, so that a golden frame sees the
   same ticks at each run. alert only queues its message for the
   browser to show after the task ([take_alerts]). A real alert stops
   the script until OK is pressed, which a script that is an OCaml call
   cannot do.

   Here is what it keeps of the DOM (plan_tiny_firefox.md):
   - document's getElementById, querySelector, querySelectorAll,
     createElement, createTextNode, body, title;
   - an element's tagName, id, className, textContent, innerHTML,
     getAttribute, setAttribute, removeAttribute, style, value,
     children, firstChild, parentNode, appendChild, removeChild,
     insertBefore, remove, addEventListener, removeEventListener;
   - setTimeout, setInterval, clearTimeout, clearInterval, alert.
   For the web's old scripts (Hacker News' hn.js), it also keeps:
   - getElementsByClassName and getElementsByTagName (the document's
     and an element's), nextSibling, nextElementSibling and their
     previous ones, classList, an a's href resolved, insertAdjacentHTML,
     scrollIntoView and focus (which have nothing to do),
     event.stopImmediatePropagation;
   - window (the global object, with its size; its listeners are the
     document's), location, navigator, new URL(href, base) and its
     searchParams;
   - XMLHttpRequest and fetch (in their own modules, XMLHttpRequest and
     Script_fetch), whose requests the browser sends ([take_requests])
     and whose answers it gives back ([answer]).
   It does not keep the node types other than elements, text, comments
   and fragments, NodeList's liveness, ranges, or the forms' own
   interface. A form's field that was typed into keeps its text in the
   browser (Browser_page's values), not in the tree; [value] reads the value=
   attribute.

   **In ix.** This module grew in the playground's teaching browsers,
   one browser at a time (TinyMosaic, TinyNetscape, TinyFirefox,
   TinyChrome), then in mini-chrome. Beside the ten modules, this
   directory has four more: Event_loop (the timers), LocalStorage,
   Cors, and Script_prelude (what could be written in JavaScript, in a
   string). Under them are the engine (Js_eval), the page's tree and
   its reader (Dom, and Html_tree, since innerHTML is a parse), and the
   matching of a selector on an element (Css.matches). Above them there
   is one caller, mini-netscape's Tab, and what it calls is the life of
   a page's scripts:

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

   Every arrow goes one way: the scripts never call the browser; they
   leave what they ask in the page's state (Script_types), and the
   browser takes it when the task is over. That is what lets this
   directory have no capability at all, no network and no file: a
   page's scripts, the least trusted code of the whole system, run in
   modules that cannot reach the system (the types say so, where a
   browser in C++ needs a sandboxed process to say it). *)
(* ix: copied from src/webapi/run/Browser_script.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

(* a page with its scripts: the engine, the copy of its tree, the console *)
type t

(* how a page's scripts are started:
 * - [seed] is Math.random's seed;
 * - [log] is also given the console's lines as they come;
 * - [base] is the page's address (an a's href, location and new URL
 *   are resolved against it);
 * - [epoch] (in ms since 1970) is where Date's clock, the page's,
 *   starts;
 * - [viewport] is the window's size;
 * - [cookies] is the browser's jar for this page: what document.cookie
 *   reads ("a=1; b=2"), and what an assignment to it does with its
 *   string (one "name=value; Path=/").
 * (ix: a record, where they were create's optional arguments) *)
type options = {
  seed : int;
  log : string -> unit;
  base : string;
  epoch : float;
  viewport : float * float;
  cookies : (unit -> string) * (string -> unit);
}

(* a seed of 1, no log, about:blank, an epoch of 0., a window of 1000
 * by 768, and no jar (it reads "" and keeps nothing) *)
val defaults : options

(* [create_with options tree] thaws the tree, and defines document and
 * window *)
val create_with : options -> Dom.element -> t

(* the same with [defaults] *)
val create : Dom.element -> t

(* ix: how many steps a page's run may take, for the host to set (it was
 * the environment's JS_BUDGET). By default there is no bound *)
val page_budget : int ref

(* the resolved addresses of the page's scripts that have their own
 * file (a <script src=...> that is JavaScript by its type=), for the
 * browser to fetch before [run_scripts] *)
val script_sources : t -> string list

(* runs the page's <script>s, in order. A <script src> gets its text
 * from [source], given its resolved address; one that [source] cannot
 * give is said in the console. Those of another type= (JSON, a module)
 * are not run. Each script's error goes to the console. Then the
 * document's DOMContentLoaded and load listeners run *)
val run_scripts_with : (string -> string option) -> t -> unit

(* the same for a page whose scripts are all written in it *)
val run_scripts : t -> unit

(* runs a script of the host's (a line typed in a console, or a test's)
 * and gives its value, or its error; errors also go to the console *)
val eval : t -> string -> (Js_value.value, Js_eval.error) result

(* When false (the default), a page's script is read as far as it can
 * be, and what cannot be read is passed over with a warning in the
 * console (Js_parse.parse_page). When true (mini-netscape's strict=on,
 * with Js_eval.lenient false), a script that does not parse is refused
 * whole and its SyntaxError is said, as a browser does *)
val strict : bool ref

(* the tree as the scripts left it, frozen. Its elements are the ones
 * that [click] and [input] take (the layout of this tree gives them) *)
val tree : t -> Dom.element

(* dispatches a click on an element of the last [tree], bubbling, and
 * says whether a handler prevented the default (so that the link is
 * not followed) *)
val click : t -> Dom.element -> bool

(* the same, with the pointer's place given (ix: it was click's ?at):
 * [at] says where it is in the page's window (clientX, clientY) *)
val click_at : (float * float) option -> t -> Dom.element -> bool

(* a key pressed ("a", "Enter", "ArrowUp"): a keydown is dispatched at
 * the body and bubbles to the document, with the key in event.key. It
 * says whether the event was prevented *)
val key : t -> string -> bool

(* whether a script listens on the window for events of that type *)
val listens : t -> string -> bool

(* tells an event of the window to its listeners (those added by
 * window.addEventListener, and the document's). The event is one of:
 * - a key down or up ("keydown"); its field "key" is the platform's
 *   name of the key, turned into the web's ("return" becomes "Enter");
 * - the pointer moved, pressed or let go ("mousemove", "mousedown",
 *   "mouseup"), with clientX, clientY, button and buttons;
 * - the wheel ("wheel"), with deltaY.
 * These are what a page that is a program listens to, such as a game,
 * or the Playground's web platform (docs/plans/plan_tinybox.md). If no
 * script listens, nothing is done and the result is false; otherwise
 * the result says whether a listener prevented what the browser does *)
val window_event : t -> string -> (string * Js_value.value) list -> bool

(* the same, with the element it is at given (ix: it was window_event's
 * ?at). [at] is the element under the pointer, the event's target (a
 * page asks for it to know whether a press was inside its menu or
 * outside) *)
val window_event_at : Dom.element option -> t -> string -> (string * Js_value.value) list -> bool

(* a form's field typed into: its value= becomes the text, then its
 * input event is dispatched *)
val input : t -> Dom.element -> string -> unit

(* sets an attribute of an element of the last [tree], or removes it
 * (None), on behalf of the browser itself, as when a click opens a
 * <details> *)
val set_attribute : t -> Dom.element -> string -> string option -> unit

(* moves the page's clock on by [ms]. The timers due run, the earliest
 * first, each as a task (a thousand at most per call); this is the
 * event loop's turn for them (Event_loop.mli) *)
val advance : t -> float -> unit

(* [set_measure t f] gives f, which, given the tree as it is, says
 * where each of its elements is laid out (x, y, width, height). f is
 * asked when a script reads a size or a position, at most once between
 * two changes *)
val set_measure : t -> (Dom.element -> Dom.element -> (float * float * float * float) option) -> unit

(* [scrolled t y] says that the window shows the page from [y] down. It
 * only keeps a number (for scrollY, and because a getBoundingClientRect
 * is measured from the window's top) and dispatches no event: the wheel
 * turns while a script runs, and what waits for a place to come into
 * view looks again by itself (IntersectionObserver, in
 * data/prelude/web/) *)
val scrolled : t -> float -> unit

(* [submit t form] says that the form is about to be sent: it dispatches
 * the form's submit event, bubbling, and says whether a script
 * prevented it. [value_now t e] is a control's value as the scripts
 * have left it *)
val submit : t -> Dom.element -> bool
val value_now : t -> Dom.element -> string option

(* where a script sent the page since the last time (with location.href
 * = url, assign, replace or reload): the address, and whether the new
 * page takes this page's place in the history instead of coming after
 * it *)
val take_navigation : t -> (string * bool) option

(* takes the form that a script sent itself (form.submit()): the
 * address, and a POST's content type and body *)
val take_submission : t -> (string * (string * string) option) option

(* [popstate t url] says that the browser went back or forward to [url],
 * a state of this same document: location becomes that address, and
 * the window's popstate listeners are told *)
val popstate : t -> string -> unit

(* [picture t url size] says that the picture of that address has come,
 * with that size (None if it could not be had). The page's <img>s of
 * that address get their load event (or error), and say complete,
 * naturalWidth and naturalHeight *)
val picture : t -> string -> (float * float) option -> unit

(* the addresses the page gave itself since last asked, in order, with
 * no page being loaded (history.pushState; the flag is true for
 * replaceState). The browser shows the last one, and Back comes back
 * through the others *)
val take_address : t -> (string * bool) list



(* the requests (GETs and POSTs) that XMLHttpRequest and fetch queued
 * since the last call, the oldest first, with their addresses resolved,
 * for the browser to send ([answer] gives their answers back) *)
val take_requests : t -> Script_types.request list

(* [answer t rid result] gives the answer of the request of that number
 * (its status, headers, body and final URL), or the reason there is
 * none, to the script that asked. It is a task: XMLHttpRequest's onload
 * is called, or fetch's promise is settled and its thens run *)
val answer : t -> int -> (Script_types.answer, string) result -> unit

(* the messages that alert() queued since the last call, the oldest
 * first *)
val take_alerts : t -> string list

(* whether a script changed the tree since the last [tree] *)
val changed : t -> bool

(* what the console printed, the oldest first: console.log's lines, and
 * the errors as "Uncaught TypeError: ... (line 3)" *)
val console : t -> string list

(* puts a line of the host's in the console, such as a command line's
 * echo *)
val print : t -> string -> unit

(* the engine, for a line typed in a console, or for the host calling a
 * script's function *)
val engine : t -> Js_eval.t
