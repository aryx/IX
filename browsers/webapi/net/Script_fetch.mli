(* Script_fetch: a script asking the network. It has the request that
   leaves a page, the answer that comes back to it, and fetch.

   A page's script cannot wait: it runs to its end before the page
   moves again (Js_eval), and an answer takes a second. So asking takes
   two tasks, with the browser between them:

       the script                 the browser                the server
       ----------                 -----------                ----------
       fetch("/items")
         a request queued  ---->  take_requests: sent  --->
         a promise, pending       (Tab, by Http_client)
       ... runs to its end
                                  the answer arrives   <---  200, a body
       then(...) called    <----  Browser_script.answer:
       the page changed           a task; then laid out again

   [ask] queues a request with what to do with its answer; [answer] is
   that answer coming back, found by the request's number.
   XMLHttpRequest (in its own module) and fetch are two faces of these
   two functions.

   **fetch(url, { method, headers, body })** gives a promise of a
   response. The response has ok, status, statusText, url,
   headers.get(name), and its body as promises too, text() and json():

     const r = await fetch("/items.json")
     if (r.ok) show(await r.json())

   A status of 404 is an answer (ok is false). The promise is rejected
   (with a TypeError, as browsers do) only when there is no answer:
   when there is no network, or when the answer is one the page may
   not read.

   **Who may read what.** An answer from another site is given to the
   script only if that site allows it; Cors.mli tells this rule, the
   same-origin policy and CORS. [answer] asks [Cors.readable]. An
   answer that is not readable is a failure for the script, and the
   console says so. That one check is all there is here: there is no
   preflight, and requests with credentials are not treated apart.

   Only GET and POST are sent (what the browser's Fetch sends). The
   request keeps the script's own headers, except those that only a
   browser may set (Host, Cookie, Origin, User-Agent...: the
   standard's "forbidden" names).

   In ix the browser's side is in Tab. A request taken after a task
   becomes one more piece of Tab's list of work. Http_client sends it
   and waits for the answer (the window is still meanwhile), and the
   answer is given in the same piece; the page is laid out again if
   the answer's task changed it. Tab sends the request's method,
   address and body. The headers that the script set are kept in the
   request (Script_types' said) but are not sent yet. Of the server's
   headers, the answer comes back with Content-Type alone.

   cs-history:
   fetch itself dates from 2015 (Chrome 42, Firefox 39; the Fetch
   Standard, Anne van Kesteren, WHATWG). It is the same request as
   XMLHttpRequest's, as a promise. Its standard is where what every
   request of a browser does (a page's, a picture's, a script's) was at
   last written in one place.

   Reference: the Fetch Standard (fetch.spec.whatwg.org), section 5
   (the Fetch API; 5.6, the fetch method). *)
(* ix: copied from src/webapi/net/Script_fetch.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* [ask t ~meth ~url ~post k] queues a request for the browser, with
 * [url] resolved against the page's address, and returns the request's
 * number. [k] is called with its answer, or with the reason there is
 * none. [cors] says whether the answer is given only if the page may
 * read it; it is false for a classic <script src>, which runs from
 * anywhere *)
val ask : cors:bool -> headers:(string * string) list -> t -> meth:string -> url:string -> post:(string * string) option -> ((answer, string) result -> unit) -> int

(* forgets the request of that number, so that its answer is not given
 * to the script (abort) *)
val forget : t -> int -> unit

(* [answer t rid result] gives the answer of request [rid] to whoever
 * asked, if the page may read it. It must be called in a task of the
 * engine (as Browser_script.answer does) *)
val answer : t -> int -> (answer, string) result -> unit

(* a header's value, whatever the case of its name *)
val header : answer -> string -> string option

(* calls a script's function from a host function; the console says the
 * error it throws, if any *)
val call : t -> value -> this:value -> value list -> unit

(* parses a text as JSON with the engine's JSON.parse, which throws a
 * SyntaxError when the text is not JSON *)
val parse_json : t -> string -> value

(* defines fetch *)
val install : t -> (string -> value -> unit) -> unit

(* a request's body as the bytes to send: a text is sent as it is, and
 * in an array of bytes each byte becomes a character *)
val body_bytes : Js_value.value -> string
