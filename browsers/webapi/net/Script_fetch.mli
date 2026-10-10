(* Script_fetch: a script asking the network -- the request that leaves
   a page and the answer that comes back to it; and fetch.

   A page's script cannot wait: it runs to its end before the page
   moves again (Js_eval), and an answer takes a second. So asking is
   two tasks, and the browser between them:

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
   that answer coming back, by the request's number. XMLHttpRequest
   (its own module) and fetch are two faces of these two.

   **fetch(url, { method, headers, body })** gives a promise of a
   response: ok, status, statusText, url, headers.get(name), and its
   body as promises too, text() and json():

     const r = await fetch("/items.json")
     if (r.ok) show(await r.json())

   A status of 404 is an answer (ok is false); the promise is rejected
   (a TypeError, as browsers say it) only when there is no answer: no
   network, or one the page may not read.

   **Who may read what.** An answer of another site is given to the
   script only if that site allows it: the same-origin policy and
   CORS, told in Cors.mli. [answer] asks [Cors.readable]; an answer
   that is not is a failure to the script, and said on the console.
   One check is all of it here: no preflight, no distinction of
   requests with credentials.

   GET and POST only (what the browser's Fetch sends), with the
   script's own request headers but those a browser alone may say
   (Host, Cookie, Origin, User-Agent...: the standard's "forbidden"
   names).

   In ix the browser's side is Tab's: a request taken after a task is
   one more piece of its list of work, sent by Http_client (which
   waits for the answer, the window still meanwhile) and answered in
   the same piece; the page is laid out again if the answer's task
   changed it. Of the request it sends the method, the address and
   the body; the headers the script set are kept in the request
   (Script_types' said) and not sent yet, and the answer comes back
   with its Content-Type alone of the server's headers. A page's
   modules are fetched by the same two functions (Script_modules).

   cs-history:
   fetch itself is of 2015 (Chrome 42, Firefox 39; the Fetch Standard,
   Anne van Kesteren, WHATWG): the same request as XMLHttpRequest's,
   as a promise, and the standard where what a browser's every request
   does -- a page's, a picture's, a script's -- was at last written in
   one place.

   Reference: the Fetch Standard (fetch.spec.whatwg.org), section 5
   (the Fetch API; 5.6, the fetch method). *)
(* ix: the author's mini-chrome's src/webapi/net/Script_fetch.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* [ask t ~meth ~url ~post k]: a request queued for the browser, [url]
 * resolved against the page's; [k] called with its answer, or with why
 * there is none. The request's number. [cors] (true): whether the
 * answer is given only if the page may read it -- false for a classic
 * <script src>, which runs from anywhere *)
(* [ahead]: called with the body where the answer is fetched (a thread
 * of the pool), before [k] has it: Script_types.request *)
val ask : cors:bool -> headers:(string * string) list -> ahead:(string -> unit) option -> t -> meth:string -> url:string -> post:(string * string) option -> ((answer, string) result -> unit) -> int

(* the request of that number will not be answered to (abort) *)
val forget : t -> int -> unit

(* [answer t rid result]: the answer of request [rid], given to who
 * asked, if the page may read it. To be called in a task of the
 * engine's (Browser_script.answer) *)
val answer : t -> int -> (answer, string) result -> unit

(* a header's value, whatever its name's case *)
val header : answer -> string -> string option

(* a script's function called from a host function, its error said on
 * the console *)
val call : t -> value -> this:value -> value list -> unit

(* a text as JSON, by the engine's JSON.parse (a SyntaxError thrown) *)
val parse_json : t -> string -> value

(* fetch defined *)
val install : t -> (string -> value -> unit) -> unit

(* a request's body as the bytes to send: a text as it is, an array of
 * bytes or a buffer each byte a character *)
val body_bytes : t -> Js_value.value -> string
